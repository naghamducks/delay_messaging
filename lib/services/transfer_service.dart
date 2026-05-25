import 'package:delay_messenger/models/dtn_message.dart';
import 'package:delay_messenger/services/battery_service.dart';
import 'package:delay_messenger/services/prophet_routing_service.dart';
import 'package:delay_messenger/services/prophet_broadcast_routing_service.dart';

class TransferService {
  final ProphetRoutingService routing;
  final BatteryService battery;
  final ProphetBroadcastRoutingService sosRouting;

  TransferService(this.routing, this.battery, this.sosRouting);

  /// Decides which messages to forward to a peer.
  ///
  /// SOS messages (priority > 5) are forwarded to ALL peers via broadcast
  /// routing, bypassing delivery-probability gating. Normal messages use
  /// standard PRoPHET probability comparison. SOS messages are placed first
  /// in the returned list (higher urgency), then normal messages. Within
  /// each group, messages are sorted by priority desc then delivery prob desc.
  List<DtnMessage> decideMessagesToSend(
    List<DtnMessage> myMessages,
    List<String> peerMessages,
    String peerId,
    Map<String, double> peerPreds,
  ) {
    print('\n🔍 DECIDING MESSAGES TO SEND:');
    print(
      '   Evaluating ${myMessages.length} messages against peer $peerId\n',
    );

    // ── Split into SOS and normal ────────────────────────────────────────
    final sosMsgs = myMessages.where(sosRouting.isSosMessage).toList();
    final normalMsgs = myMessages.where((m) => !sosRouting.isSosMessage(m)).toList();

    // ── SOS: broadcast to all peers (TTL + dedup only) ───────────────────
    final sosToSend = sosRouting.decideSosMessages(sosMsgs, peerMessages);

    for (final msg in sosMsgs) {
      final willSend = sosToSend.contains(msg);
      print(
        '   ${willSend ? "🆘" : "⏭️ "} ${msg.id} [SOS] → ${msg.destination}: '
        '${willSend ? "BROADCAST" : "SKIP (peer has it or expired)"}',
      );
    }

    // ── Normal: standard PRoPHET probability gating ──────────────────────
    final List<DtnMessage> normalToSend = [];

    for (final msg in normalMsgs) {
      if (peerMessages.contains(msg.id)) {
        print('   ⏭️  ${msg.id}: SKIP (peer already has it)');
        continue;
      }

      if (msg.isExpired()) {
        print('   ⏭️  ${msg.id}: SKIP (expired)');
        continue;
      }

      final double myP = routing.getPred(msg.destination);
      final double peerP = peerPreds[msg.destination] ?? 0;

      // PRoPHET condition: forward if peer has better delivery probability
      final bool shouldForward = peerP >= myP;

      print(
        '   ${shouldForward ? "✅" : "❌"} ${msg.id} → ${msg.destination}: '
        'myP=$myP, peerP=$peerP '
        '${shouldForward ? "(peer is better!)" : "(I\'m better)"}',
      );

      if (shouldForward) {
        normalToSend.add(msg);
      }
    }

    // ── Sort each group: priority desc then delivery prob desc ────────────
    int _sortByPriorityAndProb(DtnMessage a, DtnMessage b) {
      final int pCompare = b.priority.compareTo(a.priority);
      if (pCompare != 0) return pCompare;
      final double pA = routing.getPred(a.destination);
      final double pB = routing.getPred(b.destination);
      return pB.compareTo(pA);
    }

    sosToSend.sort(_sortByPriorityAndProb);
    normalToSend.sort(_sortByPriorityAndProb);

    // SOS messages come first
    return [...sosToSend, ...normalToSend];
  }
}