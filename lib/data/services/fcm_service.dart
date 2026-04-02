import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io' show Platform;
import '../../core/utils/logger.dart';

@pragma('vm:entry-point')
void onFcmNotificationTapBackground(NotificationResponse response) {
  // Intentionally minimal — no Flutter context available in background isolate
}

class FCMService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  String? _fcmToken;

  // ✅ THÊM MỚI: callback để AuthNotifier lắng nghe khi token refresh.
  // AuthNotifier sẽ inject hàm này sau khi login thành công.
  // Khi Firebase refresh token, listener bên dưới sẽ gọi callback này
  // để AuthNotifier tự động cập nhật Firestore (xóa token cũ, thêm token mới).
  Future<void> Function(String newToken, String? oldToken)? onTokenChanged;

  String? get fcmToken => _fcmToken;

  Future<void> initialize() async {
    try {
      await _setupLocalNotifications();

      if (!kIsWeb && Platform.isIOS) {
        await FirebaseMessaging.instance
            .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      }

      await requestPermission();
      await getToken();

      // ✅ SỬA: onTokenRefresh listener đúng cách.
      // Lưu token cũ → cập nhật _fcmToken → gọi callback ra ngoài.
      // AuthNotifier (được inject qua onTokenChanged) sẽ xử lý Firestore.
      _messaging.onTokenRefresh.listen((newToken) async {
        logger.i('FCM token refreshed: ${newToken.substring(0, 20)}...');
        final oldToken = _fcmToken; // lưu token cũ trước khi ghi đè
        _fcmToken = newToken;
        await onTokenChanged?.call(newToken, oldToken);
      });

      await setupMessageHandlers();

      logger.i('FCM initialized successfully');
    } catch (e) {
      logger.e('Failed to initialize FCM', error: e);
    }
  }

  Future<void> _setupLocalNotifications() async {
    if (kIsWeb) return;

    if (Platform.isAndroid) {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'cg_calendar_reminders_v2',
        'CG Calendar Reminders',
        description: 'Nhắc nhở sự kiện từ CG Calendar',
        importance: Importance.max,
        enableVibration: true,
        playSound: true,
      );
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _localNotifications.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
      ),
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        logger.i('Local notification tapped: ${response.payload}');
      },
      onDidReceiveBackgroundNotificationResponse:
          onFcmNotificationTapBackground,
    );

    logger.i('Local notifications initialized');
  }

  Future<NotificationSettings> requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    logger.i(
        'Notification permission status: ${settings.authorizationStatus}');
    return settings;
  }

  Future<String?> getToken() async {
    try {
      _fcmToken = await _messaging.getToken();
      if (_fcmToken != null) {
        logger.i('FCM token obtained: ${_fcmToken!.substring(0, 20)}...');
      } else {
        logger.w('Failed to get FCM token');
      }
      return _fcmToken;
    } catch (e) {
      logger.e('Error getting FCM token', error: e);
      return null;
    }
  }

  Future<void> setupMessageHandlers() async {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      logger.i('Foreground message received');
      _handleMessage(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      logger.i('Background message opened');
      _handleMessageTap(message);
    });

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      logger.i('Terminated message opened');
      _handleMessageTap(initialMessage);
    }
  }

  void _handleMessage(RemoteMessage message) {
    logger.i('Message data: ${message.data}');
    if (message.notification != null) {
      logger.i('Message notification: ${message.notification!.title}');
      if (!kIsWeb) {
        _showLocalNotification(message);
      }
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    const androidDetails = AndroidNotificationDetails(
      'cg_calendar_reminders_v2',
      'CG Calendar Reminders',
      channelDescription: 'Nhắc nhở sự kiện từ CG Calendar',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      enableVibration: true,
      playSound: true,
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _localNotifications.show(
      message.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
          android: androidDetails, iOS: darwinDetails, macOS: darwinDetails),
      payload: message.data['eventId'],
    );
  }

  void _handleMessageTap(RemoteMessage message) {
    logger.i('Message tapped: ${message.data}');
    final type = message.data['type'];
    final eventId = message.data['eventId'];
    if (type == 'reminder' && eventId != null) {
      logger.i('Opening event: $eventId');
    }
  }

  Future<void> deleteToken() async {
    try {
      await _messaging.deleteToken();
      _fcmToken = null;
      logger.i('FCM token deleted');
    } catch (e) {
      logger.e('Error deleting FCM token', error: e);
    }
  }

  Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
      logger.i('Subscribed to topic: $topic');
    } catch (e) {
      logger.e('Error subscribing to topic', error: e);
    }
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
      logger.i('Unsubscribed from topic: $topic');
    } catch (e) {
      logger.e('Error unsubscribing from topic', error: e);
    }
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  logger.i('Background message: ${message.messageId}');
  if (message.notification != null) {
    logger.i('Background notification: ${message.notification!.title}');
  }
}