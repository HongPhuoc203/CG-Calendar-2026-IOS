import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/number_formatter.dart';
import '../../data/models/artist_model.dart';
import '../../data/models/dashboard_stats_model.dart';
import '../../data/models/event_model.dart';
import '../../providers/artists_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/events_provider.dart';
import '../home/widgets/revenue_chart.dart';

/// Revenue Screen - Detailed revenue analysis for DBA only
class DBARevenueScreen extends ConsumerWidget {
  const DBARevenueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTimeFrame = ref.watch(selectedRevenueTimeFrameProvider);
    final selectedMonth = ref.watch(selectedRevenueMonthProvider);
    final revenueStats = ref.watch(revenueStatsProvider);
    final eventsAsync = ref.watch(eventsStreamProvider);
    final artistsAsync = ref.watch(artistsStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(context),

            // Time Frame Selector
            _buildTimeFrameSelector(context, ref, selectedTimeFrame, selectedMonth),

            // Content
            Expanded(
              child: revenueStats.when(
                data: (stats) {
                  // Đợi cả events và artists load xong
                  if (eventsAsync.isLoading || artistsAsync.isLoading) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    );
                  }

                  return _buildRevenueContent(
                    context,
                    ref,
                    stats,
                    events: eventsAsync.value ?? [],
                    artists: artistsAsync.value ?? [],
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
            'Doanh thu DBA',
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
                onTap: () async {
                  if (timeFrame == RevenueTimeFrame.month && isSelected) {
                    // Show month year picker using a bottom sheet
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
    WidgetRef ref,
    RevenueStatsModel stats, {
    List<EventModel> events = const [],
    List<ArtistModel> artists = const [],
    required RevenueTimeFrame selectedTimeFrame,
    required DateTime selectedMonth,
  }) {
    // 1. Tìm Artist ID của DBA để lọc chính xác
    final dbaArtist = artists.where((a) => a.name.trim().toUpperCase() == 'DBA').firstOrNull;
    final dbaId = dbaArtist?.id;

    // 2. Lọc sự kiện của DBA theo TimeFrame và tính toán lại stats
    final now = DateTime.now();
    final dbaEvents = events.where((e) {
      final isDBA = (dbaId != null && e.artistIds.contains(dbaId)) || 
                   e.title.toUpperCase().contains('DBA');
      if (!isDBA) return false;

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

    // 3. Khởi tạo lại dbaOnlyStats với dữ liệu đã lọc để hiển thị biểu đồ
    double dbaTotalRevenue = 0;
    double dbaTotalExpenses = 0;
    Map<DateTime, RevenueByDate> dbaRevenueByDateMap = {};

    for (var e in dbaEvents) {
      if (e.finance != null) {
        final rev = e.finance!.revenue;
        final exp = e.finance!.totalExpenses;
        dbaTotalRevenue += rev;
        dbaTotalExpenses += exp;

        final dateKey = DateTime(e.startTime.year, e.startTime.month, e.startTime.day);
        final existing = dbaRevenueByDateMap[dateKey];
        if (existing != null) {
          dbaRevenueByDateMap[dateKey] = existing.copyWith(
            revenue: existing.revenue + rev,
            expenses: existing.expenses + exp,
          );
        } else {
          dbaRevenueByDateMap[dateKey] = RevenueByDate(
            date: dateKey,
            revenue: rev,
            expenses: exp,
          );
        }
      }
    }

    final dbaRevenueByDate = dbaRevenueByDateMap.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final dbaOnlyStats = RevenueStatsModel(
      totalRevenue: dbaTotalRevenue,
      totalExpenses: dbaTotalExpenses,
      revenueByDate: dbaRevenueByDate,
      revenueByArtist: [
        RevenueByArtist(
          artistId: dbaId ?? '',
          artistName: 'DBA',
          revenue: dbaTotalRevenue,
          expenses: dbaTotalExpenses,
          eventCount: dbaEvents.length,
        )
      ],
    );

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(revenueStatsProvider);
      },
      color: AppColors.primary,
      backgroundColor: AppColors.surfaceDark,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Summary Cards cho DBA
            _buildSummaryCards(dbaOnlyStats),
            const SizedBox(height: 24),

            // Chart cho DBA
            RevenueChart(
              revenueStats: dbaOnlyStats,
              showExpenses: true,
            ),
            const SizedBox(height: 24),

            // Chi tiết doanh thu (0% share)
            _buildRevenueDetails(dbaOnlyStats),
            const SizedBox(height: 24),

            // Danh sách sự kiện của DBA
            _buildDBAEventList(dbaEvents),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards(RevenueStatsModel stats) {
    // Với DBA, lợi nhuận = Doanh thu - Chi phí (Artist Share = 0)
    final netIncome = stats.totalRevenue - stats.totalExpenses;

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
            NumberFormatter.formatCurrency(stats.totalExpenses),
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

  Widget _buildRevenueDetails(RevenueStatsModel stats) {
    // Tỷ lệ chia cho DBA mặc định là 0%
    final netIncome = stats.totalRevenue - stats.totalExpenses;

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
            'Chi tiết doanh thu DBA',
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
            'Tổng chi phí vận hành',
            '- ${NumberFormatter.formatCurrency(stats.totalExpenses)}',
            AppColors.error,
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

  Widget _buildDBAEventList(List<EventModel> events) {
    if (events.isEmpty) return _buildEmptyEvents();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Danh sách sự kiện DBA',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...events.map((event) {
          final revenue = event.finance?.revenue ?? 0;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderDark, width: 1),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '${event.startTime.day}/${event.startTime.month}/${event.startTime.year}',
                        style: const TextStyle(
                          color: AppColors.textDarkSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  NumberFormatter.formatCurrency(revenue),
                  style: const TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
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
            'Chưa có sự kiện nào của DBA',
            style: TextStyle(
              color: AppColors.textDarkSecondary.withValues(alpha: 0.6),
              fontSize: 14,
            ),
          ),
        ],
      ),
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
