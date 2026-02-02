import 'package:freezed_annotation/freezed_annotation.dart';
import '../../core/utils/firestore_helpers.dart';

part 'notification_job_model.freezed.dart';
part 'notification_job_model.g.dart';

/// Notification job created by Cloud Functions to schedule push notifications
@freezed
class NotificationJobModel with _$NotificationJobModel {
  const factory NotificationJobModel({
    required String id,
    required String reminderId,
    required String eventId,
    required String eventTitle,
    required DateTime eventStartTime,
    required String recipientUserId,
    required DateTime scheduledTime,
    @Default('pending') String status, // pending, sent, failed
    String? errorMessage,
    DateTime? sentAt,
    DateTime? createdAt,
  }) = _NotificationJobModel;

  factory NotificationJobModel.fromJson(Map<String, dynamic> json) =>
      _$NotificationJobModelFromJson(json);
}

/// Extension for Firestore conversion
extension NotificationJobModelX on NotificationJobModel {
  Map<String, dynamic> toFirestore() {
    return {
      'reminderId': reminderId,
      'eventId': eventId,
      'eventTitle': eventTitle,
      'eventStartTime': eventStartTime.toIso8601String(),
      'recipientUserId': recipientUserId,
      'scheduledTime': scheduledTime.toIso8601String(),
      'status': status,
      'errorMessage': errorMessage,
      'sentAt': sentAt?.toIso8601String(),
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  static NotificationJobModel fromFirestore(
      Map<String, dynamic> data, String id) {
    return NotificationJobModel(
      id: id,
      reminderId: data['reminderId'] as String,
      eventId: data['eventId'] as String,
      eventTitle: data['eventTitle'] as String,
      eventStartTime: FirestoreHelpers.toDateTime(data['eventStartTime']) ?? DateTime.now(),
      recipientUserId: data['recipientUserId'] as String,
      scheduledTime: FirestoreHelpers.toDateTime(data['scheduledTime']) ?? DateTime.now(),
      status: data['status'] as String? ?? 'pending',
      errorMessage: data['errorMessage'] as String?,
      sentAt: FirestoreHelpers.toDateTime(data['sentAt']),
      createdAt: FirestoreHelpers.toDateTime(data['createdAt']),
    );
  }
}

