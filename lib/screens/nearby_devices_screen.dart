import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../models/message.dart';

/// Screen displaying locations of SOS messages
class LocationScreen extends StatelessWidget {
  const LocationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, child) {
        // Collect all SOS messages with locations
        final sosMessages = <Message>[];
        for (final chat in chatProvider.chats) {
          for (final message in chat.messages) {
            if (message.isSOSMessage && message.latitude != null && message.longitude != null) {
              sosMessages.add(message);
            }
          }
        }

        return Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'SOS Message Locations',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            // SOS messages list
            Expanded(
              child: sosMessages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.location_off,
                            size: 64,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No SOS locations',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'SOS messages with location data will appear here',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: sosMessages.length,
                      itemBuilder: (context, index) {
                        final message = sosMessages[index];
                        return _SOSLocationItem(message: message);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

/// Individual SOS location list item
class _SOSLocationItem extends StatelessWidget {
  final Message message;

  const _SOSLocationItem({required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
          child: Icon(
            Icons.warning,
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
        ),
        title: Text(
          message.content,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'Lat: ${message.latitude!.toStringAsFixed(4)}, Lng: ${message.longitude!.toStringAsFixed(4)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              _formatTime(message.timestamp),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.map),
          onPressed: () {
            // TODO: Open map with location
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Map integration coming soon')),
            );
          },
          tooltip: 'View on map',
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}
