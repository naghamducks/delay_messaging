import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'package:delay_messenger/models/dtn_message.dart';
import 'package:delay_messenger/services/service_locator.dart';
import 'package:delay_messenger/services/node_identity.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/chat.dart';
import '../models/message.dart';

class ChatProvider extends ChangeNotifier {
  final _storage = ServiceLocator.storage;

  List<Chat> _chats = [];
  Chat? _currentChat;

  List<Chat> get chats   => _chats;
  Chat? get currentChat  => _currentChat;

  ChatProvider() {
    _ensureNamesLoaded().then((_) => loadStoredMessages());
  }

  // ── Peer name cache (persisted by DTNProvider) ─────────────────────────────

  static Map<String, String>? _cachedPeerNames;

  static Future<void> _ensureNamesLoaded() async {
    if (_cachedPeerNames != null) return;
    _cachedPeerNames = {};
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getStringList('dtn_peer_names') ?? [];
    for (final entry in raw) {
      final sep = entry.indexOf('|');
      if (sep > 0) _cachedPeerNames![entry.substring(0, sep)] = entry.substring(sep + 1);
    }
  }

  static void invalidatePeerNamesCache() => _cachedPeerNames = null;

  String _peerDisplayName(String peerId) {
    final cached = _cachedPeerNames?[peerId];
    if (cached != null && cached.isNotEmpty) return cached;
    // If it looks like a DTN node ID (node_xxxxxxxx), show it cleanly
    // rather than as "Node node_xxxxxx"
    if (peerId.startsWith('node_')) return peerId;
    try { return 'Node ${peerId.substring(0, min(10, peerId.length))}'; }
    catch (_) { return peerId; }
  }

  // ── Delivered message from DtnManager ─────────────────────────────────────

  void handleDeliveredMessage(DtnMessage dtnMsg) {
    print('\n🎉 [ChatProvider] handleDeliveredMessage called!');
    print('   id=${dtnMsg.id} src=${dtnMsg.source} payload=${dtnMsg.payload}');
    _onMessageDelivered(dtnMsg);
  }

  void _onMessageDelivered(DtnMessage dtnMsg) {
    print('📲 [ChatProvider] _onMessageDelivered: id=${dtnMsg.id} src=${dtnMsg.source}');
    final isSOSMessage = dtnMsg.priority > 5;
    final senderId     = dtnMsg.source; // stable DTN node ID

    // Look up the BLE UUID that maps to this sender's DTN ID so we can
    // find any chat that was created under the BLE UUID before the HELLO
    // exchange completed and the mapping was learned.
    final senderBleId  = ServiceLocator.dtnManager.getBleId(senderId);
    print('📲 [ChatProvider] senderBleId=$senderBleId for senderId=$senderId');

    // Search by DTN ID, BLE UUID, or any partial match
    var chatIndex = _chats.indexWhere((c) =>
        c.id == senderId ||
        c.nodeId == senderId ||
        (senderBleId != null && (c.id == senderBleId || c.nodeId == senderBleId)),
    );

    if (chatIndex != -1) {
      // Found an existing chat — upgrade its id/nodeId to the DTN ID if it
      // was still stored under the BLE UUID
      final existing = _chats[chatIndex];
      if (existing.id != senderId || existing.nodeId != senderId) {
        print('📲 [ChatProvider] Upgrading chat from BLE UUID to DTN ID: ${existing.id} → $senderId');
        _chats[chatIndex] = existing.copyWith(
          id:     senderId,
          nodeId: senderId,
          name:   _peerDisplayName(senderId),
        );
      }
    } else {
      _chats.add(Chat(
        id:              senderId,
        name:            _peerDisplayName(senderId),
        nodeId:          senderId,
        messages:        [],
        lastMessageTime: DateTime.now(),
      ));
      chatIndex = _chats.length - 1;
    }

    if (_chats[chatIndex].messages.any((m) => m.id == dtnMsg.id)) return;

    double? latitude, longitude;
    String content = dtnMsg.payload;
    if (isSOSMessage && dtnMsg.payload.contains('|')) {
      final parts = dtnMsg.payload.split('|');
      if (parts.length >= 2) {
        content = parts[0];
        try {
          final coords = parts[1].split(',');
          if (coords.length == 2) {
            latitude  = double.parse(coords[0]);
            longitude = double.parse(coords[1]);
          }
        } catch (_) {}
      }
    }

    final newMsg = Message(
      id:           dtnMsg.id,
      content:      content,
      timestamp:    dtnMsg.createdAt,
      isSentByMe:   false,
      status:       MessageStatus.delivered,
      isSOSMessage: isSOSMessage,
      latitude:     latitude,
      longitude:    longitude,
    );

    // Refresh display name now that we may have learned it from a HELLO
    final resolvedName = _peerDisplayName(senderId);
    if (_chats[chatIndex].name != resolvedName &&
        !resolvedName.startsWith('node_') &&
        !resolvedName.startsWith('Node ')) {
      _chats[chatIndex] = _chats[chatIndex].copyWith(name: resolvedName);
    }

    final updated = List<Message>.from(_chats[chatIndex].messages)..add(newMsg);
    _chats[chatIndex] = _chats[chatIndex].copyWith(
        messages: updated, lastMessageTime: newMsg.timestamp);

    if (_currentChat?.id == senderId || _currentChat?.nodeId == senderId) {
      _currentChat = _chats[chatIndex];
    }
    notifyListeners();
  }

  // ── Identity helpers ──────────────────────────────────────────────────────

  /// Returns true if the string looks like a BLE UUID (all-zeros prefix format
  /// used by the bluetooth_low_energy package: 00000000-0000-0000-0000-xxxxxxxxxxxx)
  static bool _isBleUuid(String id) =>
      id.startsWith('00000000-0000-0000-0000-');

  // ── Load from storage ──────────────────────────────────────────────────────

  void loadStoredMessages() {
    final dtnMessages = _storage.getMyMessages();
    if (dtnMessages.isEmpty) return;

    final byChat = <String, List<Message>>{};
    for (final m in dtnMessages) {
      // Always use the stable DTN node ID as the chat key.
      // For sent messages: nodeDestination is the recipient's DTN ID.
      // For received messages: source is the sender's DTN ID.
      // Never use destination (BLE UUID) — it changes every session.
      String chatId;
      if (m.source == NodeIdentity.id) {
        // Sent by me — use nodeDestination (recipient DTN ID) if available,
        // fall back to destination only if nodeDestination is a valid DTN ID
        final nd = m.nodeDestination;
        chatId = (nd != null && nd.isNotEmpty && !_isBleUuid(nd))
            ? nd
            : (!_isBleUuid(m.destination) ? m.destination : nd ?? m.destination);
      } else {
        // Received — source is always the sender's stable DTN node ID
        chatId = m.source;
      }
      // Skip messages whose only identifier is a stale BLE UUID — they cannot
      // be associated with any peer across sessions
      if (_isBleUuid(chatId)) continue;
      final isSOSMessage = m.priority > 5;

      MessageStatus uiStatus;
      switch (m.status) {
        case 'relayed':   uiStatus = MessageStatus.relayed;   break;
        case 'delivered': uiStatus = MessageStatus.delivered; break;
        default:          uiStatus = MessageStatus.sent;
      }

      double? latitude, longitude;
      String content = m.payload;
      if (isSOSMessage && m.payload.contains('|')) {
        final parts = m.payload.split('|');
        if (parts.length >= 2) {
          content = parts[0];
          try {
            final coords = parts[1].split(',');
            if (coords.length == 2) {
              latitude  = double.parse(coords[0]);
              longitude = double.parse(coords[1]);
            }
          } catch (_) {}
        }
      }

      byChat.putIfAbsent(chatId, () => []).add(Message(
        id:           m.id,
        content:      content,
        timestamp:    m.createdAt,
        isSentByMe:   m.source == NodeIdentity.id,
        status:       uiStatus,
        isSOSMessage: isSOSMessage,
        latitude:     latitude,
        longitude:    longitude,
      ));
    }

    _chats = byChat.entries.map((e) {
      final msgs = e.value..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return Chat(
        id:              e.key,
        name:            _peerDisplayName(e.key),
        nodeId:          e.key,
        messages:        msgs,
        lastMessageTime: msgs.last.timestamp,
      );
    }).toList();

    _currentChat = _chats.isNotEmpty ? _chats.first : null;
    notifyListeners();
  }

  void replaceBleIdWithNodeId(String oldBleId, String newNodeId) {
    // Find both potential chats: one under BLE UUID, one under DTN ID
    final bleIdx = _chats.indexWhere((c) => c.id == oldBleId || c.nodeId == oldBleId);
    final dtnIdx = _chats.indexWhere((c) => c.id == newNodeId || c.nodeId == newNodeId);

    if (bleIdx != -1 && dtnIdx != -1 && bleIdx != dtnIdx) {
      // Both exist — merge messages into the DTN chat and remove the BLE one
      final bleChat = _chats[bleIdx];
      final dtnChat = _chats[dtnIdx];
      final mergedMsgs = <Message>{...bleChat.messages, ...dtnChat.messages}
          .toList()
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      _chats[dtnIdx] = dtnChat.copyWith(
        messages:        mergedMsgs,
        lastMessageTime: mergedMsgs.isNotEmpty ? mergedMsgs.last.timestamp : dtnChat.lastMessageTime,
        name:            dtnChat.name.isNotEmpty && !dtnChat.name.startsWith('Node ')
            ? dtnChat.name
            : bleChat.name,
      );
      _chats.removeAt(bleIdx);
      print('🔀 [ChatProvider] Merged BLE chat ($oldBleId) into DTN chat ($newNodeId)');
    } else if (bleIdx != -1) {
      // Only BLE chat exists — rename it to DTN ID
      _chats[bleIdx] = _chats[bleIdx].copyWith(id: newNodeId, nodeId: newNodeId);
      print('🔀 [ChatProvider] Renamed BLE chat ($oldBleId) → DTN ID ($newNodeId)');
    }

    if (_currentChat != null &&
        (_currentChat!.id == oldBleId || _currentChat!.nodeId == oldBleId)) {
      _currentChat = _chats.firstWhere(
        (c) => c.nodeId == newNodeId || c.id == newNodeId,
        orElse: () => _currentChat!,
      );
    }

    notifyListeners();
  }

  // ── Send ───────────────────────────────────────────────────────────────────

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
        print('❌ SOS location error: $e');
      }
    }

    final messageId = 'msg_${DateTime.now().millisecondsSinceEpoch}';
    final rawId = _currentChat!.nodeId;

    print('\n════════════════════════════════════');
    print('📝 [ChatProvider] sendMessage START');
    print('   content: $content');
    print('   isSOSMessage: $isSOSMessage');
    print('   currentChat.id: ${_currentChat!.id}');
    print('   currentChat.nodeId: $rawId');

    if (rawId == null || rawId.isEmpty) {
      print('❌ [ChatProvider] ERROR: missing DTN nodeId for current chat');
      return;
    }

    // Resolve to canonical DTN node ID.
    // getDtnId(rawId) works if rawId is a BLE UUID we discovered this session.
    // If rawId is already a DTN node ID (starts with "node_"), use it directly.
    // If rawId looks like a stale BLE UUID (starts with "00000000") and we have
    // no mapping for it, we still queue it — DTN store-and-forward will deliver
    // it when the peer is encountered next.
    final dtnId = ServiceLocator.dtnManager.getDtnId(rawId) ?? rawId;
    print('   rawId: $rawId');
    print('   resolved dtnId: $dtnId  (getDtnId returned: ${ServiceLocator.dtnManager.getDtnId(rawId)})');
    print('   rawId looks like DTN ID: ${rawId.startsWith("node_")}');
    print('   rawId is stale BLE UUID: ${ChatProvider._isBleUuid(dtnId)}');

    String payload = content;
    if (latitude != null && longitude != null) {
      payload = '$content|$latitude,$longitude';
    }

    final bleId = ServiceLocator.dtnManager.getBleId(dtnId) ?? dtnId;
    print('   getBleId($dtnId) = ${ServiceLocator.dtnManager.getBleId(dtnId)}');
    print('   using bleId: $bleId');
    print('   messageId: $messageId');
    print('   source (my nodeId): ${NodeIdentity.id}');

    final dtnMsg = DtnMessage(
      id:              messageId,
      source:          NodeIdentity.id,
      destination:     bleId,
      nodeDestination: dtnId,
      payload:         payload,
      createdAt:       DateTime.now(),
      ttl:             3600,
      priority:        isSOSMessage ? 10 : 5,
    );

    _storage.saveMyMessage(dtnMsg);
    print('💾 [ChatProvider] DtnMessage saved to storage: ${dtnMsg.id}');
    print('   dest=${dtnMsg.destination} nodeDest=${dtnMsg.nodeDestination} src=${dtnMsg.source}');

    final uiMsg = Message(
      id:           messageId,
      content:      content,
      timestamp:    DateTime.now(),
      isSentByMe:   true,
      status:       MessageStatus.sent,
      isSOSMessage: isSOSMessage,
      latitude:     latitude,
      longitude:    longitude,
    );

    final updated = List<Message>.from(_currentChat!.messages)..add(uiMsg);
    _currentChat = _currentChat!.copyWith(
      messages:        updated,
      lastMessageTime: uiMsg.timestamp,
    );

    final idx = _chats.indexWhere(
      (c) => c.id == _currentChat!.id || c.nodeId == _currentChat!.nodeId,
    );
    if (idx != -1) _chats[idx] = _currentChat!;
    notifyListeners();

    // sendOrQueue:
    //    mapping known + peer connected → sends immediately, returns true
    //   mapping missing or peer not yet connected → queues in DtnManager,
    //     flushed automatically when the HELLO mapping arrives, returns false
    print('📮 [ChatProvider] Calling sendOrQueue(dtnId=$dtnId, msgId=${dtnMsg.id})');
    final sent = await ServiceLocator.dtnManager.sendOrQueue(dtnId, dtnMsg);
    print('📮 [ChatProvider] sendOrQueue returned: sent=$sent');
    if (!sent) {
      print('📪 [ChatProvider] Message queued — will send when $dtnId connects');
      _simulateStatusProgression(uiMsg);
    } else {
      print('✅ [ChatProvider] Message sent immediately');
    }
    print('════════════════════════════════════\n');
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void setCurrentChat(Chat chat) { _currentChat = chat; notifyListeners(); }

  void updateChatName(String nodeId, String displayName) {
    final i = _chats.indexWhere((c) => c.id == nodeId || c.nodeId == nodeId);
    if (i == -1) return;
    _chats[i] = _chats[i].copyWith(name: displayName);
    if (_currentChat?.id == nodeId || _currentChat?.nodeId == nodeId) _currentChat = _chats[i];
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
    final exists = _chats.any((c) => c.id == chat.id || c.nodeId == chat.nodeId);
    if (!exists) { _chats.add(chat); notifyListeners(); }
  }

  void _simulateStatusProgression(Message msg) async {
    await Future.delayed(const Duration(seconds: 2));
    _updateMessageStatus(msg.id, MessageStatus.searchingForRelay);
    await Future.delayed(const Duration(seconds: 5));
    _updateMessageStatus(msg.id, MessageStatus.relayed);
  }

  void _updateMessageStatus(String msgId, MessageStatus status) {
    if (_currentChat == null) return;
    final updated = _currentChat!.messages
        .map((m) => m.id == msgId ? m.copyWith(status: status) : m)
        .toList();
    _currentChat = _currentChat!.copyWith(messages: updated);
    final i = _chats.indexWhere((c) => c.id == _currentChat!.id);
    if (i != -1) _chats[i] = _currentChat!;
    ServiceLocator.storage.updateMessageStatus(msgId, status.name);
    notifyListeners();
  }

  void purgeExpiredSosMessages() {
    final now    = DateTime.now();
    bool changed = false;

    _chats = _chats.map((chat) {
      final filtered = chat.messages.where((msg) {
        if (!msg.isSOSMessage) return true;
        return now.difference(msg.timestamp).inHours < 24;
      }).toList();
      if (filtered.length != chat.messages.length) {
        changed = true;
        return chat.copyWith(
          messages:        filtered,
          lastMessageTime: filtered.isNotEmpty ? filtered.last.timestamp : chat.lastMessageTime,
        );
      }
      return chat;
    }).toList();

    for (final msg in _storage.getAllMessages()) {
      if (msg.priority > 5 && now.difference(msg.createdAt).inHours >= 24) {
        _storage.deleteMessage(msg.id);
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