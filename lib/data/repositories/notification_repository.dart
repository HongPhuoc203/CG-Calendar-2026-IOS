import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_model.dart';
import '../services/firestore_service.dart';
import '../../core/constants/app_constants.dart';
import '../../core/errors/failures.dart';

/// Repository for notification operations
class NotificationRepository {
  final FirestoreService _firestoreService;

  NotificationRepository(this._firestoreService);

  /// Stream notifications for a user (real-time updates)
  Stream<List<NotificationModel>> streamNotifications(String userId) {
    return _firestoreService.streamCollection(
      AppConstants.notificationsCollection,
      queryBuilder: (ref) => ref
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(50), // Limit to recent 50 notifications
    ).map((snapshot) {
      return snapshot.docs
          .map((doc) => NotificationModelX.fromFirestore(doc.data(), doc.id))
          .toList();
    });
  }

  /// Get unread notifications count
  Future<int> getUnreadCount(String userId) async {
    try {
      final snapshot = await _firestoreService.getCollection(
        AppConstants.notificationsCollection,
        queryBuilder: (ref) => ref
            .where('userId', isEqualTo: userId)
            .where('isRead', isEqualTo: false),
      );

      return snapshot.docs.length;
    } catch (e) {
      throw FirestoreFailure('Lỗi lấy số thông báo chưa đọc: $e');
    }
  }

  /// Get unread notifications only
  Stream<List<NotificationModel>> streamUnreadNotifications(String userId) {
    return _firestoreService.streamCollection(
      AppConstants.notificationsCollection,
      queryBuilder: (ref) => ref
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .orderBy('createdAt', descending: true),
    ).map((snapshot) {
      return snapshot.docs
          .map((doc) => NotificationModelX.fromFirestore(doc.data(), doc.id))
          .toList();
    });
  }

  /// Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestoreService.updateDocument(
        AppConstants.notificationsCollection,
        notificationId,
        {
          'isRead': true,
        },
      );
    } catch (e) {
      throw FirestoreFailure('Lỗi đánh dấu đã đọc: $e');
    }
  }

  /// Mark all notifications as read for a user
  Future<void> markAllAsRead(String userId) async {
    try {
      // Get all unread notifications
      final snapshot = await _firestoreService.getCollection(
        AppConstants.notificationsCollection,
        queryBuilder: (ref) => ref
            .where('userId', isEqualTo: userId)
            .where('isRead', isEqualTo: false),
      );

      // Batch update
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();
    } catch (e) {
      throw FirestoreFailure('Lỗi đánh dấu tất cả đã đọc: $e');
    }
  }

  /// Create notification (typically called by Cloud Functions or FCM)
  Future<String> createNotification(NotificationModel notification) async {
    try {
      final data = notification.toFirestore();
      data['createdAt'] = DateTime.now().toIso8601String();

      return await _firestoreService.createDocument(
        AppConstants.notificationsCollection,
        data,
      );
    } catch (e) {
      throw FirestoreFailure('Lỗi tạo thông báo: $e');
    }
  }

  /// Delete notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _firestoreService.deleteDocument(
        AppConstants.notificationsCollection,
        notificationId,
      );
    } catch (e) {
      throw FirestoreFailure('Lỗi xóa thông báo: $e');
    }
  }

  /// Delete all read notifications for a user (cleanup)
  Future<void> deleteAllReadNotifications(String userId) async {
    try {
      final snapshot = await _firestoreService.getCollection(
        AppConstants.notificationsCollection,
        queryBuilder: (ref) => ref
            .where('userId', isEqualTo: userId)
            .where('isRead', isEqualTo: true),
      );

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    } catch (e) {
      throw FirestoreFailure('Lỗi xóa thông báo đã đọc: $e');
    }
  }

  /// Get notifications by type
  Stream<List<NotificationModel>> streamNotificationsByType(
    String userId,
    NotificationType type,
  ) {
    return _firestoreService.streamCollection(
      AppConstants.notificationsCollection,
      queryBuilder: (ref) => ref
          .where('userId', isEqualTo: userId)
          .where('type', isEqualTo: type.toFirestore())
          .orderBy('createdAt', descending: true)
          .limit(20),
    ).map((snapshot) {
      return snapshot.docs
          .map((doc) => NotificationModelX.fromFirestore(doc.data(), doc.id))
          .toList();
    });
  }
}
