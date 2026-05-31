import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';

import '../models/dtn_message.dart';

final _kServiceUuid    = UUID.fromString('12345678-1234-1234-1234-1234567890ab');
final _kWriteCharUuid  = UUID.fromString('12345678-1234-1234-1234-1234567890ac');
final _kNotifyCharUuid = UUID.fromString('12345678-1234-1234-1234-1234567890ad');

class _PeerState {
  bool writeReady  = false;
  bool notifyReady = false;
  bool helloSent   = false;

  bool get isReady => writeReady || notifyReady;
}

class BleTransportService {

  // ── Callbacks ──────────────────────────────────────────────────────────────

  void Function(String peerId, Map<String, double> peerPreds, List<String> peerMsgIds)? onPeerConnected;
  void Function(DtnMessage msg)?                       onMessageReceived;
  Future<Map<String, dynamic>> Function()?             helloPacketBuilder;
  void Function(String peerId, String name, int rssi)? onDeviceDiscovered;
  void Function(String peerId)?                        onDeviceLost;
  void Function(String peerId, String displayName)?    onPeerDisplayName;

  /// Fires when a HELLO packet is received from a peer, providing the mapping:
  ///   blePeerId (UUID as seen by our CentralManager) → dtnNodeId (peer's stable ID).
  ///
  /// ⚠️  Multiple services need this event. Always CHAIN onto the existing handler:
  ///
  ///   final prev = ble.onPeerNodeId;
  ///   ble.onPeerNodeId = (blePeerId, dtnNodeId) {
  ///     prev?.call(blePeerId, dtnNodeId);
  ///     // your logic here
  ///   };
  void Function(String blePeerId, String dtnNodeId)?  onPeerNodeId;

  /// Fired when we learn our own BLE UUID as seen by a connected peer.
  void Function(String myBleUuid)? onMyBleIdLearned;

  // ── BLE managers ───────────────────────────────────────────────────────────

  final CentralManager    _central    = CentralManager();
  final PeripheralManager _peripheral = PeripheralManager();

  // ── State ──────────────────────────────────────────────────────────────────

  final Map<String, GATTCharacteristic> _writeChars        = {};
  final Map<String, GATTCharacteristic> _notifyChars       = {};
  final Map<String, Peripheral>         _discoveredPeers   = {};
  final Map<String, Central>            _connectedCentrals = {};
  final Map<String, StringBuffer>       _rxBuffers         = {};

  // FIX: was referenced but never declared
  final Map<String, _PeerState>         _peerState         = {};

  GATTCharacteristic? _myNotifyChar;

  // FIX: was called but never declared — completes when advertising is ready
  Completer<void>? _advertisingReady;

  late final StreamSubscription<BluetoothLowEnergyStateChangedEventArgs>      _centralStateSub;
  late final StreamSubscription<BluetoothLowEnergyStateChangedEventArgs>      _peripheralStateSub;
  late final StreamSubscription<DiscoveredEventArgs>                           _discoverySub;
  late final StreamSubscription<PeripheralConnectionStateChangedEventArgs>     _centralConnSub;
  late final StreamSubscription<GATTCharacteristicNotifiedEventArgs>           _notifiedSub;
  late final StreamSubscription<CentralConnectionStateChangedEventArgs>        _peripheralConnSub;
  late final StreamSubscription<GATTCharacteristicWriteRequestedEventArgs>     _writeRequestSub;
  late final StreamSubscription<GATTCharacteristicNotifyStateChangedEventArgs> _notifyStateSub;

  bool _isSetup       = false;
  bool _isAdvertising = false;
  bool _isScanning    = false;

  // ── Peer-ready helpers ─────────────────────────────────────────────────────

  void _markReady(String id, {bool? write, bool? notify}) {
    final p = _peerState[id] ??= _PeerState();
    if (write  != null) p.writeReady  = write;
    if (notify != null) p.notifyReady = notify;
    _trySendHello(id);
  }

  void _trySendHello(String id) {
    final p = _peerState[id];
    if (p == null) return;
    if (!p.isReady) return;
    if (p.helloSent) return;
    if (_myNotifyChar == null) return;
    p.helloSent = true;
    _sendHelloToCentral(id);
  }

  // FIX: was called in startAdvertising but never defined
  void _completeAdvertisingReady() {
    if (_advertisingReady != null && !_advertisingReady!.isCompleted) {
      _advertisingReady!.complete();
    }
  }

  // ── Setup ──────────────────────────────────────────────────────────────────

  Future<void> setup() async {
    if (_isSetup) return;
    _isSetup = true;

    _centralStateSub = _central.stateChanged.listen((e) async {
      if (Platform.isAndroid && e.state == BluetoothLowEnergyState.unauthorized) {
        try { await _central.authorize(); } catch (_) {}
      }
    });

    _peripheralStateSub = _peripheral.stateChanged.listen((e) async {
      if (Platform.isAndroid && e.state == BluetoothLowEnergyState.unauthorized) {
        try { await _peripheral.authorize(); } catch (_) {}
      }
    });

    if (_central.state != BluetoothLowEnergyState.poweredOn) {
      await _central.stateChanged
          .where((e) => e.state == BluetoothLowEnergyState.poweredOn)
          .first
          .timeout(const Duration(seconds: 10),
              onTimeout: () => throw TimeoutException('BT init timeout'));
    }

    _listenCentralEvents();
    _listenPeripheralEvents();
  }

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

  // ── Advertising ────────────────────────────────────────────────────────────

  Future<void> startAdvertising(String nodeId) async {
    if (_isAdvertising) return;
    _isAdvertising = true;

    try {
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
            uuid: UUID.fromString('00002902-0000-1000-8000-00805f9b34fb'),
            permissions: [
              GATTCharacteristicPermission.read,
              GATTCharacteristicPermission.write,
            ],
          ),
        ],
      );

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

      // Set AFTER startAdvertising so _myNotifyChar != null only when
      // the GATT service is fully registered and advertising has started.
      // The retry loop in _sendHelloToCentralWithRetry checks this.
      _myNotifyChar = notifyChar;
      print('✅ [BLE] Advertising ready — notifyChar set, completing ready signal');
      _completeAdvertisingReady();

      for (final id in List.from(_connectedCentrals.keys)) {
        print('🔔 [BLE] Flushing HELLO to already-connected central: $id');
        _sendHelloToCentral(id);
      }
    } catch (e) {
      print('❌ [BLE] startAdvertising failed: $e');
      _isAdvertising = false;
    }
  }

  Future<void> stopAdvertising() async {
    try {
      await _peripheral.stopAdvertising();
      await _peripheral.removeAllServices();
      _myNotifyChar = null;
    } catch (_) {}
    _isAdvertising = false;
  }

  // ── Scanning ───────────────────────────────────────────────────────────────

  Future<bool> startScan() async {
    if (_isScanning) return true;
    _isScanning = true;
    try {
      if (_central.state != BluetoothLowEnergyState.poweredOn) {
        _isScanning = false;
        return false;
      }
      await _central.startDiscovery();
      return true;
    } catch (_) {
      _isScanning = false;
      return false;
    }
  }

  Future<void> stopScan() async {
    try { await _central.stopDiscovery(); } catch (_) {}
    _isScanning = false;
  }

  // ── Central events ─────────────────────────────────────────────────────────

  void _listenCentralEvents() {
    _discoverySub = _central.discovered.listen((e) {
      final id = e.peripheral.uuid.toString();
      if (!_discoveredPeers.containsKey(id)) {
        _discoveredPeers[id] = e.peripheral;
        onDeviceDiscovered?.call(id, e.advertisement.name ?? 'DTN Node', e.rssi);

        final hasOurService = e.advertisement.serviceUUIDs.any(
          (u) => u.toString().toLowerCase() == _kServiceUuid.toString().toLowerCase(),
        );
        if (hasOurService) _connectToPeer(e.peripheral);
      }
    });

    _centralConnSub = _central.connectionStateChanged.listen((e) {
      final id = e.peripheral.uuid.toString();
      if (e.state == ConnectionState.disconnected) {
        _discoveredPeers.remove(id);
        _writeChars.remove(id);
        _notifyChars.remove(id);
        _rxBuffers.remove(id);
        _peerState.remove(id);
        onDeviceLost?.call(id);
      }
    });

    _notifiedSub = _central.characteristicNotified.listen((e) {
      final id = e.peripheral.uuid.toString();
      print('🔔 Notify from peripheral: $id  bytes: ${e.value.length}');
      _onData(id, e.value);
    });
  }

  // ── Peripheral events ──────────────────────────────────────────────────────

  void _listenPeripheralEvents() {
    _peripheralConnSub = _peripheral.connectionStateChanged.listen((e) {
      final id = e.central.uuid.toString();
      if (e.state == ConnectionState.connected) {
        _connectedCentrals[id] = e.central;
        _sendHelloToCentralWithRetry(id);
      } else {
        _connectedCentrals.remove(id);
        _rxBuffers.remove(id);
        _peerState.remove(id);
      }
    });

    _writeRequestSub = _peripheral.characteristicWriteRequested.listen((e) async {
      final id = e.central.uuid.toString();
      print('✏️ Write request from central: $id  bytes: ${e.request.value.length}');
      _onData(id, e.request.value);
      try { await _peripheral.respondWriteRequest(e.request); } catch (_) {}
    });

    _notifyStateSub = _peripheral.characteristicNotifyStateChanged.listen((_) {});
  }

  // ── Connection ─────────────────────────────────────────────────────────────

  Future<void> _sendHelloToCentralWithRetry(String centralId) async {
    // Fast path: notify char already ready.
    if (_myNotifyChar != null) {
      await _sendHelloToCentral(centralId);
      return;
    }

    // Slow path: advertising hasn't finished yet — wait then retry in a loop.
    // The central may have connected before startAdvertising completed.
    // We keep retrying every 2 seconds for up to 30 seconds so the HELLO
    // is eventually delivered even after a long startup delay.
    _advertisingReady ??= Completer<void>();

    bool sent = false;
    for (int attempt = 0; attempt < 15 && !sent; attempt++) {
      try {
        await _advertisingReady!.future.timeout(const Duration(seconds: 2));
      } catch (_) {
        // timeout on this attempt — check if char is ready yet
      }

      if (_myNotifyChar != null) {
        await _sendHelloToCentral(centralId);
        sent = true;
        print('✅ Hello sent to $centralId on attempt ${attempt + 1}');
      } else {
        // Still not ready — only keep waiting if central is still connected
        if (!_connectedCentrals.containsKey(centralId)) {
          print('⚠️ Central $centralId disconnected before HELLO could be sent');
          return;
        }
        print('⏳ Waiting for advertising ready (attempt ${attempt + 1}) for $centralId');

        // Reset completer for next wait round if it was already completed
        if (_advertisingReady!.isCompleted) {
          _advertisingReady = Completer<void>();
        }
      }
    }

    if (!sent) {
      print('❌ Gave up waiting to send HELLO to $centralId after 30s');
    }
  }

  Future<void> _connectToPeer(Peripheral peripheral) async {
    final id = peripheral.uuid.toString();
    try {
      await _central.connect(peripheral);

      if (Platform.isAndroid) {
        try { await _central.requestMTU(peripheral, mtu: 517); } catch (_) {}
      }

      final services = await _central.discoverGATT(peripheral);

      for (final svc in services) {
        if (svc.uuid.toString().toLowerCase() != _kServiceUuid.toString().toLowerCase()) continue;

        for (final char in svc.characteristics) {
          final uuid = char.uuid.toString().toLowerCase();

          if (uuid == _kWriteCharUuid.toString().toLowerCase()) {
            _writeChars[id] = char;
            _markReady(id, write: true);
          }

          if (uuid == _kNotifyCharUuid.toString().toLowerCase()) {
            _notifyChars[id] = char;
            try {
              await _central.setCharacteristicNotifyState(peripheral, char, state: true);
              print('✅ Notify subscribed for $id');
              _markReady(id, notify: true);
            } catch (_) {}
          }
        }
      }

      await _sendHello(id);
    } catch (_) {
      _discoveredPeers.remove(id);
    }
  }

  // ── Sending ────────────────────────────────────────────────────────────────

  Future<void> _sendHello(String peerId) async {
    final packet = await _buildHelloPacket();
    // Tell the peripheral its own BLE UUID as we (the central) see it.
    packet['recipientBleId'] = peerId;
    await _writePacket(peerId, packet);
  }

  Future<void> _sendHelloToCentral(String centralId) async {
    final central = _connectedCentrals[centralId];
    final char    = _myNotifyChar;
    if (central == null || char == null) return;

    final packet = await _buildHelloPacket();
    final raw = Uint8List.fromList(utf8.encode('${jsonEncode(packet)}\n'));

    try {
      await _peripheral.notifyCharacteristic(central, char, value: raw);
    } catch (e) {
      print('❌ notifyCharacteristic FAILED: $e');
    }
  }

  Future<Map<String, dynamic>> _buildHelloPacket() async {
    if (helloPacketBuilder != null) return helloPacketBuilder!();
    return {'type': 'HELLO', 'nodeId': 'unknown', 'preds': {}, 'msgIds': []};
  }

  Future<void> sendMessage(String peerId, DtnMessage msg) async {
    final packet     = _msgToPacket(msg);
    final writeChar  = _writeChars[peerId];
    final peripheral = _discoveredPeers[peerId];
    final central    = _connectedCentrals[peerId];

    print('📤 [BLE sendMessage] peerId=$peerId msgId=${msg.id}');
    print('   writeChar=${writeChar != null} peripheral=${peripheral != null} central=${central != null}');

    if (writeChar != null && peripheral != null) {
      // We are the central — use GATT write
      print('   → path: central→write');
      await _writePacket(peerId, packet);
      print('✅ [BLE sendMessage] write sent for ${msg.id}');
    } else if (central != null && _myNotifyChar != null) {
      // We are the peripheral — use notify
      print('   → path: peripheral→notify');
      final raw = Uint8List.fromList(utf8.encode('${jsonEncode(packet)}\n'));
      try {
        await _peripheral.notifyCharacteristic(central, _myNotifyChar!, value: raw);
        print('✅ [BLE sendMessage] notify sent for ${msg.id}');
      } catch (e) {
        print('❌ [BLE sendMessage] notify failed for ${msg.id}: $e');
      }
    } else {
      print('❌ [BLE sendMessage] NO SEND PATH for $peerId — writeChar=$writeChar peripheral=$peripheral central=$central myNotifyChar=${_myNotifyChar != null}');
    }
  }

  Future<void> sendMessageToCentral(String centralId, DtnMessage msg) async {
    final central = _connectedCentrals[centralId];
    final char    = _myNotifyChar;
    if (central == null || char == null) return;
    final raw = Uint8List.fromList(utf8.encode('${jsonEncode(_msgToPacket(msg))}\n'));
    try {
      await _peripheral.notifyCharacteristic(central, char, value: raw);
    } catch (_) {}
  }

  // The sender's display name is injected by DtnManager via helloPacketBuilder.
  // We store it here so _msgToPacket can include it.
  String? myDisplayName;

  Map<String, dynamic> _msgToPacket(DtnMessage msg) => {
    'type':            'MSG',
    'id':              msg.id,
    'source':          msg.source,
    'senderName':      myDisplayName ?? '',
    'destination':     msg.destination,
    'nodeDestination': msg.nodeDestination,
    'payload':         msg.payload,
    'ttl':             msg.ttl,
    'priority':        msg.priority,
    'createdAt':       msg.createdAt.toIso8601String(),
  };

  Future<void> _writePacket(String peerId, Map<String, dynamic> packet) async {
    final char       = _writeChars[peerId];
    final peripheral = _discoveredPeers[peerId];
    if (char == null || peripheral == null) return;

    final raw          = Uint8List.fromList(utf8.encode('${jsonEncode(packet)}\n'));
    final fragmentSize = await _central.getMaximumWriteLength(
      peripheral,
      type: GATTCharacteristicWriteType.withoutResponse,
    );

    var start = 0;
    while (start < raw.length) {
      final end   = start + fragmentSize;
      final chunk = end < raw.length ? raw.sublist(start, end) : raw.sublist(start);
      try {
        await _central.writeCharacteristic(
          peripheral, char,
          value: chunk,
          type: GATTCharacteristicWriteType.withoutResponse,
        );
      } catch (_) {
        return;
      }
      start = end;
    }
  }

  // ── Receiving ──────────────────────────────────────────────────────────────

  void _onData(String peerId, Uint8List data) {
    print('📡 [BLE _onData] from=$peerId bytes=${data.length}');
    final buf     = _rxBuffers[peerId] ??= StringBuffer();
    final decoded = utf8.decode(data, allowMalformed: false);
    buf.write(decoded);

    final frames = buf.toString().split('\n');
    _rxBuffers[peerId] = StringBuffer(frames.removeLast());
    print('📡 [BLE _onData] frames to process: ${frames.where((f) => f.trim().isNotEmpty).length}');

    for (final frame in frames) {
      if (frame.trim().isEmpty) continue;
      try {
        final map = jsonDecode(frame) as Map<String, dynamic>;
        print('📡 [BLE _onData] parsed frame type=${map['type']}');
        _handlePacket(peerId, map);
      } catch (e) {
        print('❌ [BLE _onData] failed to parse frame: $e  raw="${frame.length > 80 ? frame.substring(0,80) : frame}"');
      }
    }
  }

  void _handlePacket(String peerId, Map<String, dynamic> map) {
    final type = map['type'] as String? ?? '';

    switch (type) {
      case 'HELLO':
        print('📨 HELLO packet from $peerId: nodeId=${map['nodeId']}');

        final preds = Map<String, double>.from(
          (map['preds'] as Map? ?? {}).map(
            (k, v) => MapEntry(k as String, (v as num).toDouble()),
          ),
        );

        final peerNodeId   = map['nodeId']      as String?;
        final peerDispName = map['displayName'] as String?;

        if (peerNodeId != null && peerNodeId.isNotEmpty) {
          onPeerNodeId?.call(peerId, peerNodeId);
        }

        // Tell DtnManager our own BLE UUID so it can match incoming messages
        final myBleId = map['recipientBleId'] as String?;
        if (myBleId != null && myBleId.isNotEmpty) {
          onMyBleIdLearned?.call(myBleId);
        }

        if (peerDispName != null && peerDispName.isNotEmpty) {
          onPeerDisplayName?.call(peerId, peerDispName);
        }

        onPeerConnected?.call(
          peerId,
          preds,
          List<String>.from(map['msgIds'] as List? ?? []),
        );
        break;

      case 'MSG':
        print('📨 [BLE _handlePacket] MSG received from $peerId');
        print('   id=${map['id']} src=${map['source']} dest=${map['destination']} nodeDest=${map['nodeDestination']}');
        print('   payload=${map['payload']} ttl=${map['ttl']} priority=${map['priority']}');

        // Learn BLE UUID → DTN ID mapping from the message source field.
        // This handles the case where a MSG arrives before any HELLO was
        // exchanged (e.g. peripheral never sent HELLO back in time).
        final msgSrc = map['source'] as String?;
        if (msgSrc != null && msgSrc.isNotEmpty && msgSrc.startsWith('node_')) {
          print('📡 [BLE] Learning mapping from MSG: $peerId → $msgSrc');
          onPeerNodeId?.call(peerId, msgSrc);
        }

        // Also learn the sender display name if included in MSG
        final senderName = map['senderName'] as String?;
        if (senderName != null && senderName.isNotEmpty && msgSrc != null) {
          print('📡 [BLE] Learning display name from MSG: $msgSrc = $senderName');
          onPeerDisplayName?.call(peerId, senderName);
        }

        try {
          final msg = DtnMessage(
            id:              map['id']          as String,
            source:          map['source']      as String,
            destination:     map['destination'] as String,
            nodeDestination: (map['nodeDestination'] as String?)?.isNotEmpty == true
                ? map['nodeDestination'] as String
                : map['destination'] as String,
            payload:         map['payload']   as String,
            createdAt:       DateTime.parse(map['createdAt'] as String),
            ttl:             map['ttl']       as int,
            priority:        map['priority']  as int,
          );
          print('📨 [BLE _handlePacket] DtnMessage built OK, calling onMessageReceived');
          if (onMessageReceived != null) {
            onMessageReceived!.call(msg);
            print('📨 [BLE _handlePacket] onMessageReceived callback returned');
          } else {
            print('⚠️ [BLE _handlePacket] onMessageReceived is NULL — message dropped!');
          }
        } catch (e) {
          print('❌ [BLE _handlePacket] Failed to build DtnMessage from MSG: $e  map=$map');
        }
        break;

      default:
        break;
    }
  }

  // ── Utility ────────────────────────────────────────────────────────────────

  bool isConnected(String peerId) =>
      _writeChars.containsKey(peerId) || _connectedCentrals.containsKey(peerId);

  List<String> get connectedPeerIds =>
      {..._writeChars.keys, ..._connectedCentrals.keys}.toList();

  void clearDiscoveryCache() {
    _discoveredPeers.removeWhere((id, _) => !_writeChars.containsKey(id));
  }
}