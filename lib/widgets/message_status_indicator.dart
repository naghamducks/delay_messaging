import 'package:flutter/material.dart';
import '../models/message.dart';

/// Widget to display DTN message status with appropriate icons
class MessageStatusIndicator extends StatelessWidget {
  final MessageStatus status;
  final bool isSOSMessage;

  const MessageStatusIndicator({
    super.key,
    required this.status,
    this.isSOSMessage = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final iconColor = isSOSMessage
        ? Colors.white70
        : colorScheme.onPrimaryContainer.withOpacity(0.7);

    return Tooltip(
      message: _getStatusTooltip(),
      child: Icon(
        _getStatusIcon(),
        size: 16,
        color: iconColor,
      ),
    );
  }

  /// Get the appropriate icon for the message status
  IconData _getStatusIcon() {
    switch (status) {
      case MessageStatus.sent:
        // Normal check mark - message stored/sent from device
        return Icons.check;
      case MessageStatus.searchingForRelay:
        // Reload/circular arrow - message waiting for relay
        return Icons.sync;
      case MessageStatus.relayed:
        // Up arrow - message forwarded but not delivered
        return Icons.arrow_upward;
      case MessageStatus.delivered:
        // Double check mark - message delivered
        return Icons.done_all;
    }
  }

  /// Get tooltip text explaining the status
  String _getStatusTooltip() {
    switch (status) {
      case MessageStatus.sent:
        return 'Sent from device';
      case MessageStatus.searchingForRelay:
        return 'Searching for relay node';
      case MessageStatus.relayed:
        return 'Relayed, awaiting delivery';
      case MessageStatus.delivered:
        return 'Delivered';
    }
  }
}
