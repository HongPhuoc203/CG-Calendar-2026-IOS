import '../models/event_type_model.dart';
import '../services/firestore_service.dart';
import '../../core/constants/app_constants.dart';
import '../../core/errors/failures.dart';

/// Repository for event type operations
class EventTypeRepository {
  final FirestoreService _firestoreService;

  EventTypeRepository(this._firestoreService);

  /// Get all active event types
  Future<List<EventTypeModel>> getAllEventTypes() async {
    try {
      final snapshot = await _firestoreService.getCollection(
        AppConstants.eventTypesCollection,
        queryBuilder: (ref) => ref.where('isActive', isEqualTo: true),
      );

      return snapshot.docs
          .map((doc) => EventTypeModelX.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw FirestoreFailure('Lỗi lấy loại sự kiện: $e');
    }
  }

  /// Stream all active event types
  Stream<List<EventTypeModel>> streamAllEventTypes() {
    return _firestoreService.streamCollection(
      AppConstants.eventTypesCollection,
      queryBuilder: (ref) => ref.where('isActive', isEqualTo: true),
    ).map((snapshot) => snapshot.docs
        .map((doc) => EventTypeModelX.fromFirestore(doc.data(), doc.id))
        .toList());
  }

  /// Get event type by ID
  Future<EventTypeModel?> getEventTypeById(String typeId) async {
    try {
      final doc = await _firestoreService.getDocument(
        AppConstants.eventTypesCollection,
        typeId,
      );

      if (!doc.exists) return null;

      return EventTypeModelX.fromFirestore(doc.data()!, doc.id);
    } catch (e) {
      throw FirestoreFailure('Lỗi lấy loại sự kiện: $e');
    }
  }

  /// Create event type
  Future<String> createEventType(EventTypeModel eventType) async {
    try {
      final data = eventType.toFirestore();
      data['createdAt'] = DateTime.now().toIso8601String();
      data['updatedAt'] = DateTime.now().toIso8601String();

      return await _firestoreService.createDocument(
        AppConstants.eventTypesCollection,
        data,
      );
    } catch (e) {
      throw FirestoreFailure('Lỗi tạo loại sự kiện: $e');
    }
  }

  /// Update event type
  Future<void> updateEventType(EventTypeModel eventType) async {
    try {
      final data = eventType.toFirestore();
      data['updatedAt'] = DateTime.now().toIso8601String();

      await _firestoreService.updateDocument(
        AppConstants.eventTypesCollection,
        eventType.id,
        data,
      );
    } catch (e) {
      throw FirestoreFailure('Lỗi cập nhật loại sự kiện: $e');
    }
  }

  /// Delete event type (soft delete)
  Future<void> deleteEventType(String typeId) async {
    try {
      await _firestoreService.updateDocument(
        AppConstants.eventTypesCollection,
        typeId,
        {
          'isActive': false,
          'updatedAt': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      throw FirestoreFailure('Lỗi xóa loại sự kiện: $e');
    }
  }
}

