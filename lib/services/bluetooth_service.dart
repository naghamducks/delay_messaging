import 'dart:io';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

/// Service for managing Bluetooth functionality
class BluetoothService {
  /// Check if Bluetooth is currently enabled
  Future<bool> isBluetoothEnabled() async {
    try {
      final adapterState = await FlutterBluePlus.adapterState.first;
      return adapterState == BluetoothAdapterState.on;
    } catch (e) {
      return false;
    }
  }

  /// Request Bluetooth + Location permissions, retrying up to [maxAttempts] times.
  /// Returns true only when bluetoothScan, bluetoothConnect, AND location are granted.
  /// Does NOT fail on Permission.bluetooth (legacy pre-12) being denied.
  Future<bool> requestBluetoothPermissions({int maxAttempts = 3}) async {
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      print('Permission request attempt $attempt/$maxAttempts');

      final statuses = await [
        Permission.bluetooth,        // legacy; silently granted on API 31+
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.bluetoothAdvertise,
        Permission.location,
      ].request();

      print('Permission statuses:');
      statuses.forEach((p, s) => print('  $p: $s'));

      // Only gate on BLE granular permissions + location — NOT legacy bluetooth
      final bleGranted =
          (statuses[Permission.bluetoothScan]?.isGranted ?? false) &&
          (statuses[Permission.bluetoothConnect]?.isGranted ?? false);
      final locationGranted =
          statuses[Permission.location]?.isGranted ?? false;

      print('BLE granted: $bleGranted, Location granted: $locationGranted');

      if (bleGranted && locationGranted) {
        print('All required permissions granted on attempt $attempt');
        return true;
      }

      // If permanently denied there's no point retrying — bail early
      final permanentlyDenied = await areBluetoothPermissionsPermanentlyDenied();
      if (permanentlyDenied) {
        print('Permissions permanently denied — stopping early');
        return false;
      }

      if (attempt < maxAttempts) {
        // Small pause before next attempt so the OS dialog can fully dismiss
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }

    print('Failed to get permissions after $maxAttempts attempts');
    return false;
  }

  /// Check if Bluetooth permissions are granted.
  /// On Android 12+, only checks the granular permissions (Scan, Connect)
  /// since legacy Permission.bluetooth always returns denied on API 31+.
  Future<bool> hasBluetoothPermissions() async {
    final scanStatus = await Permission.bluetoothScan.status;
    final connectStatus = await Permission.bluetoothConnect.status;

    // Legacy Permission.bluetooth is auto-granted via manifest on API 31+,
    // so we intentionally skip it here to avoid false negatives.
    return scanStatus.isGranted && connectStatus.isGranted;
  }

  /// Check if location permission is granted (required for BLE scanning)
  Future<bool> hasLocationPermission() async {
    final locationStatus = await Permission.location.status;
    return locationStatus.isGranted;
  }

  /// Check if all required permissions are granted
  Future<bool> hasAllRequiredPermissions() async {
    return await hasBluetoothPermissions() && await hasLocationPermission();
  }

  /// Check if any Bluetooth permissions are permanently denied
  Future<bool> areBluetoothPermissionsPermanentlyDenied() async {
    final scanStatus = await Permission.bluetoothScan.status;
    final connectStatus = await Permission.bluetoothConnect.status;

    return scanStatus.isPermanentlyDenied || connectStatus.isPermanentlyDenied;
  }

  /// Check if location permission is permanently denied
  Future<bool> isLocationPermissionPermanentlyDenied() async {
    final locationStatus = await Permission.location.status;
    return locationStatus.isPermanentlyDenied;
  }

  /// Stream to listen for Bluetooth state changes
  Stream<bool> get bluetoothStateStream {
    return FlutterBluePlus.adapterState.map(
      (state) => state == BluetoothAdapterState.on,
    );
  }

  /// Attempt to turn on Bluetooth
  Future<void> requestEnableBluetooth() async {
    try {
      if (await FlutterBluePlus.isSupported) {
        await FlutterBluePlus.turnOn();
      }
    } catch (e) {
      rethrow;
    }
  }
}
