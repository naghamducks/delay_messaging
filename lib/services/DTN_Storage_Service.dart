import 'package:delay_messenger/models/dtn_message.dart';
import 'package:hive_flutter/hive_flutter.dart';

class DtnStorageService {
  Box get _myBox    => Hive.box('my_messages');
  Box get _relayBox => Hive.box('relay_buffer');

  // ── Write ──────────────────────────────────────────────────────────────────

  void saveMyMessage(DtnMessage msg) => _myBox.put(msg.id, _toMap(msg));

  void saveRelayMessage(DtnMessage msg) => _relayBox.put(msg.id, _toMap(msg));

  // ── Read ───────────────────────────────────────────────────────────────────

  List<DtnMessage> getMyMessages() => _myBox.values
      .map((e) => _fromMap(Map<String, dynamic>.from(e as Map)))
      .toList();

  List<DtnMessage> getRelayMessages() => _relayBox.values
      .map((e) => _fromMap(Map<String, dynamic>.from(e as Map)))
      .toList();

  List<DtnMessage> getAllMessages() =>
      [...getMyMessages(), ...getRelayMessages()];

  bool hasMessage(String id) =>
      _myBox.containsKey(id) || _relayBox.containsKey(id);

  // ── Delete & Update ────────────────────────────────────────────────────────

  void deleteMessage(String id) {
    if (_myBox.containsKey(id))        _myBox.delete(id);
    else if (_relayBox.containsKey(id)) _relayBox.delete(id);
  }

  void updateMessageStatus(String id, String status) {
    if (!_myBox.containsKey(id)) return;
    final raw = Map<String, dynamic>.from(_myBox.get(id) as Map);
    raw['status'] = status;
    _myBox.put(id, raw);
  }

  // ── Serialization ──────────────────────────────────────────────────────────

  Map<String, dynamic> _toMap(DtnMessage msg) => {
    'id':              msg.id,
    'source':          msg.source,
    'destination':     msg.destination,
    'nodeDestination': msg.nodeDestination, // nullable — null for old messages
    'payload':         msg.payload,
    'createdAt':       msg.createdAt.toIso8601String(),
    'ttl':             msg.ttl,
    'copies':          msg.copies,
    'priority':        msg.priority,
    'status':          msg.status,
  };

  DtnMessage _fromMap(Map<String, dynamic> map) => DtnMessage(
    id:              map['id']          as String,
    source:          map['source']      as String,
    destination:     map['destination'] as String,
    // nodeDestination is nullable — old records won't have it, that's fine.
    nodeDestination: map['nodeDestination'] as String?,
    payload:         map['payload']     as String,
    createdAt:       DateTime.parse(map['createdAt'] as String),
    ttl:             map['ttl']         as int,
    copies:          map['copies']      as int?  ?? 1,
    priority:        map['priority']    as int?  ?? 0,
    status:          map['status']      as String? ?? 'sent',
  );
}