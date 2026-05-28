import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';

import '../models/dtn_message.dart';

/// Service UUIDs used for BLE discovery and advertisement
final _kServiceUuid = UUID.fromString('12345678-1234-1234-1234-1234567890ab');
final _kWriteCharUuid = UUID.fromString('12345678-1234-1234-1234-1234567890ac');
final _kNotifyCharUuid = UUID.fromString('12345678-1234-1234-1234-1234567890ad');

/// BLE transport layer for Delay-Tolerant Networking (DTN) messages.
///
/// Provides bidirectional communication between BLE central and peripheral devices,
/// handling both discovery, connection, and message exchange over GATT characteristics.
/// Compatible with bluetooth_low_energy v6.x API.
class BleTransportService {
  /// Callback when a peer connects and sends its hello packet.
  /// Parameters: [peerId], [peerPreds], [peerMsgIds]
  void Function(String peerId, Map<String, double> peerPreds,
      List<String> peerMsgIds)? onPeerConnected;

  /// Callback when a DTN message is received.
  void Function(DtnMessage msg)? onMessageReceived;

  /// Custom hello packet builder. If null, uses default packet.
  Future<Map<String, dynamic>> Function()? helloPacketBuilder;

  /// Called when a new BLE peripheral is discovered during scan.
  /// Parameters: [peerId], [name], [rssi]
  void Function(String peerId, String name, int rssi)? onDeviceDiscovered;

  /// Called when a previously discovered peer disconnects or is lost.
  void Function(String peerId)? onDeviceLost;

  /// Called when a peer's display name is learned from their HELLO packet.
  /// Parameters: [peerId], [displayName]
  void Function(String peerId, String displayName)? onPeerDisplayName;

  /// Called when a peer's DTN node ID is learned from their HELLO packet.
  /// Parameters: [blePeerId], [dtnNodeId]
  void Function(String blePeerId, String dtnNodeId)? onPeerNodeId;

  // BLE Manager instances (v6: factory constructors, not .instance)
  final CentralManager _central = CentralManager();
  final PeripheralManager _peripheral = PeripheralManager();

  // Connection state maps
  final Map<String, GATTCharacteristic> _writeChars = {};
  final Map<String, GATTCharacteristic> _notifyChars = {};
  final Map<String, Peripheral> _discoveredPeers = {};
  final Map<String, Central> _connectedCentrals = {};

  // Receive buffer for incomplete frames
  final Map<String, StringBuffer> _rxBuffers = {};

  // Our own notify characteristic (when in peripheral role)
  GATTCharacteristic? _myNotifyChar;

  // Stream subscriptions
  late final StreamSubscription<BluetoothLowEnergyStateChangedEventArgs>
      _centralStateSub;
  late final StreamSubscription<BluetoothLowEnergyStateChangedEventArgs>
      _peripheralStateSub;
  late final StreamSubscription<DiscoveredEventArgs> _discoverySub;
  late final StreamSubscription<PeripheralConnectionStateChangedEventArgs>
      _centralConnSub;
  late final StreamSubscription<GATTCharacteristicNotifiedEventArgs>
      _notifiedSub;
  late final StreamSubscription<CentralConnectionStateChangedEventArgs>
      _peripheralConnSub;
  late final StreamSubscription<GATTCharacteristicWriteRequestedEventArgs>
      _writeRequestSub;
  late final StreamSubscription<GATTCharacteristicNotifyStateChangedEventArgs>
      _notifyStateSub;

  bool _isSetup = false;
  bool _isAdvertising = false;
bool _isScanning = false;
bool _isConnecting = false;

  // ────────────────────────────────────────────────────────────────────────
  // Setup & Lifecycle
  // ────────────────────────────────────────────────────────────────────────

  /// Initializes the BLE transport service.
  ///
  /// Sets up both central and peripheral managers, registers state listeners,
  /// and waits for Bluetooth to be powered on. Must be called before using
  /// advertising or scanning.
  Future<void> setup() async {
    if (_isSetup) return;
    _isSetup = true;

    // v6: No setUp() call needed; instead listen to state changes and authorize
    // manually on Android
    _centralStateSub = _central.stateChanged.listen((e) async {
      if (Platform.isAndroid &&
          e.state == BluetoothLowEnergyState.unauthorized) {
        try {
          await _central.authorize();
        } catch (_) {
          // Authorization may fail; user must grant permission in system settings
        }
      }
    });

    _peripheralStateSub = _peripheral.stateChanged.listen((e) async {
      if (Platform.isAndroid &&
          e.state == BluetoothLowEnergyState.unauthorized) {
        try {
          await _peripheral.authorize();
        } catch (_) {
          // Authorization may fail; user must grant permission in system settings
        }
      }
    });

    // v6: state is now a synchronous property, not async
    final currentState = _central.state;
    if (currentState != BluetoothLowEnergyState.poweredOn) {
      await _central.stateChanged
          .where((e) => e.state == BluetoothLowEnergyState.poweredOn)
          .first
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () =>
                throw TimeoutException('Bluetooth initialization timeout'),
          );
    }

    _listenCentralEvents();
    _listenPeripheralEvents();
  }

  /// Cleans up all resources and subscriptions.
  ///
  /// Should be called when the service is no longer needed, typically in
  /// [dispose()] of the owning widget or on app shutdown.
  Future<void> dispose() async {
    await stopAdvertising();
    await stopScan();
    await _centralStateSub.cancel();
    await _peripheralStateSub.cancel();
    await _discoverySub.cancel();
    await _centralConnSub.cancel();
    await _notifiedSub.cancel();
    await _peripheralConnSub.cancel();
    await _writeRequestSub.cancel();
    await _notifyStateSub.cancel();
  }

  // ────────────────────────────────────────────────────────────────────────
  // Advertising (Peripheral Role)
  // ────────────────────────────────────────────────────────────────────────

  /// Starts advertising the BLE service as a peripheral.
  ///
  /// Sets up the GATT service with read/write and notify characteristics,
  /// then advertises with the given [nodeId].
  ///
  /// Errors are silently caught; check connectivity via [connectedPeerIds].
 Future<void> startAdvertising(String nodeId) async {
  if (_isAdvertising) {
    print('⚠️ Already advertising');
    return;
  }

  try {
    _isAdvertising = true;

    await _peripheral.removeAllServices();

    final writeChar = GATTCharacteristic.mutable(
      uuid: _kWriteCharUuid,
      properties: [
        GATTCharacteristicProperty.write,
        GATTCharacteristicProperty.writeWithoutResponse,
      ],
      permissions: [
        GATTCharacteristicPermission.write,
        GATTCharacteristicPermission.writeEncrypted,
      ],
      descriptors: [],
    );

    final notifyChar = GATTCharacteristic.mutable(
      uuid: _kNotifyCharUuid,
      properties: [GATTCharacteristicProperty.notify],
      permissions: [GATTCharacteristicPermission.read],
      descriptors: [
        GATTDescriptor.mutable(
          uuid: UUID.fromString(
            '00002902-0000-1000-8000-00805f9b34fb',
          ),
          permissions: [
            GATTCharacteristicPermission.read,
            GATTCharacteristicPermission.write,
          ],
        ),
      ],
    );

    _myNotifyChar = notifyChar;

    await _peripheral.addService(
      GATTService(
        uuid: _kServiceUuid,
        isPrimary: true,
        characteristics: [writeChar, notifyChar],
        includedServices: [],
      ),
    );

    await _peripheral.startAdvertising(
      Advertisement(
        name: 'DTN-$nodeId',
        serviceUUIDs: [_kServiceUuid],
      ),
    );

    print('📡 Advertising started');
  } catch (e) {
    _isAdvertising = false;
    print('❌ Advertising failed: $e');
  }
}

  /// Stops advertising and removes all services from the local GATT database.
Future<void> stopAdvertising() async {
  if (!_isAdvertising) return;

  try {
    await _peripheral.stopAdvertising();
    await _peripheral.removeAllServices();

    _myNotifyChar = null;

    print('🛑 Advertising stopped');
  } catch (e) {
    print('❌ Stop advertising failed: $e');
  } finally {
    _isAdvertising = false;
  }
}

  // ────────────────────────────────────────────────────────────────────────
  // Scanning (Central Role)
  // ────────────────────────────────────────────────────────────────────────

  /// Starts scanning for advertised BLE peripherals.
  ///
  /// Returns true if scan started successfully, false if Bluetooth is off.
  /// Discovered peers matching our service UUID are automatically connected.
  /// Service UUID filtering is done in the discovered event handler.
  ///
  /// v6 note: [startDiscovery] no longer accepts [serviceUUIDs]; filtering
  /// is manual in the event listener.
Future<bool> startScan() async {
  if (_isScanning) {
    print('⚠️ Already scanning');
    return true;
  }

  try {
    final state = _central.state;

    if (state != BluetoothLowEnergyState.poweredOn) {
      return false;
    }

    _isScanning = true;

    await _central.startDiscovery();

    print('🔍 Scan started');

    return true;
  } catch (e) {
    _isScanning = false;
    print('❌ Scan failed: $e');
    return false;
  }
}

  /// Stops scanning for peripherals.
Future<void> stopScan() async {
  if (!_isScanning) return;

  try {
    await _central.stopDiscovery();

    print('🛑 Scan stopped');
  } catch (e) {
    print('❌ Stop scan failed: $e');
  } finally {
    _isScanning = false;
  }
}

  // ────────────────────────────────────────────────────────────────────────
  // Central Event Listeners
  // ────────────────────────────────────────────────────────────────────────

  /// Sets up listeners for central manager events.
  ///
  /// Handles:
  /// - Peripheral discovery: auto-connect if service UUID matches
  /// - Connection state changes: cleanup on disconnect
  /// - Characteristic notifications: data reception
  void _listenCentralEvents() {
    // Device discovered while scanning
    _discoverySub = _central.discovered.listen((e) {
      final id = e.peripheral.uuid.toString();
      if (!_discoveredPeers.containsKey(id)) {
        _discoveredPeers[id] = e.peripheral;

        // Notify UI of any discovered device immediately (before service check)
        final name = e.advertisement.name ?? 'DTN Node';
        final rssi = e.rssi;
        onDeviceDiscovered?.call(id, name, rssi);

        // v6: Manual service UUID filtering (no longer in startDiscovery)
        final advServiceUuids = e.advertisement.serviceUUIDs;
        final hasOurService = advServiceUuids.any(
          (u) =>
              u.toString().toLowerCase() ==
              _kServiceUuid.toString().toLowerCase(),
        );

      if (hasOurService &&
    !_writeChars.containsKey(id) &&
    !_isConnecting) {
  _connectToPeer(e.peripheral);
}
      }
    });

    // Peripheral connection state changed
    _centralConnSub = _central.connectionStateChanged.listen((e) {
      final id = e.peripheral.uuid.toString();

      if (e.state==ConnectionState.disconnected) {
        _discoveredPeers.remove(id);
        _writeChars.remove(id);
        _notifyChars.remove(id);
        _rxBuffers.remove(id);
        onDeviceLost?.call(id);
      }
    });

    // Incoming characteristic notifications from a connected peripheral
    // v6: Event arg is GATTCharacteristicNotifiedEventArgs
    _notifiedSub = _central.characteristicNotified.listen((e) {
      _onData(e.peripheral.uuid.toString(), e.value);
    });
  }

  // ────────────────────────────────────────────────────────────────────────
  // Peripheral Event Listeners
  // ────────────────────────────────────────────────────────────────────────

  /// Sets up listeners for peripheral manager events.
  ///
  /// Handles:
  /// - Central connections: send hello packet
  /// - Write requests: process incoming data and respond
  /// - Notify state changes: track subscription status
  void _listenPeripheralEvents() {
    // v6: connectionStateChanged available on Android only
    _peripheralConnSub = _peripheral.connectionStateChanged.listen((e) {
      final id = e.central.uuid.toString();
      if (e.state==ConnectionState.connected) {
        _connectedCentrals[id] = e.central;
        _sendHelloToCentral(id);
      } else {
        _connectedCentrals.remove(id);
        _rxBuffers.remove(id);
      }
    });

    // v6: characteristicWriteRequested replaces characteristicWritten
    // We must call respondWriteRequest() to complete the ATT exchange
    _writeRequestSub = _peripheral.characteristicWriteRequested.listen((e) async {
         _onData(e.central.uuid.toString(), e.request.value);   // ✅ RIGHT
      // IMPORTANT: Must respond to write requests in v6
      try {
    await _peripheral.respondWriteRequest(e.request); 

      } catch (_) {
        // Response may fail if connection drops; ignore silently
      }
    });

    // Subscription state changed (central enabled/disabled notifications)
    _notifyStateSub = _peripheral.characteristicNotifyStateChanged.listen((_) {
      // Track state changes if needed; currently unused
    });
  }

  // ────────────────────────────────────────────────────────────────────────
  // Connection Management
  // ────────────────────────────────────────────────────────────────────────

  /// Connects to a discovered peripheral and discovers GATT characteristics.
  ///
  /// - Connects to the peripheral
  /// - Requests MTU on Android (v6 requires manual request)
  /// - Discovers GATT services and characteristics
  /// - Subscribes to notify characteristic
  /// - Sends hello packet to peer
 Future<void> _connectToPeer(Peripheral peripheral) async {
  final id = peripheral.uuid.toString();

  if (_writeChars.containsKey(id)) {
    print('⚠️ Already connected to $id');
    return;
  }

  if (_isConnecting) {
    print('⚠️ Connection already in progress');
    return;
  }

  _isConnecting = true;

  try {
    await _central.connect(peripheral);

    if (Platform.isAndroid) {
      try {
        await _central.requestMTU(peripheral, mtu: 517);
      } catch (_) {}
    }

    final services = await _central.discoverGATT(peripheral);

    for (final svc in services) {
      if (svc.uuid.toString().toLowerCase() !=
          _kServiceUuid.toString().toLowerCase()) {
        continue;
      }

      for (final char in svc.characteristics) {
        final uuid = char.uuid.toString().toLowerCase();

        if (uuid == _kWriteCharUuid.toString().toLowerCase()) {
          _writeChars[id] = char;
        }

        if (uuid == _kNotifyCharUuid.toString().toLowerCase()) {
          _notifyChars[id] = char;

          try {
            await _central.setCharacteristicNotifyState(
              peripheral,
              char,
              state: true,
            );
          } catch (_) {}
        }
      }
    }

    await _sendHello(id);

    print('✅ Connected to peer: $id');
  } catch (e) {
    _discoveredPeers.remove(id);
    print('❌ Connection failed: $e');
  } finally {
    _isConnecting = false;
  }
}
  // ────────────────────────────────────────────────────────────────────────
  // Message Sending (Handshake & Data)
  // ────────────────────────────────────────────────────────────────────────

  /// Sends a HELLO packet to the peer (as central, via write).
  Future<void> _sendHello(String peerId) async {
    await _writePacket(peerId, await _buildHelloPacket());
  }

  /// Sends a HELLO packet to a connected central (as peripheral, via notify).
  Future<void> _sendHelloToCentral(String centralId) async {
    final central = _connectedCentrals[centralId];
    final char = _myNotifyChar;
    if (central == null || char == null) return;

    final raw = Uint8List.fromList(
      utf8.encode('${jsonEncode(await _buildHelloPacket())}\n'),
    );

    try {
      // v6: notifyCharacteristic takes (central, characteristic, value:)
      await _peripheral.notifyCharacteristic(
        central,
        char,
        value: raw,
      );
    } catch (_) {
      // Notification may fail if connection drops or central unsubscribed
    }
  }

  /// Builds the hello packet, or uses custom builder if provided.
  Future<Map<String, dynamic>> _buildHelloPacket() async {
    if (helloPacketBuilder != null) {
      return helloPacketBuilder!();
    }
    return {
      'type': 'HELLO',
      'nodeId': 'unknown',
      'preds': {},
      'msgIds': [],
    };
  }

  /// Sends a DTN message to a peer (central role, via write characteristic).
  Future<void> sendMessage(String peerId, DtnMessage msg) async {
    await _writePacket(peerId, _msgToPacket(msg));
  }

  /// Sends a DTN message to a connected central (peripheral role, via notify).
  Future<void> sendMessageToCentral(String centralId, DtnMessage msg) async {
    final central = _connectedCentrals[centralId];
    final char = _myNotifyChar;
    if (central == null || char == null) return;

    final raw = Uint8List.fromList(
      utf8.encode('${jsonEncode(_msgToPacket(msg))}\n'),
    );

    try {
      // v6: notifyCharacteristic takes (central, characteristic, value:)
      await _peripheral.notifyCharacteristic(
        central,
        char,
        value: raw,
      );
    } catch (_) {
      // Notification may fail
    }
  }

  /// Converts a DTN message to a wire format packet.
  Map<String, dynamic> _msgToPacket(DtnMessage msg) => {
        'type': 'MSG',
        'id': msg.id,
        'source': msg.source,
        'destination': msg.destination,
        'payload': msg.payload,
        'ttl': msg.ttl,
        'priority': msg.priority,
        'createdAt': msg.createdAt.toIso8601String(),
      };

  /// Writes a packet to a peer's characteristic with automatic fragmentation.
  ///
  /// v6 requires manual fragmentation based on getMaximumWriteLength().
  /// Packets are split into chunks and sent sequentially.
  Future<void> _writePacket(
      String peerId, Map<String, dynamic> packet) async {
    final char = _writeChars[peerId];
    final peripheral = _discoveredPeers[peerId];
    if (char == null || peripheral == null) return;

    final raw = Uint8List.fromList(utf8.encode('${jsonEncode(packet)}\n'));

    // v6: Query maximum write length and manually fragment
    final fragmentSize = await _central.getMaximumWriteLength(
      peripheral,
      type: GATTCharacteristicWriteType.withoutResponse,
    );

    var start = 0;
    while (start < raw.length) {
      final end = start + fragmentSize;
      final chunk = end < raw.length
          ? raw.sublist(start, end)
          : raw.sublist(start);

      // v6: writeCharacteristic takes (peripheral, characteristic, value:, type:)
      try {
        await _central.writeCharacteristic(
          peripheral,
          char,
          value: chunk,
          type: GATTCharacteristicWriteType.withoutResponse,
        );
      } catch (_) {
        // Write failed; stop sending remaining fragments
        return;
      }

      start = end;
    }
  }

  // ────────────────────────────────────────────────────────────────────────
  // Message Receiving
  // ────────────────────────────────────────────────────────────────────────

  /// Processes incoming raw data from a peer.
  ///
  /// Buffers incomplete frames (split by newlines) and handles complete frames
  /// via [_handlePacket].
  void _onData(String peerId, Uint8List data) {
    final buf = _rxBuffers[peerId] ??= StringBuffer();
    buf.write(utf8.decode(data, allowMalformed: true));

    // Split on newline and keep incomplete frame in buffer
    final frames = buf.toString().split('\n');
    _rxBuffers[peerId] = StringBuffer(frames.removeLast());

    for (final frame in frames) {
      if (frame.trim().isEmpty) continue;
      try {
        _handlePacket(peerId, jsonDecode(frame) as Map<String, dynamic>);
      } catch (_) {
        // Malformed frame; skip silently
      }
    }
  }

  /// Handles a complete packet from a peer.
  ///
  /// Dispatches to [onPeerConnected] for HELLO packets or
  /// [onMessageReceived] for MSG packets.
  void _handlePacket(String peerId, Map<String, dynamic> map) {
    final type = map['type'] as String? ?? '';

    switch (type) {
      case 'HELLO':
        final preds = Map<String, double>.from(
          (map['preds'] as Map? ?? {}).map(
            (k, v) => MapEntry(k as String, (v as num).toDouble()),
          ),
        );
        final peerDtnNodeId = map['nodeId'] as String?;
        if (peerDtnNodeId != null && peerDtnNodeId.isNotEmpty) {
          onPeerNodeId?.call(peerId, peerDtnNodeId);
        }
        final peerDisplayName = map['displayName'] as String?;
        if (peerDisplayName != null && peerDisplayName.isNotEmpty) {
          onPeerDisplayName?.call(peerId, peerDisplayName);
        }
        onPeerConnected?.call(
          peerId,
          preds,
          List<String>.from(map['msgIds'] as List? ?? []),
        );

      case 'MSG':
        try {
          onMessageReceived?.call(DtnMessage(
            id: map['id'] as String,
            source: map['source'] as String,
            destination: map['destination'] as String,
            payload: map['payload'] as String,
            createdAt: DateTime.parse(map['createdAt'] as String),
            ttl: map['ttl'] as int,
            priority: map['priority'] as int,
          ));
        } catch (_) {
          // Malformed message; silently ignore
        }

      default:
        // Unknown packet type; ignore
        break;
    }
  }

  // ────────────────────────────────────────────────────────────────────────
  // Utility
  // ────────────────────────────────────────────────────────────────────────

  /// Checks if a peer is connected (either as central or peripheral).
  bool isConnected(String peerId) =>
      _writeChars.containsKey(peerId) ||
      _connectedCentrals.containsKey(peerId);

  /// Returns a list of all connected peer IDs.
  List<String> get connectedPeerIds =>
      {..._writeChars.keys, ..._connectedCentrals.keys}.toList();
}