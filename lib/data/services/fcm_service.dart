import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io' show Platform;
import '../../core/utils/logger.dart';

/// FCM Service for handling push notifications
class FCMService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();
  
  String? _fcmToken;
  
  /// Get current FCM token
  String? get fcmToken => _fcmToken;
  
  /// Initialize FCM
  Future<void> initialize() async {
    try {
      // Setup local notifications (Android)
      await _setupLocalNotifications();
      
      // Request permission (iOS & Android 13+)
      await requestPermission();
      
      // Get FCM token
      await getToken();
      
      // Listen for token refresh
      _messaging.onTokenRefresh.listen((newToken) {
        logger.i('FCM token refreshed: $newToken');
        _fcmToken = newToken;
        // TODO: Update token in Firestore via callback
      });
      
      // Setup message handlers
      await setupMessageHandlers();
      
      logger.i('FCM initialized successfully');
    } catch (e) {
      logger.e('Failed to initialize FCM', error: e);
    }
  }
  
  /// Setup local notifications (for Android foreground notifications)
  Future<void> _setupLocalNotifications() async {
    if (!kIsWeb && Platform.isAndroid) {
      // Create notification channel for Android 8.0+
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'cg_calendar_reminders', // Must match AndroidManifest.xml
        'CG Calendar Reminders',
        description: 'Notifications for event reminders',
        importance: Importance.high,
        enableVibration: true,
        playSound: true,
      );
      
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
      
      // Initialize plugin
      const AndroidInitializationSettings androidSettings = 
          AndroidInitializationSettings('@mipmap/ic_launcher');
      
      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
      );
      
      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          logger.i('Local notification tapped: ${response.payload}');
          // TODO: Handle notification tap
        },
      );
      
      logger.i('Local notifications initialized');
    }
  }
  
  /// Request notification permission
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
    
    logger.i('Notification permission status: ${settings.authorizationStatus}');
    
    return settings;
  }
  
  /// Get FCM token
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
  
  /// Setup message handlers
  Future<void> setupMessageHandlers() async {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      logger.i('Foreground message received');
      _handleMessage(message);
    });
    
    // Handle background message tap
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      logger.i('Background message opened');
      _handleMessageTap(message);
    });
    
    // Handle terminated state message tap
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      logger.i('Terminated message opened');
      _handleMessageTap(initialMessage);
    }
  }
  
  /// Handle received message (foreground)
  void _handleMessage(RemoteMessage message) {
    logger.i('Message data: ${message.data}');
    
    if (message.notification != null) {
      logger.i('Message notification: ${message.notification!.title}');
      
      // Show local notification on Android (foreground)
      if (!kIsWeb && Platform.isAndroid) {
        _showLocalNotification(message);
      }
      
      // Log for debugging
      if (kDebugMode) {
        print('📬 Notification: ${message.notification!.title}');
        print('   ${message.notification!.body}');
      }
    }
  }
  
  /// Show local notification (Android foreground)
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'cg_calendar_reminders',
      'CG Calendar Reminders',
      channelDescription: 'Notifications for event reminders',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      enableVibration: true,
      playSound: true,
    );
    
    const NotificationDetails details = NotificationDetails(android: androidDetails);
    
    await _localNotifications.show(
      message.hashCode,
      notification.title,
      notification.body,
      details,
      payload: message.data['eventId'],
    );
  }
  
  /// Handle message tap (background/terminated)
  void _handleMessageTap(RemoteMessage message) {
    logger.i('Message tapped: ${message.data}');
    
    final type = message.data['type'];
    final eventId = message.data['eventId'];
    
    if (type == 'reminder' && eventId != null) {
      logger.i('Opening event: $eventId');
      // TODO: Navigate to event details via callback
      // Can use a GlobalKey<NavigatorState> or event bus
    }
  }
  
  /// Delete FCM token (on logout)
  Future<void> deleteToken() async {
    try {
      await _messaging.deleteToken();
      _fcmToken = null;
      logger.i('FCM token deleted');
    } catch (e) {
      logger.e('Error deleting FCM token', error: e);
    }
  }
  
  /// Subscribe to topic
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
      logger.i('Subscribed to topic: $topic');
    } catch (e) {
      logger.e('Error subscribing to topic', error: e);
    }
  }
  
  /// Unsubscribe from topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
      logger.i('Unsubscribed from topic: $topic');
    } catch (e) {
      logger.e('Error unsubscribing from topic', error: e);
    }
  }
}

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // This function runs in its own isolate
  // Cannot access app state or UI
  logger.i('Background message: ${message.messageId}');
  
  if (message.notification != null) {
    logger.i('Background notification: ${message.notification!.title}');
  }
}
