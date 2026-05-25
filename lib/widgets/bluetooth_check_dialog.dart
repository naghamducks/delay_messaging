import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';

/// Dialog to check and prompt for Bluetooth enablement.
///
/// Uses only [permission_handler] and [bluetooth_low_energy] — no
/// android_intent_plus dependency needed.
class BluetoothCheckDialog {
  // ── Permission helpers ────────────────────────────────────────────────────

  static Future<bool> _hasPermissions() async {
    if (Platform.isAndroid) {
      final scan      = await Permission.bluetoothScan.status;
      final connect   = await Permission.bluetoothConnect.status;
      final advertise = await Permission.bluetoothAdvertise.status;
      final location  = await Permission.location.status;
      return scan.isGranted && connect.isGranted &&
             advertise.isGranted && location.isGranted;
    }
    if (Platform.isIOS) {
      final bt = await Permission.bluetooth.status;
      return bt.isGranted;
    }
    return false;
  }

  static Future<bool> _requestPermissions() async {
    if (Platform.isAndroid) {
      final results = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.bluetoothAdvertise,
        Permission.location,
      ].request();
      print('  Permission.location: ${results[Permission.location]}');
      print('  Permission.bluetooth: ${results[Permission.bluetoothScan]}');
      print('  Permission.bluetoothScan: ${results[Permission.bluetoothScan]}');
      print('  Permission.bluetoothAdvertise: ${results[Permission.bluetoothAdvertise]}');
      print('  Permission.bluetoothConnect: ${results[Permission.bluetoothConnect]}');
      return results.values.every((s) => s.isGranted);
    }
    if (Platform.isIOS) {
      final result = await Permission.bluetooth.request();
      return result.isGranted;
    }
    return false;
  }

  static Future<bool> _isBluetoothOn() async {
    final central = CentralManager();
    return central.state == BluetoothLowEnergyState.poweredOn;
  }

  /// Opens Bluetooth settings (platform-appropriate).
  /// Uses [openAppSettings] from permission_handler — no android_intent_plus needed.
  static Future<void> _openBluetoothSettings() async {
    await openAppSettings();
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Show Bluetooth status check dialog if anything is missing.
  static Future<void> show(BuildContext context) async {
    final hasPermissions = await _hasPermissions();
    print('Bluetooth permissions granted: $hasPermissions');

    if (!hasPermissions) {
      print('Showing permission dialog');
      if (context.mounted) _showPermissionDialog(context);
      return;
    }

    final isEnabled = await _isBluetoothOn();
    print('Bluetooth enabled: $isEnabled');

    if (!isEnabled) {
      print('Showing Bluetooth settings dialog');
      if (context.mounted) _showBluetoothSettingsDialog(context);
    } else {
      print('All good - no dialog needed');
    }
  }

  /// Returns true if permissions are granted and Bluetooth is on.
  static Future<bool> checkAndPrompt(BuildContext context) async {
    final hasPermissions = await _hasPermissions();
    if (!hasPermissions) {
      if (context.mounted) _showPermissionDialog(context);
      return false;
    }

    final isEnabled = await _isBluetoothOn();
    if (!isEnabled) {
      if (context.mounted) _showBluetoothSettingsDialog(context);
      return false;
    }

    return true;
  }

  // ── Dialogs ───────────────────────────────────────────────────────────────

  static void _showPermissionDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.bluetooth_disabled, size: 64, color: Colors.orange),
        title: const Text('Bluetooth Permissions Required'),
        content: const Text(
          'This app needs Bluetooth permissions to discover and connect to nearby '
          'DTN devices.\n\nPlease grant the necessary permissions to continue.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (context.mounted) _showPermissionWarningDialog(context);
            },
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final granted = await _requestPermissions();
              if (!context.mounted) return;
              if (granted) {
                show(context);
              } else {
                _showPermissionWarningDialog(context);
              }
            },
            child: const Text('Grant Permissions'),
          ),
        ],
      ),
    );
  }

  static void _showBluetoothSettingsDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.bluetooth_disabled, size: 64, color: Colors.red),
        title: const Text('Bluetooth is Off'),
        content: const Text(
          'DTN Messenger requires Bluetooth to discover and communicate with '
          'nearby devices.\n\nPlease enable Bluetooth in your device settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _openBluetoothSettings();
            },
            child: const Text('Open Bluetooth Settings'),
          ),
        ],
      ),
    );
  }

  static void _showPermissionWarningDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning, size: 64, color: Colors.red),
        title: const Text('Permissions Required'),
        content: const Text(
          'Bluetooth and location permissions are required for DTN Messenger '
          'to function.\n\nWithout these permissions, the app cannot discover '
          'or communicate with nearby devices.\n\nYou will need to enable them '
          'in Settings to use this app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
}