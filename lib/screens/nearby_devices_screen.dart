import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/dtn_provider.dart';
import '../models/dtn_device.dart';

/// Screen displaying nearby DTN-capable devices
class NearbyDevicesScreen extends StatelessWidget {
  const NearbyDevicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DTNProvider>(
      builder: (context, dtnProvider, child) {
        return Column(
          children: [
            // Scan button
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => dtnProvider.scanForDevices(),
                  icon: const Icon(Icons.radar),
                  label: const Text('Scan for Devices'),
                ),
              ),
            ),
            // Device list
            Expanded(
              child: dtnProvider.nearbyDevices.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.devices_outlined,
                            size: 64,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No devices found',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap scan to discover nearby DTN nodes',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: dtnProvider.nearbyDevices.length,
                      itemBuilder: (context, index) {
                        final device = dtnProvider.nearbyDevices[index];
                        return _DeviceListItem(
                          device: device,
                          onToggleConnection: () {
                            dtnProvider.toggleDeviceConnection(device.id);
                          },
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

/// Individual device list item
class _DeviceListItem extends StatelessWidget {
  final DTNDevice device;
  final VoidCallback onToggleConnection;

  const _DeviceListItem({
    required this.device,
    required this.onToggleConnection,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: device.isConnected
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHighest,
          child: Icon(
            _getDeviceIcon(),
            color: device.isConnected
                ? colorScheme.onPrimaryContainer
                : colorScheme.onSurfaceVariant,
          ),
        ),
        title: Text(device.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(device.deviceType),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.signal_cellular_alt,
                  size: 16,
                  color: _getSignalColor(device.signalStrength, colorScheme),
                ),
                const SizedBox(width: 4),
                Text(
                  '${(device.signalStrength * 100).toInt()}%',
                  style: TextStyle(
                    color: _getSignalColor(device.signalStrength, colorScheme),
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  _getLastSeenText(),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
        trailing: FilledButton.tonal(
          onPressed: onToggleConnection,
          child: Text(device.isConnected ? 'Disconnect' : 'Connect'),
        ),
      ),
    );
  }

  /// Get icon based on device type
  IconData _getDeviceIcon() {
    switch (device.deviceType.toLowerCase()) {
      case 'mobile':
        return Icons.smartphone;
      case 'fixed station':
        return Icons.router;
      case 'satellite':
        return Icons.satellite_alt;
      default:
        return Icons.device_unknown;
    }
  }

  /// Get color based on signal strength
  Color _getSignalColor(double strength, ColorScheme colorScheme) {
    if (strength >= 0.7) {
      return Colors.green;
    } else if (strength >= 0.4) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  /// Get human-readable last seen text
  String _getLastSeenText() {
    final now = DateTime.now();
    final difference = now.difference(device.lastSeen);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}
