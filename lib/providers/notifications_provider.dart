import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/notification_model.dart';
import 'repositories_providers.dart';
import 'auth_provider.dart';

/// Stream provider for notifications (real-time)
final notificationsStreamProvider = StreamProvider.autoDispose<List<NotificationModel>>((ref) {
  final notificationRepository = ref.watch(notificationRepositoryProvider);
  final userProfileAsync = ref.watch(currentUserProfileProvider);

  final user = userProfileAsync.asData?.value;
  if (user == null) {
    return Stream.value([]);
  }

  return notificationRepository.streamNotifications(user.id);
});

/// Stream provider for unread notifications only
final unreadNotificationsStreamProvider = StreamProvider.autoDispose<List<NotificationModel>>((ref) {
  final notificationRepository = ref.watch(notificationRepositoryProvider);
  final userProfileAsync = ref.watch(currentUserProfileProvider);

  final user = userProfileAsync.asData?.value;
  if (user == null) {
    return Stream.value([]);
  }

  return notificationRepository.streamUnreadNotifications(user.id);
});

/// Provider for unread notifications count
final unreadNotificationsCountProvider = StreamProvider.autoDispose<int>((ref) {
  final unreadNotifications = ref.watch(unreadNotificationsStreamProvider);

  return unreadNotifications.when(
    data: (notifications) => Stream.value(notifications.length),
    loading: () => Stream.value(0),
    error: (_, __) => Stream.value(0),
  );
});

/// Provider to mark notification as read
final markNotificationAsReadProvider = FutureProvider.family<void, String>((ref, notificationId) {
  final notificationRepository = ref.watch(notificationRepositoryProvider);
  return notificationRepository.markAsRead(notificationId);
});

/// Provider to mark all notifications as read
final markAllNotificationsAsReadProvider = FutureProvider.autoDispose<void>((ref) async {
  final notificationRepository = ref.watch(notificationRepositoryProvider);
  final userProfileAsync = ref.watch(currentUserProfileProvider);

  final user = userProfileAsync.asData?.value;
  if (user == null) return;

  await notificationRepository.markAllAsRead(user.id);
  
  // Invalidate to refresh
  ref.invalidate(notificationsStreamProvider);
  ref.invalidate(unreadNotificationsStreamProvider);
});

/// Provider for notifications by type
final notificationsByTypeProvider = StreamProvider.autoDispose.family<List<NotificationModel>, NotificationType>(
  (ref, type) {
    final notificationRepository = ref.watch(notificationRepositoryProvider);
    final userProfileAsync = ref.watch(currentUserProfileProvider);

    final user = userProfileAsync.asData?.value;
    if (user == null) {
      return Stream.value([]);
    }

    return notificationRepository.streamNotificationsByType(user.id, type);
  },
);

/// Provider to create a notification (for testing or manual creation)
final createNotificationProvider = FutureProvider.family<String, NotificationModel>((ref, notification) {
  final notificationRepository = ref.watch(notificationRepositoryProvider);
  return notificationRepository.createNotification(notification);
});

/// Provider to delete a notification
final deleteNotificationProvider = FutureProvider.family<void, String>((ref, notificationId) {
  final notificationRepository = ref.watch(notificationRepositoryProvider);
  return notificationRepository.deleteNotification(notificationId);
});
