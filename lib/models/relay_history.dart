/// Represents a relay action in the DTN network
class RelayHistory {
  final String id;
  final String messageId;
  final String messagePreview;
  final String fromDevice;
  final String toDevice;
  final DateTime relayTime;
  final bool successful;

  RelayHistory({
    required this.id,
    required this.messageId,
    required this.messagePreview,
    required this.fromDevice,
    required this.toDevice,
    required this.relayTime,
    required this.successful,
  });

  /// Create a copy of the relay history with updated fields
  RelayHistory copyWith({
    String? id,
    String? messageId,
    String? messagePreview,
    String? fromDevice,
    String? toDevice,
    DateTime? relayTime,
    bool? successful,
  }) {
    return RelayHistory(
      id: id ?? this.id,
      messageId: messageId ?? this.messageId,
      messagePreview: messagePreview ?? this.messagePreview,
      fromDevice: fromDevice ?? this.fromDevice,
      toDevice: toDevice ?? this.toDevice,
      relayTime: relayTime ?? this.relayTime,
      successful: successful ?? this.successful,
    );
  }
}
