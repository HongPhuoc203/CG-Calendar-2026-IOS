import 'package:freezed_annotation/freezed_annotation.dart';
import '../../core/enums/reminder_unit.dart';
import '../../core/utils/firestore_helpers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'reminder_model.freezed.dart';
part 'reminder_model.g.dart';

@freezed
class ReminderModel with _$ReminderModel {
  const factory ReminderModel({
    required String id,
    required String eventId,
    required int value, // e.g., 1, 2, 12
    required ReminderUnit unit, // minutes, hours, days
    required List<String> recipientUserIds, // Who should receive this reminder
    required DateTime triggerTime, // Calculated time when notification should be sent
    @Default(false) bool isSent,
    DateTime? sentAt,
    DateTime? createdAt,
  }) = _ReminderModel;

  factory ReminderModel.fromJson(Map<String, dynamic> json) =>
      _$ReminderModelFromJson(json);
}

/// Extension for Firestore conversion
extension ReminderModelX on ReminderModel {
  /// Get display text for reminder (e.g., "1 giờ trước")
  String get displayText => '$value ${unit.displayName} trước';

  Map<String, dynamic> toFirestore() {
    return {
      'eventId': eventId,
      'value': value,
      'unit': unit.toFirestore(),
      'recipientUserIds': recipientUserIds,
      'triggerTime': Timestamp.fromDate(triggerTime),
      'isSent': isSent,
      'sentAt': sentAt != null ? Timestamp.fromDate(sentAt!) : null,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
    };
  }

  static ReminderModel fromFirestore(Map<String, dynamic> data, String id) {
    return ReminderModel(
      id: id,
      eventId: data['eventId'] as String,
      value: data['value'] as int,
      unit: ReminderUnit.fromString(data['unit'] as String),
      recipientUserIds: List<String>.from(data['recipientUserIds'] ?? []),
      triggerTime: FirestoreHelpers.toDateTime(data['triggerTime']) ?? DateTime.now(),
      isSent: data['isSent'] as bool? ?? false,
      sentAt: FirestoreHelpers.toDateTime(data['sentAt']),
      createdAt: FirestoreHelpers.toDateTime(data['createdAt']),
    );
  }
}

