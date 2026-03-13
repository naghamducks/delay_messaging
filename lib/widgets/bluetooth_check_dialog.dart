import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/bluetooth_service.dart';

/// Dialog to check and prompt for Bluetooth enablement
class BluetoothCheckDialog {
  static final BluetoothService _bluetoothService = BluetoothService();

  /// Show Bluetooth status check dialog
  static Future<void> show(BuildContext context) async {
    // Check permissions first
    final hasPermissions = await _bluetoothService.hasBluetoothPermissions();
    
    if (!hasPermissions) {
      _showPermissionDialog(context);
      return;
    }

    // Check if Bluetooth is enabled
    final isEnabled = await _bluetoothService.isBluetoothEnabled();

    if (!isEnabled) {
      _showBluetoothOffDialog(context);
    }
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
            onPressed: () => Navigator.pop(context),
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
                // Show settings dialog if permissions denied
                _showOpenSettingsDialog(context);
              }
            },
            child: const Text('Grant Permissions'),
          ),
        ],
      ),
    );
  }

  /// Show dialog when Bluetooth is turned off
  static void _showBluetoothOffDialog(BuildContext context) {
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
          'Please enable Bluetooth to continue.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await _bluetoothService.requestEnableBluetooth();
                Navigator.pop(context);
                
                // Wait a moment for Bluetooth to turn on
                await Future.delayed(const Duration(seconds: 1));
                
                // Verify it's on
                final isNowEnabled = await _bluetoothService.isBluetoothEnabled();
                if (!isNowEnabled) {
                  // If still not enabled, show settings option
                  _showOpenSettingsDialog(context);
                }
              } catch (e) {
                // If automatic enable fails, show settings
                Navigator.pop(context);
                _showOpenSettingsDialog(context);
              }
            },
            child: const Text('Enable Bluetooth'),
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

  /// Check Bluetooth status and show appropriate dialog if needed
  static Future<bool> checkAndPrompt(BuildContext context) async {
    final hasPermissions = await _bluetoothService.hasBluetoothPermissions();
    if (!hasPermissions) {
      _showPermissionDialog(context);
      return false;
    }

    final isEnabled = await _bluetoothService.isBluetoothEnabled();
    if (!isEnabled) {
      _showBluetoothOffDialog(context);
      return false;
    }

    return true;
  }
}
