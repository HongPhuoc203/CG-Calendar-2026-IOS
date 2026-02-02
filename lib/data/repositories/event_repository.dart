import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/event_model.dart';
import '../services/firestore_service.dart';
import '../../core/constants/app_constants.dart';
import '../../core/errors/failures.dart';

/// Repository for event operations
class EventRepository {
  final FirestoreService _firestoreService;

  EventRepository(this._firestoreService);

  /// Get all events
  Future<List<EventModel>> getAllEvents() async {
    try {
      final snapshot = await _firestoreService.getCollection(
        AppConstants.eventsCollection,
        queryBuilder: (ref) => ref.orderBy('startTime', descending: false),
      );

      return snapshot.docs
          .map((doc) => EventModelX.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw FirestoreFailure('Lỗi lấy danh sách sự kiện: $e');
    }
  }

  /// Stream events (for real-time updates)
  Stream<List<EventModel>> streamEvents({
    DateTime? startDate,
    DateTime? endDate,
    List<String>? artistIds,
  }) {
    return _firestoreService.streamCollection(
      AppConstants.eventsCollection,
      queryBuilder: (ref) {
        Query<Map<String, dynamic>> query = ref;

        // Filter by artistIds FIRST (most important for permissions!)
        if (artistIds != null && artistIds.isNotEmpty) {
          // Use array-contains-any to filter by artistIds
          query = query.where('artistIds', arrayContainsAny: artistIds);
        }

        if (startDate != null) {
          query = query.where('startTime',
              isGreaterThanOrEqualTo: startDate.toIso8601String());
        }

        if (endDate != null) {
          query = query.where('startTime',
              isLessThanOrEqualTo: endDate.toIso8601String());
        }

        // Note: Can't use orderBy with array-contains-any
        // Will sort in memory instead
        return query;
      },
    ).map((snapshot) {
      var events = snapshot.docs
          .map((doc) => EventModelX.fromFirestore(doc.data(), doc.id))
          .toList();

      // Sort by startTime in memory
      events.sort((a, b) => a.startTime.compareTo(b.startTime));

      return events;
    });
  }

  /// Get events for a specific date range
  Future<List<EventModel>> getEventsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final snapshot = await _firestoreService.getCollection(
        AppConstants.eventsCollection,
        queryBuilder: (ref) => ref
            .where('startTime',
                isGreaterThanOrEqualTo: startDate.toIso8601String())
            .where('startTime', isLessThanOrEqualTo: endDate.toIso8601String())
            .orderBy('startTime', descending: false),
      );

      return snapshot.docs
          .map((doc) => EventModelX.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw FirestoreFailure('Lỗi lấy sự kiện theo ngày: $e');
    }
  }

  /// Get events for specific artists
  Future<List<EventModel>> getEventsByArtists(List<String> artistIds) async {
    if (artistIds.isEmpty) return [];

    try {
      final snapshot = await _firestoreService.getCollection(
        AppConstants.eventsCollection,
        queryBuilder: (ref) => ref
            .where('artistIds', arrayContainsAny: artistIds)
            .orderBy('startTime', descending: false),
      );

      return snapshot.docs
          .map((doc) => EventModelX.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw FirestoreFailure('Lỗi lấy sự kiện theo nghệ sĩ: $e');
    }
  }

  /// Get event by ID
  Future<EventModel?> getEventById(String eventId) async {
    try {
      final doc = await _firestoreService.getDocument(
        AppConstants.eventsCollection,
        eventId,
      );

      if (!doc.exists) return null;

      return EventModelX.fromFirestore(doc.data()!, doc.id);
    } catch (e) {
      throw FirestoreFailure('Lỗi lấy chi tiết sự kiện: $e');
    }
  }

  /// Create event
  Future<String> createEvent(EventModel event) async {
    try {
      final data = event.toFirestore();
      data['createdAt'] = DateTime.now().toIso8601String();
      data['updatedAt'] = DateTime.now().toIso8601String();

      return await _firestoreService.createDocument(
        AppConstants.eventsCollection,
        data,
        docId: event.id, // ← FIX: Use event.id instead of auto-generated ID
      );
    } catch (e) {
      throw FirestoreFailure('Lỗi tạo sự kiện: $e');
    }
  }

  /// Update event
  Future<void> updateEvent(EventModel event) async {
    try {
      final data = event.toFirestore();
      data['updatedAt'] = DateTime.now().toIso8601String();

      await _firestoreService.updateDocument(
        AppConstants.eventsCollection,
        event.id,
        data,
      );
    } catch (e) {
      throw FirestoreFailure('Lỗi cập nhật sự kiện: $e');
    }
  }

  /// Delete event
  Future<void> deleteEvent(String eventId) async {
    try {
      await _firestoreService.deleteDocument(
        AppConstants.eventsCollection,
        eventId,
      );
    } catch (e) {
      throw FirestoreFailure('Lỗi xóa sự kiện: $e');
    }
  }

  /// Update checklist item
  Future<void> updateChecklistItem(
    String eventId,
    List<ChecklistItem> checklistItems,
  ) async {
    try {
      await _firestoreService.updateDocument(
        AppConstants.eventsCollection,
        eventId,
        {
          'checklistItems': checklistItems.map((e) => e.toJson()).toList(),
          'updatedAt': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      throw FirestoreFailure('Lỗi cập nhật checklist: $e');
    }
  }
}

