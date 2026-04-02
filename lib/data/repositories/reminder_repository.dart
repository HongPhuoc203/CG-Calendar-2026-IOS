import '../models/reminder_model.dart';
import '../services/firestore_service.dart';
import '../../core/constants/app_constants.dart';
import '../../core/errors/failures.dart';

/// Repository for reminder operations
class ReminderRepository {
  final FirestoreService _firestoreService;

  ReminderRepository(this._firestoreService);

  /// Get reminders for an event
  Future<List<ReminderModel>> getRemindersByEventId(String eventId) async {
    try {
      final snapshot = await _firestoreService.getCollection(
        AppConstants.remindersCollection,
        queryBuilder: (ref) =>
            ref.where('eventId', isEqualTo: eventId).orderBy('triggerTime'),
      );

      return snapshot.docs
          .map((doc) => ReminderModelX.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw FirestoreFailure('Lỗi lấy nhắc lịch: $e');
    }
  }

  /// Stream reminders for an event
  Stream<List<ReminderModel>> streamRemindersByEventId(String eventId) {
    return _firestoreService.streamCollection(
      AppConstants.remindersCollection,
      queryBuilder: (ref) =>
          ref.where('eventId', isEqualTo: eventId).orderBy('triggerTime'),
    ).map((snapshot) => snapshot.docs
        .map((doc) => ReminderModelX.fromFirestore(doc.data(), doc.id))
        .toList());
  }

  /// Create reminder
  Future<String> createReminder(ReminderModel reminder) async {
    try {
      final data = reminder.toFirestore();
      data['createdAt'] = DateTime.now().toIso8601String();

      return await _firestoreService.createDocument(
        AppConstants.remindersCollection,
        data,
      );
    } catch (e) {
      throw FirestoreFailure('Lỗi tạo nhắc lịch: $e');
    }
  }

  /// Create multiple reminders at once.
  /// Uses reminder.id as the Firestore document ID so the local scheduler
  /// (via ReminderSyncService) always works with the same ID that was
  /// computed in Dart — preventing duplicate notifications from ID mismatch.
  Future<void> createReminders(List<ReminderModel> reminders) async {
    try {
      final batch = _firestoreService.batch();

      for (var reminder in reminders) {
        final docRef = _firestoreService.firestore
            .collection(AppConstants.remindersCollection)
            .doc(reminder.id); // ← use Dart UUID, not auto-generated ID

        final data = reminder.toFirestore();
        data['createdAt'] = DateTime.now().toIso8601String();

        batch.set(docRef, data);
      }

      await batch.commit();
    } catch (e) {
      throw FirestoreFailure('Lỗi tạo nhiều nhắc lịch: $e');
    }
  }

  /// Update reminder
  Future<void> updateReminder(ReminderModel reminder) async {
    try {
      await _firestoreService.updateDocument(
        AppConstants.remindersCollection,
        reminder.id,
        reminder.toFirestore(),
      );
    } catch (e) {
      throw FirestoreFailure('Lỗi cập nhật nhắc lịch: $e');
    }
  }

  /// Delete reminder
  Future<void> deleteReminder(String reminderId) async {
    try {
      await _firestoreService.deleteDocument(
        AppConstants.remindersCollection,
        reminderId,
      );
    } catch (e) {
      throw FirestoreFailure('Lỗi xóa nhắc lịch: $e');
    }
  }

  /// Atomically replace all reminders for an event in a SINGLE Firestore batch.
  ///
  /// Combines delete-old + create-new into one write so Firestore streams on
  /// other devices only fire ONCE (with the final state), eliminating the
  /// intermediate empty-reminder window that caused the update-notification
  /// race condition.
  Future<void> replaceRemindersForEvent(
    String eventId,
    List<ReminderModel> newReminders,
  ) async {
    try {
      // Fetch existing reminder refs (need IDs to delete)
      final existing = await _firestoreService.getCollection(
        AppConstants.remindersCollection,
        queryBuilder: (ref) => ref.where('eventId', isEqualTo: eventId),
      );

      final batch = _firestoreService.batch();
      final col = _firestoreService.firestore.collection(AppConstants.remindersCollection);

      // Delete all old reminders
      for (final doc in existing.docs) {
        batch.delete(doc.reference);
      }

      // Create all new reminders (using Dart UUID as doc ID)
      for (final reminder in newReminders) {
        final data = reminder.toFirestore();
        data['createdAt'] = DateTime.now().toIso8601String();
        batch.set(col.doc(reminder.id), data);
      }

      await batch.commit();
    } catch (e) {
      throw FirestoreFailure('Lỗi thay thế nhắc lịch: $e');
    }
  }

  /// Delete all reminders for an event
  Future<void> deleteRemindersByEventId(String eventId) async {
    try {
      final snapshot = await _firestoreService.getCollection(
        AppConstants.remindersCollection,
        queryBuilder: (ref) => ref.where('eventId', isEqualTo: eventId),
      );

      final batch = _firestoreService.batch();

      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    } catch (e) {
      throw FirestoreFailure('Lỗi xóa nhắc lịch: $e');
    }
  }

  /// Get all upcoming (future, not yet sent) reminders where userId is a recipient.
  /// Used by ReminderSyncService to schedule local notifications on each device.
  ///
  /// Uses only a single array-contains filter to avoid requiring a Firestore
  /// composite index. isSent and triggerTime are filtered client-side.
  Future<List<ReminderModel>> getPendingRemindersForUser(String userId) async {
    try {
      final snapshot = await _firestoreService.getCollection(
        AppConstants.remindersCollection,
        queryBuilder: (ref) =>
            ref.where('recipientUserIds', arrayContains: userId),
      );

      final now = DateTime.now();
      return snapshot.docs
          .map((doc) => ReminderModelX.fromFirestore(doc.data(), doc.id))
          .where((r) => !r.isSent && r.triggerTime.isAfter(now))
          .toList();
    } catch (e) {
      throw FirestoreFailure('Lỗi lấy reminders của người dùng: $e');
    }
  }

  /// Stream upcoming reminders for a user in real-time.
  /// Emits whenever any reminder for this user is added/updated/deleted.
  ///
  /// Uses only array-contains (no composite index needed).
  /// isSent and triggerTime filtering is client-side.
  Stream<List<ReminderModel>> streamUpcomingRemindersForUser(String userId) {
    return _firestoreService
        .streamCollection(
          AppConstants.remindersCollection,
          queryBuilder: (ref) =>
              ref.where('recipientUserIds', arrayContains: userId),
        )
        .map((snapshot) {
          final now = DateTime.now();
          return snapshot.docs
              .map((doc) => ReminderModelX.fromFirestore(doc.data(), doc.id))
              .where((r) => !r.isSent && r.triggerTime.isAfter(now))
              .toList();
        });
  }

  /// Mark reminder as sent
  Future<void> markReminderAsSent(String reminderId) async {
    try {
      await _firestoreService.updateDocument(
        AppConstants.remindersCollection,
        reminderId,
        {
          'isSent': true,
          'sentAt': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      throw FirestoreFailure('Lỗi cập nhật trạng thái: $e');
    }
  }
}

