import 'package:delay_messenger/models/dtn_message.dart';
import 'package:delay_messenger/services/node_identity.dart';
import 'package:delay_messenger/services/service_locator.dart';
import 'package:flutter/material.dart';
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
  }

  Future<void> scanForDevices() async {
    await ServiceLocator.dtnManager.startBle();
    // BLE scan results will come back via the onPeerConnected callback;
    // update _nearbyDevices there once real BLE data arrives.
    await Future.delayed(const Duration(seconds: 2));
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
  ServiceLocator.storage.saveMessage(msg);

  final peerPreds = {'nodeA': 0.2, 'nodeB': 0.8, 'nodeC': 0.9};
  ServiceLocator.dtnManager.onPeerConnected('nodeB', peerPreds, []);

  print('🧪 ===== PROPHET TEST COMPLETE =====\n');
}
  // Keep existing mock data and toggle helpers unchanged
  void _initializeMockData() { /* your existing code */ }
  void toggleDeviceConnection(String deviceId) { /* your existing code */ }
}