import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/dashboard_stats_model.dart';
import '../../../core/utils/number_formatter.dart';

/// Revenue chart widget using fl_chart
class RevenueChart extends StatelessWidget {
  final RevenueStatsModel revenueStats;
  final bool showExpenses;

  const RevenueChart({
    super.key,
    required this.revenueStats,
    this.showExpenses = true,
  });

  @override
  Widget build(BuildContext context) {
    if (revenueStats.revenueByDate.isEmpty) {
      return _buildEmptyState();
    }

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Biểu đồ doanh thu',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  _buildLegendItem('Thu', AppColors.success),
                  if (showExpenses) ...[
                    const SizedBox(width: 12),
                    _buildLegendItem('Chi', AppColors.error),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: LineChart(
              _buildLineChartData(),
              duration: const Duration(milliseconds: 250),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textDarkSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.borderDark,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.show_chart,
            size: 48,
            color: AppColors.textDarkSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(
            'Chưa có dữ liệu doanh thu',
            style: TextStyle(
              color: AppColors.textDarkSecondary.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  LineChartData _buildLineChartData() {
    final spots = <FlSpot>[];
    final expenseSpots = <FlSpot>[];

    for (var i = 0; i < revenueStats.revenueByDate.length; i++) {
      final data = revenueStats.revenueByDate[i];
      spots.add(FlSpot(i.toDouble(), data.revenue));
      if (showExpenses) {
        expenseSpots.add(FlSpot(i.toDouble(), data.expenses));
      }
    }

    // Calculate max Y value for scaling
    double maxY = 0;
    for (final data in revenueStats.revenueByDate) {
      if (data.revenue > maxY) maxY = data.revenue;
      if (showExpenses && data.expenses > maxY) maxY = data.expenses;
    }
    
    // Add some padding to max
    maxY = maxY * 1.2;
    if (maxY == 0) maxY = 1000000; // Default if no data

    return LineChartData(
      minX: 0,
      maxX: (revenueStats.revenueByDate.length - 1).toDouble(),
      minY: 0,
      maxY: maxY,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: maxY / 5,
        getDrawingHorizontalLine: (value) {
          return FlLine(
            color: AppColors.borderDark,
            strokeWidth: 1,
          );
        },
      ),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 50,
            getTitlesWidget: (value, meta) {
              return Text(
                NumberFormatter.formatCompact(value),
                style: const TextStyle(
                  color: AppColors.textDarkSecondary,
                  fontSize: 10,
                ),
              );
            },
          ),
        ),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            interval: (revenueStats.revenueByDate.length / 7).ceilToDouble(),
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index >= 0 && index < revenueStats.revenueByDate.length) {
                final date = revenueStats.revenueByDate[index].date;
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    DateFormat('dd/MM').format(date),
                    style: const TextStyle(
                      color: AppColors.textDarkSecondary,
                      fontSize: 10,
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (touchedSpot) => AppColors.backgroundDark,
          tooltipPadding: const EdgeInsets.all(8),
          tooltipRoundedRadius: 8,
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((spot) {
              final date = revenueStats.revenueByDate[spot.x.toInt()].date;
              final isRevenue = spot.barIndex == 0;
              
              return LineTooltipItem(
                '${DateFormat('dd/MM').format(date)}\n',
                const TextStyle(
                  color: AppColors.textDarkSecondary,
                  fontSize: 10,
                ),
                children: [
                  TextSpan(
                    text: '${isRevenue ? "Thu" : "Chi"}: ',
                    style: TextStyle(
                      color: isRevenue ? AppColors.success : AppColors.error,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextSpan(
                    text: NumberFormatter.formatCurrency(spot.y),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              );
            }).toList();
          },
        ),
      ),
      lineBarsData: [
        // Revenue line
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: AppColors.success,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: spots.length <= 10,
            getDotPainter: (spot, percent, barData, index) {
              return FlDotCirclePainter(
                radius: 4,
                color: AppColors.success,
                strokeWidth: 2,
                strokeColor: AppColors.backgroundDark,
              );
            },
          ),
          belowBarData: BarAreaData(
            show: true,
            color: AppColors.success.withValues(alpha: 0.1),
          ),
        ),
        // Expenses line
        if (showExpenses)
          LineChartBarData(
            spots: expenseSpots,
            isCurved: true,
            color: AppColors.error,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: expenseSpots.length <= 10,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: AppColors.error,
                  strokeWidth: 2,
                  strokeColor: AppColors.backgroundDark,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.error.withValues(alpha: 0.1),
            ),
          ),
      ],
    );
  }
}
