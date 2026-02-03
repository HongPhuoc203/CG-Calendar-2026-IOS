import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Script to check pending notifications
void main() async {
  // Initialize timezone
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));
  
  // Initialize notifications
  final FlutterLocalNotificationsPlugin notifications = 
      FlutterLocalNotificationsPlugin();
  
  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  
  const InitializationSettings initSettings = InitializationSettings(
    android: androidSettings,
  );
  
  await notifications.initialize(initSettings);
  
  // Get pending notifications
  final List<PendingNotificationRequest> pending = 
      await notifications.pendingNotificationRequests();
  
  print('\n📋 PENDING NOTIFICATIONS: ${pending.length}');
  print('=' * 60);
  
  if (pending.isEmpty) {
    print('⚠️  No pending notifications found!');
    print('\nPossible reasons:');
    print('  1. No events with reminders have been created yet');
    print('  2. All reminder times are in the past');
    print('  3. Notifications were not scheduled properly');
  } else {
    for (var i = 0; i < pending.length; i++) {
      final notif = pending[i];
      print('\n${i + 1}. Notification ID: ${notif.id}');
      print('   Title: ${notif.title}');
      print('   Body: ${notif.body}');
      print('   Payload: ${notif.payload}');
    }
  }
  
  print('\n' + '=' * 60);
}
