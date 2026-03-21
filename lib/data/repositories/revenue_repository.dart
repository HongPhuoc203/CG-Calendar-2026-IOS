import '../models/event_model.dart';
import '../models/dashboard_stats_model.dart';
import '../services/firestore_service.dart';
import '../../core/constants/app_constants.dart';
import '../../core/errors/failures.dart';

/// Repository for revenue and financial statistics
class RevenueRepository {
  final FirestoreService _firestoreService;

  RevenueRepository(this._firestoreService);

  /// Get revenue statistics for a date range
  Future<RevenueStatsModel> getRevenueStats({
    required List<String> artistIds,
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    try {
      // Get events in date range
      final snapshot = await _firestoreService.getCollection(
        AppConstants.eventsCollection,
        queryBuilder: (ref) {
          var query = ref
              .where('startTime', isGreaterThanOrEqualTo: fromDate.toIso8601String())
              .where('startTime', isLessThanOrEqualTo: toDate.toIso8601String());

          if (artistIds.isNotEmpty) {
            query = query.where('artistIds', arrayContainsAny: artistIds);
          }

          return query;
        },
      );

      final events = snapshot.docs
          .map((doc) => EventModelX.fromFirestore(doc.data(), doc.id))
          .toList();

      // Calculate totals
      double totalRevenue = 0;
      double totalExpenses = 0;

      // Group by date
      Map<DateTime, RevenueByDate> revenueByDateMap = {};

      // Group by artist
      Map<String, RevenueByArtistData> revenueByArtistMap = {};

      for (final event in events) {
        if (event.finance != null) {
          final revenue = event.finance!.revenue;
          final expenses = event.finance!.totalExpenses;

          totalRevenue += revenue;
          totalExpenses += expenses;

          // Group by date (start of day)
          final dateKey = DateTime(
            event.startTime.year,
            event.startTime.month,
            event.startTime.day,
          );

          if (revenueByDateMap.containsKey(dateKey)) {
            final existing = revenueByDateMap[dateKey]!;
            revenueByDateMap[dateKey] = RevenueByDate(
              date: dateKey,
              revenue: existing.revenue + revenue,
              expenses: existing.expenses + expenses,
            );
          } else {
            revenueByDateMap[dateKey] = RevenueByDate(
              date: dateKey,
              revenue: revenue,
              expenses: expenses,
            );
          }

          // Group by artist
          for (final artistId in event.artistIds) {
            if (revenueByArtistMap.containsKey(artistId)) {
              final existing = revenueByArtistMap[artistId]!;
              revenueByArtistMap[artistId] = RevenueByArtistData(
                artistId: artistId,
                revenue: existing.revenue + revenue,
                expenses: existing.expenses + expenses,
                eventCount: existing.eventCount + 1,
              );
            } else {
              revenueByArtistMap[artistId] = RevenueByArtistData(
                artistId: artistId,
                revenue: revenue,
                expenses: expenses,
                eventCount: 1,
              );
            }
          }
        }
      }

      // Convert to lists and sort
      final revenueByDate = revenueByDateMap.values.toList()
        ..sort((a, b) => a.date.compareTo(b.date));

      // Get artist names
      final revenueByArtist = await _getRevenueByArtistWithNames(
        revenueByArtistMap.values.toList(),
      );

      return RevenueStatsModel(
        totalRevenue: totalRevenue,
        totalExpenses: totalExpenses,
        revenueByDate: revenueByDate,
        revenueByArtist: revenueByArtist,
        fromDate: fromDate,
        toDate: toDate,
      );
    } catch (e) {
      throw FirestoreFailure('Lỗi lấy thống kê doanh thu: $e');
    }
  }

  /// Get revenue for current month
  Future<RevenueStatsModel> getCurrentMonthRevenue({
    required List<String> artistIds,
  }) async {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    return getRevenueStats(
      artistIds: artistIds,
      fromDate: firstDayOfMonth,
      toDate: lastDayOfMonth,
    );
  }

  /// Get revenue for current week
  Future<RevenueStatsModel> getCurrentWeekRevenue({
    required List<String> artistIds,
  }) async {
    final now = DateTime.now();
    final firstDayOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final startOfWeek = DateTime(
      firstDayOfWeek.year,
      firstDayOfWeek.month,
      firstDayOfWeek.day,
    );
    final endOfWeek = startOfWeek.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));

    return getRevenueStats(
      artistIds: artistIds,
      fromDate: startOfWeek,
      toDate: endOfWeek,
    );
  }

  /// Get revenue for today
  Future<RevenueStatsModel> getTodayRevenue({
    required List<String> artistIds,
  }) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    return getRevenueStats(
      artistIds: artistIds,
      fromDate: startOfDay,
      toDate: endOfDay,
    );
  }

  /// Helper to get artist names
  Future<List<RevenueByArtist>> _getRevenueByArtistWithNames(
    List<RevenueByArtistData> revenueDataList,
  ) async {
    final List<RevenueByArtist> result = [];

    for (final data in revenueDataList) {
      try {
        final artistDoc = await _firestoreService.getDocument(
          AppConstants.artistsCollection,
          data.artistId,
        );

        String artistName = 'Unknown Artist';
        if (artistDoc.exists) {
          final artistData = artistDoc.data();
          artistName = artistData?['name'] as String? ?? 'Unknown Artist';
        }

        result.add(RevenueByArtist(
          artistId: data.artistId,
          artistName: artistName,
          revenue: data.revenue,
          expenses: data.expenses,
          eventCount: data.eventCount,
        ));
      } catch (e) {
        // If artist not found, use unknown
        result.add(RevenueByArtist(
          artistId: data.artistId,
          artistName: 'Unknown Artist',
          revenue: data.revenue,
          expenses: data.expenses,
          eventCount: data.eventCount,
        ));
      }
    }

    // Sort by revenue descending
    result.sort((a, b) => b.revenue.compareTo(a.revenue));

    return result;
  }
}

/// Temporary data class for grouping revenue by artist
class RevenueByArtistData {
  final String artistId;
  final double revenue;
  final double expenses;
  final int eventCount;

  RevenueByArtistData({
    required this.artistId,
    required this.revenue,
    required this.expenses,
    required this.eventCount,
  });
}
