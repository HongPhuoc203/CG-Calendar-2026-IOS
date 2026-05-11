import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/dashboard_stats_model.dart';
import '../data/models/event_model.dart';
import '../core/enums/user_role.dart';
import 'repositories_providers.dart';
import 'auth_provider.dart';
import 'notifications_provider.dart';
import 'events_provider.dart';
import 'artists_provider.dart';


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
    case UserRole.guest:
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

    // Get urgent tasks (same logic as urgentEventsProvider — 7 days, no checklist = urgent)
    final allUpcoming = await eventRepository.getUpcomingEvents(
      artistIds: artistIds,
      days: 7,
    );
    final urgentEvents = allUpcoming.where((e) {
      if (e.checklistItems.isEmpty) return true;
      return e.checklistItems.any((item) => !item.isCompleted);
    }).toList();

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

/// Provider for urgent events — dùng eventsStreamProvider để cập nhật realtime.
///
/// Hiển thị các sự kiện trong 7 ngày tới mà:
///   - Có checklist item chưa hoàn thành, HOẶC
///   - Chưa có checklist nào được thiết lập (cần chuẩn bị)
final urgentEventsProvider =
    Provider.autoDispose<AsyncValue<List<EventModel>>>((ref) {
  final eventsAsync = ref.watch(eventsStreamProvider);
  final userProfileAsync = ref.watch(currentUserProfileProvider);

  return eventsAsync.when(
    loading: () => const AsyncValue.loading(),
    error: (e, s) => AsyncValue.error(e, s),
    data: (events) {
      final user = userProfileAsync.asData?.value;
      if (user == null || user.role == UserRole.guest) {
        return const AsyncValue.data([]);
      }

      final now = DateTime.now();
      final deadline = now.add(const Duration(days: 7));

      final urgent = events.where((e) {
        // Lọc theo khoảng thời gian (7 ngày tới)
        if (e.startTime.isBefore(now) || e.startTime.isAfter(deadline)) {
          return false;
        }
        // Lọc theo role / nghệ sĩ quản lý
        if (user.role == UserRole.viewer) {
          if (user.artistId == null) return false;
          if (!e.artistIds.contains(user.artistId)) return false;
        } else if (user.role == UserRole.editor) {
          if (!e.artistIds.any((id) => user.managedArtistIds.contains(id))) {
            return false;
          }
        }
        // Urgent nếu: chưa có checklist HOẶC có item chưa xong
        if (e.checklistItems.isEmpty) return true;
        return e.checklistItems.any((item) => !item.isCompleted);
      }).toList()
        ..sort((a, b) => a.startTime.compareTo(b.startTime));

      return AsyncValue.data(urgent);
    },
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
    case UserRole.guest:
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
    case UserRole.guest:
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
  alltime,
  custom;

  String get displayName {
    switch (this) {
      case RevenueTimeFrame.today:
        return 'Hôm nay';
      case RevenueTimeFrame.week:
        return 'Tuần này';
      case RevenueTimeFrame.month:
        return 'Tháng này';
      case RevenueTimeFrame.alltime:
        return 'Tất cả';
      case RevenueTimeFrame.custom:
        return 'Tùy chỉnh';
    }
  }
}

/// State provider for selected revenue time frame
final selectedRevenueTimeFrameProvider = StateProvider<RevenueTimeFrame>((ref) {
  return RevenueTimeFrame.month;
});

/// State provider for selected revenue month (when time frame is month)
final selectedRevenueMonthProvider = StateProvider<DateTime>((ref) {
  return DateTime.now();
});

/// Provider for revenue statistics based on time frame
final revenueStatsProvider = FutureProvider.autoDispose<RevenueStatsModel>((ref) async {
  final revenueRepository = ref.watch(revenueRepositoryProvider);
  final userProfileAsync = ref.watch(currentUserProfileProvider);
  final timeFrame = ref.watch(selectedRevenueTimeFrameProvider);
  final selectedMonth = ref.watch(selectedRevenueMonthProvider);

  final user = userProfileAsync.asData?.value;
  if (user == null) {
    return const RevenueStatsModel();
  }

  List<String> artistIds = [];
  switch (user.role) {
    case UserRole.guest:
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
      final fromDate = DateTime(selectedMonth.year, selectedMonth.month, 1);
      final toDate = DateTime(selectedMonth.year, selectedMonth.month + 1, 0, 23, 59, 59);
      return revenueRepository.getRevenueStats(
        artistIds: artistIds,
        fromDate: fromDate,
        toDate: toDate,
      );
    case RevenueTimeFrame.alltime:
      return revenueRepository.getAllTimeRevenue(artistIds: artistIds);
    case RevenueTimeFrame.custom:
      return revenueRepository.getCurrentMonthRevenue(artistIds: artistIds);
  }
});

/// Dedicated provider for the Home screen revenue chart.
///
/// Mirrors the Revenue screen's "by month" logic exactly:
///   • Watches [eventsStreamProvider] so it reacts to live event changes.
///   • Excludes DBA events (same as Revenue screen).
///   • Includes artist share (60 %) in [RevenueByDate.expenses] so the chart
///     "Chi" line shows the real total outgoing — no double-counting needed
///     inside [RevenueChart].
///   • Always scoped to the current calendar month, independent of the
///     Revenue screen's time-frame selector.
final homeRevenueStatsProvider =
    Provider.autoDispose<AsyncValue<RevenueStatsModel>>((ref) {
  final eventsAsync = ref.watch(eventsStreamProvider);
  final artistsAsync = ref.watch(artistsStreamProvider);

  return eventsAsync.when(
    loading: () => const AsyncValue.loading(),
    error: (e, s) => AsyncValue.error(e, s),
    data: (events) {
      final artists = artistsAsync.value ?? [];
      final now = DateTime.now();

      // Identify DBA artist to exclude (same logic as Revenue screen)
      final dbaArtist = artists
          .where((a) => a.name.trim().toUpperCase() == 'DBA')
          .firstOrNull;
      final dbaId = dbaArtist?.id;

      // Keep only current-month events, excluding DBA
      final monthEvents = events.where((e) {
        final isDBA = (dbaId != null && e.artistIds.contains(dbaId)) ||
            e.title.toUpperCase().contains('DBA');
        final isCurrentMonth =
            e.startTime.year == now.year && e.startTime.month == now.month;
        return !isDBA && isCurrentMonth;
      }).toList();

      // Build RevenueByDate with expenses = raw + artist share (60 %)
      double totalRevenue = 0;
      double totalExpenses = 0;
      final Map<DateTime, RevenueByDate> byDateMap = {};

      for (final e in monthEvents) {
        if (e.finance == null) continue;
        final rev = e.finance!.revenue;
        final opExp = e.finance!.totalExpenses;
        final totalOutgoings = opExp + rev * 0.6;

        totalRevenue += rev;
        totalExpenses += opExp;

        final key = DateTime(e.startTime.year, e.startTime.month, e.startTime.day);
        final existing = byDateMap[key];
        byDateMap[key] = existing == null
            ? RevenueByDate(date: key, revenue: rev, expenses: totalOutgoings)
            : existing.copyWith(
                revenue: existing.revenue + rev,
                expenses: existing.expenses + totalOutgoings,
              );
      }

      final revenueByDate = byDateMap.values.toList()
        ..sort((a, b) => a.date.compareTo(b.date));

      return AsyncValue.data(RevenueStatsModel(
        totalRevenue: totalRevenue,
        totalExpenses: totalExpenses,
        revenueByDate: revenueByDate,
      ));
    },
  );
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
      case UserRole.guest:
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
