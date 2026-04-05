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

    for (var msg in myMessages) {
      if (peerMessages.contains(msg.id)) continue;

      double myP = routing.getPred(msg.destination);
      double peerP = peerPreds[msg.destination] ?? 0;

      // ⭐ PRoPHET condition
      if (peerP >= myP) {
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