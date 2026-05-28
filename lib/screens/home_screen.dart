import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/dtn_provider.dart';
import '../models/chat.dart';
import 'chat_screen.dart';
import 'conversations_screen.dart';
import 'location_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final chatProvider  = Provider.of<ChatProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_getAppBarTitle()),
        actions: [
          if (_currentIndex == 0)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _showCreateChatDialog(context, chatProvider),
              tooltip: 'New conversation',
            ),
          IconButton(
            icon: Icon(
              themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode,
            ),
            onPressed: themeProvider.toggleTheme,
            tooltip: 'Toggle theme',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          ConversationsScreen(
            onFindNearbyDevices: () => setState(() => _currentIndex = 1),
          ),
          const LocationScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_outlined),
            selectedIcon: Icon(Icons.chat),
            label: 'Chats',
          ),
          NavigationDestination(
            icon: Icon(Icons.location_on_outlined),
            selectedIcon: Icon(Icons.location_on),
            label: 'Location',
          ),
        ],
      ),
    );
  }

  void _showCreateChatDialog(BuildContext context, ChatProvider chatProvider) {
    final nameController   = TextEditingController();
    final nodeIdController = TextEditingController();
    final formKey          = GlobalKey<FormState>();
    final nearbyDevices    =
        Provider.of<DTNProvider>(context, listen: false).nearbyDevices;

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New conversation'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nearby devices picker
                if (nearbyDevices.isNotEmpty) ...[
                  Text(
                    'Nearby devices',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                  const SizedBox(height: 6),
                  ...nearbyDevices.map(
                    (device) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        device.isConnected
                            ? Icons.bluetooth_connected
                            : Icons.bluetooth,
                        color: device.isConnected ? Colors.blue : Colors.grey,
                        size: 20,
                      ),
                      title: Text(device.name),
                      subtitle: Text(
                        device.id,
                        style: const TextStyle(
                            fontSize: 11, fontFamily: 'monospace'),
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: device.isConnected
                          ? const Icon(Icons.circle,
                              color: Colors.green, size: 10)
                          : null,
                      onTap: () {
                        nameController.text   = device.name;
                        nodeIdController.text = device.id;
                      },
                    ),
                  ),
                  const Divider(),
                  Text(
                    'Or enter manually',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                  const SizedBox(height: 6),
                ],
                // Manual fields
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Contact name',
                    hintText: 'e.g. Team Alpha',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Name is required'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: nodeIdController,
                  decoration: const InputDecoration(
                    labelText: 'Peer Node ID',
                    hintText: 'e.g. node_8spm1s5t',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Peer Node ID is required'
                      : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              final name   = nameController.text.trim();
              final nodeId = nodeIdController.text.trim();
              Navigator.pop(ctx);
              final newChat = Chat(
                id:              nodeId,
                name:            name,
                nodeId:          nodeId,
                messages:        [],
                lastMessageTime: DateTime.now(),
              );
              chatProvider.addChat(newChat);
              chatProvider.setCurrentChat(newChat);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ChatScreen()),
              );
            },
            child: const Text('Start'),
          ),
        ],
      ),
    );
  }

  String _getAppBarTitle() {
    switch (_currentIndex) {
      case 0:  return 'Chats';
      case 1:  return 'Location';
      default: return 'ReachOut';
    }
  }
}