class DtnMessage {
  final String id;
  final String source;
  final String destination;
  final String payload;
  final DateTime createdAt;
  final int ttl;
  int copies;
  int priority;

  DtnMessage({
    required this.id,
    required this.source,
    required this.destination,
    required this.payload,
    required this.createdAt,
    required this.ttl,
    this.copies = 1,
    this.priority = 0,
  });

  bool isExpired() {
    return DateTime.now().difference(createdAt).inSeconds > ttl;
  }
}