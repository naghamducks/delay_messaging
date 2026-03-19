import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import '../services/bluetooth_service.dart';

/// Dialog to check and prompt for Bluetooth enablement
class BluetoothCheckDialog {
  static final BluetoothService _bluetoothService = BluetoothService();

  /// Opens Bluetooth settings directly on Android, or general settings on iOS
  static Future<void> _openBluetoothSettings() async {
    if (Platform.isAndroid) {
      const intent = AndroidIntent(
        action: 'android.settings.BLUETOOTH_SETTINGS',
        flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
      );
      await intent.launch();
    } else {
      await openAppSettings();
    }
  }

  /// Show Bluetooth status check dialog
  static Future<void> show(BuildContext context) async {
    // Check permissions first
    final hasPermissions = await _bluetoothService.hasBluetoothPermissions();
    print('Bluetooth permissions granted: $hasPermissions');

    if (!hasPermissions) {
      print('Showing permission dialog');
      _showPermissionDialog(context);
      return;
    }

    // Check if Bluetooth is enabled
    final isEnabled = await _bluetoothService.isBluetoothEnabled();
    print('Bluetooth enabled: $isEnabled');

    if (!isEnabled) {
      print('Showing Bluetooth settings dialog');
      _showBluetoothSettingsDialog(context);
    } else {
      print('All good - no dialog needed');
    }
    // If permissions are granted and Bluetooth is enabled, do nothing
  }

  /// Show dialog when Bluetooth permissions are not granted
  static void _showPermissionDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(
          Icons.bluetooth_disabled,
          size: 64,
          color: Colors.orange,
        ),
        title: const Text('Bluetooth Permissions Required'),
        content: const Text(
          'This app needs Bluetooth permissions to discover and connect to nearby DTN devices.\n\n'
          'Please grant the necessary permissions to continue.',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              // Show warning when user cancels
              _showPermissionWarningDialog(context);
            },
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              final granted = await _bluetoothService.requestBluetoothPermissions();

              if (granted) {
                // Check Bluetooth status after permissions granted
                show(context);
              } else {
                // Show warning dialog before going to settings
                _showPermissionWarningDialog(context);
              }
            },
            child: const Text('Grant Permissions'),
          ),
        ],
      ),
    );
  }

  /// Show dialog when Bluetooth is turned off
  static void _showBluetoothSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(
          Icons.bluetooth_disabled,
          size: 64,
          color: Colors.red,
        ),
        title: const Text('Bluetooth is Off'),
        content: const Text(
          'DTN Messenger requires Bluetooth to discover and communicate with nearby devices.\n\n'
          'Please enable Bluetooth in your device settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              // Open Bluetooth settings directly
              await _openBluetoothSettings();
            },
            child: const Text('Open Bluetooth Settings'),
          ),
        ],
      ),
    );
  }

  /// Show dialog to open system settings
  static void _showOpenSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(
          Icons.settings,
          size: 64,
          color: Colors.blue,
        ),
        title: const Text('Open Settings'),
        content: const Text(
          'Please enable Bluetooth in your device settings to use DTN Messenger features.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              await openAppSettings();
              Navigator.pop(context);
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  /// Show warning dialog when permissions are denied
  static void _showPermissionWarningDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(
          Icons.warning,
          size: 64,
          color: Colors.red,
        ),
        title: const Text('Permissions Required'),
        content: const Text(
          'Bluetooth and location permissions are required for DTN Messenger to function.\n\n'
          'Without these permissions, the app cannot discover or communicate with nearby devices.\n\n'
          'You will need to enable them in Settings to use this app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              _showOpenSettingsDialog(context);
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  /// Check Bluetooth status and show appropriate dialog if needed
  static Future<bool> checkAndPrompt(BuildContext context) async {
    final hasPermissions = await _bluetoothService.hasBluetoothPermissions();
    if (!hasPermissions) {
      _showPermissionDialog(context);
      return false;
    }

    final isEnabled = await _bluetoothService.isBluetoothEnabled();
    if (!isEnabled) {
      _showBluetoothSettingsDialog(context);
      return false;
    }

    return true;
  }
}
