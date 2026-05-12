
import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:permission_handler/permission_handler.dart';

class BluetoothService {
  final _central = CentralManager();

  Future<bool> isBluetoothEnabled() async {
    try {
      // state is a Stream in v6, use .first to get current value
      final state = await _central.state;
      return state == BluetoothLowEnergyState.poweredOn;
    } catch (e) {
      return false;
    }
  }

  Future<bool> requestBluetoothPermissions({int maxAttempts = 3}) async {
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      print('Permission request attempt $attempt/$maxAttempts');

      final statuses = await [
        Permission.bluetooth,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.bluetoothAdvertise,
        Permission.location,
      ].request();

      statuses.forEach((p, s) => print('  $p: $s'));

      final bleGranted =
          (statuses[Permission.bluetoothScan]?.isGranted    ?? false) &&
          (statuses[Permission.bluetoothConnect]?.isGranted  ?? false) &&
          (statuses[Permission.bluetoothAdvertise]?.isGranted ?? false);
      final locationGranted =
          statuses[Permission.location]?.isGranted ?? false;

      print('BLE granted: $bleGranted, Location granted: $locationGranted');

      if (bleGranted && locationGranted) {
        print('All required permissions granted on attempt $attempt');
        return true;
      }

      if (await areBluetoothPermissionsPermanentlyDenied()) return false;

      if (attempt < maxAttempts) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
    return false;
  }

  Future<bool> hasBluetoothPermissions() async {
    final scan      = await Permission.bluetoothScan.status;
    final connect   = await Permission.bluetoothConnect.status;
    final advertise = await Permission.bluetoothAdvertise.status;
    return scan.isGranted && connect.isGranted && advertise.isGranted;
  }

  Future<bool> hasLocationPermission() async =>
      (await Permission.location.status).isGranted;

  Future<bool> hasAllRequiredPermissions() async =>
      await hasBluetoothPermissions() && await hasLocationPermission();

  Future<bool> areBluetoothPermissionsPermanentlyDenied() async {
    final scan    = await Permission.bluetoothScan.status;
    final connect = await Permission.bluetoothConnect.status;
    print('Checking if Bluetooth permissions are permanently denied:');
    print('  Bluetooth Scan: ${scan.isPermanentlyDenied}');
    print('  Bluetooth Connect: ${connect.isPermanentlyDenied}');
    print('  Bluetooth Advertise: ${(await Permission.bluetoothAdvertise.status).isPermanentlyDenied}');
    return scan.isPermanentlyDenied || connect.isPermanentlyDenied;
  }

  Future<bool> isLocationPermissionPermanentlyDenied() async =>
      (await Permission.location.status).isPermanentlyDenied;

  // Stream of Bluetooth on/off state
  Stream<bool> get bluetoothStateStream async* {
    bool lastState = await isBluetoothEnabled();
    yield lastState;

    while (true) {
      await Future.delayed(const Duration(milliseconds: 500));
      final currentState = await isBluetoothEnabled();
      if (currentState != lastState) {
        lastState = currentState;
        yield currentState;
      }
    }
  }
}