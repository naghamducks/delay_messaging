import 'dart:ui';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Handles local notifications for incoming messages and SOS alerts.
class NotificationService {
  static const _keyNotifMessages = 'notif_messages';
  static const _keyNotifRelay    = 'notif_relay';

  static const _channelMessageId   = 'dtn_messages';
  static const _channelSosId       = 'dtn_sos';
  static const _channelRelayId     = 'dtn_relay';

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  /// Call once at app startup before any notification is shown.
  static Future<void> init() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );

    // Create Android notification channels
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await android?.createNotificationChannel(const AndroidNotificationChannel(
      _channelMessageId,
      'Messages',
      description: 'Incoming DTN messages',
      importance: Importance.high,
    ));

    await android?.createNotificationChannel(const AndroidNotificationChannel(
      _channelSosId,
      'SOS Alerts',
      description: 'Emergency SOS messages',
      importance: Importance.max,
      sound: RawResourceAndroidNotificationSound('notification_sos'),
      enableVibration: true,
    ));

    await android?.createNotificationChannel(const AndroidNotificationChannel(
      _channelRelayId,
      'Relay Activity',
      description: 'Messages relayed through this device',
      importance: Importance.low,
    ));

    _initialized = true;
  }

  /// Show a notification for a received message.
  static Future<void> showMessageNotification({
    required String senderName,
    required String content,
    required bool isSOSMessage,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // SOS always notifies regardless of settings
    if (!isSOSMessage) {
      final enabled = prefs.getBool(_keyNotifMessages) ?? true;
      if (!enabled) return;
    }

    if (isSOSMessage) {
      await _plugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        '🆘 SOS from $senderName',
        content,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelSosId,
            'SOS Alerts',
            channelDescription: 'Emergency SOS messages',
            importance: Importance.max,
            priority: Priority.max,
            color: Color(0xFFD32F2F),
            enableVibration: true,
            playSound: true,
            icon: '@mipmap/ic_launcher',
            styleInformation: BigTextStyleInformation(''),
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            interruptionLevel: InterruptionLevel.critical,
          ),
        ),
      );
    } else {
      await _plugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'Message from $senderName',
        content,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelMessageId,
            'Messages',
            channelDescription: 'Incoming DTN messages',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );
    }
  }

  /// Show a notification when this device relays a message for someone else.
  static Future<void> showRelayNotification({
    required String fromName,
    required String toName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_keyNotifRelay) ?? false;
    if (!enabled) return;

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'Message relayed',
      'Forwarded a message from $fromName → $toName',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelRelayId,
          'Relay Activity',
          channelDescription: 'Messages relayed through this device',
          importance: Importance.low,
          priority: Priority.low,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: false,
          presentBadge: true,
          presentSound: false,
        ),
      ),
    );
  }
}
