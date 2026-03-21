import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/user_repository.dart';
import '../data/repositories/artist_repository.dart';
import '../data/repositories/event_repository.dart';
import '../data/repositories/event_type_repository.dart';
import '../data/repositories/reminder_repository.dart';
import '../data/repositories/notification_repository.dart';
import '../data/repositories/revenue_repository.dart';
import 'services_providers.dart';

/// Provider for UserRepository
final userRepositoryProvider = Provider<UserRepository>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return UserRepository(firestoreService);
});

/// Provider for ArtistRepository
final artistRepositoryProvider = Provider<ArtistRepository>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return ArtistRepository(firestoreService);
});

/// Provider for EventRepository
final eventRepositoryProvider = Provider<EventRepository>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return EventRepository(firestoreService);
});

/// Provider for EventTypeRepository
final eventTypeRepositoryProvider = Provider<EventTypeRepository>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return EventTypeRepository(firestoreService);
});

/// Provider for ReminderRepository
final reminderRepositoryProvider = Provider<ReminderRepository>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return ReminderRepository(firestoreService);
});

/// Provider for NotificationRepository
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return NotificationRepository(firestoreService);
});

/// Provider for RevenueRepository
final revenueRepositoryProvider = Provider<RevenueRepository>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return RevenueRepository(firestoreService);
});

