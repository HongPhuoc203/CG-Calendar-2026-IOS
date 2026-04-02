import 'dart:async';
import '../repositories/reminder_repository.dart';
import '../repositories/event_repository.dart';
import 'local_notification_scheduler.dart';
import '../../core/utils/logger.dart';

/// Synchronizes Firestore reminders → device local notifications.
///
/// Each device fetches its own reminders from Firestore and schedules
/// local notifications independently — no Cloud Functions needed for
/// the local-notification path (Cloud Functions still handle FCM push
/// for background/killed devices).
///
/// Key guarantees:
///   - Debounced: rapid Firestore stream events (e.g. delete + create in
///     one batch arriving as separate listener callbacks) are collapsed into
///     a single sync, eliminating duplicate scheduling.
///   - Mutex: only one syncAndSchedule runs at a time; a pending run is
///     cancelled and replaced if a newer trigger arrives.
class ReminderSyncService {
  StreamSubscription<dynamic>? _subscription;

  // Debounce timer — coalesces rapid stream events into a single sync
  Timer? _debounceTimer;
  static const _debounceDuration = Duration(milliseconds: 800);

  // Mutex flag — prevents overlapping syncAndSchedule calls
  bool _syncing = false;
  bool _pendingSync = false;

  // Stored references for debounced re-sync
  String? _lastUserId;
  ReminderRepository? _lastReminderRepo;
  EventRepository? _lastEventRepo;
  LocalNotificationScheduler? _lastScheduler;

  /// Cancel all local notifications and re-schedule from Firestore.
  Future<void> syncAndSchedule({
    required String userId,
    required ReminderRepository reminderRepo,
    required EventRepository eventRepo,
    required LocalNotificationScheduler scheduler,
  }) async {
    // If already syncing, mark pending and return — the in-progress sync
    // will loop once more when it finishes.
    if (_syncing) {
      _pendingSync = true;
      return;
    }

    _syncing = true;
    _pendingSync = false;

    try {
      logger.i('🔄 ReminderSync: syncing for user $userId');

      await scheduler.cancelAllNotifications();

      final reminders = await reminderRepo.getPendingRemindersForUser(userId);
      logger.i('📋 ReminderSync: ${reminders.length} pending reminders');

      int scheduled = 0;
      for (final reminder in reminders) {
        try {
          final event = await eventRepo.getEventById(reminder.eventId);
          if (event != null) {
            await scheduler.scheduleReminderNotification(
              event: event,
              reminder: reminder,
            );
            scheduled++;
          }
        } catch (e) {
          logger.w('⚠️ ReminderSync: skip reminder ${reminder.id}: $e');
        }
      }

      logger.i('✅ ReminderSync: scheduled $scheduled/${reminders.length}');
    } catch (e) {
      logger.e('❌ ReminderSync.syncAndSchedule failed', error: e);
    } finally {
      _syncing = false;
      // If a new trigger arrived while we were syncing, run once more
      if (_pendingSync &&
          _lastUserId != null &&
          _lastReminderRepo != null &&
          _lastEventRepo != null &&
          _lastScheduler != null) {
        _pendingSync = false;
        await syncAndSchedule(
          userId: _lastUserId!,
          reminderRepo: _lastReminderRepo!,
          eventRepo: _lastEventRepo!,
          scheduler: _lastScheduler!,
        );
      }
    }
  }

  /// Start real-time Firestore listener.
  /// Uses an 800 ms debounce so that a delete+create batch (which emits two
  /// Firestore stream events in quick succession) results in only ONE sync.
  void startListening({
    required String userId,
    required ReminderRepository reminderRepo,
    required EventRepository eventRepo,
    required LocalNotificationScheduler scheduler,
  }) {
    _subscription?.cancel();

    // Cache refs for use in debounced callback and mutex retry
    _lastUserId = userId;
    _lastReminderRepo = reminderRepo;
    _lastEventRepo = eventRepo;
    _lastScheduler = scheduler;

    _subscription = reminderRepo
        .streamUpcomingRemindersForUser(userId)
        .listen(
          (_) {
            // Debounce: reset the timer on every stream event
            _debounceTimer?.cancel();
            _debounceTimer = Timer(_debounceDuration, () {
              logger.i('🔔 ReminderSync: stream change (debounced) — syncing');
              syncAndSchedule(
                userId: userId,
                reminderRepo: reminderRepo,
                eventRepo: eventRepo,
                scheduler: scheduler,
              );
            });
          },
          onError: (Object e) {
            logger.e('❌ ReminderSync stream error', error: e);
          },
        );

    logger.i('👂 ReminderSync: listening (user: $userId)');
  }

  void stopListening() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _subscription?.cancel();
    _subscription = null;
    logger.i('🛑 ReminderSync: stopped');
  }
}
