import 'dart:async';
import 'package:delay_messenger/screens/sos_map_screens.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../providers/dtn_provider.dart';
import '../models/chat.dart';
import '../models/message.dart';
import '../models/dtn_device.dart';
import 'chat_screen.dart';

class LocationScreen extends StatefulWidget {
  const LocationScreen({super.key});

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  Timer? _cleanupTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _cleanupTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _purgeExpiredSos();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _purgeExpiredSos());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _cleanupTimer?.cancel();
    super.dispose();
  }

  void _purgeExpiredSos() {
    if (!mounted) return;
    context.read<ChatProvider>().purgeExpiredSosMessages();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.sensors), text: 'Nearby Devices'),
            Tab(icon: Icon(Icons.location_on), text: 'SOS Alerts'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              _NearbyDevicesTab(),
              _SosAlertsTab(),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Nearby Devices Tab ────────────────────────────────────────────────────────

class _NearbyDevicesTab extends StatelessWidget {
  const _NearbyDevicesTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<DTNProvider>(
      builder: (context, dtnProvider, _) {
        final devices = dtnProvider.nearbyDevices;

        return Column(
          children: [
            // Header + scan button
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
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
                  const Icon(Icons.bluetooth_searching, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text(
                    'Nearby DTN Nodes',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const Spacer(),
                  FilledButton.tonal(
                    onPressed: () => dtnProvider.scanForDevices(),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.refresh, size: 16),
                        SizedBox(width: 4),
                        Text('Scan'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Device list
            Expanded(
              child: devices.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.bluetooth_disabled,
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
                            'Make sure another device is running\nthe app nearby with Bluetooth on.',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withOpacity(0.6),
                                ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          FilledButton.icon(
                            icon: const Icon(Icons.bluetooth_searching),
                            label: const Text('Start Scanning'),
                            onPressed: () =>
                                context.read<DTNProvider>().scanForDevices(),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: devices.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        return _DeviceTile(device: devices[index]);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _DeviceTile extends StatelessWidget {
  final DTNDevice device;
  const _DeviceTile({required this.device});

  @override
  Widget build(BuildContext context) {
    final signal = device.signalStrength;
    final signalIcon = signal > 0.7
        ? Icons.signal_wifi_4_bar
        : signal > 0.4
            ? Icons.network_wifi_2_bar
            : Icons.network_wifi_1_bar;

    final signalColor = signal > 0.7
        ? Colors.green
        : signal > 0.4
            ? Colors.orange
            : Colors.red;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: device.isConnected
              ? Colors.blue.shade100
              : Colors.grey.shade200,
          child: Icon(
            device.deviceType == 'Laptop'
                ? Icons.laptop
                : Icons.smartphone,
            color: device.isConnected ? Colors.blue : Colors.grey,
          ),
        ),
        title: Text(
          device.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              device.id.length > 20
                  ? '${device.id.substring(0, 20)}…'
                  : device.id,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.5),
                    fontFamily: 'monospace',
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              'Last seen: ${_timeAgo(device.lastSeen)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.5),
                  ),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(signalIcon, color: signalColor, size: 20),
            const SizedBox(height: 4),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: device.isConnected
                    ? Colors.green.shade100
                    : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                device.isConnected ? 'Connected' : 'Nearby',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: device.isConnected
                      ? Colors.green.shade700
                      : Colors.grey.shade600,
                ),
              ),
            ),
          ],
        ),
        onTap: () => _startConversation(context, device),
      ),
    );
  }

  void _startConversation(BuildContext context, DTNDevice device) {
    final chatProvider = context.read<ChatProvider>();
    final newChat = Chat(
      id:              device.id,
      name:            device.name,
      nodeId:          device.id,
      messages:        [],
      lastMessageTime: DateTime.now(),
    );
    chatProvider.addChat(newChat);
    chatProvider.setCurrentChat(newChat);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ChatScreen()),
    );
  }

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}

// ── SOS Alerts Tab ────────────────────────────────────────────────────────────

class _SosAlertsTab extends StatelessWidget {
  const _SosAlertsTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, _) {
        final now = DateTime.now();
        final sosMessages = <Message>[];

        for (final chat in chatProvider.chats) {
          for (final message in chat.messages) {
            if (!message.isSOSMessage) continue;
            if (message.latitude == null || message.longitude == null) continue;
            if (now.difference(message.timestamp).inHours >= 24) continue;
            sosMessages.add(message);
          }
        }

        sosMessages.sort((a, b) => b.timestamp.compareTo(a.timestamp));

        return Column(
          children: [
            _SosHeader(count: sosMessages.length),
            Expanded(
              child: sosMessages.isEmpty
                  ? const _SosEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: sosMessages.length,
                      itemBuilder: (context, index) =>
                          _SOSLocationItem(message: sosMessages[index]),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _SosHeader extends StatelessWidget {
  final int count;
  const _SosHeader({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on, color: Colors.red),
          const SizedBox(width: 8),
          Text(
            'SOS Locations',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          if (count > 0)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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

class _SosEmptyState extends StatelessWidget {
  const _SosEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.location_off,
              size: 64, color: Theme.of(context).colorScheme.secondary),
          const SizedBox(height: 16),
          Text('No active SOS alerts',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'SOS messages with location are shown here\nand removed after 24 hours',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.6),
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _SOSLocationItem extends StatelessWidget {
  final Message message;
  const _SOSLocationItem({required this.message});

  @override
  Widget build(BuildContext context) {
    final expiry = message.timestamp.add(const Duration(hours: 24));
    final remaining = expiry.difference(DateTime.now());
    final isExpiring = remaining.inHours < 2;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color:
              isExpiring ? Colors.orange.shade300 : Colors.red.shade200,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.warning_rounded,
                          color: Colors.white, size: 12),
                      SizedBox(width: 3),
                      Text('SOS',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isExpiring
                        ? Colors.orange.shade50
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.timer_outlined,
                          size: 11,
                          color: isExpiring
                              ? Colors.orange.shade700
                              : Colors.grey.shade600),
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
                        color: Colors.grey.shade500),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              message.content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on,
                    size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${message.latitude!.toStringAsFixed(5)}, '
                    '${message.longitude!.toStringAsFixed(5)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                          fontFamily: 'monospace',
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) =>
                          SosMapScreen(sosMessage: message),
                    ));
                  },
                  icon: const Icon(Icons.map, size: 16),
                  label: const Text('View Map'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    textStyle: const TextStyle(fontSize: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _remainingText(Duration r) {
    if (r.isNegative) return 'Expired';
    if (r.inHours > 0) return '${r.inHours}h ${r.inMinutes % 60}m left';
    return '${r.inMinutes}m left';
  }

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}