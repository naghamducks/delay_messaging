import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/dtn_provider.dart';
import '../models/relay_history.dart';
import '../models/dtn_message.dart';
import '../services/DTN_Storage_Service.dart';
import 'package:intl/intl.dart';

/// Screen displaying stored DTN messages
class RelayHistoryScreen extends StatelessWidget {
  const RelayHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dtnProvider = Provider.of<DTNProvider>(context);
    final storedMessages = dtnProvider.getStoredMessages();

    if (storedMessages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.storage_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.secondary,
            ),
            const SizedBox(height: 16),
            Text(
              'No stored messages',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'DTN messages will appear here when stored',
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
      itemCount: storedMessages.length,
      itemBuilder: (context, index) {
        final message = storedMessages[index];
        return _DTNMessageItem(message: message);
      },
    );
  }
}

/// Individual DTN message item
class _DTNMessageItem extends StatelessWidget {
  final DtnMessage message;

  const _DTNMessageItem({required this.message});

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
            // Header with message ID and timestamp
            Row(
              children: [
                Icon(
                  Icons.message,
                  color: colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Message ${message.id.substring(0, 8)}...',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                Text(
                  _formatTime(message.createdAt),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.6),
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Message payload
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                message.payload,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 12),
            // Source and destination
            Row(
              children: [
                Expanded(
                  child: _buildDeviceChip(
                    context,
                    'From: ${message.source}',
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
                    'To: ${message.destination}',
                    Icons.inbox,
                    colorScheme.secondaryContainer,
                    colorScheme.onSecondaryContainer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Priority and TTL info
            Row(
              children: [
                Icon(
                  Icons.priority_high,
                  size: 16,
                  color: message.priority > 5 ? Colors.red : colorScheme.onSurface.withOpacity(0.6),
                ),
                const SizedBox(width: 4),
                Text(
                  'Priority: ${message.priority}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.6),
                      ),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.timer,
                  size: 16,
                  color: colorScheme.onSurface.withOpacity(0.6),
                ),
                const SizedBox(width: 4),
                Text(
                  'TTL: ${message.ttl}s',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.6),
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
