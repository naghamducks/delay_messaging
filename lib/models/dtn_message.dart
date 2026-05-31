class DtnMessage {
  final String id;
  final String source;
  final String destination;
  final String? nodeDestination; //   DTN nodeId, set at creation
  final String payload;
  final DateTime createdAt;
  final int ttl;
  int copies;
  int priority;
  String status;

  DtnMessage({
    required this.id,
    required this.source,
    required this.destination,
    this.nodeDestination,
    required this.payload,
    required this.createdAt,
    required this.ttl,
    this.copies = 1,
    this.priority = 0,
    this.status = 'sent',
  });

  bool isExpired() =>
      DateTime.now().difference(createdAt).inSeconds > ttl;

  DtnMessage copyWith({
    String? id,
    String? source,
    String? destination,
    String? nodeDestination,
    String? payload,
    DateTime? createdAt,
    int? ttl,
    int? copies,
    int? priority,
    String? status,
  }) => DtnMessage(
    id:              id              ?? this.id,
    source:          source          ?? this.source,
    destination:     destination     ?? this.destination,
    nodeDestination: nodeDestination ?? this.nodeDestination,
    payload:         payload         ?? this.payload,
    createdAt:       createdAt       ?? this.createdAt,
    ttl:             ttl             ?? this.ttl,
    copies:          copies          ?? this.copies,
    priority:        priority        ?? this.priority,
    status:          status          ?? this.status,
  );

  Map<String, dynamic> toJson() => {
    'id':              id,
    'source':          source,
    'destination':     destination,
    'nodeDestination': nodeDestination,
    'payload':         payload,
    'createdAt':       createdAt.toIso8601String(),
    'ttl':             ttl,
    'copies':          copies,
    'priority':        priority,
    'status':          status,
  };

  factory DtnMessage.fromJson(Map<String, dynamic> json) => DtnMessage(
    id:              json['id']              as String,
    source:          json['source']          as String,
    destination:     json['destination']     as String,
    nodeDestination: json['nodeDestination'] as String?,
    payload:         json['payload']         as String,
    createdAt:       DateTime.parse(json['createdAt'] as String),
    ttl:             json['ttl']             as int,
    copies:          json['copies']          as int? ?? 1,
    priority:        json['priority']        as int? ?? 0,
    status:          json['status']          as String? ?? 'sent',
  );
}