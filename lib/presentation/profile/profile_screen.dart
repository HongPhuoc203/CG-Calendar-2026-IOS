import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/enums/user_role.dart';
import '../../providers/auth_provider.dart';
import '../../providers/services_providers.dart';
import '../admin/admin_panel_screen.dart';
import '../export/export_revenue_screen.dart';
import '../../core/utils/logger.dart';
import '../helper/help_screen.dart';
import 'personal_info_screen.dart';

/// Profile Screen
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: currentUser.when(
          data: (user) => _buildProfileContent(context, ref, user),
          loading: () => const Center(
            child: CircularProgressIndicator(
              color: AppColors.primary,
            ),
          ),
          error: (error, stack) => Center(
            child: Text(
              'Có lỗi xảy ra',
              style: TextStyle(
                color: AppColors.textDarkSecondary.withValues(alpha: 0.7),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileContent(BuildContext context, WidgetRef ref, dynamic user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 24),

          // Avatar & Name
          CircleAvatar(
            radius: 50,
            backgroundColor: AppColors.primary.withValues(alpha: 0.2),
            backgroundImage: user?.photoUrl != null ? NetworkImage(user!.photoUrl) : null,
            child: user?.photoUrl == null
                ? Text(
                    user?.displayName?.substring(0, 1).toUpperCase() ?? 'U',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 16),

          Text(
            user?.displayName ?? 'User',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),

          Text(
            user?.email ?? '',
            style: TextStyle(
              color: AppColors.textDarkSecondary.withValues(alpha: 0.8),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),

          // Role Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.primary,
                width: 1,
              ),
            ),
            child: Text(
              user?.role.displayName ?? '',
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Menu Items
          _buildMenuItem(
            icon: Icons.person_outline,
            title: 'Thông tin cá nhân',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PersonalInfoScreen(),
                ),
              );
            },
          ),

          _buildMenuItem(
            icon: Icons.notifications_outlined,
            title: 'Cài đặt thông báo',
            onTap: () {
              _showNotificationTestDialog(context, ref);
            },
          ),

          if (user?.role == UserRole.superEditor)
            _buildMenuItem(
              icon: Icons.admin_panel_settings,
              title: 'Quản trị hệ thống',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AdminPanelScreen(),
                  ),
                );
              },
              iconColor: AppColors.warning,
            ),

          if (user?.role == UserRole.superEditor)
            _buildMenuItem(
              icon: Icons.table_chart_outlined,
              title: 'Xuất file Doanh thu',
              subtitle: 'Xuất báo cáo Excel tổng hợp',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ExportRevenueScreen(),
                  ),
                );
              },
              iconColor: AppColors.success,
            ),

          _buildMenuItem(
            icon: Icons.help_outline,
            title: 'Trợ giúp ',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const HelpScreen(),
                ),
              );
            },
          ),

          _buildMenuItem(
            icon: Icons.info_outline,
            title: 'Về ứng dụng',
            onTap: () {
              _showAboutDialog(context);
            },
          ),

          const SizedBox(height: 16),

          // Logout Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _logout(context, ref),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.logout),
              label: const Text(
                'Đăng xuất',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Version
          Text(
            'Phiên bản 1.0.0',
            style: TextStyle(
              color: AppColors.textDarkSecondary.withValues(alpha: 0.5),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? iconColor,
    String? subtitle,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.borderDark,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (iconColor ?? AppColors.primary).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: iconColor ?? AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.textDarkSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppColors.textDarkSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _showNotificationTestDialog(BuildContext context, WidgetRef ref) {
    final scheduler = ref.read(localNotificationSchedulerProvider);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: const Text(
          '🔔 Kiểm tra thông báo',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Chọn loại test để kiểm tra hệ thống thông báo:',
          style: TextStyle(color: AppColors.textDarkSecondary),
        ),
        actions: [
          // Test ngay lập tức
          TextButton.icon(
            icon: const Icon(Icons.bolt, color: AppColors.primary),
            label: const Text(
              'Test ngay',
              style: TextStyle(color: AppColors.primary),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final sent = await scheduler.sendTestNotification();
              if (!context.mounted) return;
              if (sent) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Đã gửi test notification! Kiểm tra thanh thông báo.'),
                    backgroundColor: AppColors.success,
                    duration: Duration(seconds: 4),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Vui lòng bật quyền thông báo trong Cài đặt (Thông báo) để test.'),
                    backgroundColor: AppColors.warning,
                    duration: Duration(seconds: 5),
                  ),
                );
              }
            },
          ),
          // Test sau 1 phút
          TextButton.icon(
            icon: const Icon(Icons.schedule, color: AppColors.warning),
            label: const Text(
              'Test sau 1 phút',
              style: TextStyle(color: AppColors.warning),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final scheduled = await scheduler.sendScheduledTestNotification();
              if (!context.mounted) return;
              if (scheduled) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('⏰ Đã lên lịch test notification sau 1 phút!'),
                    backgroundColor: AppColors.warning,
                    duration: Duration(seconds: 4),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Vui lòng bật quyền thông báo trong Cài đặt (Thông báo) để lên lịch.'),
                    backgroundColor: AppColors.warning,
                    duration: Duration(seconds: 5),
                  ),
                );
              }
            },
          ),
          // Tắt battery optimization
          TextButton.icon(
            icon: const Icon(Icons.battery_charging_full, color: Colors.orange),
            label: const Text(
              'Tắt Battery Opt.',
              style: TextStyle(color: Colors.orange),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await scheduler.requestBatteryOptimizationExemption();
            },
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: const Text(
          'CG Calendar',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Ứng dụng quản lý lịch trình công việc và doanh thu cho nghệ sĩ.\n\nPhiên bản 1.0.0',
          style: TextStyle(color: AppColors.textDarkSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    try {
      final authService = ref.read(authServiceProvider);
      await authService.signOut();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã đăng xuất thành công'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      logger.e('Logout error', error: e);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi đăng xuất: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}
