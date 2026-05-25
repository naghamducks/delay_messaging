import 'package:hive_flutter/hive_flutter.dart';
import 'package:delay_messenger/services/ble_transport_service.dart';
import 'package:delay_messenger/services/dtn_manager.dart';
import 'package:delay_messenger/services/DTN_Storage_Service.dart';
import 'package:delay_messenger/services/prophet_routing_service.dart';
import 'package:delay_messenger/services/prophet_broadcast_routing_service.dart';
import 'package:delay_messenger/services/transfer_service.dart';
import 'package:delay_messenger/services/battery_service.dart';
import 'package:delay_messenger/services/node_identity.dart';

/// Single source of truth for all singleton services.
/// Call ServiceLocator.init() once in main() before runApp().
class ServiceLocator {
  ServiceLocator._();

  static late final DtnStorageService storage;
  static late final ProphetRoutingService routing;
  static late final ProphetBroadcastRoutingService sosRouting;
  static late final BatteryService battery;
  static late final TransferService transfer;
  static late final BleTransportService ble;
  static late final DtnManager dtnManager;

  /// Must be called (and awaited) before runApp().
  static Future<void> init() async {
    await NodeIdentity.init();

    await Hive.openBox('my_messages');
    await Hive.openBox('relay_buffer');

    storage    = DtnStorageService();
    routing    = ProphetRoutingService();
    sosRouting = ProphetBroadcastRoutingService();
    battery    = BatteryService();
    transfer   = TransferService(routing, battery, sosRouting);
    ble        = BleTransportService();
    dtnManager = DtnManager(
      storage:  storage,
      routing:  routing,
      transfer: transfer,
      battery:  battery,
      ble:      ble,
    );
     await ble.setup(); // ← add this
  }
}