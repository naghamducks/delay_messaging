import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/chat_provider.dart';
import 'chat_screen.dart';
import 'nearby_devices_screen.dart';
import 'relay_history_screen.dart';
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
    ChatScreen(),
    NearbyDevicesScreen(),
    RelayHistoryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: _currentIndex == 0
            ? _buildChatSelector(chatProvider)
            : Text(_getAppBarTitle()),
        actions: [
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
            icon: Icon(Icons.devices_outlined),
            selectedIcon: Icon(Icons.devices),
            label: 'Nearby Devices',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'Relay History',
          ),
        ],
      ),
    );
  }

  /// Build the chat selector dropdown in app bar
  Widget _buildChatSelector(ChatProvider chatProvider) {
    return PopupMenuButton<String>(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(chatProvider.currentChat?.name ?? 'Select Chat'),
          const SizedBox(width: 8),
          const Icon(Icons.arrow_drop_down),
        ],
      ),
      onSelected: (chatId) {
        final chat = chatProvider.chats.firstWhere((c) => c.id == chatId);
        chatProvider.setCurrentChat(chat);
      },
      itemBuilder: (context) {
        return chatProvider.chats.map((chat) {
          return PopupMenuItem<String>(
            value: chat.id,
            child: Row(
              children: [
                Icon(
                  Icons.circle,
                  size: 12,
                  color: chat.id == chatProvider.currentChat?.id
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey,
                ),
                const SizedBox(width: 12),
                Text(chat.name),
              ],
            ),
          );
        }).toList();
      },
    );
  }

  /// Get app bar title based on current tab
  String _getAppBarTitle() {
    switch (_currentIndex) {
      case 1:
        return 'Nearby Devices';
      case 2:
        return 'Relay History';
      default:
        return 'DTN Messenger';
    }
  }
}
