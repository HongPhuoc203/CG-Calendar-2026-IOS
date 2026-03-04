import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:badges/badges.dart' as badges;
import '../../core/constants/app_colors.dart';
import '../../core/utils/number_formatter.dart';
import '../../data/models/dashboard_stats_model.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/notifications_provider.dart';
import '../../providers/auth_provider.dart';
import '../event_details/event_details_screen.dart';
import '../notifications/notifications_screen.dart';
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
    final unreadCount = ref.watch(unreadNotificationsCountProvider);
    final currentUser = ref.watch(currentUserProfileProvider);

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
                child: _buildHeader(context, currentUser.value, unreadCount),
              ),

              // Stats Cards
              SliverToBoxAdapter(
                child: dashboardStats.when(
                  data: (stats) => _buildStatsCards(context, stats),
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

              // Revenue Chart
              SliverToBoxAdapter(
                child: revenueStats.when(
                  data: (stats) => _buildRevenueSection(context, stats),
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

  Widget _buildHeader(BuildContext context, dynamic user, AsyncValue<int> unreadCount) {
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
          // Notification Bell with Badge
          unreadCount.when(
            data: (count) => badges.Badge(
              position: badges.BadgePosition.topEnd(top: -4, end: -4),
              showBadge: count > 0,
              badgeContent: Text(
                count > 99 ? '99+' : count.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              badgeStyle: const badges.BadgeStyle(
                badgeColor: AppColors.error,
                padding: EdgeInsets.all(6),
              ),
              child: IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NotificationsScreen(),
                    ),
                  );
                },
                icon: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceDark,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.notifications_outlined,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
            loading: () => IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NotificationsScreen(),
                  ),
                );
              },
              icon: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.notifications_outlined,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards(BuildContext context, DashboardStatsModel stats) {
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
                  value: NumberFormatter.formatCompact(stats.netIncome),
                  iconColor: stats.netIncome >= 0 ? AppColors.success : AppColors.error,
                ),
              ),
            ],
          ),
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
            // Navigate to calendar with today selected
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
          onActionTap: () {
            // Navigate to urgent tasks view
          },
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

  Widget _buildRevenueSection(BuildContext context, RevenueStatsModel stats) {
    return Column(
      children: [
        const SizedBox(height: 16),
        SectionHeader(
          title: 'Doanh thu tháng này',
          icon: Icons.bar_chart,
          actionText: 'Chi tiết',
          onActionTap: () {
            // Navigate to revenue screen
          },
        ),
        const SizedBox(height: 8),
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
}
