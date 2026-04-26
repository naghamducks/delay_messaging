import 'package:delay_messenger/services/service_locator.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'providers/theme_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/dtn_provider.dart';
import 'widgets/bluetooth_check_dialog.dart';
import 'services/ble_permission_service.dart';

Future<void> initStorage() async {
  await Hive.initFlutter();
  await Hive.openBox('messages');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initStorage();
  await ServiceLocator.init();
  runApp(const DTNMessengerApp());
}

class DTNMessengerApp extends StatelessWidget {
  const DTNMessengerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => DTNProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'DTN Messenger',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.blue,
                brightness: Brightness.light,
              ),
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.blue,
                brightness: Brightness.dark,
              ),
            ),
            themeMode: themeProvider.themeMode,
            home: const BluetoothCheckWrapper(),
          );
        },
      ),
    );
  }
}

class BluetoothCheckWrapper extends StatefulWidget {
  const BluetoothCheckWrapper({super.key});

  @override
  State<BluetoothCheckWrapper> createState() => _BluetoothCheckWrapperState();
}

class _BluetoothCheckWrapperState extends State<BluetoothCheckWrapper> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Step 1: show your existing Bluetooth on/off check
      BluetoothCheckDialog.show(context);

      // Step 2: request BLE permissions, then start scanning + advertising
      final granted = await BlePermissionService.requestAll(context);
      if (granted) {
        await ServiceLocator.dtnManager.startBle();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const HomeScreen();
  }
}