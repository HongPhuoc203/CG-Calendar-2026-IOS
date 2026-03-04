import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/dashboard_stats_model.dart';
import '../data/models/event_model.dart';
import '../core/enums/user_role.dart';
import 'repositories_providers.dart';
import 'auth_provider.dart';
import 'notifications_provider.dart';

/// Provider for Dashboard Statistics
final dashboardStatsProvider = FutureProvider.autoDispose<DashboardStatsModel>((ref) async {
  final eventRepository = ref.watch(eventRepositoryProvider);
  final revenueRepository = ref.watch(revenueRepositoryProvider);
  final userProfileAsync = ref.watch(currentUserProfileProvider);
  final unreadCount = ref.watch(unreadNotificationsCountProvider);

  final user = userProfileAsync.asData?.value;
  if (user == null) {
    return const DashboardStatsModel();
  }

  // Determine artist IDs based on role
  List<String> artistIds = [];
  switch (user.role) {
    case UserRole.pending:
      artistIds = [];
      break;
    case UserRole.viewer:
      if (user.artistId != null) {
        artistIds = [user.artistId!];
      }
      break;
    case UserRole.editor:
      artistIds = user.managedArtistIds;
      break;
    case UserRole.superEditor:
      artistIds = []; // Will fetch all events
      break;
  }

  try {
    // Get upcoming events (next 7 days)
    final upcomingEvents = await eventRepository.getUpcomingEvents(
      artistIds: artistIds,
      days: 7,
    );

    // Get urgent tasks
    final urgentEvents = await eventRepository.getUrgentEvents(
      artistIds: artistIds,
      hoursThreshold: 48,
    );

    // Get revenue stats for current month
    final revenueStats = await revenueRepository.getCurrentMonthRevenue(
      artistIds: artistIds,
    );

    // Get unread notifications count
    final unreadNotificationsCount = unreadCount.maybeWhen(
      data: (count) => count,
      orElse: () => 0,
    );

    return DashboardStatsModel(
      totalRevenue: revenueStats.totalRevenue,
      totalExpenses: revenueStats.totalExpenses,
      upcomingEventsCount: upcomingEvents.length,
      urgentTasksCount: urgentEvents.length,
      unreadNotificationsCount: unreadNotificationsCount,
    );
  } catch (e) {
    // Return empty stats on error
    return const DashboardStatsModel();
  }
});

/// Provider for urgent events
final urgentEventsProvider = FutureProvider.autoDispose<List<EventModel>>((ref) async {
  final eventRepository = ref.watch(eventRepositoryProvider);
  final userProfileAsync = ref.watch(currentUserProfileProvider);

  final user = userProfileAsync.asData?.value;
  if (user == null) return [];

  List<String> artistIds = [];
  switch (user.role) {
    case UserRole.pending:
      return [];
    case UserRole.viewer:
      if (user.artistId != null) {
        artistIds = [user.artistId!];
      }
      break;
    case UserRole.editor:
      artistIds = user.managedArtistIds;
      break;
    case UserRole.superEditor:
      artistIds = [];
      break;
  }

  return eventRepository.getUrgentEvents(
    artistIds: artistIds,
    hoursThreshold: 48,
  );
});

/// Provider for today's events
final todayEventsProvider = FutureProvider.autoDispose<List<EventModel>>((ref) async {
  final eventRepository = ref.watch(eventRepositoryProvider);
  final userProfileAsync = ref.watch(currentUserProfileProvider);

  final user = userProfileAsync.asData?.value;
  if (user == null) return [];

  List<String>? artistIds;
  switch (user.role) {
    case UserRole.pending:
      return [];
    case UserRole.viewer:
      if (user.artistId != null) {
        artistIds = [user.artistId!];
      }
      break;
    case UserRole.editor:
      artistIds = user.managedArtistIds;
      break;
    case UserRole.superEditor:
      artistIds = null; // Fetch all
      break;
  }

  return eventRepository.getTodayEvents(artistIds: artistIds);
});

/// Provider for upcoming events (next 7 days)
final upcomingEventsProvider = FutureProvider.autoDispose<List<EventModel>>((ref) async {
  final eventRepository = ref.watch(eventRepositoryProvider);
  final userProfileAsync = ref.watch(currentUserProfileProvider);

  final user = userProfileAsync.asData?.value;
  if (user == null) return [];

  List<String> artistIds = [];
  switch (user.role) {
    case UserRole.pending:
      return [];
    case UserRole.viewer:
      if (user.artistId != null) {
        artistIds = [user.artistId!];
      }
      break;
    case UserRole.editor:
      artistIds = user.managedArtistIds;
      break;
    case UserRole.superEditor:
      artistIds = [];
      break;
  }

  return eventRepository.getUpcomingEvents(
    artistIds: artistIds,
    days: 7,
  );
});

/// Provider for revenue statistics
enum RevenueTimeFrame {
  today,
  week,
  month,
  custom;

  String get displayName {
    switch (this) {
      case RevenueTimeFrame.today:
        return 'Hôm nay';
      case RevenueTimeFrame.week:
        return 'Tuần này';
      case RevenueTimeFrame.month:
        return 'Tháng này';
      case RevenueTimeFrame.custom:
        return 'Tùy chỉnh';
    }
  }
}

/// State provider for selected revenue time frame
final selectedRevenueTimeFrameProvider = StateProvider<RevenueTimeFrame>((ref) {
  return RevenueTimeFrame.month;
});

/// Provider for revenue statistics based on time frame
final revenueStatsProvider = FutureProvider.autoDispose<RevenueStatsModel>((ref) async {
  final revenueRepository = ref.watch(revenueRepositoryProvider);
  final userProfileAsync = ref.watch(currentUserProfileProvider);
  final timeFrame = ref.watch(selectedRevenueTimeFrameProvider);

  final user = userProfileAsync.asData?.value;
  if (user == null) {
    return const RevenueStatsModel();
  }

  List<String> artistIds = [];
  switch (user.role) {
    case UserRole.pending:
      return const RevenueStatsModel();
    case UserRole.viewer:
      if (user.artistId != null) {
        artistIds = [user.artistId!];
      }
      break;
    case UserRole.editor:
      artistIds = user.managedArtistIds;
      break;
    case UserRole.superEditor:
      artistIds = [];
      break;
  }

  switch (timeFrame) {
    case RevenueTimeFrame.today:
      return revenueRepository.getTodayRevenue(artistIds: artistIds);
    case RevenueTimeFrame.week:
      return revenueRepository.getCurrentWeekRevenue(artistIds: artistIds);
    case RevenueTimeFrame.month:
      return revenueRepository.getCurrentMonthRevenue(artistIds: artistIds);
    case RevenueTimeFrame.custom:
      return revenueRepository.getCurrentMonthRevenue(artistIds: artistIds);
  }
});

/// Provider for custom date range revenue
final customDateRangeRevenueProvider = FutureProvider.autoDispose.family<RevenueStatsModel, DateRange>(
  (ref, dateRange) async {
    final revenueRepository = ref.watch(revenueRepositoryProvider);
    final userProfileAsync = ref.watch(currentUserProfileProvider);

    final user = userProfileAsync.asData?.value;
    if (user == null) {
      return const RevenueStatsModel();
    }

    List<String> artistIds = [];
    switch (user.role) {
      case UserRole.pending:
        return const RevenueStatsModel();
      case UserRole.viewer:
        if (user.artistId != null) {
          artistIds = [user.artistId!];
        }
        break;
      case UserRole.editor:
        artistIds = user.managedArtistIds;
        break;
      case UserRole.superEditor:
        artistIds = [];
        break;
    }

    return revenueRepository.getRevenueStats(
      artistIds: artistIds,
      fromDate: dateRange.start,
      toDate: dateRange.end,
    );
  },
);

/// Helper class for date range
class DateRange {
  final DateTime start;
  final DateTime end;

  DateRange(this.start, this.end);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DateRange &&
          runtimeType == other.runtimeType &&
          start == other.start &&
          end == other.end;

  @override
  int get hashCode => start.hashCode ^ end.hashCode;
}
