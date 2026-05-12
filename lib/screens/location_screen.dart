import 'dart:async';
import 'package:delay_messenger/screens/sos_map_screens.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../models/message.dart';
 
class LocationScreen extends StatefulWidget {
  const LocationScreen({super.key});

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  Timer? _cleanupTimer;

  @override
  void initState() {
    super.initState();
    // Run cleanup every minute to remove expired SOS messages
    _cleanupTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _purgeExpiredSos();
    });
    // Also run once immediately on screen open
    WidgetsBinding.instance.addPostFrameCallback((_) => _purgeExpiredSos());
  }

  @override
  void dispose() {
    _cleanupTimer?.cancel();
    super.dispose();
  }

  void _purgeExpiredSos() {
    final provider = context.read<ChatProvider>();
    provider.purgeExpiredSosMessages();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, child) {
        // Collect all non-expired SOS messages with locations
        final now        = DateTime.now();
        final sosMessages = <Message>[];

        for (final chat in chatProvider.chats) {
          for (final message in chat.messages) {
            if (!message.isSOSMessage) continue;
            if (message.latitude == null || message.longitude == null) continue;

            final age = now.difference(message.timestamp);
            if (age.inHours >= 24) continue; // already expired

            sosMessages.add(message);
          }
        }

        // Sort newest first
        sosMessages.sort((a, b) => b.timestamp.compareTo(a.timestamp));

        return Column(
          children: [
            // Header
            _Header(count: sosMessages.length),

            // List
            Expanded(
              child: sosMessages.isEmpty
                  ? const _EmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: sosMessages.length,
                      itemBuilder: (context, index) {
                        return _SOSLocationItem(message: sosMessages[index]);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final int count;
  const _Header({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on, color: Colors.red),
          const SizedBox(width: 8),
          Text(
            'SOS Locations',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          if (count > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$count active',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
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
            'No active SOS alerts',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'SOS messages with location are shown here\nand removed after 24 hours',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── SOS list item ─────────────────────────────────────────────────────────────
class _SOSLocationItem extends StatelessWidget {
  final Message message;
  const _SOSLocationItem({required this.message});

  @override
  Widget build(BuildContext context) {
    final expiry     = message.timestamp.add(const Duration(hours: 24));
    final remaining  = expiry.difference(DateTime.now());
    final isExpiring = remaining.inHours < 2;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isExpiring ? Colors.orange.shade300 : Colors.red.shade200,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: SOS badge + expiry
            Row(
              children: [
                // SOS badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.warning_rounded, color: Colors.white, size: 12),
                      SizedBox(width: 3),
                      Text(
                        'SOS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Expiry chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isExpiring
                        ? Colors.orange.shade50
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 11,
                        color: isExpiring
                            ? Colors.orange.shade700
                            : Colors.grey.shade600,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        _remainingText(remaining),
                        style: TextStyle(
                          fontSize: 11,
                          color: isExpiring
                              ? Colors.orange.shade700
                              : Colors.grey.shade600,
                          fontWeight: isExpiring
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  _timeAgo(message.timestamp),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Message content
            Text(
              message.content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),

            // Coordinates + map button
            Row(
              children: [
                const Icon(Icons.location_on, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${message.latitude!.toStringAsFixed(5)}, ${message.longitude!.toStringAsFixed(5)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                      fontFamily: 'monospace',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),

                // ── Open Map button ──────────────────────────────────────────
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SosMapScreen(sosMessage: message),
                      ),
                    );
                  },
                  icon: const Icon(Icons.map, size: 16),
                  label: const Text('View Map'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    textStyle: const TextStyle(fontSize: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _remainingText(Duration remaining) {
    if (remaining.isNegative) return 'Expired';
    if (remaining.inHours > 0) {
      return '${remaining.inHours}h ${remaining.inMinutes % 60}m left';
    }
    return '${remaining.inMinutes}m left';
  }

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours   < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}