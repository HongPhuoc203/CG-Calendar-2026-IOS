import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/enums/user_role.dart';
import '../../core/utils/number_formatter.dart';
import '../../data/models/dashboard_stats_model.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/auth_provider.dart';
import '../event_details/event_details_screen.dart';
import '../calendar/calendar_screen.dart';
import '../revenue/revenue_screen.dart';
import 'widgets/stat_card.dart';
import 'widgets/section_header.dart';
import 'widgets/compact_event_card.dart';
import 'widgets/revenue_chart.dart';

/// Home Screen - Dashboard with overview
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardStats = ref.watch(dashboardStatsProvider);
    final urgentEvents = ref.watch(urgentEventsProvider);
    final todayEvents = ref.watch(todayEventsProvider);
    final revenueStats = ref.watch(revenueStatsProvider);
    final currentUser = ref.watch(currentUserProfileProvider);
    final isViewer = currentUser.maybeWhen(
      data: (user) => user?.role == UserRole.viewer,
      orElse: () => false,
    );
    final isEditor = currentUser.maybeWhen(
      data: (user) => user?.role == UserRole.editor,
      orElse: () => false,
    );

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(dashboardStatsProvider);
            ref.invalidate(urgentEventsProvider);
            ref.invalidate(todayEventsProvider);
            ref.invalidate(revenueStatsProvider);
          },
          color: AppColors.primary,
          backgroundColor: AppColors.surfaceDark,
          child: CustomScrollView(
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: _buildHeader(context, currentUser.value),
              ),

              // Stats Cards
              SliverToBoxAdapter(
                child: dashboardStats.when(
                  data: (stats) => _buildStatsCards(
                    context,
                    stats,
                    isViewer: isViewer,
                    isEditor: isEditor,
                  ),
                  loading: () => _buildStatsCardsLoading(),
                  error: (error, stack) => _buildError(error.toString()),
                ),
              ),

              // Today's Events
              SliverToBoxAdapter(
                child: todayEvents.when(
                  data: (events) => _buildTodayEvents(context, ref, events),
                  loading: () => _buildSectionLoading(),
                  error: (error, stack) => const SizedBox.shrink(),
                ),
              ),

              // Urgent Tasks
              SliverToBoxAdapter(
                child: urgentEvents.when(
                  data: (events) => _buildUrgentTasks(context, ref, events),
                  loading: () => _buildSectionLoading(),
                  error: (error, stack) => const SizedBox.shrink(),
                ),
              ),

              // Revenue Chart (hidden for Editor)
              SliverToBoxAdapter(
                child: isEditor
                    ? const SizedBox.shrink()
                    : revenueStats.when(
                        data: (stats) => _buildRevenueSection(
                          context,
                          stats,
                          isViewer: isViewer,
                        ),
                        loading: () => _buildSectionLoading(),
                        error: (error, stack) => const SizedBox.shrink(),
                      ),
              ),

              // Bottom padding
              const SliverToBoxAdapter(
                child: SizedBox(height: 100),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, dynamic user) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Xin chào,',
                  style: TextStyle(
                    color: AppColors.textDarkSecondary.withValues(alpha: 0.8),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user?.displayName ?? 'User',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards(
    BuildContext context,
    DashboardStatsModel stats, {
    bool isViewer = false,
    bool isEditor = false,
  }) {
    final artistShare = stats.totalRevenue * 0.6;
    final totalExpenses = stats.totalExpenses + artistShare;
    final netIncome = stats.totalRevenue - totalExpenses;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: StatCard(
                  icon: Icons.event_available,
                  title: 'Sự kiện sắp tới',
                  value: '${stats.upcomingEventsCount}',
                  iconColor: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  icon: Icons.warning_amber_rounded,
                  title: 'Việc cần gấp',
                  value: '${stats.urgentTasksCount}',
                  iconColor: AppColors.error,
                  badge: stats.urgentTasksCount > 0
                      ? Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                          ),
                        )
                      : null,
                ),
              ),
            ],
          ),
          if (!isViewer && !isEditor) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    icon: Icons.trending_up,
                    title: 'Doanh thu',
                    value: NumberFormatter.formatCompact(stats.totalRevenue),
                    iconColor: AppColors.success,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    icon: Icons.account_balance_wallet,
                    title: 'Lợi nhuận',
                    value: NumberFormatter.formatCompact(netIncome),
                    iconColor: netIncome >= 0 ? AppColors.success : AppColors.error,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsCardsLoading() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildLoadingCard()),
              const SizedBox(width: 12),
              Expanded(child: _buildLoadingCard()),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildLoadingCard()),
              const SizedBox(width: 12),
              Expanded(child: _buildLoadingCard()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          color: AppColors.primary,
          strokeWidth: 2,
        ),
      ),
    );
  }

  Widget _buildTodayEvents(BuildContext context, WidgetRef ref, List events) {
    if (events.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        const SizedBox(height: 16),
        SectionHeader(
          title: 'Hôm nay',
          icon: Icons.today,
          actionText: 'Xem tất cả',
          onActionTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const CalendarScreen(),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: events.take(3).map((event) {
              return CompactEventCard(
                event: event,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EventDetailsScreen(event: event),
                    ),
                  );
                },
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildUrgentTasks(BuildContext context, WidgetRef ref, List events) {
    if (events.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        const SizedBox(height: 16),
        SectionHeader(
          title: 'Việc cần làm gấp',
          icon: Icons.warning_amber_rounded,
          actionText: 'Xem tất cả',
          onActionTap: () {},
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: events.take(3).map((event) {
              return CompactEventCard(
                event: event,
                showUrgentBadge: true,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EventDetailsScreen(event: event),
                    ),
                  );
                },
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildRevenueSection(
    BuildContext context,
    RevenueStatsModel stats, {
    bool isViewer = false,
  }) {
    final artistShare = stats.totalRevenue * 0.6;

    return Column(
      children: [
        const SizedBox(height: 16),
        SectionHeader(
          title: isViewer ? 'Thu nhập tháng này' : 'Doanh thu tháng này',
          icon: Icons.bar_chart,
          actionText: 'Chi tiết',
          onActionTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const RevenueScreen(),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        if (isViewer)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderDark, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Thu nhập tháng này',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Nghệ sĩ nhận (60%)',
                              style: TextStyle(
                                color: AppColors.textDarkSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          NumberFormatter.formatCompact(artistShare),
                          style: const TextStyle(
                            color: AppColors.success,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    const Divider(color: AppColors.borderDark, height: 1),
                    const SizedBox(height: 16),

                    // Mini bar chart
                    if (stats.revenueByDate.isNotEmpty)
                      _buildViewerMiniChart(stats)
                    else
                      const SizedBox(height: 60),
                  ],
                ),
              ),
            )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: RevenueChart(
              revenueStats: stats,
              showExpenses: true,
            ),
          ),
      ],
    );
  }

  Widget _buildSectionLoading() {
    return const Padding(
      padding: EdgeInsets.all(32),
      child: Center(
        child: CircularProgressIndicator(
          color: AppColors.primary,
          strokeWidth: 2,
        ),
      ),
    );
  }

  Widget _buildError(String error) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline,
            size: 48,
            color: AppColors.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Có lỗi xảy ra',
            style: TextStyle(
              color: AppColors.textDarkSecondary.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewerMiniChart(RevenueStatsModel stats) {
    final maxRevenue = stats.revenueByDate
        .map((e) => e.revenue * 0.6)
        .reduce((a, b) => a > b ? a : b);

    const maxBarHeight = 70.0;

    return SizedBox(
      height: 110, // tăng chiều cao để chứa label số tiền
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: stats.revenueByDate.map((data) {
          final artistAmount = data.revenue * 0.6;
          final barHeight = maxRevenue > 0
              ? (artistAmount / maxRevenue) * maxBarHeight
              : 4.0;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Số tiền bé trên đầu cột
                  Text(
                    NumberFormatter.formatCompact(artistAmount),
                    style: const TextStyle(
                      color: AppColors.success,
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 2),

                  // Bar
                  Container(
                    height: barHeight.clamp(4.0, maxBarHeight),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Ngày
                  Text(
                    '${data.date.day}/${data.date.month}',
                    style: const TextStyle(
                      color: AppColors.textDarkSecondary,
                      fontSize: 9,
                    ),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

}
