import 'package:delay_messenger/models/dtn_message.dart';

/// PRoPHET Broadcast Routing Service for high-priority SOS messages.
///
/// SOS messages (priority > 5) bypass normal probability gating and are
/// forwarded to ALL connected peers (pure epidemic flooding), while still
/// respecting TTL expiry and deduplication.
class ProphetBroadcastRoutingService {
  /// Threshold above which a message is treated as SOS.
  static const int sosPriorityThreshold = 5;

  /// Returns true if [msg] qualifies as an SOS message.
  bool isSosMessage(DtnMessage msg) => msg.priority > sosPriorityThreshold;

  /// Decides which SOS messages to forward to a peer.
  ///
  /// - Filters [allMessages] to SOS messages only (`priority > 5`).
  /// - Excludes messages the peer already holds (`peerMessageIds`).
  /// - Excludes TTL-expired messages.
  /// - Returns ALL remaining SOS messages regardless of delivery probability
  ///   (broadcast / epidemic forwarding).
  List<DtnMessage> decideSosMessages(
    List<DtnMessage> allMessages,
    List<String> peerMessageIds,
  ) {
    return allMessages.where((msg) {
      if (!isSosMessage(msg)) return false;
      if (peerMessageIds.contains(msg.id)) return false;
      if (msg.isExpired()) return false;
      return true;
    }).toList();
  }
}
