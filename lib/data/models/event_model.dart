import 'package:freezed_annotation/freezed_annotation.dart';
import '../../core/utils/firestore_helpers.dart';

part 'event_model.freezed.dart';
part 'event_model.g.dart';

@freezed
class EventModel with _$EventModel {
  const factory EventModel({
    required String id,
    required String title,
    String? description,
    required DateTime startTime,
    required DateTime endTime,
    String? location,
    required List<String> artistIds, // Multiple artists can be assigned
    required String eventTypeId,
    @Default([]) List<ChecklistItem> checklistItems,
    @Default({}) Map<String, dynamic> customFields,
    @Default([]) List<EventLink> links,
    String? notes,
    EventFinance? finance, // Finance/Budget data
    @Default(false) bool isAllDay,
    required String createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _EventModel;

  factory EventModel.fromJson(Map<String, dynamic> json) =>
      _$EventModelFromJson(json);
}

/// Checklist item that can be checked off
@freezed
class ChecklistItem with _$ChecklistItem {
  const factory ChecklistItem({
    required String id,
    required String title,
    @Default(false) bool isCompleted,
    DateTime? completedAt,
    String? completedBy,
  }) = _ChecklistItem;

  factory ChecklistItem.fromJson(Map<String, dynamic> json) =>
      _$ChecklistItemFromJson(json);
}

/// Link to external resources (Drive, etc.)
@freezed
class EventLink with _$EventLink {
  const factory EventLink({
    required String id,
    required String title,
    required String url,
    String? type, // 'drive', 'other'
  }) = _EventLink;

  factory EventLink.fromJson(Map<String, dynamic> json) =>
      _$EventLinkFromJson(json);
}

/// Finance/Budget tracking for events
@freezed
class EventFinance with _$EventFinance {
  const factory EventFinance({
    @Default(0) double revenue, // Doanh thu
    @Default([]) List<ExpenseItem> expenses, // Chi phí
  }) = _EventFinance;

  factory EventFinance.fromJson(Map<String, dynamic> json) =>
      _$EventFinanceFromJson(json);
}

/// Extension for EventFinance Firestore conversion
extension EventFinanceFirestoreX on EventFinance {
  Map<String, dynamic> toFirestore() {
    return {
      'revenue': revenue,
      'expenses': expenses.map((e) => e.toJson()).toList(),
    };
  }

  static EventFinance fromFirestore(Map<String, dynamic> data) {
    return EventFinance(
      revenue: (data['revenue'] as num?)?.toDouble() ?? 0,
      expenses: (data['expenses'] as List?)
              ?.map((e) => ExpenseItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

/// Individual expense item
@freezed
class ExpenseItem with _$ExpenseItem {
  const factory ExpenseItem({
    required String id,
    required String name,
    required double amount,
  }) = _ExpenseItem;

  factory ExpenseItem.fromJson(Map<String, dynamic> json) =>
      _$ExpenseItemFromJson(json);
}

/// Extension for EventFinance calculations
extension EventFinanceX on EventFinance {
  /// Total expenses
  double get totalExpenses => expenses.fold(0, (sum, item) => sum + item.amount);
  
  /// Net income (revenue - expenses)
  double get netIncome => revenue - totalExpenses;
}

/// Extension for Firestore conversion
extension EventModelX on EventModel {
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'location': location,
      'artistIds': artistIds,
      'eventTypeId': eventTypeId,
      'checklistItems': checklistItems.map((e) => e.toJson()).toList(),
      'customFields': customFields,
      'links': links.map((e) => e.toJson()).toList(),
      'notes': notes,
      'finance': finance != null ? EventFinanceFirestoreX(finance!).toFirestore() : null,
      'isAllDay': isAllDay,
      'createdBy': createdBy,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  static EventModel fromFirestore(Map<String, dynamic> data, String id) {
    return EventModel(
      id: id,
      title: data['title'] as String,
      description: data['description'] as String?,
      startTime: FirestoreHelpers.toDateTime(data['startTime']) ?? DateTime.now(),
      endTime: FirestoreHelpers.toDateTime(data['endTime']) ?? DateTime.now(),
      location: data['location'] as String?,
      artistIds: List<String>.from(data['artistIds'] ?? []),
      eventTypeId: data['eventTypeId'] as String,
      checklistItems: (data['checklistItems'] as List?)
              ?.map((e) => ChecklistItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      customFields: Map<String, dynamic>.from(data['customFields'] ?? {}),
      links: (data['links'] as List?)
              ?.map((e) => EventLink.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      notes: data['notes'] as String?,
      finance: data['finance'] != null
          ? EventFinanceFirestoreX.fromFirestore(data['finance'] as Map<String, dynamic>)
          : null,
      isAllDay: (data['isAllDay'] as bool?) ?? false,
      createdBy: data['createdBy'] as String,
      createdAt: FirestoreHelpers.toDateTime(data['createdAt']),
      updatedAt: FirestoreHelpers.toDateTime(data['updatedAt']),
    );
  }
}

