import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class BlePermissionService {
  /// Call this once from main() or a splash screen before starting BLE.
  /// Returns true if all required permissions are granted.
  static Future<bool> requestAll(BuildContext context) async {
    final required = _requiredPermissions();
    final statuses = await required.request();

    final denied = statuses.entries
        .where((e) => !e.value.isGranted)
        .map((e) => e.key.toString())
        .toList();

    if (denied.isEmpty) {
      print('✅ [Permissions] All BLE permissions granted');
      return true;
    }

    print('❌ [Permissions] Denied: $denied');

    // Show a dialog explaining why permissions are needed
    if (context.mounted) {
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Bluetooth permissions required'),
          content: const Text(
            'DTN Messenger needs Bluetooth access to discover and communicate '
            'with nearby devices. Please grant the permissions in Settings.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
    }

    return false;
  }

  static List<Permission> _requiredPermissions() {
    if (Platform.isAndroid) {
      return [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.bluetoothAdvertise,
        Permission.locationWhenInUse,
      ];
    } else if (Platform.isIOS) {
      return [
        Permission.bluetooth,
        Permission.locationWhenInUse,
      ];
    }
    return [];
  }
}