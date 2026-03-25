import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/chat_provider.dart';
import '../models/chat.dart';
import 'chat_screen.dart';
import 'conversations_screen.dart';
import 'nearby_devices_screen.dart';
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
          // Add new chat button (only on Chats tab)
          if (_currentIndex == 0)
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



  /// Show dialog to create a new chat
  void _showCreateChatDialog(BuildContext context, ChatProvider chatProvider) {
    final nameController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('New conversation'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Contact name',
              hintText: 'e.g. Team Alpha',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(context);
                final newChat = Chat(
                  id: 'chat_${DateTime.now().millisecondsSinceEpoch}',
                  name: name,
                  messages: [],
                  lastMessageTime: DateTime.now(),
                );
                chatProvider.addChat(newChat);
                chatProvider.setCurrentChat(newChat);
                // Navigate to chat screen
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
