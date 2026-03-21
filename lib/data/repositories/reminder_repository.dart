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

  /// Create multiple reminders at once
  Future<void> createReminders(List<ReminderModel> reminders) async {
    try {
      final batch = _firestoreService.batch();

      for (var reminder in reminders) {
        final docRef = _firestoreService.firestore
            .collection(AppConstants.remindersCollection)
            .doc();

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

