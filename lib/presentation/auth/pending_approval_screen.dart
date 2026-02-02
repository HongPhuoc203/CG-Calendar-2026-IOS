import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/services_providers.dart';

/// Pending Approval Screen - For users waiting for admin approval
class PendingApprovalScreen extends ConsumerWidget {
  const PendingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceDark,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.hourglass_empty,
                    size: 60,
                    color: AppColors.warning,
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Title
                Text(
                  'Đang Chờ Duyệt',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 16),
                
                // Description
                Text(
                  'Tài khoản của bạn đang được xem xét.\nVui lòng chờ quản trị viên phê duyệt.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.textDarkSecondary,
                      ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 48),
                
                // Info card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.borderDark,
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildInfoRow(
                        Icons.check_circle_outline,
                        'Đăng ký thành công',
                        AppColors.success,
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow(
                        Icons.schedule,
                        'Chờ phê duyệt',
                        AppColors.warning,
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow(
                        Icons.email_outlined,
                        'Sẽ nhận email khi được duyệt',
                        AppColors.info,
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Contact info
                Text(
                  'Thời gian duyệt: 1-2 ngày làm việc',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textDarkSecondary.withValues(alpha: 0.7),
                      ),
                ),
                
                const SizedBox(height: 8),
                
                TextButton.icon(
                  onPressed: () {
                    // TODO: Open contact/help
                  },
                  icon: const Icon(Icons.help_outline, size: 18),
                  label: const Text('Liên hệ hỗ trợ'),
                ),
                
                const SizedBox(height: 24),
                
                // Logout Button
                OutlinedButton.icon(
                  onPressed: () async {
                    try {
                      final authService = ref.read(authServiceProvider);
                      await authService.signOut();
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Lỗi đăng xuất: $e'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      }
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textDarkSecondary,
                    side: const BorderSide(color: AppColors.borderDark),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.logout, size: 20),
                  label: const Text('Đăng xuất'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: color,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}
