import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';

class BluetoothCheckDialog {

  // ── Platform channel for opening BT settings directly ────────────────────
  static const _channel = MethodChannel('com.example.delay_messaging/settings');

  /// Opens the Bluetooth settings panel directly (not just app settings).
  static Future<void> _openBluetoothSettings() async {
    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod('openBluetoothSettings');
        return;
      } catch (_) {
        // Fall through to openAppSettings if channel not implemented yet
      }
    }
    await openAppSettings();
  }

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
      return (await Permission.bluetooth.status).isGranted;
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
      return results.values.every((s) => s.isGranted);
    }
    if (Platform.isIOS) {
      return (await Permission.bluetooth.request()).isGranted;
    }
    return false;
  }

  static Future<bool> _isBluetoothOn() async {
    final central = CentralManager();
    return central.state == BluetoothLowEnergyState.poweredOn;
  }

  // ── Public API ────────────────────────────────────────────────────────────

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

  static Future<bool> checkAndPrompt(BuildContext context) async {
    if (!await _hasPermissions()) {
      if (context.mounted) _showPermissionDialog(context);
      return false;
    }
    if (!await _isBluetoothOn()) {
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
          'ReachOut needs Bluetooth permissions to discover and connect to '
          'nearby devices.\n\nPlease grant the necessary permissions to continue.',
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
              granted ? show(context) : _showPermissionWarningDialog(context);
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
          'ReachOut requires Bluetooth to discover and communicate with '
          'nearby devices.\n\nPlease enable Bluetooth to continue.',
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
              // Re-check after returning from settings
              if (context.mounted) {
                await Future.delayed(const Duration(milliseconds: 500));
                show(context);
              }
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
          'Bluetooth and location permissions are required for ReachOut to '
          'function.\n\nPlease enable them in Settings.',
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