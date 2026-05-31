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

  final Map<String, String> _peerNames  = {};
  final Map<String, String> _peerDtnIds = {};

  ChatProvider? _chatProviderRef;

  List<DTNDevice>    get nearbyDevices => _nearbyDevices;
  List<RelayHistory> get relayHistory  => _relayHistory;

  void setChatProvider(ChatProvider provider) => _chatProviderRef = provider;

  String peerDisplayName(String peerId) =>
      _peerNames[peerId] ??
      _peerNames[_peerDtnIds[peerId] ?? ''] ??
      peerId;

  DTNProvider() {
    _loadPersistedNames();
    _wireDiscoveryCallbacks();
    SchedulerBinding.instance.addPostFrameCallback((_) => _wirePeerConnectedCallback());
  }

  static const _kNamesKey = 'dtn_peer_names';

  Future<void> _loadPersistedNames() async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getStringList(_kNamesKey) ?? [];
    for (final entry in raw) {
      final sep = entry.indexOf('|');
      if (sep > 0) _peerNames[entry.substring(0, sep)] = entry.substring(sep + 1);
    }
  }

  Future<void> _persistNames() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kNamesKey,
        _peerNames.entries.map((e) => '${e.key}|${e.value}').toList());
    ChatProvider.invalidatePeerNamesCache();
  }

  void _storeName(String id, String name) {
    _peerNames[id] = name;
    _persistNames();
  }

  void _wireDiscoveryCallbacks() {
    ServiceLocator.ble.onDeviceDiscovered = (blePeerId, advName, rssi) {
      final strength     = ((rssi.clamp(-100, -40) + 100) / 60.0).clamp(0.0, 1.0);
      final strippedName = advName.startsWith('DTN-') ? advName.substring(4) : advName;
      final resolvedName = _peerNames[blePeerId] ??
          _peerNames[_peerDtnIds[blePeerId] ?? ''] ??
          strippedName;

      final dtnId        = _peerDtnIds[blePeerId];
      final alreadyExists = _nearbyDevices.any(
          (d) => d.id == blePeerId || (dtnId != null && d.id == dtnId));

      if (!alreadyExists) {
        _nearbyDevices.add(DTNDevice(
          id: blePeerId, name: resolvedName, deviceType: 'BLE',
          signalStrength: strength, isConnected: false, lastSeen: DateTime.now(),
        ));
        notifyListeners();
      } else {
        final idx = _nearbyDevices.indexWhere(
            (d) => d.id == blePeerId || (dtnId != null && d.id == dtnId));
        if (idx != -1) {
          _nearbyDevices[idx] = _nearbyDevices[idx]
              .copyWith(signalStrength: strength, lastSeen: DateTime.now());
          notifyListeners();
        }
      }
    };

    ServiceLocator.ble.onDeviceLost = (peerId) {
      final idx = _nearbyDevices.indexWhere(
          (d) => d.id == peerId || d.id == (_peerDtnIds[peerId] ?? ''));
      if (idx != -1) {
        _nearbyDevices[idx] = _nearbyDevices[idx].copyWith(isConnected: false);
        notifyListeners();
      }
    };

    // FIX: capture prev BEFORE the assignment so the closure holds the old
    // handler, not a reference to itself (which caused an infinite loop).
    final prevOnPeerNodeId = ServiceLocator.ble.onPeerNodeId;
    ServiceLocator.ble.onPeerNodeId = (blePeerId, dtnNodeId) {
      // Chain: call DtnManager's handler first (registered in _wireBlCallbacks)
      prevOnPeerNodeId?.call(blePeerId, dtnNodeId);

      _peerDtnIds[blePeerId] = dtnNodeId;
      print('🔄 MAPPING (DTNProvider): $blePeerId → $dtnNodeId');

      // registerMapping keeps the DTNProvider's own reverse map in sync
      ServiceLocator.dtnManager.registerMapping(blePeerId, dtnNodeId);

      // Consolidate chat list: any chat created under the BLE UUID should
      // be renamed/merged into the canonical DTN ID chat immediately.
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _chatProviderRef?.replaceBleIdWithNodeId(blePeerId, dtnNodeId);
      });

      notifyListeners();
    };

    ServiceLocator.ble.onPeerDisplayName = (blePeerId, displayName) {
      _storeName(blePeerId, displayName);
      final dtnId = _peerDtnIds[blePeerId];
      if (dtnId != null) _storeName(dtnId, displayName);

      final idx = _nearbyDevices.indexWhere(
          (d) => d.id == blePeerId || (dtnId != null && d.id == dtnId));
      if (idx != -1) _nearbyDevices[idx] = _nearbyDevices[idx].copyWith(name: displayName);
      notifyListeners();

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

      final idx = _nearbyDevices.indexWhere((d) => d.id == peerId || d.id == dtnId);
      if (idx != -1) {
        _nearbyDevices[idx] = _nearbyDevices[idx].copyWith(
            isConnected: true, lastSeen: DateTime.now(), name: name);
      } else {
        _nearbyDevices.removeWhere((d) => d.id == peerId);
        _nearbyDevices.add(DTNDevice(
          id: dtnId, name: name, deviceType: 'BLE',
          signalStrength: 0.05, isConnected: true, lastSeen: DateTime.now(),
        ));
      }
      notifyListeners();
      original?.call(peerId, peerPreds, peerMsgIds);
    };
  }

  Future<void> scanForDevices() async {
    _nearbyDevices.removeWhere((d) => !d.isConnected);
    ServiceLocator.dtnManager.startBle();
    notifyListeners();
  }

  void toggleDeviceConnection(String deviceId) {
    final idx = _nearbyDevices.indexWhere((d) => d.id == deviceId);
    if (idx == -1) return;
    _nearbyDevices[idx] = _nearbyDevices[idx]
        .copyWith(isConnected: !_nearbyDevices[idx].isConnected);
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
    ServiceLocator.dtnManager.onPeerConnected(
        'nodeB', {'nodeA': 0.2, 'nodeB': 0.8, 'nodeC': 0.9}, []);
  }
}