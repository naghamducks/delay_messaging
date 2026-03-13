import 'package:flutter/material.dart';
import '../models/message.dart';
import 'message_status_indicator.dart';
import 'package:intl/intl.dart';

/// Message bubble widget for chat display
class MessageBubble extends StatelessWidget {
  final Message message;

  const MessageBubble({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSentByMe = message.isSentByMe;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isSentByMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isSentByMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: colorScheme.primaryContainer,
              child: Icon(
                Icons.person,
                size: 20,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: message.isSOSMessage
                    ? Colors.red.shade700
                    : isSentByMe
                        ? colorScheme.primaryContainer
                        : colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isSentByMe ? 16 : 4),
                  bottomRight: Radius.circular(isSentByMe ? 4 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // SOS label if applicable
                  if (message.isSOSMessage) ...[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.emergency,
                          size: 16,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'SOS MESSAGE',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],
                  // Message content
                  Text(
                    message.content,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: message.isSOSMessage
                              ? Colors.white
                              : isSentByMe
                                  ? colorScheme.onPrimaryContainer
                                  : colorScheme.onSurface,
                        ),
                  ),
                  const SizedBox(height: 4),
                  // Timestamp and status
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTimestamp(message.timestamp),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: message.isSOSMessage
                                  ? Colors.white70
                                  : isSentByMe
                                      ? colorScheme.onPrimaryContainer.withOpacity(0.7)
                                      : colorScheme.onSurface.withOpacity(0.6),
                            ),
                      ),
                      // Status indicator for sent messages
                      if (isSentByMe) ...[
                        const SizedBox(width: 6),
                        MessageStatusIndicator(
                          status: message.status,
                          isSOSMessage: message.isSOSMessage,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isSentByMe) const SizedBox(width: 8),
        ],
      ),
    );
  }

  /// Format timestamp for display
  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(timestamp.year, timestamp.month, timestamp.day);

    if (messageDate == today) {
      // Show time only for today's messages
      return DateFormat('HH:mm').format(timestamp);
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      // Show "Yesterday" for yesterday's messages
      return 'Yesterday ${DateFormat('HH:mm').format(timestamp)}';
    } else if (now.difference(messageDate).inDays < 7) {
      // Show day name for messages within a week
      return DateFormat('EEE HH:mm').format(timestamp);
    } else {
      // Show date for older messages
      return DateFormat('MMM d, HH:mm').format(timestamp);
    }
  }
}
