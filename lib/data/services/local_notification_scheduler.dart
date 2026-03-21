import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'dart:io' show Platform;
import '../../core/utils/logger.dart';
import '../models/event_model.dart';
import '../models/reminder_model.dart';

/// Service để schedule local notifications (không cần Cloud Functions)
class LocalNotificationScheduler {
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  // Channel ID - thay đổi version khi cần force recreate
  static const String _channelId = 'cg_calendar_reminders_v2';
  static const String _channelName = 'CG Calendar Reminders';
  static const String _channelDesc = 'Nhắc nhở sự kiện từ CG Calendar';

  Future<void> initialize() async {
    if (kIsWeb) return;

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS / macOS: yêu cầu quyền khi initialize
    const DarwinInitializationSettings darwinSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    final InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    if (Platform.isAndroid) {
      // Tạo notification channel (Android 8+)
      await _createNotificationChannel();
      // Request notification permission (Android 13+)
      await _requestPermissions();
      // Check exact alarm permission (Android 12+)
      await _checkExactAlarmPermission();
    } else if (Platform.isIOS || Platform.isMacOS) {
      await _requestiOSPermissions();
    }

    // Log pending notifications for debugging
    await _logPendingNotifications();

    logger.i('✅ Local notification scheduler initialized');
  }

  /// Tạo notification channel rõ ràng để đảm bảo Importance.max
  Future<void> _createNotificationChannel() async {
    if (!Platform.isAndroid) return;
    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return;

    // Xóa channel cũ nếu còn tồn tại (để force recreate với settings đúng)
    try {
      await androidPlugin.deleteNotificationChannel('cg_calendar_reminders');
      logger.i('🗑️ Deleted old notification channel');
    } catch (_) {}

    // Tạo channel mới với Importance.max
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.max,
      enableVibration: true,
      playSound: true,
      showBadge: true,
    );
    await androidPlugin.createNotificationChannel(channel);
    logger.i('✅ Created notification channel: $_channelId (Importance.max)');
  }

  /// Request POST_NOTIFICATIONS permission (Android 13+ / API 33+)
  Future<void> _requestPermissions() async {
    if (!kIsWeb && Platform.isAndroid) {
      final androidPlugin = _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      final granted = await androidPlugin?.requestNotificationsPermission();
      logger.i('Notification permission granted: $granted');
    }
  }

  /// Request notification permissions on iOS / macOS. Returns true if granted, false if denied, null if N/A or error.
  Future<bool?> _requestiOSPermissions() async {
    try {
      final iosPlugin = _notifications
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      final macPlugin = _notifications
          .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin>();

      bool? granted;
      if (Platform.isIOS) {
        granted = await iosPlugin?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
          critical: false,
        );
      } else if (Platform.isMacOS) {
        granted = await macPlugin?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
      }
      logger.i('iOS/macOS notification permission granted: $granted');
      return granted;
    } catch (e) {
      logger.e('iOS permission request failed', error: e);
      return null;
    }
  }

  Future<bool> _ensureDarwinNotificationPermission() async {
    if (kIsWeb) return false;
    try {
      final iosPlugin = _notifications
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      final macPlugin = _notifications
          .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin>();

      NotificationsEnabledOptions? current;
      if (Platform.isIOS) {
        current = await iosPlugin?.checkPermissions();
      } else if (Platform.isMacOS) {
        current = await macPlugin?.checkPermissions();
      } else {
        return true;
      }

      final alreadyEnabled = (current?.isAlertEnabled ?? false) ||
          (current?.isBadgeEnabled ?? false) ||
          (current?.isSoundEnabled ?? false) ||
          (current?.isEnabled ?? false) ||
          (current?.isProvisionalEnabled ?? false);
      if (alreadyEnabled) return true;

      await _requestiOSPermissions();

      NotificationsEnabledOptions? after;
      if (Platform.isIOS) {
        after = await iosPlugin?.checkPermissions();
      } else if (Platform.isMacOS) {
        after = await macPlugin?.checkPermissions();
      }

      return (after?.isAlertEnabled ?? false) ||
          (after?.isBadgeEnabled ?? false) ||
          (after?.isSoundEnabled ?? false) ||
          (after?.isEnabled ?? false) ||
          (after?.isProvisionalEnabled ?? false);
    } catch (e) {
      logger.e('Darwin notification permission check failed', error: e);
      return false;
    }
  }

  /// Check & request exact alarm permission (Android 12+ / API 31+)
  Future<void> _checkExactAlarmPermission() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final androidPlugin = _notifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();

        final canSchedule = await androidPlugin?.canScheduleExactNotifications();
        if (canSchedule == false) {
          logger.w('⚠️ Exact alarm permission not granted — requesting...');
          await androidPlugin?.requestExactAlarmsPermission();
        } else {
          logger.i('✅ Exact alarm permission granted');
        }
      } catch (e) {
        logger.e('Exact alarm permission check failed', error: e);
      }
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    logger.i('Notification tapped: ${response.payload}');
  }

  // ─────────────────────────────────────────────
  // Schedule một notification
  // ─────────────────────────────────────────────

  Future<void> scheduleReminderNotification({
    required EventModel event,
    required ReminderModel reminder,
  }) async {
    if (kIsWeb) return;

    try {
      // Dùng millisecondsSinceEpoch để tránh timezone ambiguity
      // DateTime.millisecondsSinceEpoch luôn là UTC epoch → chính xác
      final triggerTime = tz.TZDateTime.fromMillisecondsSinceEpoch(
        tz.local,
        reminder.triggerTime.millisecondsSinceEpoch,
      );

      final now = tz.TZDateTime.now(tz.local);

      if (triggerTime.isBefore(now)) {
        logger.w('⏭️ Skipped (past): ${event.title} @ $triggerTime');
        return;
      }

      final androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        enableVibration: true,
        playSound: true,
        visibility: NotificationVisibility.public,
        fullScreenIntent: false,
        channelShowBadge: true,
      );

      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
        macOS: darwinDetails,
      );
      final reminderLabel = ReminderModelX(reminder).displayText;

      // Format thời gian sự kiện: "14:30 hôm nay" hoặc "14:30 Thứ 2, 25/03"
      final eventTime = _formatEventTime(event.startTime);
      final locationPart = (event.location != null && event.location!.isNotEmpty)
          ? ' • ${event.location}'
          : '';
      final body = 'Bắt đầu $eventTime (còn $reminderLabel)$locationPart';

      await _notifications.zonedSchedule(
        reminder.id.hashCode.abs(),
        event.title,
        body,
        triggerTime,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: event.id,
      );

      logger.i('✅ Scheduled: "${event.title}" lúc $triggerTime (local: ${reminder.triggerTime})');
    } catch (e) {
      logger.e('❌ Failed to schedule notification: ${event.title}', error: e);
    }
  }

  // ─────────────────────────────────────────────
  // Schedule tất cả reminders của một event
  // ─────────────────────────────────────────────

  Future<void> scheduleEventReminders({
    required EventModel event,
    required List<ReminderModel> reminders,
  }) async {
    if (kIsWeb) return;

    int scheduled = 0;
    for (final reminder in reminders) {
      await scheduleReminderNotification(event: event, reminder: reminder);
      scheduled++;
    }
    logger.i('📅 Scheduled $scheduled/${reminders.length} reminders for "${event.title}"');
  }

  // ─────────────────────────────────────────────
  // Cancel
  // ─────────────────────────────────────────────

  Future<void> cancelNotification(String reminderId) async {
    if (kIsWeb) return;
    await _notifications.cancel(reminderId.hashCode.abs());
    logger.i('🗑️ Cancelled: $reminderId');
  }

  Future<void> cancelEventNotifications(List<String> reminderIds) async {
    for (final id in reminderIds) {
      await cancelNotification(id);
    }
  }

  Future<void> cancelAllNotifications() async {
    if (kIsWeb) return;
    await _notifications.cancelAll();
    logger.i('🗑️ Cancelled all notifications');
  }

  // ─────────────────────────────────────────────
  // Debug helpers
  // ─────────────────────────────────────────────

  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    if (kIsWeb) return [];
    return _notifications.pendingNotificationRequests();
  }

  Future<void> _logPendingNotifications() async {
    if (kIsWeb) return;
    final pending = await getPendingNotifications();
    logger.i('📋 Pending notifications: ${pending.length}');
    for (final n in pending) {
      logger.i('  - [${n.id}] ${n.title}: ${n.body}');
    }
  }

  // ─────────────────────────────────────────────
  // Test & Battery Optimization
  // ─────────────────────────────────────────────

  /// Gửi test notification ngay lập tức. Returns true if sent, false if permission denied (e.g. iOS).
  Future<bool> sendTestNotification() async {
    if (kIsWeb) return false;
    try {
      if (Platform.isIOS || Platform.isMacOS) {
        final canNotify = await _ensureDarwinNotificationPermission();
        if (!canNotify) return false;
      }
      final androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        enableVibration: true,
        playSound: true,
        visibility: NotificationVisibility.public,
        channelShowBadge: true,
      );
      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      );
      await _notifications.show(
        99999,
        '🔔 Test Notification',
        'Hệ thống thông báo hoạt động bình thường! ✅',
        NotificationDetails(android: androidDetails, iOS: darwinDetails, macOS: darwinDetails),
      );
      logger.i('✅ Test notification sent');
      return true;
    } catch (e) {
      logger.e('❌ Test notification failed', error: e);
      return false;
    }
  }

  /// Gửi test notification sau 1 phút. Returns true if scheduled, false if permission denied (e.g. iOS).
  Future<bool> sendScheduledTestNotification() async {
    if (kIsWeb) return false;
    try {
      if (Platform.isIOS || Platform.isMacOS) {
        final canNotify = await _ensureDarwinNotificationPermission();
        if (!canNotify) return false;
      }
      final triggerTime = tz.TZDateTime.now(tz.local).add(const Duration(minutes: 1));
      final androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        enableVibration: true,
        playSound: true,
        visibility: NotificationVisibility.public,
        channelShowBadge: true,
      );
      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      );
      await _notifications.zonedSchedule(
        99998,
        '⏰ Scheduled Test',
        'Scheduled notification hoạt động! Trigger lúc ${triggerTime.hour}:${triggerTime.minute.toString().padLeft(2, '0')}',
        triggerTime,
        NotificationDetails(android: androidDetails, iOS: darwinDetails, macOS: darwinDetails),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      logger.i('✅ Scheduled test notification at $triggerTime');
      return true;
    } catch (e) {
      logger.e('❌ Scheduled test failed', error: e);
      return false;
    }
  }

  /// Yêu cầu tắt battery optimization (chỉ Android - Samsung/Xiaomi/OPPO)
  Future<bool> requestBatteryOptimizationExemption() async {
    if (kIsWeb) return true;
    if (!Platform.isAndroid) return true; // iOS/macOS không cần
    try {
      const channel = MethodChannel('cg_calendar/battery');
      final result = await channel.invokeMethod<bool>('requestIgnoreBatteryOptimization');
      logger.i('Battery optimization exemption: $result');
      return result ?? false;
    } catch (e) {
      logger.w('Battery optimization request not available: $e');
      return false;
    }
  }

  String _formatEventTime(DateTime startTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final eventDay = DateTime(startTime.year, startTime.month, startTime.day);
    final timeStr =
        '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';

    if (eventDay == today) return '$timeStr hôm nay';
    if (eventDay == tomorrow) return '$timeStr ngày mai';

    const weekdays = ['Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7', 'CN'];
    final weekday = weekdays[startTime.weekday - 1];
    return '$timeStr $weekday, ${startTime.day}/${startTime.month}';
  }
}
