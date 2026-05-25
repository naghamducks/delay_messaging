import 'package:delay_messenger/models/dtn_message.dart';
import 'package:delay_messenger/services/node_identity.dart';
import 'package:delay_messenger/services/service_locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../models/dtn_device.dart';
import '../models/relay_history.dart';
import '../services/dtn_manager.dart';

class DTNProvider extends ChangeNotifier {
  // All services come from the shared singleton — no local instantiation
  DtnManager get dtnManager => ServiceLocator.dtnManager;

  List<DTNDevice>    _nearbyDevices = [];
  List<RelayHistory> _relayHistory  = [];

  List<DTNDevice>    get nearbyDevices => _nearbyDevices;
  List<RelayHistory> get relayHistory  => _relayHistory;

  DTNProvider() {
    _initializeMockData();
    // Wire discovery callbacks immediately (ble exists at this point)
    _wireDiscoveryCallbacks();
    // Wire peer-connected callback after the current frame so DtnManager
    // has finished its own _wireBlCallbacks() constructor call first.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _wirePeerConnectedCallback();
    });
  }

  void _wireDiscoveryCallbacks() {
    ServiceLocator.ble.onDeviceDiscovered = (peerId, name, rssi) {
      final clamped = rssi.clamp(-100, -40);
      final strength = (clamped + 100) / 60.0;

      final exists = _nearbyDevices.any((d) => d.id == peerId);
      if (!exists) {
        _nearbyDevices.add(DTNDevice(
          id: peerId,
          name: name.startsWith('DTN-') ? name.substring(4) : name,
          deviceType: 'BLE',
          signalStrength: strength.clamp(0.0, 1.0),
          isConnected: false,
          lastSeen: DateTime.now(),
        ));
        notifyListeners();
      }
    };

    ServiceLocator.ble.onDeviceLost = (peerId) {
      final index = _nearbyDevices.indexWhere((d) => d.id == peerId);
      if (index != -1) {
        _nearbyDevices[index] =
            _nearbyDevices[index].copyWith(isConnected: false);
        notifyListeners();
      }
    };
  }

  void _wirePeerConnectedCallback() {
    // Wrap the callback that DtnManager set so we get UI updates too
    final originalBleCallback = ServiceLocator.ble.onPeerConnected;
    ServiceLocator.ble.onPeerConnected = (peerId, peerPreds, peerMsgIds) {
      final index = _nearbyDevices.indexWhere((d) => d.id == peerId);
      if (index != -1) {
        _nearbyDevices[index] = _nearbyDevices[index].copyWith(
          isConnected: true,
          lastSeen: DateTime.now(),
        );
      } else {
        // Handshake completed without a prior discovery event (peripheral role)
        _nearbyDevices.add(DTNDevice(
          id: peerId,
          name: peerId,
          deviceType: 'BLE',
          signalStrength: 0.5,
          isConnected: true,
          lastSeen: DateTime.now(),
        ));
      }
      notifyListeners();
      originalBleCallback?.call(peerId, peerPreds, peerMsgIds);
    };
  }

  Future<void> scanForDevices() async {
    await ServiceLocator.dtnManager.startBle();
    // Results arrive via onDeviceDiscovered callback above — no delay needed.
    notifyListeners();
  }

void runProphetTest() {
  print('\n🧪 ===== PROPHET ROUTING TEST =====\n');

  // Clean up previous test messages to avoid accumulation
  final existing = ServiceLocator.storage.getAllMessages();
  for (final m in existing) {
    if (m.id.startsWith('msg_test_')) {
      ServiceLocator.storage.deleteMessage(m.id);
    }
  }

  final msg = DtnMessage(
    id:          'msg_test_${DateTime.now().millisecondsSinceEpoch}',
    source:      NodeIdentity.id,   // ← fixed
    destination: 'nodeC',
    payload:     'Test DTN message for routing',
    createdAt:   DateTime.now(),
    ttl:         300,
    priority:    3,
  );
  ServiceLocator.storage.saveMyMessage(msg);

  final peerPreds = {'nodeA': 0.2, 'nodeB': 0.8, 'nodeC': 0.9};
  ServiceLocator.dtnManager.onPeerConnected('nodeB', peerPreds, []);

  print('🧪 ===== PROPHET TEST COMPLETE =====\n');
}
  // Keep existing mock data and toggle helpers unchanged
  void _initializeMockData() { /* your existing code */ }
  void toggleDeviceConnection(String deviceId) { /* your existing code */ }
}