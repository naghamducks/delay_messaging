import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'providers/theme_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/dtn_provider.dart';
import 'widgets/bluetooth_check_dialog.dart';

void main() {
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

/// Wrapper to check Bluetooth on app start
class BluetoothCheckWrapper extends StatefulWidget {
  const BluetoothCheckWrapper({super.key});

  @override
  State<BluetoothCheckWrapper> createState() => _BluetoothCheckWrapperState();
}

class _BluetoothCheckWrapperState extends State<BluetoothCheckWrapper> {
  @override
  void initState() {
    super.initState();
    // Check Bluetooth after first frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      BluetoothCheckDialog.show(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return const HomeScreen();
  }
}
