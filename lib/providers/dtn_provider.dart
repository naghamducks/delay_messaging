import 'package:flutter/material.dart';
import '../models/dtn_device.dart';
import '../models/relay_history.dart';

/// Provider for managing DTN-specific functionality (devices, relay history)
class DTNProvider extends ChangeNotifier {
  List<DTNDevice> _nearbyDevices = [];
  List<RelayHistory> _relayHistory = [];

  List<DTNDevice> get nearbyDevices => _nearbyDevices;
  List<RelayHistory> get relayHistory => _relayHistory;

  DTNProvider() {
    _initializeMockData();
  }

  /// Initialize with mock data for demonstration
  void _initializeMockData() {
    _nearbyDevices = [
      DTNDevice(
        id: 'd1',
        name: 'Field Device Alpha',
        deviceType: 'Mobile',
        signalStrength: 0.85,
        isConnected: true,
        lastSeen: DateTime.now().subtract(const Duration(seconds: 30)),
      ),
      DTNDevice(
        id: 'd2',
        name: 'Relay Node 7',
        deviceType: 'Fixed Station',
        signalStrength: 0.65,
        isConnected: true,
        lastSeen: DateTime.now().subtract(const Duration(minutes: 1)),
      ),
      DTNDevice(
        id: 'd3',
        name: 'Emergency Responder Unit',
        deviceType: 'Mobile',
        signalStrength: 0.45,
        isConnected: false,
        lastSeen: DateTime.now().subtract(const Duration(minutes: 5)),
      ),
      DTNDevice(
        id: 'd4',
        name: 'Base Station Charlie',
        deviceType: 'Fixed Station',
        signalStrength: 0.92,
        isConnected: true,
        lastSeen: DateTime.now().subtract(const Duration(seconds: 15)),
      ),
      DTNDevice(
        id: 'd5',
        name: 'Satellite Relay',
        deviceType: 'Satellite',
        signalStrength: 0.55,
        isConnected: true,
        lastSeen: DateTime.now().subtract(const Duration(minutes: 2)),
      ),
    ];

    _relayHistory = [
      RelayHistory(
        id: 'r1',
        messageId: 'm1',
        messagePreview: 'Hello! Are you there?',
        fromDevice: 'This Device',
        toDevice: 'Relay Node 7',
        relayTime: DateTime.now().subtract(const Duration(hours: 1, minutes: 50)),
        successful: true,
      ),
      RelayHistory(
        id: 'r2',
        messageId: 'm1',
        messagePreview: 'Hello! Are you there?',
        fromDevice: 'Relay Node 7',
        toDevice: 'Base Station Charlie',
        relayTime: DateTime.now().subtract(const Duration(hours: 1, minutes: 45)),
        successful: true,
      ),
      RelayHistory(
        id: 'r3',
        messageId: 'm5',
        messagePreview: 'All clear. Continuing to waypoint B.',
        fromDevice: 'This Device',
        toDevice: 'Field Device Alpha',
        relayTime: DateTime.now().subtract(const Duration(hours: 2, minutes: 28)),
        successful: true,
      ),
      RelayHistory(
        id: 'r4',
        messageId: 'm3',
        messagePreview: 'Stay safe. I\'ll keep trying to reach you.',
        fromDevice: 'This Device',
        toDevice: 'Relay Node 7',
        relayTime: DateTime.now().subtract(const Duration(minutes: 28)),
        successful: false,
      ),
    ];

    notifyListeners();
  }

  /// Simulate scanning for nearby devices
  Future<void> scanForDevices() async {
    // In a real implementation, this would use BLE, WiFi Direct, or other DTN protocols
    await Future.delayed(const Duration(seconds: 2));
    
    // Update signal strengths and last seen times
    _nearbyDevices = _nearbyDevices.map((device) {
      return device.copyWith(
        signalStrength: (device.signalStrength + (0.1 - 0.05 * 2 * (device.signalStrength > 0.5 ? 1 : -1))).clamp(0.0, 1.0),
        lastSeen: DateTime.now(),
      );
    }).toList();

    notifyListeners();
  }

  /// Toggle connection to a device
  void toggleDeviceConnection(String deviceId) {
    final deviceIndex = _nearbyDevices.indexWhere((d) => d.id == deviceId);
    if (deviceIndex != -1) {
      _nearbyDevices[deviceIndex] = _nearbyDevices[deviceIndex].copyWith(
        isConnected: !_nearbyDevices[deviceIndex].isConnected,
      );
      notifyListeners();
    }
  }

  /// Add a relay history entry
  void addRelayHistory(RelayHistory relay) {
    _relayHistory.insert(0, relay);
    notifyListeners();
  }
}
