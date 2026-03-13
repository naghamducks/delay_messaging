import 'package:flutter/material.dart';
import '../models/chat.dart';
import '../models/message.dart';
import '../services/dtn_service.dart';

/// Provider for managing chats and messages
class ChatProvider extends ChangeNotifier {
  final DTNService _dtnService = DTNService();
  
  List<Chat> _chats = [];
  Chat? _currentChat;

  List<Chat> get chats => _chats;
  Chat? get currentChat => _currentChat;

  ChatProvider() {
    _initializeMockData();
  }

  /// Initialize with mock data for demonstration
  void _initializeMockData() {
    _chats = [
      Chat(
        id: '1',
        name: 'Emergency Contact',
        messages: [
          Message(
            id: 'm1',
            content: 'Hello! Are you there?',
            timestamp: DateTime.now().subtract(const Duration(hours: 2)),
            isSentByMe: true,
            status: MessageStatus.relayed,
          ),
          Message(
            id: 'm2',
            content: 'Yes, I\'m here. Network is unstable.',
            timestamp: DateTime.now().subtract(const Duration(hours: 1, minutes: 45)),
            isSentByMe: false,
          ),
          Message(
            id: 'm3',
            content: 'Stay safe. I\'ll keep trying to reach you.',
            timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
            isSentByMe: true,
            status: MessageStatus.searchingForRelay,
          ),
        ],
        lastMessageTime: DateTime.now().subtract(const Duration(minutes: 30)),
      ),
      Chat(
        id: '2',
        name: 'Field Team Alpha',
        messages: [
          Message(
            id: 'm4',
            content: 'Mission status update?',
            timestamp: DateTime.now().subtract(const Duration(hours: 3)),
            isSentByMe: false,
          ),
          Message(
            id: 'm5',
            content: 'All clear. Continuing to waypoint B.',
            timestamp: DateTime.now().subtract(const Duration(hours: 2, minutes: 30)),
            isSentByMe: true,
            status: MessageStatus.relayed,
          ),
        ],
        lastMessageTime: DateTime.now().subtract(const Duration(hours: 2, minutes: 30)),
      ),
      Chat(
        id: '3',
        name: 'Base Station',
        messages: [
          Message(
            id: 'm6',
            content: 'Weather update: Storm approaching.',
            timestamp: DateTime.now().subtract(const Duration(hours: 5)),
            isSentByMe: false,
          ),
        ],
        lastMessageTime: DateTime.now().subtract(const Duration(hours: 5)),
      ),
    ];

    if (_chats.isNotEmpty) {
      _currentChat = _chats[0];
    }

    notifyListeners();
  }

  /// Set the current active chat
  void setCurrentChat(Chat chat) {
    _currentChat = chat;
    notifyListeners();
  }

  /// Send a new message in the current chat
  Future<void> sendMessage(String content, {bool isSOSMessage = false}) async {
    if (_currentChat == null || content.trim().isEmpty) return;

    final newMessage = Message(
      id: 'm_${DateTime.now().millisecondsSinceEpoch}',
      content: content,
      timestamp: DateTime.now(),
      isSentByMe: true,
      status: MessageStatus.sent,
      isSOSMessage: isSOSMessage,
    );

    // Add message to current chat
    final updatedMessages = List<Message>.from(_currentChat!.messages)..add(newMessage);
    _currentChat = _currentChat!.copyWith(
      messages: updatedMessages,
      lastMessageTime: newMessage.timestamp,
    );

    // Update in chats list
    final chatIndex = _chats.indexWhere((c) => c.id == _currentChat!.id);
    if (chatIndex != -1) {
      _chats[chatIndex] = _currentChat!;
    }

    notifyListeners();

    // Simulate DTN message status progression
    _simulateMessageStatusProgression(newMessage);
  }

  /// Simulate the progression of message status in DTN network
  void _simulateMessageStatusProgression(Message message) async {
    // After 2 seconds, move to "searching for relay"
    await Future.delayed(const Duration(seconds: 2));
    _updateMessageStatus(message.id, MessageStatus.searchingForRelay);

    // After 5 more seconds, move to "relayed"
    await Future.delayed(const Duration(seconds: 5));
    _updateMessageStatus(message.id, MessageStatus.relayed);

    // In a real app, this would be driven by actual DTN events
  }

  /// Update the status of a specific message
  void _updateMessageStatus(String messageId, MessageStatus newStatus) {
    if (_currentChat == null) return;

    final updatedMessages = _currentChat!.messages.map((msg) {
      if (msg.id == messageId) {
        return msg.copyWith(status: newStatus);
      }
      return msg;
    }).toList();

    _currentChat = _currentChat!.copyWith(messages: updatedMessages);

    final chatIndex = _chats.indexWhere((c) => c.id == _currentChat!.id);
    if (chatIndex != -1) {
      _chats[chatIndex] = _currentChat!;
    }

    notifyListeners();
  }

  /// Receive a new message (simulated for demo)
  void receiveMessage(String chatId, String content) {
    final chatIndex = _chats.indexWhere((c) => c.id == chatId);
    if (chatIndex == -1) return;

    final newMessage = Message(
      id: 'm_${DateTime.now().millisecondsSinceEpoch}',
      content: content,
      timestamp: DateTime.now(),
      isSentByMe: false,
    );

    final updatedMessages = List<Message>.from(_chats[chatIndex].messages)..add(newMessage);
    _chats[chatIndex] = _chats[chatIndex].copyWith(
      messages: updatedMessages,
      lastMessageTime: newMessage.timestamp,
    );

    if (_currentChat?.id == chatId) {
      _currentChat = _chats[chatIndex];
    }

    notifyListeners();
  }
}
