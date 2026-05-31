import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../widgets/message_bubble.dart';
import '../widgets/message_input_bar.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Consumer<ChatProvider>(
          builder: (context, chatProvider, _) =>
              Text(chatProvider.currentChat?.name ?? 'Chat'),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Consumer<ChatProvider>(
        builder: (context, chatProvider, _) {
          final currentChat = chatProvider.currentChat;

          if (currentChat == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline,
                      size: 64,
                      color: Theme.of(context).colorScheme.secondary),
                  const SizedBox(height: 16),
                  Text('No chat selected',
                      style: Theme.of(context).textTheme.titleLarge),
                ],
              ),
            );
          }

          // Auto-scroll when new messages arrive
          if (currentChat.messages.isNotEmpty) _scrollToBottom();

          return Column(
            children: [
              Expanded(
                child: currentChat.messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.forum_outlined,
                                size: 64,
                                color:
                                    Theme.of(context).colorScheme.secondary),
                            const SizedBox(height: 16),
                            Text('No messages yet',
                                style:
                                    Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: 8),
                            Text(
                              'Start a conversation',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.6),
                                  ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        itemCount: currentChat.messages.length,
                        itemBuilder: (context, index) => MessageBubble(
                          message: currentChat.messages[index],
                        ),
                      ),
              ),
              MessageInputBar(
                onSendMessage: (content) {
                  chatProvider.sendMessage(content);
                  _scrollToBottom();
                },
                onSendSOS: (content) {
                  chatProvider.sendMessage(content, isSOSMessage: true);
                  _scrollToBottom();
                },
              ),
            ],
          );
        },
      ),
    );
  }
}