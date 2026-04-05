import 'package:delay_messenger/models/dtn_message.dart';
import 'package:hive_flutter/hive_flutter.dart';

class DtnStorageService {
  final Box box = Hive.box('messages');

  void saveMessage(DtnMessage msg) {
    box.put(msg.id, _toMap(msg));
  }

  List<DtnMessage> getAllMessages() {
    return box.values
        .map((e) => _fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  void deleteMessage(String id) {
    box.delete(id);
  }

  bool hasMessage(String id) {
    return box.containsKey(id);
  }

  Map<String, dynamic> _toMap(DtnMessage msg) {
    return {
      'id': msg.id,
      'source': msg.source,
      'destination': msg.destination,
      'payload': msg.payload,
      'createdAt': msg.createdAt.toIso8601String(),
      'ttl': msg.ttl,
      'priority': msg.priority,
    };
  }

  DtnMessage _fromMap(Map<String, dynamic> map) {
    return DtnMessage(
      id: map['id'],
      source: map['source'],
      destination: map['destination'],
      payload: map['payload'],
      createdAt: DateTime.parse(map['createdAt']),
      ttl: map['ttl'],
      priority: map['priority'] ?? 0,
    );
  }
}