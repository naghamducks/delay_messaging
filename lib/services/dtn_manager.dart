import 'package:delay_messenger/models/dtn_message.dart';
import 'package:delay_messenger/services/DTN_Storage_Service.dart';
import 'package:delay_messenger/services/ble_transport_service.dart';
import 'package:delay_messenger/services/node_identity.dart';
import 'package:delay_messenger/services/prophet_routing_service.dart';
import 'package:delay_messenger/services/transfer_service.dart';
 
typedef OnMessageDelivered = void Function(DtnMessage msg);
typedef OnMessageRelayed   = void Function(DtnMessage msg, String toPeerId);

class DtnManager {
  final DtnStorageService      storage;
  final ProphetRoutingService  routing;
  final TransferService        transfer;
  final BleTransportService    ble;

  OnMessageDelivered? onMessageDelivered;
  OnMessageRelayed?   onMessageRelayed;

  final Map<String, String>           _peerDtnIds         = {};
  final Map<String, String>           _reversePeerMap     = {};
  final Map<String, List<dynamic>>    _pendingConnections = {};
  final Set<String>                   _myKnownBleIds      = {};
  final Map<String, List<DtnMessage>> _pendingOutbound    = {};
  final Map<String, String>           _bleToDtn           = {};

  Map<String, String> get debugPeers => _peerDtnIds;
  Map<String, String> get peerDtnIds => _peerDtnIds;

  DtnManager({
    required this.storage,
    required this.routing,
    required this.transfer,
    required this.ble,
  }) {
    _wireBlCallbacks();
  }

  // ── BLE wiring ─────────────────────────────────────────────────────────────

  void _wireBlCallbacks() {
    ble.helloPacketBuilder = () async {
      final myMsgIds = [
        ...storage.getMyMessages().map((m) => m.id),
        ...storage.getRelayMessages().map((m) => m.id),
      ];
      // Keep BLE transport aware of our display name so it can include it in MSG packets
      ble.myDisplayName = NodeIdentity.displayNameOrId;
      final packet = {
        'type':        'HELLO',
        'nodeId':      NodeIdentity.id,
        'displayName': NodeIdentity.displayNameOrId,
        'preds':       Map<String, double>.from(routing.preds),
        'msgIds':      myMsgIds,
      };
      print('📦 [DtnManager] Built HELLO packet: nodeId=${NodeIdentity.id} msgCount=${myMsgIds.length}');
      return packet;
    };

    ble.onPeerNodeId = (blePeerId, dtnNodeId) {
      _peerDtnIds[blePeerId]     = dtnNodeId;
      _reversePeerMap[dtnNodeId] = blePeerId;
      print('🔗 [DtnManager] Mapping stored: $blePeerId → $dtnNodeId');
      print('🗺️  [DtnManager] _peerDtnIds: $_peerDtnIds');
      print('🗺️  [DtnManager] _reversePeerMap: $_reversePeerMap');

      Future.microtask(() async {
        final pending = _pendingConnections.remove(blePeerId);
        if (pending != null) {
          print('🔓 [DtnManager] Flushing pending connection for $blePeerId (DTN: $dtnNodeId)');
          final peerPreds  = pending[0] as Map<String, double>;
          final peerMsgIds = pending[1] as List<String>;
          await onPeerConnected(blePeerId, peerPreds, peerMsgIds);
        }

        final byDtn    = _pendingOutbound.remove(dtnNodeId) ?? [];
        final byBle    = _pendingOutbound.remove(blePeerId) ?? [];
        final outbound = [...byDtn, ...byBle];
        print('📬 [DtnManager] onPeerNodeId flush: byDtn=${byDtn.length} byBle=${byBle.length} total=${outbound.length}');

        for (final msg in outbound) {
          final patched = msg.copyWith(destination: blePeerId);
          print('📤 [DtnManager] Flushing queued msg ${msg.id} → $blePeerId');
          print('    src=${patched.source} dest=${patched.destination} nodeDest=${patched.nodeDestination}');
          try {
            await ble.sendMessage(blePeerId, patched);
            storage.saveMyMessage(patched);
            print('✅ [DtnManager] Flushed msg ${msg.id}');
          } catch (e) {
            print('❌ [DtnManager] Flush failed for ${msg.id}: $e');
          }
        }
      });
    };

    ble.onPeerConnected = (peerId, peerPreds, peerMsgIds) {
      final dtnId = _peerDtnIds[peerId];
      print('🤝 [BLE→DtnManager] onPeerConnected: peerId=$peerId dtnId=$dtnId');
      if (dtnId != null) {
        onPeerConnected(peerId, peerPreds, peerMsgIds);
      } else {
        print('⏳ [DtnManager] No DTN ID yet for $peerId — queuing connection');
        _pendingConnections[peerId] = [peerPreds, peerMsgIds];
      }
    };

    ble.onMyBleIdLearned = (myBleUuid) {
      _myKnownBleIds.add(myBleUuid);
      print('📌 [DtnManager] My own BLE UUID learned: $myBleUuid');
      print('📌 [DtnManager] All my BLE UUIDs: $_myKnownBleIds');
    };

    ble.onMessageReceived = (msg) {
      print('📨 [BLE→DtnManager] onMessageReceived fired for msg ${msg.id}');
      _handleIncomingMessage(msg);
    };
  }

  // ── Core DTN flow ──────────────────────────────────────────────────────────

  Future<void> onPeerConnected(
    String peerId,
    Map<String, double> peerPreds,
    List<String> peerMessageIds,
  ) async {
    final dtnId = _peerDtnIds[peerId] ?? peerId;
    print('\n════════════════════════════════════');
    print('🤝 PEER CONNECTED: $peerId');
    print('   DTN ID: $dtnId');
    print('   peerPreds: $peerPreds');
    print('   peerMsgIds count: ${peerMessageIds.length}');

    routing.updateDeliveryPred(dtnId);
    routing.updateTransitivePreds(dtnId, peerPreds);

    final allMessages = _loadAndExpire();
    print('📦 Total messages in store: ${allMessages.length}');

    final candidates = allMessages.where((msg) =>
      !peerMessageIds.contains(msg.id) &&
      msg.destination != NodeIdentity.id
    ).toList();
    print('🔍 Candidates after filter: ${candidates.length}');
    for (final c in candidates) {
      print('   candidate: ${c.id} dest=${c.destination} nodeDest=${c.nodeDestination}');
    }

    final toSend = transfer.decideMessagesToSend(
      candidates,
      peerMessageIds,
      dtnId,
      peerPreds,
    );
    print('📤 TransferService decided to send: ${toSend.length}');

    for (final msg in toSend) {
      print('📤 [DtnManager] Sending via PROPHET: ${msg.id} → $peerId');
      print('    src=${msg.source} dest=${msg.destination} nodeDest=${msg.nodeDestination}');
      await ble.sendMessage(peerId, msg);
    }

    // Flush any user-queued messages (sent before mapping was known)
    final byDtn2 = _pendingOutbound.remove(dtnId) ?? [];
    final byBle2 = _pendingOutbound.remove(peerId) ?? [];
    final extra  = [...byDtn2, ...byBle2];
    print('📬 [DtnManager] onPeerConnected queue flush: byDtn=${byDtn2.length} byBle=${byBle2.length}');
    for (final msg in extra) {
      final patched = msg.copyWith(destination: peerId);
      print('📤 [DtnManager] Flushing (onPeerConnected): ${msg.id} → $peerId');
      print('    src=${patched.source} dest=${patched.destination} nodeDest=${patched.nodeDestination}');
      try {
        await ble.sendMessage(peerId, patched);
        storage.saveMyMessage(patched);
        print('✅ [DtnManager] Flushed ${msg.id}');
      } catch (e) {
        print('❌ [DtnManager] Flush failed ${msg.id}: $e');
      }
    }

    print('🤝 PEER DONE');
    print('════════════════════════════════════\n');
  }

  String? getBleId(String dtnId) => _reversePeerMap[dtnId];

  Future<bool> sendOrQueue(String dtnId, DtnMessage msg) async {
    print('📮 [DtnManager] sendOrQueue: dtnId=$dtnId msgId=${msg.id}');
    print('   src=${msg.source} dest=${msg.destination} nodeDest=${msg.nodeDestination}');
    print('   _reversePeerMap: $_reversePeerMap');
    print('   _peerDtnIds: $_peerDtnIds');

    // Primary: DTN ID → BLE UUID via reverse map
    final bleId = _reversePeerMap[dtnId];
    print('   resolved bleId from _reversePeerMap: $bleId');

    if (bleId != null && ble.isConnected(bleId)) {
      print('📤 [DtnManager] Sending immediately (central path) to $dtnId ($bleId)');
      await ble.sendMessage(bleId, msg);
      print('✅ [DtnManager] Sent immediately: ${msg.id}');
      return true;
    }

    // Fallback: maybe we know the BLE UUID from _peerDtnIds but reversePeerMap
    // hasn't been populated yet (e.g. peripheral received HELLO write but
    // onPeerNodeId hasn't finished setting _reversePeerMap)
    final bleIdFromDtnIds = _peerDtnIds.entries
        .where((e) => e.value == dtnId)
        .map((e) => e.key)
        .firstOrNull;
    print('   bleIdFromDtnIds (_peerDtnIds reverse lookup): $bleIdFromDtnIds');

    if (bleIdFromDtnIds != null && ble.isConnected(bleIdFromDtnIds)) {
      // Also fix the reverse map for next time
      _reversePeerMap[dtnId] = bleIdFromDtnIds;
      print('📤 [DtnManager] Sending immediately (peripheral path) to $dtnId ($bleIdFromDtnIds)');
      await ble.sendMessage(bleIdFromDtnIds, msg);
      print('✅ [DtnManager] Sent immediately: ${msg.id}');
      return true;
    }

    print('📪 [DtnManager] Queuing msg ${msg.id} under key "$dtnId"');
    print('   bleId=$bleId bleIdFromDtnIds=$bleIdFromDtnIds');
    _pendingOutbound.putIfAbsent(dtnId, () => []).add(msg);
    print('   _pendingOutbound keys: ${_pendingOutbound.keys.toList()}');
    return false;
  }

  void _handleIncomingMessage(DtnMessage msg) {
    print('\n════════════════════════════════════');
    print('📥 INCOMING MESSAGE');
    print('   id:          ${msg.id}');
    print('   source:      ${msg.source}');
    print('   destination: ${msg.destination}');
    print('   nodeDest:    ${msg.nodeDestination}');
    print('   payload:     ${msg.payload}');
    print('   priority:    ${msg.priority}');
    print('   ttl:         ${msg.ttl}');
    print('   createdAt:   ${msg.createdAt}');

    print('🔑 My NodeIdentity.id = ${NodeIdentity.id}');
    print('🔑 My known BLE UUIDs = $_myKnownBleIds');

    if (_isExpired(msg)) {
      print('🗑 DROPPED: expired (age=${DateTime.now().difference(msg.createdAt).inSeconds}s ttl=${msg.ttl}s)');
      print('════════════════════════════════════\n');
      return;
    }

    if (storage.hasMessage(msg.id)) {
      print('⏭ DROPPED: already in storage');
      print('════════════════════════════════════\n');
      return;
    }

    final matchesNodeDest = msg.nodeDestination == NodeIdentity.id;
    final matchesDest     = msg.destination == NodeIdentity.id;
    final matchesBleUuid  = _myKnownBleIds.contains(msg.destination);
    final noNodeDest      = msg.nodeDestination == null || msg.nodeDestination!.isEmpty;

    print('🔍 isForMe checks:');
    print('   nodeDestination == myId?  $matchesNodeDest  ("${msg.nodeDestination}" == "${NodeIdentity.id}")');
    print('   destination == myId?      $matchesDest  ("${msg.destination}" == "${NodeIdentity.id}")');
    print('   destination in myBleUuids? $matchesBleUuid  ("${msg.destination}" in $_myKnownBleIds)');
    print('   noNodeDest?               $noNodeDest');

    final isForMe = matchesNodeDest ||
        (noNodeDest ? matchesDest : false) ||
        matchesBleUuid;

    print('   ➡️  isForMe = $isForMe');

    if (isForMe) {
      print('✅ DELIVERING to UI: ${msg.id}');
      final delivered = msg.copyWith(status: 'delivered');
      storage.saveMyMessage(delivered);
      print('💾 Saved to storage as delivered');
      if (onMessageDelivered != null) {
        print('📲 Calling onMessageDelivered callback');
        onMessageDelivered!.call(delivered);
        print('📲 onMessageDelivered callback returned');
      } else {
        print('⚠️ onMessageDelivered is NULL — message will NOT show in UI!');
      }
      print('════════════════════════════════════\n');
      return;
    }

    print('📦 Not for me — storing for relay');
    storage.saveRelayMessage(msg);
    print('════════════════════════════════════\n');
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  List<DtnMessage> _loadAndExpire() {
    final all     = [...storage.getMyMessages(), ...storage.getRelayMessages()];
    final expired = all.where(_isExpired).toList();
    for (final msg in expired) {
      print('🗑 TTL expired: ${msg.id}');
      storage.deleteMessage(msg.id);
    }
    return all.where((m) => !_isExpired(m)).toList();
  }

  bool _isExpired(DtnMessage msg) =>
      DateTime.now().difference(msg.createdAt).inSeconds >= msg.ttl;

  void registerMapping(String bleId, String dtnId) {
    _bleToDtn[bleId] = dtnId;
  }

  String? getDtnId(String bleId)       => _peerDtnIds[bleId];
  String? resolveToDtnId(String bleId) => _peerDtnIds[bleId];

  Future<void> startBle() async {
    print('🚀 [DtnManager] startBle: starting advertising + scan');
    // Set display name early so MSG packets carry it even before first HELLO build
    ble.myDisplayName = NodeIdentity.displayNameOrId;
    await ble.startAdvertising(NodeIdentity.displayNameOrId);
    await ble.startScan();
    print('✅ [DtnManager] startBle complete');
  }

  Future<void> stopBle() async {
    await ble.stopAdvertising();
    await ble.stopScan();
  }
}