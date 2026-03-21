import 'package:freezed_annotation/freezed_annotation.dart';
import '../../core/utils/firestore_helpers.dart';

part 'notification_model.freezed.dart';
part 'notification_model.g.dart';

/// Types of notifications
enum NotificationType {
  eventReminder,
  taskUrgent,
  revenueUpdate,
  systemNotification;

  String get displayName {
    switch (this) {
      case NotificationType.eventReminder:
        return 'Nhắc nhở sự kiện';
      case NotificationType.taskUrgent:
        return 'Công việc gấp';
      case NotificationType.revenueUpdate:
        return 'Cập nhật doanh thu';
      case NotificationType.systemNotification:
        return 'Thông báo hệ thống';
    }
  }

  String toFirestore() {
    switch (this) {
      case NotificationType.eventReminder:
        return 'event_reminder';
      case NotificationType.taskUrgent:
        return 'task_urgent';
      case NotificationType.revenueUpdate:
        return 'revenue_update';
      case NotificationType.systemNotification:
        return 'system_notification';
    }
  }

  static NotificationType fromString(String value) {
    switch (value) {
      case 'event_reminder':
        return NotificationType.eventReminder;
      case 'task_urgent':
        return NotificationType.taskUrgent;
      case 'revenue_update':
        return NotificationType.revenueUpdate;
      case 'system_notification':
        return NotificationType.systemNotification;
      default:
        return NotificationType.systemNotification;
    }
  }
}

/// Notification Model
@freezed
class NotificationModel with _$NotificationModel {
  const factory NotificationModel({
    required String id,
    required String userId, // Người nhận
    required String title,
    required String body,
    required NotificationType type,
    String? relatedId, // eventId, taskId, etc.
    @Default(false) bool isRead,
    DateTime? createdAt,
  }) = _NotificationModel;

  factory NotificationModel.fromJson(Map<String, dynamic> json) =>
      _$NotificationModelFromJson(json);
}

/// Extension for Firestore conversion
extension NotificationModelX on NotificationModel {
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'title': title,
      'body': body,
      'type': type.toFirestore(),
      'relatedId': relatedId,
      'isRead': isRead,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  static NotificationModel fromFirestore(Map<String, dynamic> data, String id) {
    return NotificationModel(
      id: id,
      userId: data['userId'] as String,
      title: data['title'] as String,
      body: data['body'] as String,
      type: NotificationType.fromString(data['type'] as String? ?? 'system_notification'),
      relatedId: data['relatedId'] as String?,
      isRead: data['isRead'] as bool? ?? false,
      createdAt: FirestoreHelpers.toDateTime(data['createdAt']),
    );
  }
}
