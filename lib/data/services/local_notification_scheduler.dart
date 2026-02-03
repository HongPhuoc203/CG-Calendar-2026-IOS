import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import '../../core/utils/logger.dart';
import '../models/event_model.dart';
import '../models/reminder_model.dart';

/// Service để schedule local notifications (không cần Cloud Functions)
class LocalNotificationScheduler {
  final FlutterLocalNotificationsPlugin _notifications = 
      FlutterLocalNotificationsPlugin();
  
  /// Initialize local notifications
  Future<void> initialize() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
    );
    
    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
    
    logger.i('Local notification scheduler initialized');
    
    // Check exact alarm permission for Android 12+
    await checkExactAlarmPermission();
  }
  
  /// Check if exact alarm permission is granted (Android 12+)
  Future<bool> checkExactAlarmPermission() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final bool? canScheduleExactAlarms = await _notifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.canScheduleExactNotifications();
        
        if (canScheduleExactAlarms == false) {
          logger.w('⚠️  Exact alarm permission not granted');
          logger.w('   Please enable "Alarms & reminders" permission in app settings');
          
          // Request permission
          await _notifications
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()
              ?.requestExactAlarmsPermission();
          
          return false;
        }
        
        logger.i('✅ Exact alarm permission granted');
        return true;
      } catch (e) {
        logger.e('Error checking exact alarm permission', error: e);
        return false;
      }
    }
    return true;
  }
  
  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    logger.i('Notification tapped: ${response.payload}');
    // TODO: Navigate to event details
    // Can use GlobalKey<NavigatorState> or event bus
  }
  
  /// Schedule notification for an event reminder
  Future<void> scheduleReminderNotification({
    required EventModel event,
    required ReminderModel reminder,
  }) async {
    try {
      // Calculate trigger time
      final triggerTime = tz.TZDateTime.from(
        reminder.triggerTime,
        tz.local,
      );
      
      // Check if trigger time is in the future
      if (triggerTime.isBefore(tz.TZDateTime.now(tz.local))) {
        logger.w('Reminder trigger time is in the past, skipping');
        return;
      }
      
      // Create notification details
      final androidDetails = AndroidNotificationDetails(
        'cg_calendar_reminders',
        'CG Calendar Reminders',
        channelDescription: 'Notifications for event reminders',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        enableVibration: true,
        playSound: true,
      );
      
      final notificationDetails = NotificationDetails(
        android: androidDetails,
      );
      
      // Get reminder time label from ReminderModel extension
      final reminderLabel = ReminderModelX(reminder).displayText;
      
      // Schedule notification
      await _notifications.zonedSchedule(
        reminder.id.hashCode, // Unique ID from reminder ID
        '🔔 Nhắc nhở sự kiện',
        '${event.title} - $reminderLabel',
        triggerTime,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: event.id, // Pass event ID for navigation
      );
      
      logger.i('Scheduled local notification for event: ${event.title}');
      logger.i('Trigger time: $triggerTime');
    } catch (e) {
      logger.e('Failed to schedule local notification', error: e);
    }
  }
  
  /// Schedule notifications for all reminders of an event
  Future<void> scheduleEventReminders({
    required EventModel event,
    required List<ReminderModel> reminders,
  }) async {
    for (final reminder in reminders) {
      await scheduleReminderNotification(
        event: event,
        reminder: reminder,
      );
    }
    
    logger.i('Scheduled ${reminders.length} local notifications for event: ${event.title}');
  }
  
  /// Cancel a scheduled notification
  Future<void> cancelNotification(String reminderId) async {
    await _notifications.cancel(reminderId.hashCode);
    logger.i('Cancelled notification: $reminderId');
  }
  
  /// Cancel all notifications for an event
  Future<void> cancelEventNotifications(List<String> reminderIds) async {
    for (final reminderId in reminderIds) {
      await cancelNotification(reminderId);
    }
    logger.i('Cancelled ${reminderIds.length} notifications');
  }
  
  /// Cancel all scheduled notifications
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
    logger.i('Cancelled all notifications');
  }
  
  /// Get pending notifications (for debugging)
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }
}
