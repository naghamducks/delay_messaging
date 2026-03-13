/// Represents the delivery status of a message in the DTN network
enum MessageStatus {
  sent, // Message stored/sent from device
  searchingForRelay, // Message waiting for a relay node
  relayed, // Message forwarded but destination not reached
  delivered, // Message successfully delivered to destination
}

/// Message model for DTN messaging
class Message {
  final String id;
  final String content;
  final DateTime timestamp;
  final bool isSentByMe;
  final MessageStatus status;
  final bool isSOSMessage;

  Message({
    required this.id,
    required this.content,
    required this.timestamp,
    required this.isSentByMe,
    this.status = MessageStatus.sent,
    this.isSOSMessage = false,
  });

  /// Create a copy of the message with updated fields
  Message copyWith({
    String? id,
    String? content,
    DateTime? timestamp,
    bool? isSentByMe,
    MessageStatus? status,
    bool? isSOSMessage,
  }) {
    return Message(
      id: id ?? this.id,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      isSentByMe: isSentByMe ?? this.isSentByMe,
      status: status ?? this.status,
      isSOSMessage: isSOSMessage ?? this.isSOSMessage,
    );
  }

  /// Convert message to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'isSentByMe': isSentByMe,
      'status': status.index,
      'isSOSMessage': isSOSMessage,
    };
  }

  /// Create message from JSON
  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      content: json['content'],
      timestamp: DateTime.parse(json['timestamp']),
      isSentByMe: json['isSentByMe'],
      status: MessageStatus.values[json['status']],
      isSOSMessage: json['isSOSMessage'] ?? false,
    );
  }
}
