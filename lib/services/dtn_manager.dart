import 'package:delay_messenger/models/dtn_message.dart';
import 'package:delay_messenger/services/DTN_Storage_Service.dart';
import 'package:delay_messenger/services/battery_service.dart';
import 'package:delay_messenger/services/prophet_routing_service.dart';
import 'package:delay_messenger/services/transfer_service.dart';

class DtnManager {
  final DtnStorageService storage;
  final ProphetRoutingService routing;
  final TransferService? transfer;
  final BatteryService battery;

  DtnManager({
    required this.storage,
    required this.routing,
     this.transfer,
    required this.battery,
  });

  /// ⭐ THIS is where your function goes
  Future<void> onPeerConnected(
    String peerId,
    Map<String, double> peerPreds,
    List<String> peerMessageIds,
  ) async {
    // 1. Update PRoPHET metrics
    routing.updateDeliveryPred(peerId);
    routing.updateTransitivePreds(peerId, peerPreds);

    // 2. Get my messages
    List<DtnMessage> myMessages = storage.getAllMessages();

    // 3. Decide what to send
    List<DtnMessage> toSend = transfer!.decideMessagesToSend(
      myMessages,
      peerMessageIds,
      peerId,
      peerPreds,
    );

    // 4. Send messages
    for (var msg in toSend) {
      if (!battery.isAlive()) break;

      await sendMessage(peerId, msg);

      battery.consumeTx(msg.payload.length.toDouble());
    }
  }

  /// 🔌 You will implement this later (Bluetooth/WiFi)
  Future<void> sendMessage(String peerId, DtnMessage msg) async {
    print("Sending ${msg.id} to $peerId");
  }
}