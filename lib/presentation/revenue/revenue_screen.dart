import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/number_formatter.dart';
import '../../data/models/dashboard_stats_model.dart';
import '../../providers/dashboard_provider.dart';
import '../home/widgets/revenue_chart.dart';

/// Revenue Screen - Detailed revenue analysis
class RevenueScreen extends ConsumerWidget {
  const RevenueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTimeFrame = ref.watch(selectedRevenueTimeFrameProvider);
    final revenueStats = ref.watch(revenueStatsProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(context),

            // Time Frame Selector
            _buildTimeFrameSelector(ref, selectedTimeFrame),

            // Content
            Expanded(
              child: revenueStats.when(
                data: (stats) => _buildRevenueContent(context, stats),
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                  ),
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

  Widget _buildTimeFrameSelector(WidgetRef ref, RevenueTimeFrame selectedTimeFrame) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: RevenueTimeFrame.values.take(3).map((timeFrame) {
          final isSelected = selectedTimeFrame == timeFrame;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: InkWell(
                onTap: () {
                  ref.read(selectedRevenueTimeFrameProvider.notifier).state = timeFrame;
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
                  child: Text(
                    timeFrame.displayName,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppColors.textDarkSecondary,
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRevenueContent(BuildContext context, RevenueStatsModel stats) {
    return RefreshIndicator(
      onRefresh: () async {
        // Invalidate to refresh
      },
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
              _buildRevenueByArtist(stats),
              const SizedBox(height: 24),
            ],

            // Details
            _buildRevenueDetails(stats),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards(RevenueStatsModel stats) {
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
            NumberFormatter.formatCurrency(stats.netIncome),
            stats.netIncome >= 0 ? AppColors.success : AppColors.error,
            stats.netIncome >= 0 ? Icons.trending_up : Icons.trending_down,
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
          Icon(
            icon,
            color: color,
            size: 20,
          ),
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

  Widget _buildRevenueByArtist(RevenueStatsModel stats) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.borderDark,
          width: 1,
        ),
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
            return _buildArtistRevenueRow(artistData);
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildArtistRevenueRow(RevenueByArtist artistData) {
    final percentage = (artistData.revenue / (artistData.revenue + artistData.expenses)) * 100;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                NumberFormatter.formatCurrency(artistData.netIncome),
                style: TextStyle(
                  color: artistData.netIncome >= 0 ? AppColors.success : AppColors.error,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: percentage / 100,
                    backgroundColor: AppColors.borderDark,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.success),
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${percentage.toStringAsFixed(0)}%',
                style: const TextStyle(
                  color: AppColors.textDarkSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${artistData.eventCount} sự kiện',
            style: const TextStyle(
              color: AppColors.textDarkSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueDetails(RevenueStatsModel stats) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.borderDark,
          width: 1,
        ),
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
          _buildDetailRow('Tổng doanh thu', NumberFormatter.formatCurrency(stats.totalRevenue), AppColors.success),
          const Divider(color: AppColors.borderDark, height: 24),
          _buildDetailRow('Tổng chi phí', NumberFormatter.formatCurrency(stats.totalExpenses), AppColors.error),
          const Divider(color: AppColors.borderDark, height: 24),
          _buildDetailRow(
            'Lợi nhuận ròng',
            NumberFormatter.formatCurrency(stats.netIncome),
            stats.netIncome >= 0 ? AppColors.success : AppColors.error,
            isBold: true,
          ),
          if (stats.revenueByDate.isNotEmpty) ...[
            const Divider(color: AppColors.borderDark, height: 24),
            _buildDetailRow(
              'Trung bình/ngày',
              NumberFormatter.formatCurrency(stats.averageDailyRevenue),
              AppColors.textDarkSecondary,
            ),
          ],
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
          const Icon(
            Icons.error_outline,
            size: 64,
            color: AppColors.error,
          ),
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
