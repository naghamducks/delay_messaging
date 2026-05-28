import 'package:delay_messenger/services/service_locator.dart';
import 'package:delay_messenger/services/node_identity.dart';
import 'package:delay_messenger/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'providers/theme_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/dtn_provider.dart';
import 'widgets/bluetooth_check_dialog.dart';
import 'services/ble_permission_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await ServiceLocator.init();
  await NotificationService.init();
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
            title: 'ReachOut',
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
            home: const _AppStartup(),
          );
        },
      ),
    );
  }
}

class _AppStartup extends StatefulWidget {
  const _AppStartup();

  @override
  State<_AppStartup> createState() => _AppStartupState();
}

class _AppStartupState extends State<_AppStartup> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      // Wire DTNProvider ↔ ChatProvider so chat names update when peer names arrive
      final dtnProvider  = context.read<DTNProvider>();
      final chatProvider = context.read<ChatProvider>();
      dtnProvider.setChatProvider(chatProvider);

      // Wire notification callbacks into DtnManager
      ServiceLocator.dtnManager.onMessageDelivered = (msg) {
        // Let ChatProvider handle UI update
        chatProvider.handleDeliveredMessage(msg);

        // Fire notification
        final senderName = dtnProvider.peerDisplayName(msg.source);
        final isSOSMessage = msg.priority > 5;
        final content = msg.payload.contains('|')
            ? msg.payload.split('|').first
            : msg.payload;
        NotificationService.showMessageNotification(
          senderName: senderName,
          content: content,
          isSOSMessage: isSOSMessage,
        );
      };

      // Wire relay notification
      ServiceLocator.dtnManager.onMessageRelayed = (msg, toPeerId) {
        final fromName = dtnProvider.peerDisplayName(msg.source);
        final toName   = dtnProvider.peerDisplayName(toPeerId);
        NotificationService.showRelayNotification(
          fromName: fromName,
          toName: toName,
        );
      };

      // First-launch: prompt for display name
      if (NodeIdentity.needsDisplayName) {
        await _showNameDialog();
      }

      if (!mounted) return;

      // Bluetooth check
      await BluetoothCheckDialog.show(context);
      if (!mounted) return;

      // Request permissions
      await BlePermissionService.requestAll(context);
    });
  }

  Future<void> _showNameDialog() async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.person_outline, size: 48, color: Colors.blue),
        title: const Text('Welcome to ReachOut'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Choose a display name so nearby users can identify you.',
                style: TextStyle(height: 1.4),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Your name',
                  hintText: 'e.g. Ahmed, Field Unit 2',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
                autofocus: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Skip'),
          ),
          FilledButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                await NodeIdentity.setDisplayName(controller.text.trim());
              }
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => const HomeScreen();
}