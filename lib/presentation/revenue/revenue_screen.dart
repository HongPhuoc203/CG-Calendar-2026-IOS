import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/enums/user_role.dart';
import '../../core/utils/number_formatter.dart';
import '../../data/models/dashboard_stats_model.dart';
import '../../data/models/event_model.dart';
import '../../providers/artists_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/events_provider.dart';
import '../../data/models/artist_model.dart';
import '../home/widgets/revenue_chart.dart';

/// Revenue Screen - Detailed revenue analysis
class RevenueScreen extends ConsumerWidget {
  const RevenueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTimeFrame = ref.watch(selectedRevenueTimeFrameProvider);
    final selectedMonth = ref.watch(selectedRevenueMonthProvider);
    final revenueStats = ref.watch(revenueStatsProvider);
    final eventsAsync = ref.watch(eventsStreamProvider);
    final artistsAsync = ref.watch(artistsStreamProvider);
    final userProfileAsync = ref.watch(currentUserProfileProvider);
    final currentUser = userProfileAsync.asData?.value;
    final isViewer = currentUser?.role == UserRole.viewer;
    final isEditor = currentUser?.role == UserRole.editor;

    // Editor chỉ vào được nếu được cấp quyền canViewRevenue
    final hasRevenueAccess = switch (currentUser?.role) {
      UserRole.superEditor => true,
      UserRole.editor => currentUser?.canViewRevenue == true,
      _ => false,
    };

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(context),

            // Chặn Editor không có quyền
            if (isEditor && !hasRevenueAccess)
              Expanded(child: _buildNoPermission()),

            if (!isEditor || hasRevenueAccess) ...[
            // Time Frame Selector
            _buildTimeFrameSelector(context, ref, selectedTimeFrame, selectedMonth),

            // Content
            Expanded(
              child: revenueStats.when(
                data: (stats) {
                  if (eventsAsync.isLoading || artistsAsync.isLoading) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    );
                  }

                  final events = eventsAsync.value ?? [];
                  final artists = artistsAsync.value ?? [];

                  // 1. Tìm Artist ID của DBA để loại trừ
                  final dbaArtist = artists.where((a) => a.name.trim().toUpperCase() == 'DBA').firstOrNull;
                  final dbaId = dbaArtist?.id;

                  // 2. Lọc sự kiện loại trừ DBA
                  final filteredEvents = events.where((e) {
                    final isDBA = (dbaId != null && e.artistIds.contains(dbaId)) || 
                                 e.title.toUpperCase().contains('DBA');
                    return !isDBA;
                  }).toList();

                  // 3. Tính toán lại stats loại trừ DBA
                  double totalRevenue = 0;
                  double totalExpenses = 0;
                  Map<DateTime, RevenueByDate> revenueByDateMap = {};
                  // artistId → {revenue, expenses, eventCount}
                  Map<String, Map<String, dynamic>> artistBreakdown = {};

                  // Lọc theo timeframe để đồng bộ chart và artist breakdown
                  final now = DateTime.now();
                  final displayEvents = filteredEvents.where((e) {
                    final eventDate = DateTime(e.startTime.year, e.startTime.month, e.startTime.day);
                    switch (selectedTimeFrame) {
                      case RevenueTimeFrame.today:
                        final today = DateTime(now.year, now.month, now.day);
                        return eventDate.isAtSameMomentAs(today);
                      case RevenueTimeFrame.week:
                        final startOfWeek = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
                        final endOfWeek = startOfWeek.add(const Duration(days: 6));
                        return !eventDate.isBefore(startOfWeek) && !eventDate.isAfter(endOfWeek);
                      case RevenueTimeFrame.month:
                        return e.startTime.year == selectedMonth.year && e.startTime.month == selectedMonth.month;
                      case RevenueTimeFrame.alltime:
                        return true;
                      default:
                        return e.startTime.year == selectedMonth.year && e.startTime.month == selectedMonth.month;
                    }
                  }).toList();

                  for (var e in displayEvents) {
                    if (e.finance != null) {
                      final rev = e.finance!.revenue;
                      final operationalExp = e.finance!.totalExpenses;
                      final artistShare = rev * 0.6;
                      final totalOutgoings = operationalExp + artistShare;

                      totalRevenue += rev;
                      totalExpenses += operationalExp;

                      // revenueByDate
                      final dateKey = DateTime(e.startTime.year, e.startTime.month, e.startTime.day);
                      final existing = revenueByDateMap[dateKey];
                      if (existing != null) {
                        revenueByDateMap[dateKey] = existing.copyWith(
                          revenue: existing.revenue + rev,
                          expenses: existing.expenses + totalOutgoings,
                        );
                      } else {
                        revenueByDateMap[dateKey] = RevenueByDate(
                          date: dateKey,
                          revenue: rev,
                          expenses: totalOutgoings,
                        );
                      }

                      // revenueByArtist — rebuild từ displayEvents để đồng bộ timeframe
                      for (final artistId in e.artistIds) {
                        if (artistBreakdown.containsKey(artistId)) {
                          artistBreakdown[artistId]!['revenue'] =
                              (artistBreakdown[artistId]!['revenue'] as double) + rev;
                          artistBreakdown[artistId]!['expenses'] =
                              (artistBreakdown[artistId]!['expenses'] as double) + operationalExp;
                          artistBreakdown[artistId]!['eventCount'] =
                              (artistBreakdown[artistId]!['eventCount'] as int) + 1;
                        } else {
                          artistBreakdown[artistId] = {
                            'revenue': rev,
                            'expenses': operationalExp,
                            'eventCount': 1,
                          };
                        }
                      }
                    }
                  }

                  final revenueByDateList = revenueByDateMap.values.toList()
                    ..sort((a, b) => a.date.compareTo(b.date));

                  // Map artistBreakdown → RevenueByArtist dùng danh sách artists đã load
                  final revenueByArtist = artistBreakdown.entries
                      .map((entry) {
                        final artist = artists.cast<ArtistModel?>().firstWhere(
                          (a) => a?.id == entry.key,
                          orElse: () => null,
                        );
                        if (artist == null) return null;
                        final name = artist.name.trim();
                        if (name.toUpperCase() == 'DBA' || artist.id == dbaId) return null;
                        return RevenueByArtist(
                          artistId: entry.key,
                          artistName: name,
                          revenue: entry.value['revenue'] as double,
                          expenses: entry.value['expenses'] as double,
                          eventCount: entry.value['eventCount'] as int,
                        );
                      })
                      .whereType<RevenueByArtist>()
                      .toList()
                    ..sort((a, b) => b.revenue.compareTo(a.revenue));

                  final filteredStats = RevenueStatsModel(
                    totalRevenue: totalRevenue,
                    totalExpenses: totalExpenses,
                    revenueByDate: revenueByDateList,
                    revenueByArtist: revenueByArtist,
                  );

                  return _buildRevenueContent(
                    context,
                    filteredStats,
                    isViewer: isViewer,
                    events: filteredEvents,
                    selectedTimeFrame: selectedTimeFrame,
                    selectedMonth: selectedMonth,
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
                error: (error, stack) => _buildError(error.toString()),
              ),
            ),
            ], // end !isEditor || hasRevenueAccess
          ],
        ),
      ),
    );
  }

  Widget _buildNoPermission() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_outline_rounded,
                size: 48,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Không có quyền truy cập',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tính năng xem doanh thu chưa được cấp phép.\nVui lòng liên hệ Quản lý tổng.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textDarkSecondary.withValues(alpha: 0.8),
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppColors.borderDark,
            width: 1,
          ),
        ),
      ),
      child: const Row(
        children: [
          Text(
            'Doanh thu',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeFrameSelector(BuildContext context, WidgetRef ref, RevenueTimeFrame selectedTimeFrame, DateTime selectedMonth) {
    final displayFrames = [
      RevenueTimeFrame.month,
      RevenueTimeFrame.alltime,
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: displayFrames.map((timeFrame) {
          final isSelected = selectedTimeFrame == timeFrame;
          String displayName = timeFrame.displayName;
          
          if (timeFrame == RevenueTimeFrame.month) {
            displayName = 'Tháng ${DateFormat('MM/yyyy').format(selectedMonth)}';
          }

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: InkWell(
                onTap: () {
                  if (timeFrame == RevenueTimeFrame.month && isSelected) {
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: AppColors.surfaceDark,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      builder: (context) => Container(
                        height: 350,
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: const BoxDecoration(
                                border: Border(bottom: BorderSide(color: AppColors.borderDark)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Hủy', style: TextStyle(color: Colors.white70)),
                                  ),
                                  const Text(
                                    'Chọn tháng/năm',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Xong', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: CupertinoTheme(
                                data: const CupertinoThemeData(
                                  brightness: Brightness.dark,
                                  textTheme: CupertinoTextThemeData(
                                    dateTimePickerTextStyle: TextStyle(color: Colors.white, fontSize: 22),
                                  ),
                                ),
                                child: CupertinoDatePicker(
                                  mode: CupertinoDatePickerMode.monthYear,
                                  initialDateTime: selectedMonth,
                                  onDateTimeChanged: (DateTime newDateTime) {
                                    ref.read(selectedRevenueMonthProvider.notifier).state = 
                                        DateTime(newDateTime.year, newDateTime.month);
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  } else {
                    ref.read(selectedRevenueTimeFrameProvider.notifier).state = timeFrame;
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : AppColors.surfaceDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.borderDark,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        displayName,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isSelected ? Colors.white : AppColors.textDarkSecondary,
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                      if (timeFrame == RevenueTimeFrame.month && isSelected) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_drop_down, color: Colors.white, size: 18),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRevenueContent(
    BuildContext context,
    RevenueStatsModel stats, {
    required bool isViewer,
    List<EventModel> events = const [],
    required RevenueTimeFrame selectedTimeFrame,
    required DateTime selectedMonth,
  }) {
    if (isViewer) {
      return _buildViewerRevenueContent(stats, events, selectedTimeFrame, selectedMonth);
    }

    return RefreshIndicator(
      onRefresh: () async {},
      color: AppColors.primary,
      backgroundColor: AppColors.surfaceDark,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Summary Cards
            _buildSummaryCards(stats),
            const SizedBox(height: 24),

            // Chart
            RevenueChart(
              revenueStats: stats,
              showExpenses: true,
            ),
            const SizedBox(height: 24),

            // Revenue by Artist
            if (stats.revenueByArtist.isNotEmpty) ...[
              _buildRevenueByArtist(stats, events, selectedTimeFrame, selectedMonth),
              const SizedBox(height: 24),
            ],

            // Details
            _buildRevenueDetails(stats),
          ],
        ),
      ),
    );
  }

  Widget _buildViewerRevenueContent(RevenueStatsModel stats, List<EventModel> events, RevenueTimeFrame selectedTimeFrame, DateTime selectedMonth) {
      final now = DateTime.now();

      // Filter events theo timeframe đã chọn
        final filteredEvents = events.where((e) {
          switch (selectedTimeFrame) {
            case RevenueTimeFrame.today:
              return e.startTime.year == now.year &&
                  e.startTime.month == now.month &&
                  e.startTime.day == now.day;
            case RevenueTimeFrame.week:
              final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
              final endOfWeek = startOfWeek.add(const Duration(days: 6));
              return e.startTime.isAfter(startOfWeek.subtract(const Duration(days: 1))) &&
                  e.startTime.isBefore(endOfWeek.add(const Duration(days: 1)));
            case RevenueTimeFrame.month:
              return e.startTime.year == selectedMonth.year && e.startTime.month == selectedMonth.month;
            case RevenueTimeFrame.alltime:
              return true;
            case RevenueTimeFrame.custom:
              return e.startTime.year == selectedMonth.year && e.startTime.month == selectedMonth.month;
          }
        }).toList();

      final eventsWithFinance = filteredEvents.where((e) => e.finance != null).toList();

      final totalArtistShare = eventsWithFinance.fold<double>(
        0,
        (sum, event) => sum + (event.finance!.revenue * 0.6),
      );

    return RefreshIndicator(
      onRefresh: () async {},
      color: AppColors.primary,
      backgroundColor: AppColors.surfaceDark,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tổng doanh thu nghệ sĩ nhận
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.2),
                    AppColors.success.withValues(alpha: 0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.person_outline, color: AppColors.primary, size: 14),
                      SizedBox(width: 6),
                      Text(
                        'Tổng doanh thu',
                        style: TextStyle(
                          color: AppColors.textDarkSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    NumberFormatter.formatCurrency(totalArtistShare),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Header danh sách sự kiện
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Danh sách sự kiện',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceDark,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.borderDark),
                  ),
                  child: Text(
                    '${eventsWithFinance.length} sự kiện',
                    style: const TextStyle(
                      color: AppColors.textDarkSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Danh sách sự kiện
            if (eventsWithFinance.isEmpty)
              _buildEmptyEvents()
            else
              ...eventsWithFinance.asMap().entries.map((entry) {
                final index = entry.key;
                final event = entry.value;
                final artistShare = event.finance!.revenue * 0.6;
                final isLast = index == eventsWithFinance.length - 1;

                return Container(
                  margin: EdgeInsets.only(bottom: isLast ? 0 : 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderDark, width: 1),
                  ),
                  child: Row(
                    children: [
                      // Số thứ tự
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Tên sự kiện
                      Expanded(
                        child: Text(
                          event.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),

                      // Số tiền nghệ sĩ nhận (60%)
                      Text(
                        NumberFormatter.formatCurrency(artistShare),
                        style: const TextStyle(
                          color: AppColors.success,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyEvents() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      width: double.infinity,
      child: Column(
        children: [
          Icon(
            Icons.event_busy_outlined,
            size: 48,
            color: AppColors.textDarkSecondary.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 12),
          Text(
            'Chưa có sự kiện nào',
            style: TextStyle(
              color: AppColors.textDarkSecondary.withValues(alpha: 0.6),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  // ─── ADMIN/MANAGER UI ─────────────────────────────────────────────────────────

  Widget _buildSummaryCards(RevenueStatsModel stats) {
    final artistShare = stats.totalRevenue * 0.6;
    final totalOutgoings = stats.totalExpenses + artistShare; 
    final netIncome = stats.totalRevenue - totalOutgoings;

    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            'Tổng thu',
            NumberFormatter.formatCurrency(stats.totalRevenue),
            AppColors.success,
            Icons.arrow_upward,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            'Tổng chi',
            NumberFormatter.formatCurrency(totalOutgoings),
            AppColors.error,
            Icons.arrow_downward,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            'Lợi nhuận',
            NumberFormatter.formatCurrency(netIncome),
            netIncome >= 0 ? AppColors.success : AppColors.error,
            netIncome >= 0 ? Icons.trending_up : Icons.trending_down,
              ),
            ),
          ],
        );
  }

  Widget _buildSummaryCard(String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.borderDark,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textDarkSecondary,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueByArtist(RevenueStatsModel stats, List<EventModel> events, RevenueTimeFrame selectedTimeFrame, DateTime selectedMonth) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderDark, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Doanh thu theo nghệ sĩ',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...stats.revenueByArtist.map((artistData) {
              final now = DateTime.now();

              // Lọc events theo artist + timeframe + có finance
              final artistEvents = events.where((e) {
                if (!e.artistIds.contains(artistData.artistId)) return false;
                if (e.finance == null) return false;

                switch (selectedTimeFrame) {
                  case RevenueTimeFrame.today:
                    return e.startTime.year == now.year &&
                        e.startTime.month == now.month &&
                        e.startTime.day == now.day;
                  case RevenueTimeFrame.week:
                    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
                    final endOfWeek = startOfWeek.add(const Duration(days: 6));
                    return e.startTime.isAfter(startOfWeek.subtract(const Duration(days: 1))) &&
                        e.startTime.isBefore(endOfWeek.add(const Duration(days: 1)));
                  case RevenueTimeFrame.month:
                    return e.startTime.year == selectedMonth.year &&
                        e.startTime.month == selectedMonth.month;
                  case RevenueTimeFrame.alltime:
                    return true;
                  case RevenueTimeFrame.custom:
                    return e.startTime.year == selectedMonth.year &&
                        e.startTime.month == selectedMonth.month;
                }
              }).toList();

              return _buildArtistRevenueRow(artistData, artistEvents);
            }).toList(),
          ],
        ),
      );
  }

  Widget _buildArtistRevenueRow(RevenueByArtist artistData, List<EventModel> artistEvents) {
      final artistShare = artistData.revenue * 0.6;
      final netIncome = artistData.revenue - artistData.expenses - artistShare;

      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tên nghệ sĩ + lợi nhuận
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    artistData.artistName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  NumberFormatter.formatCurrency(netIncome),
                  style: TextStyle(
                    color: netIncome >= 0 ? AppColors.success : AppColors.error,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Danh sách sự kiện
            if (artistEvents.isEmpty)
              Text(
                '${artistData.eventCount} sự kiện',
                style: const TextStyle(
                  color: AppColors.textDarkSecondary,
                  fontSize: 11,
                ),
              )
            else
              ...artistEvents.map((event) {
                final eventArtistShare = event.finance!.revenue * 0.6;
                final eventNetAmount =
                    event.finance!.revenue -
                    event.finance!.totalExpenses -
                    eventArtistShare;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              width: 4,
                              height: 4,
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: AppColors.textDarkSecondary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                event.title,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.textDarkSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        NumberFormatter.formatCurrency(eventNetAmount),
                        style: TextStyle(
                          color:
                              eventNetAmount >= 0
                                  ? AppColors.success
                                  : AppColors.error,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
          ],
        ),
      );
  }

  Widget _buildRevenueDetails(RevenueStatsModel stats) {
    final artistShare = stats.totalRevenue * 0.6;
    final netIncome = stats.totalRevenue - stats.totalExpenses - artistShare;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderDark, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Chi tiết',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildDetailRow(
            'Tổng doanh thu',
            NumberFormatter.formatCurrency(stats.totalRevenue),
            AppColors.success,
          ),
          const Divider(color: AppColors.borderDark, height: 24),
          _buildDetailRow(
            'Tổng chi phí',
            '- ${NumberFormatter.formatCurrency(stats.totalExpenses)}',
            AppColors.error,
          ),
          const Divider(color: AppColors.borderDark, height: 24),
          _buildDetailRow(
            'Nghệ sĩ nhận',
            '- ${NumberFormatter.formatCurrency(artistShare)}',
            AppColors.warning, // hoặc AppColors.primary tùy bạn
          ),
          const Divider(color: AppColors.borderDark, height: 24),
          _buildDetailRow(
            'Lợi nhuận ròng',
            NumberFormatter.formatCurrency(netIncome),
            netIncome >= 0 ? AppColors.success : AppColors.error,
            isBold: true,
          ),
          
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, Color valueColor, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.textDarkSecondary.withValues(alpha: 0.9),
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: isBold ? 16 : 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildError(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: AppColors.error),
          const SizedBox(height: 16),
          Text(
            'Có lỗi xảy ra',
            style: TextStyle(
              color: AppColors.textDarkSecondary.withValues(alpha: 0.7),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}