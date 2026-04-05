import 'dart:math';

import 'package:delay_messenger/models/dtn_message.dart';
import 'package:delay_messenger/services/DTN_Storage_Service.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/chat.dart';
import '../models/message.dart';
import '../services/dtn_service.dart';
import '../services/dtn_manager.dart';
import '../services/prophet_routing_service.dart';
import '../services/transfer_service.dart';
import '../services/battery_service.dart';

/// Provider for managing chats and messages
class ChatProvider extends ChangeNotifier {
  final DTNService _dtnService = DTNService();
  final DtnStorageService _storage = DtnStorageService();
  final ProphetRoutingService _routing = ProphetRoutingService();
  //final TransferService _transfer = TransferService();
  final BatteryService _battery = BatteryService();
  late final DtnManager _dtnManager;

  List<Chat> _chats = [];
  Chat? _currentChat;

  List<Chat> get chats => _chats;
  Chat? get currentChat => _currentChat;

  ChatProvider() {
    _dtnManager = DtnManager(
      storage: _storage,
      routing: _routing,
     // transfer: _transfer,
      battery: _battery,
    );
    loadStoredMessages();
  }

  /// Load stored DTN messages and convert to chat messages
  void loadStoredMessages() {
    final dtnMessages = _storage.getAllMessages();
    
    if (dtnMessages.isNotEmpty) {
      // Group messages by destination (chat ID)
      final messagesByChat = <String, List<Message>>{};

      for (final dtnMsg in dtnMessages) {
        final chatId = dtnMsg.destination;
        if (!messagesByChat.containsKey(chatId)) {
          messagesByChat[chatId] = [];
        }

        final message = Message(
          id: dtnMsg.id,
          content: dtnMsg.payload,
          timestamp: dtnMsg.createdAt,
          isSentByMe: dtnMsg.source == 'this_device',
          status: MessageStatus.relayed, // Assume stored messages are relayed
          isSOSMessage: dtnMsg.priority > 5,
        );

        messagesByChat[chatId]!.add(message);
      }

      // Create chats from the grouped messages
      _chats = messagesByChat.entries.map((entry) {
        final chatId = entry.key;
        final messages = entry.value;
        messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

        return Chat(
          id: chatId,
          name: 'Chat ${chatId.substring(0, min(10, chatId.length))}',
          messages: messages,
          lastMessageTime: messages.last.timestamp,
        );
      }).toList();
    } else {
      // Fallback to mock data if no stored messages
      _initializeMockData();
    }

    if (_chats.isNotEmpty) {
      _currentChat = _chats[0];
    }

    notifyListeners();
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
            id: 'sos1',
            content: 'SOS - Emergency assistance needed! Medical emergency.',
            timestamp: DateTime.now().subtract(const Duration(hours: 1)),
            isSentByMe: true,
            status: MessageStatus.sent,
            isSOSMessage: true,
            latitude: 40.7128,
            longitude: -74.0060,
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

    double? latitude;
    double? longitude;

    // Get location for SOS messages
    if (isSOSMessage) {
      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        latitude = position.latitude;
        longitude = position.longitude;
      } catch (e) {
        // Location not available, continue without it
        print('Failed to get location for SOS message: $e');
      }
    }

    // Create message ID
    final messageId = 'msg_${DateTime.now().millisecondsSinceEpoch}';

    // Create DTN message and store it
    final dtnMessage = DtnMessage(
      id: messageId,
      source: 'this_device', // TODO: Use actual device ID
      destination: _currentChat!.id, // Use chat ID as destination
      payload: content,
      createdAt: DateTime.now(),
      ttl: 3600, // 1 hour TTL
      priority: isSOSMessage ? 10 : 5, // Higher priority for SOS
    );

    _storage.saveMessage(dtnMessage);

    final newMessage = Message(
      id: messageId,
      content: content,
      timestamp: DateTime.now(),
      isSentByMe: true,
      status: MessageStatus.sent,
      isSOSMessage: isSOSMessage,
      latitude: latitude,
      longitude: longitude,
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

  /// Pin/unpin a conversation for quicker access
  void togglePin(String chatId) {
    final chatIndex = _chats.indexWhere((c) => c.id == chatId);
    if (chatIndex == -1) return;

    final updatedChat = _chats[chatIndex].copyWith(
      pinned: !_chats[chatIndex].pinned,
    );

    _chats[chatIndex] = updatedChat;

    if (_currentChat?.id == chatId) {
      _currentChat = updatedChat;
    }

    notifyListeners();
  }

  /// Add a new chat conversation
  void addChat(Chat chat) {
    _chats.add(chat);
    notifyListeners();
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
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
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