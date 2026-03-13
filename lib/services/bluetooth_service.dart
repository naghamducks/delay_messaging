import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

/// Service for managing Bluetooth functionality
class BluetoothService {
  /// Check if Bluetooth is currently enabled
  Future<bool> isBluetoothEnabled() async {
    try {
      // Check if adapter is on
      final adapterState = await FlutterBluePlus.adapterState.first;
      return adapterState == BluetoothAdapterState.on;
    } catch (e) {
      // On platforms without Bluetooth support, return false
      return false;
    }
  }

  /// Request Bluetooth permissions
  Future<bool> requestBluetoothPermissions() async {
    // Request necessary permissions
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location, // Required for BLE scanning on Android
    ].request();

    // Check if all permissions are granted
    return statuses.values.every((status) => status.isGranted);
  }

  /// Check if Bluetooth permissions are granted
  Future<bool> hasBluetoothPermissions() async {
    final bluetoothStatus = await Permission.bluetooth.status;
    final scanStatus = await Permission.bluetoothScan.status;
    final connectStatus = await Permission.bluetoothConnect.status;
    final locationStatus = await Permission.location.status;

    return bluetoothStatus.isGranted &&
        scanStatus.isGranted &&
        connectStatus.isGranted &&
        locationStatus.isGranted;
  }

  /// Stream to listen for Bluetooth state changes
  Stream<bool> get bluetoothStateStream {
    return FlutterBluePlus.adapterState.map(
      (state) => state == BluetoothAdapterState.on,
    );
  }

  /// Attempt to turn on Bluetooth (platform-dependent)
  /// On iOS, this will prompt the user. On Android, it may open settings.
  Future<void> requestEnableBluetooth() async {
    try {
      // This might not work on all platforms
      // On iOS, it will show a system dialog
      // On Android, you may need to open settings manually
      if (await FlutterBluePlus.isSupported) {
        await FlutterBluePlus.turnOn();
      }
    } catch (e) {
      // Handle error - might need to open settings manually
      rethrow;
    }
  }
}
