import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/services/auth_service.dart';
import '../data/services/firestore_service.dart';
import '../data/services/fcm_service.dart';
import '../data/services/local_notification_scheduler.dart';
import '../data/services/reminder_sync_service.dart';

/// Provider for AuthService
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

/// Provider for FirestoreService
final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService();
});

/// Provider for FCMService
final fcmServiceProvider = Provider<FCMService>((ref) {
  return FCMService();
});

/// Provider for LocalNotificationScheduler
final localNotificationSchedulerProvider = Provider<LocalNotificationScheduler>((ref) {
  return LocalNotificationScheduler();
});

/// Provider for ReminderSyncService.
/// Singleton per app session — holds the Firestore stream subscription.
final reminderSyncServiceProvider = Provider<ReminderSyncService>((ref) {
  final service = ReminderSyncService();
  ref.onDispose(() => service.stopListening());
  return service;
});