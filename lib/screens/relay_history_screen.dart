import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/dtn_provider.dart';
import '../models/relay_history.dart';
import 'package:intl/intl.dart';

/// Screen displaying message relay history
class RelayHistoryScreen extends StatelessWidget {
  const RelayHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DTNProvider>(
      builder: (context, dtnProvider, child) {
        if (dtnProvider.relayHistory.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.history_outlined,
                  size: 64,
                  color: Theme.of(context).colorScheme.secondary,
                ),
                const SizedBox(height: 16),
                Text(
                  'No relay history',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Message relay events will appear here',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: dtnProvider.relayHistory.length,
          itemBuilder: (context, index) {
            final relay = dtnProvider.relayHistory[index];
            return _RelayHistoryItem(relay: relay);
          },
        );
      },
    );
  }
}

/// Individual relay history item
class _RelayHistoryItem extends StatelessWidget {
  final RelayHistory relay;

  const _RelayHistoryItem({required this.relay});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with status
            Row(
              children: [
                Icon(
                  relay.successful ? Icons.check_circle : Icons.error,
                  color: relay.successful ? Colors.green : Colors.red,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  relay.successful ? 'Relay Successful' : 'Relay Failed',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: relay.successful ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                Text(
                  _formatTime(relay.relayTime),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.6),
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Message preview
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.message,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      relay.messagePreview,
                      style: Theme.of(context).textTheme.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Relay path
            Row(
              children: [
                Expanded(
                  child: _buildDeviceChip(
                    context,
                    relay.fromDevice,
                    Icons.send,
                    colorScheme.primaryContainer,
                    colorScheme.onPrimaryContainer,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(
                    Icons.arrow_forward,
                    size: 20,
                    color: colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                Expanded(
                  child: _buildDeviceChip(
                    context,
                    relay.toDevice,
                    Icons.router,
                    colorScheme.secondaryContainer,
                    colorScheme.onSecondaryContainer,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Build a device chip
  Widget _buildDeviceChip(
    BuildContext context,
    String deviceName,
    IconData icon,
    Color backgroundColor,
    Color textColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: textColor),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              deviceName,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w500,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// Format timestamp
  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d').format(time);
    }
  }
}
