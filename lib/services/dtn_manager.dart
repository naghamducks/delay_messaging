import 'package:delay_messenger/models/dtn_message.dart';
import 'package:delay_messenger/services/DTN_Storage_Service.dart';
import 'package:delay_messenger/services/battery_service.dart';
import 'package:delay_messenger/services/ble_transport_service.dart';
import 'package:delay_messenger/services/node_identity.dart';
import 'package:delay_messenger/services/prophet_routing_service.dart';
import 'package:delay_messenger/services/transfer_service.dart';

/// Callback type: notifies the UI layer that a message for this device arrived.
typedef OnMessageDelivered = void Function(DtnMessage msg);

class DtnManager {
  final DtnStorageService storage;
  final ProphetRoutingService routing;
  final TransferService transfer;
  final BatteryService battery;
  final BleTransportService ble;

  /// Set by ChatProvider so the UI can display delivered messages.
  OnMessageDelivered? onMessageDelivered;

  DtnManager({
    required this.storage,
    required this.routing,
    required this.transfer,
    required this.battery,
    required this.ble,
  }) {
    _wireBlCallbacks();
  }

  // ── BLE wiring ────────────────────────────────────────────────────────────
  void _wireBlCallbacks() {
    // Supply the HELLO packet builder (our node's state)
    ble.helloPacketBuilder = () async {
      final myMsgIds = storage.getAllMessages().map((m) => m.id).toList();
      return {
        'type':   'HELLO',
        'nodeId': NodeIdentity.id,
        'preds':  Map<String, double>.from(routing.preds),
        'msgIds': myMsgIds,
      };
    };

    // Called when a HELLO arrives from a peer
    ble.onPeerConnected = (peerId, peerPreds, peerMsgIds) {
      onPeerConnected(peerId, peerPreds, peerMsgIds);
    };

    // Called when a MSG arrives from a peer
    ble.onMessageReceived = (msg) {
      _handleIncomingMessage(msg);
    };
  }

  // ── Core DTN flow ─────────────────────────────────────────────────────────
  Future<void> onPeerConnected(
    String peerId,
    Map<String, double> peerPreds,
    List<String> peerMessageIds,
  ) async {
    print('\n🤝 ===== PEER CONNECTION: $peerId =====');

    // 1. Update PRoPHET probabilities
    routing.updateDeliveryPred(peerId);
    routing.updateTransitivePreds(peerId, peerPreds);

    // 2. Load and expire messages
    final allMessages = _loadAndExpire();

    // 3. Filter: messages the peer does not have AND we should forward
    final candidates = allMessages.where((msg) =>
      !peerMessageIds.contains(msg.id) &&
      msg.destination != NodeIdentity.id   // don't re-forward already-delivered
    ).toList();

    final toSend = transfer.decideMessagesToSend(
      candidates,
      peerMessageIds,
      peerId,
      peerPreds,
    );

    print('📤 Forwarding ${toSend.length} of ${allMessages.length} messages to $peerId');

    // 4. Send
    for (final msg in toSend) {
      if (!battery.isAlive()) {
        print('🔋 Battery dead — stopping');
        break;
      }
      await ble.sendMessage(peerId, msg);
      battery.consumeTx(msg.payload.length.toDouble());
    }

    print('🤝 ===== PEER DONE =====\n');
  }

  void _handleIncomingMessage(DtnMessage msg) {
    print('📥 Incoming: ${msg.id} → ${msg.destination} from ${msg.source}');

    // Check TTL first
    if (_isExpired(msg)) {
      print('🗑 Expired on arrival: ${msg.id}');
      return;
    }

    // Deduplicate
    if (storage.hasMessage(msg.id)) {
      print('⏭ Already have: ${msg.id}');
      return;
    }

    // Is this message for us?
    if (msg.destination == NodeIdentity.id) {
      print('✅ Delivered to this device: ${msg.id}');
      onMessageDelivered?.call(msg);
      // Store it so we can show it in the chat
      storage.saveMessage(msg);
      return;
    }

    // Not for us — store and carry for later forwarding
    storage.saveMessage(msg);
    print('📦 Stored for relay: ${msg.id}');
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  List<DtnMessage> _loadAndExpire() {
    final all = storage.getAllMessages();
    final expired = all.where(_isExpired).toList();
    for (final msg in expired) {
      print('🗑 TTL expired, deleting: ${msg.id}');
      storage.deleteMessage(msg.id);
    }
    return all.where((m) => !_isExpired(m)).toList();
  }

  bool _isExpired(DtnMessage msg) {
    final age = DateTime.now().difference(msg.createdAt).inSeconds;
    return age >= msg.ttl;
  }

  // ── BLE lifecycle (call from UI) ──────────────────────────────────────────
Future<void> startBle() async {
  await ble.startAdvertising(NodeIdentity.id);
  await ble.startScan();
}

Future<void> stopBle() async {
  await ble.stopAdvertising();
  await ble.stopScan();
}
}