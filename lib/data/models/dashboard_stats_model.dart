import 'package:freezed_annotation/freezed_annotation.dart';

part 'dashboard_stats_model.freezed.dart';
part 'dashboard_stats_model.g.dart';

/// Dashboard Statistics Model
@freezed
class DashboardStatsModel with _$DashboardStatsModel {
  const factory DashboardStatsModel({
    @Default(0) double totalRevenue,
    @Default(0) double totalExpenses,
    @Default(0) int upcomingEventsCount,
    @Default(0) int urgentTasksCount,
    @Default(0) int unreadNotificationsCount,
  }) = _DashboardStatsModel;

  factory DashboardStatsModel.fromJson(Map<String, dynamic> json) =>
      _$DashboardStatsModelFromJson(json);
}

/// Extension for calculations
extension DashboardStatsModelX on DashboardStatsModel {
  /// Net income (revenue - expenses)
  double get netIncome => totalRevenue - totalExpenses;

  /// Profit margin percentage
  double get profitMargin {
    if (totalRevenue == 0) return 0;
    return (netIncome / totalRevenue) * 100;
  }

  /// Check if there are urgent items
  bool get hasUrgentItems => urgentTasksCount > 0;

  /// Check if there are unread notifications
  bool get hasUnreadNotifications => unreadNotificationsCount > 0;
}

/// Revenue Statistics Model (for detailed revenue analysis)
@freezed
class RevenueStatsModel with _$RevenueStatsModel {
  const factory RevenueStatsModel({
    @Default(0) double totalRevenue,
    @Default(0) double totalExpenses,
    @Default([]) List<RevenueByDate> revenueByDate,
    @Default([]) List<RevenueByArtist> revenueByArtist,
    DateTime? fromDate,
    DateTime? toDate,
  }) = _RevenueStatsModel;

  factory RevenueStatsModel.fromJson(Map<String, dynamic> json) =>
      _$RevenueStatsModelFromJson(json);
}

/// Extension for RevenueStatsModel
extension RevenueStatsModelX on RevenueStatsModel {
  double get netIncome => totalRevenue - totalExpenses;

  double get averageDailyRevenue {
    if (revenueByDate.isEmpty) return 0;
    return totalRevenue / revenueByDate.length;
  }
}

/// Revenue by Date (for charts)
@freezed
class RevenueByDate with _$RevenueByDate {
  const factory RevenueByDate({
    required DateTime date,
    required double revenue,
    required double expenses,
  }) = _RevenueByDate;

  factory RevenueByDate.fromJson(Map<String, dynamic> json) =>
      _$RevenueByDateFromJson(json);
}

/// Extension for RevenueByDate
extension RevenueByDateX on RevenueByDate {
  double get netIncome => revenue - expenses;
}

/// Revenue by Artist (for breakdown)
@freezed
class RevenueByArtist with _$RevenueByArtist {
  const factory RevenueByArtist({
    required String artistId,
    required String artistName,
    required double revenue,
    required double expenses,
    required int eventCount,
  }) = _RevenueByArtist;

  factory RevenueByArtist.fromJson(Map<String, dynamic> json) =>
      _$RevenueByArtistFromJson(json);
}

/// Extension for RevenueByArtist
extension RevenueByArtistX on RevenueByArtist {
  double get netIncome => revenue - expenses;

  double get averageRevenuePerEvent {
    if (eventCount == 0) return 0;
    return revenue / eventCount;
  }
}
