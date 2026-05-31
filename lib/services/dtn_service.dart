import 'package:delay_messenger/models/dtn_message.dart';
import 'package:delay_messenger/services/service_locator.dart';

import '../models/message.dart';
import '../models/dtn_device.dart';

/// Service for DTN network operations
class DTNService {

  /// Send a message through the DTN network
  /// In a real implementation, this would handle:
  /// - Message storage in the bundle layer
  /// - Routing decisions based on contact predictions
  /// - Custody transfer protocols
Future<void> sendMessage(String peerId, DtnMessage msg) async {
    // Route through the shared singleton, not a local BLE instance
    await ServiceLocator.ble.sendMessage(peerId, msg);
  }

  /// Receive messages from the DTN network
  /// In a real implementation, this would:
  /// - Listen for incoming bundle protocol messages
  /// - Handle custody acknowledgments
  /// - Process delivery reports
  Stream<Message> receiveMessages() {
    // TODO: Implement bundle protocol receiver
    return Stream.empty();
  }

  /// Discover nearby DTN-capable devices
  /// In a real implementation, this would use:
  /// - Bluetooth Low Energy (BLE)
  /// - WiFi Direct
  /// - LoRa or other radio protocols
  Future<List<DTNDevice>> discoverDevices() async {
    // TODO: Implement device discovery protocol
    await Future.delayed(const Duration(seconds: 1));
    return [];
  }

  /// Establish connection with a DTN device
  /// Handles the contact graph and routing updates
  Future<bool> connectToDevice(String deviceId) async {
    // TODO: Implement connection protocol
    // - Negotiate communication parameters
    // - Exchange routing tables
    // - Update contact graph
    await Future.delayed(const Duration(seconds: 1));
    return true;
  }

  /// Get the current status of a message in the DTN network
  Future<MessageStatus> getMessageStatus(String messageId) async {
    // TODO: Query the DTN bundle layer for message status
    await Future.delayed(const Duration(milliseconds: 100));
    return MessageStatus.sent;
  }

  /// Register as a relay node to forward messages for others
  Future<void> enableRelayMode() async {
    // Relay mode preference is persisted in SharedPreferences (SettingsScreen).
    // The actual relay behaviour is always active in DtnManager.
    await Future.delayed(const Duration(milliseconds: 500));
  }

  /// Query relay history from local storage (last 10 entries)
  Future<List<Map<String, dynamic>>> getRelayHistory() async {
    final msgs = ServiceLocator.storage.getRelayMessages()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return msgs.take(10).map((m) => {
      'id': m.id,
      'source': m.source,
      'destination': m.destination,
      'createdAt': m.createdAt.toIso8601String(),
    }).toList();
  }
}