import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../models/chat.dart';
import '../providers/chat_provider.dart';
import 'chat_screen.dart';

/// Displays the list of conversations (contacts) in a messaging app style.
class ConversationsScreen extends StatelessWidget {
  const ConversationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, child) {
        final chats = chatProvider.chats;

        if (chats.isEmpty) {
          return _buildEmptyState(context);
        }

        final pinnedChats = chats
            .where((chat) => chat.pinned)
            .toList()
          ..sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
        final unpinnedChats = chats
            .where((chat) => !chat.pinned)
            .toList()
          ..sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));

        final children = <Widget>[];

        // Add pinned section
        if (pinnedChats.isNotEmpty) {
          children.addAll(pinnedChats.map((chat) => _buildConversationTile(context, chatProvider, chat)));
        }

        // Add divider between pinned and unpinned
        if (pinnedChats.isNotEmpty && unpinnedChats.isNotEmpty) {
          children.add(const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Divider(height: 1),
          ));
        }

        // Add unpinned section
        children.addAll(unpinnedChats.map((chat) => _buildConversationTile(context, chatProvider, chat)));

        return ListView(
          padding: const EdgeInsets.all(16),
          children: children,
        );
      },
    );
  }

  Widget _buildConversationTile(
    BuildContext context,
    ChatProvider chatProvider,
    Chat chat,
  ) {
    final lastMessage = chat.lastMessage;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        chatProvider.setCurrentChat(chat);
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const ChatScreen()),
        );
      },
      onLongPress: () => _togglePin(context, chatProvider, chat),
      onSecondaryTap: () => _togglePin(context, chatProvider, chat),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
              child: Text(
                _getInitials(chat.name),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          chat.name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (chat.pinned)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Icon(
                            Icons.push_pin,
                            size: 16,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    lastMessage?.content ?? 'No messages yet',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.7),
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  lastMessage != null
                      ? _formatTime(lastMessage.timestamp)
                      : '',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.6),
                      ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    chat.pinned ? 'Pinned' : 'Tap to open',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.6),
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

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 80,
              color: Theme.of(context).colorScheme.secondary,
            ),
            const SizedBox(height: 20),
            Text(
              'No conversations yet',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Start a new conversation by tapping the button below. Your messages are stored locally and work even offline.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.add_comment_outlined),
              label: const Text('Start a conversation'),
              onPressed: () => _showCreateChatDialog(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateChatDialog(BuildContext context) {
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
                final provider =
                    Provider.of<ChatProvider>(context, listen: false);
                final newChat = Chat(
                  id: 'chat_${DateTime.now().millisecondsSinceEpoch}',
                  name: name,
                  messages: [],
                  lastMessageTime: DateTime.now(),
                );
                provider.addChat(newChat);
                provider.setCurrentChat(newChat);
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

  void _togglePin(BuildContext context, ChatProvider chatProvider, Chat chat) {
    chatProvider.togglePin(chat.id);
    final message = chat.pinned ? 'Unpinned' : 'Pinned';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$message "${chat.name}"'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else {
      return DateFormat('MMM d').format(time);
    }
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}
