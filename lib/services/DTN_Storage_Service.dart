import 'package:delay_messenger/models/dtn_message.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Dual-buffer storage service for DTN messages.
///
/// Separates messages into two Hive boxes:
/// - `my_messages`: messages originated by this node (status-tracked)
/// - `relay_buffer`: messages being carried for other nodes
class DtnStorageService {
  Box get _myBox => Hive.box('my_messages');
  Box get _relayBox => Hive.box('relay_buffer');

  // ────────────────────────────────────────────────────────────────────────
  // Write
  // ────────────────────────────────────────────────────────────────────────

  /// Saves a message originated by this node to the `my_messages` box.
  void saveMyMessage(DtnMessage msg) {
    _myBox.put(msg.id, _toMap(msg));
  }

  /// Saves a relay message (not originated by us) to the `relay_buffer` box.
  void saveRelayMessage(DtnMessage msg) {
    _relayBox.put(msg.id, _toMap(msg));
  }

  // ────────────────────────────────────────────────────────────────────────
  // Read
  // ────────────────────────────────────────────────────────────────────────

  /// Returns all messages from the `my_messages` box.
  List<DtnMessage> getMyMessages() {
    return _myBox.values
        .map((e) => _fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Returns all messages from the `relay_buffer` box.
  List<DtnMessage> getRelayMessages() {
    return _relayBox.values
        .map((e) => _fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Returns all messages from both boxes (backward compatibility).
  List<DtnMessage> getAllMessages() {
    return [...getMyMessages(), ...getRelayMessages()];
  }

  /// Returns true if the message ID exists in either box.
  bool hasMessage(String id) {
    return _myBox.containsKey(id) || _relayBox.containsKey(id);
  }

  // ────────────────────────────────────────────────────────────────────────
  // Delete & Update
  // ────────────────────────────────────────────────────────────────────────

  /// Deletes a message from whichever box contains it.
  void deleteMessage(String id) {
    if (_myBox.containsKey(id)) {
      _myBox.delete(id);
    } else if (_relayBox.containsKey(id)) {
      _relayBox.delete(id);
    }
  }

  /// Updates the `status` field of a message in `my_messages` only.
  ///
  /// Relay messages do not have status tracking; this is a no-op for them.
  void updateMessageStatus(String id, String status) {
    if (!_myBox.containsKey(id)) return;
    final raw = Map<String, dynamic>.from(_myBox.get(id) as Map);
    raw['status'] = status;
    _myBox.put(id, raw);
  }

  // ────────────────────────────────────────────────────────────────────────
  // Serialization
  // ────────────────────────────────────────────────────────────────────────

  Map<String, dynamic> _toMap(DtnMessage msg) {
    return {
      'id': msg.id,
      'source': msg.source,
      'destination': msg.destination,
      'payload': msg.payload,
      'createdAt': msg.createdAt.toIso8601String(),
      'ttl': msg.ttl,
      'copies': msg.copies,
      'priority': msg.priority,
      'status': msg.status,
    };
  }

  DtnMessage _fromMap(Map<String, dynamic> map) {
    return DtnMessage(
      id: map['id'] as String,
      source: map['source'] as String,
      destination: map['destination'] as String,
      payload: map['payload'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      ttl: map['ttl'] as int,
      copies: map['copies'] as int? ?? 1,
      priority: map['priority'] as int? ?? 0,
      status: map['status'] as String? ?? 'sent',
    );
  }
}