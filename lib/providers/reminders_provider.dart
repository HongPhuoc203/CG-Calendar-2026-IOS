import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/reminder_model.dart';
import 'repositories_providers.dart';

/// Stream reminders for a specific event
final eventRemindersStreamProvider =
    StreamProvider.family<List<ReminderModel>, String>((ref, eventId) {
  final reminderRepo = ref.watch(reminderRepositoryProvider);
  return reminderRepo.streamRemindersByEventId(eventId);
});

/// Get reminders for a specific event (future)
final eventRemindersFutureProvider =
    FutureProvider.family<List<ReminderModel>, String>((ref, eventId) {
  final reminderRepo = ref.watch(reminderRepositoryProvider);
  return reminderRepo.getRemindersByEventId(eventId);
});
