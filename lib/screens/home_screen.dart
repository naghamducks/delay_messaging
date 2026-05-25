import 'package:delay_messenger/providers/dtn_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/chat_provider.dart';
import '../models/chat.dart';
import 'chat_screen.dart';
import 'conversations_screen.dart';
import 'location_screen.dart';
import 'settings_screen.dart';

/// Main home screen with bottom navigation
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    ConversationsScreen(),
    LocationScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_getAppBarTitle()),
        actions: [
          // Add new chat button (only on Chats tab, debug builds only)
          if (_currentIndex == 0 && kDebugMode)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _showCreateChatDialog(context, chatProvider),
              tooltip: 'New conversation',
            ),
          // Light/Dark mode toggle
          IconButton(
            icon: Icon(
              themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode,
            ),
            onPressed: () => themeProvider.toggleTheme(),
            tooltip: 'Toggle theme',
          ),
       
          // Settings icon
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
            tooltip: 'Settings',
          ),
        ],
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
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
    final formKey = GlobalKey<FormState>();

    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('New conversation'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Contact name',
                    hintText: 'e.g. Team Alpha',
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: nodeIdController,
                  decoration: const InputDecoration(
                    labelText: 'Peer Node ID',
                    hintText: 'e.g. node-alpha',
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Peer Node ID is required' : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                final name   = nameController.text.trim();
                final nodeId = nodeIdController.text.trim();
                Navigator.pop(context);
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
                  MaterialPageRoute(builder: (context) => const ChatScreen()),
                );
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  /// Get app bar title based on current tab
  String _getAppBarTitle() {
    switch (_currentIndex) {
      case 0:
        return 'Chats';
      case 1:
        return 'Location';
      default:
        return 'DTN Messenger';
    }
  }
}