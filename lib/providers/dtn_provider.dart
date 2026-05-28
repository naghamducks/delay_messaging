import 'package:delay_messenger/models/dtn_message.dart';
import 'package:delay_messenger/services/node_identity.dart';
import 'package:delay_messenger/services/service_locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/dtn_device.dart';
import '../models/relay_history.dart';
import '../providers/chat_provider.dart';
import '../services/dtn_manager.dart';

class DTNProvider extends ChangeNotifier {
  DtnManager get dtnManager => ServiceLocator.dtnManager;

  List<DTNDevice>    _nearbyDevices = [];
  List<RelayHistory> _relayHistory  = [];

  /// Maps BLE UUID or DTN nodeId → display name (persisted across restarts)
  final Map<String, String> _peerNames = {};
  /// Maps BLE UUID → DTN node ID
  final Map<String, String> _peerDtnIds = {};

  ChatProvider? _chatProviderRef;

  List<DTNDevice>    get nearbyDevices => _nearbyDevices;
  List<RelayHistory> get relayHistory  => _relayHistory;

  void setChatProvider(ChatProvider provider) {
    _chatProviderRef = provider;
  }

  String peerDisplayName(String peerId) =>
      _peerNames[peerId] ??
      _peerNames[_peerDtnIds[peerId] ?? ''] ??
      peerId;

  DTNProvider() {
    _loadPersistedNames();
    _wireDiscoveryCallbacks();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _wirePeerConnectedCallback();
    });
  }

  // ── Persist display names across restarts ──────────────────────────────────

  static const _kNamesKey = 'dtn_peer_names';

  Future<void> _loadPersistedNames() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kNamesKey) ?? [];
    // stored as 'id|name' pairs
    for (final entry in raw) {
      final sep = entry.indexOf('|');
      if (sep > 0) {
        _peerNames[entry.substring(0, sep)] = entry.substring(sep + 1);
      }
    }
  }

  Future<void> _persistNames() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = _peerNames.entries
        .map((e) => '${e.key}|${e.value}')
        .toList();
    await prefs.setStringList(_kNamesKey, raw);
    // Invalidate ChatProvider's name cache so it picks up new names
    ChatProvider.invalidatePeerNamesCache();
  }

  void _storeName(String id, String name) {
    _peerNames[id] = name;
    _persistNames();
  }

  // ── BLE callbacks ──────────────────────────────────────────────────────────

  void _wireDiscoveryCallbacks() {
    ServiceLocator.ble.onDeviceDiscovered = (blePeerId, advName, rssi) {
      final clamped  = rssi.clamp(-100, -40);
      final strength = (clamped + 100) / 60.0;

      // Strip DTN- prefix from advertisement name
      final strippedName = advName.startsWith('DTN-')
          ? advName.substring(4)
          : advName;

      // Prefer persisted display name, then advertisement name
      final resolvedName = _peerNames[blePeerId] ??
          _peerNames[_peerDtnIds[blePeerId] ?? ''] ??
          strippedName;

      // Dedup: check BLE UUID and any already-mapped DTN nodeId
      final dtnId = _peerDtnIds[blePeerId];
      final alreadyExists = _nearbyDevices.any(
          (d) => d.id == blePeerId || (dtnId != null && d.id == dtnId));

      if (!alreadyExists) {
        _nearbyDevices.add(DTNDevice(
          id:             blePeerId,
          name:           resolvedName,
          deviceType:     'BLE',
          signalStrength: strength.clamp(0.0, 1.0),
          isConnected:    false,
          lastSeen:       DateTime.now(),
        ));
        notifyListeners();
      } else {
        // Update signal + lastSeen on re-scan without adding duplicate
        final index = _nearbyDevices.indexWhere(
            (d) => d.id == blePeerId || (dtnId != null && d.id == dtnId));
        if (index != -1) {
          _nearbyDevices[index] = _nearbyDevices[index].copyWith(
            signalStrength: strength.clamp(0.0, 1.0),
            lastSeen: DateTime.now(),
          );
          notifyListeners();
        }
      }
    };

    ServiceLocator.ble.onDeviceLost = (peerId) {
      final index = _nearbyDevices.indexWhere(
          (d) => d.id == peerId || d.id == (_peerDtnIds[peerId] ?? ''));
      if (index != -1) {
        _nearbyDevices[index] =
            _nearbyDevices[index].copyWith(isConnected: false);
        notifyListeners();
      }
    };

    // Learn DTN nodeId → update device tile ID to canonical DTN nodeId
    ServiceLocator.ble.onPeerNodeId = (blePeerId, dtnNodeId) {
      _peerDtnIds[blePeerId] = dtnNodeId;

      final index = _nearbyDevices.indexWhere((d) => d.id == blePeerId);
      if (index != -1) {
        final device = _nearbyDevices[index];
        // Replace BLE UUID tile with DTN nodeId tile — drop any existing
        // DTN nodeId duplicate that may have been added by onPeerConnected
        _nearbyDevices.removeWhere(
            (d) => d.id == dtnNodeId && d != _nearbyDevices[index]);
        _nearbyDevices[index] = DTNDevice(
          id:             dtnNodeId,
          name:           _peerNames[dtnNodeId] ?? _peerNames[blePeerId] ?? device.name,
          deviceType:     device.deviceType,
          signalStrength: device.signalStrength,
          isConnected:    device.isConnected,
          lastSeen:       device.lastSeen,
        );
        notifyListeners();
      }
    };

    // Learn display name → update tile + chat + persist
    ServiceLocator.ble.onPeerDisplayName = (blePeerId, displayName) {
      // Store under both BLE UUID and DTN nodeId for resilient lookup
      _storeName(blePeerId, displayName);
      final dtnId = _peerDtnIds[blePeerId];
      if (dtnId != null) _storeName(dtnId, displayName);

      // Update device tile
      final index = _nearbyDevices.indexWhere(
          (d) => d.id == blePeerId || (dtnId != null && d.id == dtnId));
      if (index != -1) {
        _nearbyDevices[index] =
            _nearbyDevices[index].copyWith(name: displayName);
      }
      notifyListeners();

      // Update chat name
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _chatProviderRef?.updateChatName(blePeerId, displayName);
        if (dtnId != null) _chatProviderRef?.updateChatName(dtnId, displayName);
      });
    };
  }

  void _wirePeerConnectedCallback() {
    final original = ServiceLocator.ble.onPeerConnected;
    ServiceLocator.ble.onPeerConnected = (peerId, peerPreds, peerMsgIds) {
      final dtnId = _peerDtnIds[peerId] ?? peerId;
      final name  = _peerNames[dtnId] ?? _peerNames[peerId] ?? dtnId;

      final index = _nearbyDevices.indexWhere(
          (d) => d.id == peerId || d.id == dtnId);

      if (index != -1) {
        _nearbyDevices[index] = _nearbyDevices[index].copyWith(
          isConnected: true,
          lastSeen:    DateTime.now(),
          name:        name,
        );
      } else {
        // Remove any duplicate BLE UUID entry before adding DTN nodeId entry
        _nearbyDevices.removeWhere((d) => d.id == peerId);
        _nearbyDevices.add(DTNDevice(
          id:             dtnId,
          name:           name,
          deviceType:     'BLE',
          signalStrength: 0.5,
          isConnected:    true,
          lastSeen:       DateTime.now(),
        ));
      }
      notifyListeners();
      original?.call(peerId, peerPreds, peerMsgIds);
    };
  }

  Future<void> scanForDevices() async {
    await ServiceLocator.dtnManager.startBle();
    notifyListeners();
  }

  void toggleDeviceConnection(String deviceId) {
    final index = _nearbyDevices.indexWhere((d) => d.id == deviceId);
    if (index == -1) return;
    final device = _nearbyDevices[index];
    _nearbyDevices[index] = device.copyWith(isConnected: !device.isConnected);
    notifyListeners();
  }

  void runProphetTest() {
    final msg = DtnMessage(
      id:          'msg_test_${DateTime.now().millisecondsSinceEpoch}',
      source:      NodeIdentity.id,
      destination: 'nodeC',
      payload:     'Test DTN message for routing',
      createdAt:   DateTime.now(),
      ttl:         300,
      priority:    3,
    );
    ServiceLocator.storage.saveMyMessage(msg);
    final peerPreds = {'nodeA': 0.2, 'nodeB': 0.8, 'nodeC': 0.9};
    ServiceLocator.dtnManager.onPeerConnected('nodeB', peerPreds, []);
  }
}