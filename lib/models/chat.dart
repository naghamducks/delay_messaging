import 'message.dart';

/// Represents a chat conversation
class Chat {
  final String id;
  final String name;
  final String? avatarUrl;
  final List<Message> messages;
  final DateTime lastMessageTime;

  Chat({
    required this.id,
    required this.name,
    this.avatarUrl,
    required this.messages,
    required this.lastMessageTime,
  });

  /// Get the last message in the chat
  Message? get lastMessage {
    return messages.isNotEmpty ? messages.last : null;
  }

  /// Create a copy of the chat with updated fields
  Chat copyWith({
    String? id,
    String? name,
    String? avatarUrl,
    List<Message>? messages,
    DateTime? lastMessageTime,
  }) {
    return Chat(
      id: id ?? this.id,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      messages: messages ?? this.messages,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
    );
  }
}
