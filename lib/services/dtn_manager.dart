import 'package:delay_messenger/models/dtn_message.dart';
import 'package:delay_messenger/services/DTN_Storage_Service.dart';
import 'package:delay_messenger/services/ble_transport_service.dart';
import 'package:delay_messenger/services/node_identity.dart';
import 'package:delay_messenger/services/prophet_routing_service.dart';
import 'package:delay_messenger/services/transfer_service.dart';
import 'package:delay_messenger/services/prophet_broadcast_routing_service.dart';

/// Callback type: notifies the UI layer that a message for this device arrived.
typedef OnMessageDelivered = void Function(DtnMessage msg);
typedef OnMessageRelayed  = void Function(DtnMessage msg, String toPeerId);

class DtnManager {
  final DtnStorageService storage;
  final ProphetRoutingService routing;
  final TransferService transfer;
  final BleTransportService ble;

  /// Set by the UI layer to display delivered messages.
  OnMessageDelivered? onMessageDelivered;

  /// Set by the UI layer to show relay notifications.
  OnMessageRelayed? onMessageRelayed;

  /// Maps BLE peer UUID → DTN node ID (learned from HELLO packets)
  final Map<String, String> _peerDtnIds = {};

  DtnManager({
    required this.storage,
    required this.routing,
    required this.transfer,
    required this.ble,
  }) {
    _wireBlCallbacks();
  }

  // ── BLE wiring ────────────────────────────────────────────────────────────
  void _wireBlCallbacks() {
    // Supply the HELLO packet builder (our node's state)
    ble.helloPacketBuilder = () async {
      final myMsgIds = [
        ...storage.getMyMessages().map((m) => m.id),
        ...storage.getRelayMessages().map((m) => m.id),
      ];
      return {
        'type':        'HELLO',
        'nodeId':      NodeIdentity.id,
        'displayName': NodeIdentity.displayNameOrId,
        'preds':       Map<String, double>.from(routing.preds),
        'msgIds':      myMsgIds,
      };
    };

    // Store BLE UUID → DTN nodeId mapping from HELLO packets
    ble.onPeerNodeId = (blePeerId, dtnNodeId) {
      _peerDtnIds[blePeerId] = dtnNodeId;
      print('🔗 Peer $blePeerId is DTN node: $dtnNodeId');
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
String _resolveNodeId(String id) {
  return _peerDtnIds.values.contains(id)
      ? id
      : id; // later you can expand mapping logic
}
  // ── Core DTN flow ─────────────────────────────────────────────────────────
  Future<void> onPeerConnected(
    String peerId,
    Map<String, double> peerPreds,
    List<String> peerMessageIds,
  ) async {
    // Use DTN node ID for routing if known, otherwise BLE UUID
    final routingId = _peerDtnIds[peerId] ?? peerId;
    print('\n🤝 ===== PEER CONNECTION: $peerId (DTN: $routingId) =====');

    // 1. Update PRoPHET probabilities using the DTN node ID
    routing.updateDeliveryPred(routingId);
    routing.updateTransitivePreds(routingId, peerPreds);

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
      routingId,  // use DTN nodeId, not BLE UUID
      peerPreds,
    );

    print('📤 Forwarding ${toSend.length} of ${allMessages.length} messages to $peerId');

    // 4. Send
    for (final msg in toSend) {
   
      await ble.sendMessage(peerId, msg);
      // If we originated this message, mark it as relayed
      if (msg.source == NodeIdentity.id) {
        storage.updateMessageStatus(msg.id, 'relayed');
      }
      // Fire relay notification for messages we're carrying for others
      if (msg.source != NodeIdentity.id) {
        onMessageRelayed?.call(msg, peerId);
      }
    }

    print('🤝 ===== PEER DONE =====\n');
  }

  void _handleIncomingMessage(DtnMessage msg) {
    print('📥 Incoming: ${msg.id} → ${msg.destination} from ${msg.source}');

    if (_isExpired(msg)) {
      print('🗑 Expired on arrival: ${msg.id}');
      return;
    }

    if (storage.hasMessage(msg.id)) {
      print('⏭ Already have: ${msg.id}');
      return;
    }

    // Delivered to us if destination matches our DTN node ID.
    // Also accept if sender mistakenly used our BLE UUID (pre-fix messages).
  final isForMe = msg.destination == NodeIdentity.id;

    print('🔍 isForMe=$isForMe  dest=${msg.destination}  myId=${NodeIdentity.id}');

    if (isForMe) {
      print('✅ Delivered to this device: ${msg.id}');
      final delivered = msg.copyWith(status: 'delivered');
      storage.saveMyMessage(delivered);
      onMessageDelivered?.call(delivered);
      return;
    }

    // Not for us — store in relay buffer and carry for later forwarding
    storage.saveRelayMessage(msg);
    print('📦 Stored for relay: ${msg.id}');
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  List<DtnMessage> _loadAndExpire() {
    final myMsgs = storage.getMyMessages();
    final relayMsgs = storage.getRelayMessages();
    final all = [...myMsgs, ...relayMsgs];
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
// ── BLE lifecycle (call from UI) ──────────────────────────────────────────

bool _bleStarted = false;

Future<void> startBle() async {
  if (_bleStarted) {
    print('⚠️ BLE already started');
    return;
  }

  try {
    _bleStarted = true;

    await ble.startAdvertising(NodeIdentity.displayNameOrId);
    await ble.startScan();

    print('✅ BLE started');
  } catch (e) {
    _bleStarted = false;
    print('❌ Failed to start BLE: $e');
  }
}

Future<void> stopBle() async {
  if (!_bleStarted) return;

  try {
    await ble.stopAdvertising();
    await ble.stopScan();

    print('🛑 BLE stopped');
  } finally {
    _bleStarted = false;
  }
}

}