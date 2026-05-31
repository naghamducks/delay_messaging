import 'package:hive_flutter/hive_flutter.dart';
import 'package:delay_messenger/services/ble_transport_service.dart';
import 'package:delay_messenger/services/dtn_manager.dart';
import 'package:delay_messenger/services/DTN_Storage_Service.dart';
import 'package:delay_messenger/services/prophet_routing_service.dart';
import 'package:delay_messenger/services/prophet_broadcast_routing_service.dart';
import 'package:delay_messenger/services/transfer_service.dart';
 import 'package:delay_messenger/services/node_identity.dart';

class ServiceLocator {
  ServiceLocator._();

  static late final DtnStorageService storage;
  static late final ProphetRoutingService routing;
  static late final ProphetBroadcastRoutingService sosRouting;
   static late final TransferService transfer;
  static late final BleTransportService ble;
  static late final DtnManager dtnManager;

  static Future<void> init() async {
    await NodeIdentity.init();

    await Hive.openBox('my_messages');
    await Hive.openBox('relay_buffer');

    storage    = DtnStorageService();
    routing    = ProphetRoutingService();
    sosRouting = ProphetBroadcastRoutingService();
     transfer   = TransferService(routing, sosRouting);
    ble        = BleTransportService();
    dtnManager = DtnManager(
      storage:  storage,
      routing:  routing,
      transfer: transfer,
       ble:      ble,
    );

    // setup() only registers state listeners and waits for BT power-on.
    // startAdvertising + startScan are called from main.dart AFTER
    // permissions are granted — otherwise they fail silently and the
    // _isAdvertising guard blocks any retry.
    await ble.setup();
  }
}