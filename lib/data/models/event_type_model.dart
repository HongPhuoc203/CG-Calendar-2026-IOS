import 'package:freezed_annotation/freezed_annotation.dart';
import '../../core/utils/firestore_helpers.dart';

part 'event_type_model.freezed.dart';
part 'event_type_model.g.dart';

@freezed
class EventTypeModel with _$EventTypeModel {
  const factory EventTypeModel({
    required String id,
    required String name,
    String? description,
    String? iconName, // Icon identifier
    @Default([]) List<String> defaultChecklistItems,
    @Default([]) List<CustomFieldTemplate> customFieldTemplates,
    @Default(true) bool isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _EventTypeModel;

  factory EventTypeModel.fromJson(Map<String, dynamic> json) =>
      _$EventTypeModelFromJson(json);
}

/// Custom field template for event types
@freezed
class CustomFieldTemplate with _$CustomFieldTemplate {
  const factory CustomFieldTemplate({
    required String key,
    required String label,
    required String fieldType, // 'text', 'number', 'date', 'url'
    @Default(false) bool isRequired,
  }) = _CustomFieldTemplate;

  factory CustomFieldTemplate.fromJson(Map<String, dynamic> json) =>
      _$CustomFieldTemplateFromJson(json);
}

/// Extension for Firestore conversion
extension EventTypeModelX on EventTypeModel {
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'iconName': iconName,
      'defaultChecklistItems': defaultChecklistItems,
      'customFieldTemplates':
          customFieldTemplates.map((e) => e.toJson()).toList(),
      'isActive': isActive,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  static EventTypeModel fromFirestore(Map<String, dynamic> data, String id) {
    return EventTypeModel(
      id: id,
      name: data['name'] as String,
      description: data['description'] as String?,
      iconName: data['iconName'] as String?,
      defaultChecklistItems:
          List<String>.from(data['defaultChecklistItems'] ?? []),
      customFieldTemplates: (data['customFieldTemplates'] as List?)
              ?.map((e) => CustomFieldTemplate.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      isActive: data['isActive'] as bool? ?? true,
      createdAt: FirestoreHelpers.toDateTime(data['createdAt']),
      updatedAt: FirestoreHelpers.toDateTime(data['updatedAt']),
    );
  }
}

