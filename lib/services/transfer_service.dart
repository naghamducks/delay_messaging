import 'package:delay_messenger/models/dtn_message.dart';
import 'package:delay_messenger/services/battery_service.dart';
import 'package:delay_messenger/services/prophet_routing_service.dart';

class TransferService {
  final ProphetRoutingService routing;
  final BatteryService battery;

  TransferService(this.routing, this.battery);

  List<DtnMessage> decideMessagesToSend(
    List<DtnMessage> myMessages,
    List<String> peerMessages,
    String peerId,
    Map<String, double> peerPreds,
  ) {
    List<DtnMessage> toSend = [];

    print("\n🔍 DECIDING MESSAGES TO SEND:");
    print("   Evaluating ${myMessages.length} messages against peer $peerId\n");

    for (var msg in myMessages) {
      // Check if peer already has this message
      if (peerMessages.contains(msg.id)) {
        print("   ⏭️  ${msg.id}: SKIP (peer already has it)");
        continue;
      }

      double myP = routing.getPred(msg.destination);
      double peerP = peerPreds[msg.destination] ?? 0;

      // ⭐ PRoPHET condition: forward if peer has better delivery probability
      bool shouldForward = peerP >= myP;

      print(
        "   ${shouldForward ? "✅" : "❌"} ${msg.id} → ${msg.destination}: "
        "myP=$myP, peerP=$peerP ${shouldForward ? "(peer is better!)" : "(I'm better)"}",
      );

      if (shouldForward) {
        toSend.add(msg);
      }
    }

    // ⭐ PRIORITY + PROBABILITY SORT
    toSend.sort((a, b) {
      int pCompare = b.priority.compareTo(a.priority);
      if (pCompare != 0) return pCompare;

      double pA = routing.getPred(a.destination);
      double pB = routing.getPred(b.destination);

      return pB.compareTo(pA);
    });

    return toSend;
  }
}