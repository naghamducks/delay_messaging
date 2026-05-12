import 'dart:math';
import 'package:delay_messenger/models/dtn_message.dart';
import 'package:delay_messenger/services/service_locator.dart';
import 'package:delay_messenger/services/node_identity.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/chat.dart';
import '../models/message.dart';

class ChatProvider extends ChangeNotifier {
  // Use the shared singleton services — no more local instantiation
  final _storage    = ServiceLocator.storage;
  final _dtnManager = ServiceLocator.dtnManager;

  List<Chat> _chats = [];
  Chat? _currentChat;

  List<Chat> get chats    => _chats;
  Chat? get currentChat   => _currentChat;

  ChatProvider() {
    // Wire up the delivered-message callback
    _dtnManager.onMessageDelivered = _onMessageDelivered;
    loadStoredMessages();
  }

  // ── Incoming message handler ───────────────────────────────────────────────
  void _onMessageDelivered(DtnMessage dtnMsg) {
    // Determine if this is an SOS message (priority > 5)
    final isSOSMessage = dtnMsg.priority > 5;

    // Find or create a chat for this sender
    final senderId = dtnMsg.source;
    var chatIndex  = _chats.indexWhere((c) => c.nodeId == senderId);

    if (chatIndex == -1) {
      _chats.add(Chat(
        id:              'chat_${DateTime.now().millisecondsSinceEpoch}',
        name:            'Node $senderId',
        nodeId:          senderId,
        messages:        [],
        lastMessageTime: DateTime.now(),
      ));
      chatIndex = _chats.length - 1;
    }

    // For SOS messages, try to extract lat/long from payload if they were encoded
    // Format: "CONTENT|lat,lng" or just "CONTENT"
    double? latitude, longitude;
    String content = dtnMsg.payload;
    
    if (isSOSMessage && dtnMsg.payload.contains('|')) {
      final parts = dtnMsg.payload.split('|');
      if (parts.length >= 2) {
        content = parts[0];
        try {
          final coords = parts[1].split(',');
          if (coords.length == 2) {
            latitude = double.parse(coords[0]);
            longitude = double.parse(coords[1]);
          }
        } catch (_) {
          // Parsing failed, ignore location
        }
      }
    }

    final newMessage = Message(
      id:          dtnMsg.id,
      content:     content,
      timestamp:   dtnMsg.createdAt,
      isSentByMe:  false,
      isSOSMessage: isSOSMessage,
      latitude:    latitude,
      longitude:   longitude,
    );

    final updated = List<Message>.from(_chats[chatIndex].messages)..add(newMessage);
    _chats[chatIndex] = _chats[chatIndex].copyWith(
      messages:        updated,
      lastMessageTime: newMessage.timestamp,
    );

    if (_currentChat?.nodeId == senderId) {
      _currentChat = _chats[chatIndex];
    }

    notifyListeners();
  }

  // ── Load persisted messages ────────────────────────────────────────────────
  void loadStoredMessages() {
    final dtnMessages = _storage.getAllMessages();
    if (dtnMessages.isEmpty) {
      _initializeMockData();
      return;
    }

    final byChat = <String, List<Message>>{};
    for (final m in dtnMessages) {
      final chatId = m.source == NodeIdentity.id ? m.destination : m.source;
      final isSOSMessage = m.priority > 5;
      
      // Extract location from payload if present
      double? latitude, longitude;
      String content = m.payload;
      
      if (isSOSMessage && m.payload.contains('|')) {
        final parts = m.payload.split('|');
        if (parts.length >= 2) {
          content = parts[0];
          try {
            final coords = parts[1].split(',');
            if (coords.length == 2) {
              latitude = double.parse(coords[0]);
              longitude = double.parse(coords[1]);
            }
          } catch (_) {}
        }
      }
      
      byChat.putIfAbsent(chatId, () => []).add(Message(
        id:          m.id,
        content:     content,
        timestamp:   m.createdAt,
        isSentByMe:  m.source == NodeIdentity.id,
        status:      MessageStatus.relayed,
        isSOSMessage: isSOSMessage,
        latitude:    latitude,
        longitude:   longitude,
      ));
    }

    _chats = byChat.entries.map((e) {
      final msgs = e.value..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return Chat(
        id:              'chat_${DateTime.now().millisecondsSinceEpoch}',
        name:            'Node ${e.key.substring(0, min(10, e.key.length))}',
        nodeId:          e.key,
        messages:        msgs,
        lastMessageTime: msgs.last.timestamp,
      );
    }).toList();

    _currentChat = _chats.isNotEmpty ? _chats.first : null;
    notifyListeners();
  }

  // ── Send message ───────────────────────────────────────────────────────────
  Future<void> sendMessage(String content, {bool isSOSMessage = false}) async {
    if (_currentChat == null || content.trim().isEmpty) return;

    double? latitude, longitude;
    if (isSOSMessage) {
      try {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        latitude  = pos.latitude;
        longitude = pos.longitude;
      } catch (e) {
        print('❌ Failed to get location for SOS: $e');
      }
    }

    final messageId = 'msg_${DateTime.now().millisecondsSinceEpoch}';
    final destination = _currentChat!.nodeId ?? _currentChat!.id;

    // Encode location in payload if we have it: "CONTENT|lat,lng"
    String payloadToSend = content;
    if (latitude != null && longitude != null) {
      payloadToSend = '$content|$latitude,$longitude';
    }

    final dtnMsg = DtnMessage(
      id:          messageId,
      source:      NodeIdentity.id,
      destination: destination,
      payload:     payloadToSend,
      createdAt:   DateTime.now(),
      ttl:         3600,
      priority:    isSOSMessage ? 10 : 5,
    );
    _storage.saveMessage(dtnMsg);

    final uiMsg = Message(
      id:          messageId,
      content:     content,
      timestamp:   DateTime.now(),
      isSentByMe:  true,
      status:      MessageStatus.sent,
      isSOSMessage: isSOSMessage,
      latitude:    latitude,
      longitude:   longitude,
    );

    final updatedMsgs = List<Message>.from(_currentChat!.messages)..add(uiMsg);
    _currentChat = _currentChat!.copyWith(
      messages:        updatedMsgs,
      lastMessageTime: uiMsg.timestamp,
    );

    final idx = _chats.indexWhere((c) => c.id == _currentChat!.id || c.nodeId == _currentChat!.nodeId);
    if (idx != -1) _chats[idx] = _currentChat!;

    notifyListeners();

    // Try to send immediately if the peer is already connected over BLE
    if (ServiceLocator.ble.isConnected(destination)) {
      await ServiceLocator.ble.sendMessage(destination, dtnMsg);
      _updateMessageStatus(messageId, MessageStatus.relayed);
    } else {
      _simulateStatusProgression(uiMsg);
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  void setCurrentChat(Chat chat) {
    _currentChat = chat;
    notifyListeners();
  }

  void togglePin(String chatId) {
    final i = _chats.indexWhere((c) => c.id == chatId);
    if (i == -1) return;
    _chats[i] = _chats[i].copyWith(pinned: !_chats[i].pinned);
    if (_currentChat?.id == chatId) _currentChat = _chats[i];
    notifyListeners();
  }

  void addChat(Chat chat) {
    _chats.add(chat);
    notifyListeners();
  }

  void _simulateStatusProgression(Message msg) async {
    await Future.delayed(const Duration(seconds: 2));
    _updateMessageStatus(msg.id, MessageStatus.searchingForRelay);
    await Future.delayed(const Duration(seconds: 5));
    _updateMessageStatus(msg.id, MessageStatus.relayed);
  }

  void _updateMessageStatus(String msgId, MessageStatus status) {
    if (_currentChat == null) return;
    final updated = _currentChat!.messages.map((m) =>
      m.id == msgId ? m.copyWith(status: status) : m,
    ).toList();
    _currentChat = _currentChat!.copyWith(messages: updated);
    final i = _chats.indexWhere((c) => c.id == _currentChat!.id);
    if (i != -1) _chats[i] = _currentChat!;
    notifyListeners();
  }

  void _initializeMockData() {
    // Keep your existing mock data here unchanged
  }

  /// Remove SOS messages older than 24 hours from all chats
  void purgeExpiredSosMessages() {
    final now     = DateTime.now();
    bool changed  = false;

    _chats = _chats.map((chat) {
      final before = chat.messages.length;

      final filtered = chat.messages.where((msg) {
        if (!msg.isSOSMessage) return true; // keep non-SOS always
        final age = now.difference(msg.timestamp);
        return age.inHours < 24; // keep if under 24h
      }).toList();

      if (filtered.length != before) {
        changed = true;
        return chat.copyWith(
          messages: filtered,
          lastMessageTime: filtered.isNotEmpty
              ? filtered.last.timestamp
              : chat.lastMessageTime,
        );
      }
      return chat;
    }).toList();

    // Also delete from Hive storage
    for (final msg in _storage.getAllMessages()) {
      if (msg.priority > 5) { // SOS messages have priority > 5
        final age = now.difference(msg.createdAt);
        if (age.inHours >= 24) {
          _storage.deleteMessage(msg.id);
        }
      }
    }

    if (changed) {
      _currentChat = _chats.firstWhere(
        (c) => c.id == _currentChat?.id,
        orElse: () => _chats.isNotEmpty ? _chats.first : _currentChat!,
      );
      notifyListeners();
    }
  }
}