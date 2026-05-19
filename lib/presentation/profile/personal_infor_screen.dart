import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/enums/user_role.dart';
import '../../core/utils/logger.dart';
import '../../providers/auth_provider.dart';
import '../../providers/artists_provider.dart';
import '../../providers/repositories_providers.dart';
import '../../providers/services_providers.dart';
import '../../data/models/artist_model.dart';

/// Show personal information of the current logged-in user.
class PersonalInfoScreen extends ConsumerWidget {
  const PersonalInfoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Thông tin cá nhân'),
      ),
      body: SafeArea(
        child: currentUser.when(
          data: (user) {
            if (user == null) {
              return const Center(
                child: Text(
                  'Không tìm thấy thông tin người dùng',
                  style: TextStyle(color: Colors.white),
                ),
              );
            }

            final roleLabel = user.role.displayName;
            final statusLabel = user.status.displayName;
            final isSuperEditor = user.role == UserRole.superEditor;
            final managedArtistIds = user.managedArtistIds;
            final managedArtistsAsync = ref.watch(artistsByIdsProvider(managedArtistIds));
            final allArtistsAsync = ref.watch(artistsProvider);
            final artistsAsync = isSuperEditor ? allArtistsAsync : managedArtistsAsync;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  _InfoCard(
                    title: 'Tài khoản',
                    children: [
                      _KeyValueRow(
                        label: 'Tên hiển thị',
                        value: (user.displayName ?? '—'),
                      ),
                      _KeyValueRow(
                        label: 'Email',
                        value: user.email,
                      ),
                      _KeyValueRow(
                        label: 'Trạng thái',
                        value: statusLabel,
                      ),
                      _KeyValueRow(
                        label: 'Vai trò',
                        value: roleLabel,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _InfoCard(
                    title: 'Quyền & liên kết',
                    children: [
                      artistsAsync.when(
                        data: (artists) => _KeyValueRow(
                          label: 'Danh sách quản lý',
                          value: isSuperEditor
                              ? 'ALL'
                              : user.role != UserRole.viewer
                                  ? _buildManagedArtistsLabel(
                                      artists: artists,
                                      fallbackIds: managedArtistIds,
                                    )
                                  : '—',
                        ),
                        loading: () => _KeyValueRow(
                          label: 'Danh sách quản lý',
                          value: isSuperEditor
                              ? 'ALL'
                              : user.role != UserRole.viewer
                                  ? 'Đang tải...'
                                  : '—',
                        ),
                        error: (_, __) => _KeyValueRow(
                          label: 'Danh sách quản lý',
                          value: isSuperEditor
                              ? 'ALL'
                              : user.role != UserRole.viewer
                                  ? _formatIdList(managedArtistIds)
                                  : '—',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _confirmDeleteAccount(context, ref),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.delete_forever_outlined),
                      label: const Text(
                        'Xóa tài khoản',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(
              color: AppColors.primary,
            ),
          ),
          error: (error, _) => Center(
            child: Text(
              'Có lỗi xảy ra',
              style: TextStyle(color: AppColors.textDarkSecondary.withValues(alpha: 0.8)),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteAccount(
      BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: const Text(
          'Xóa tài khoản?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Hành động này không thể hoàn tác.\n'
          'Tài khoản và toàn bộ dữ liệu của bạn sẽ bị xóa vĩnh viễn.',
          style: TextStyle(color: AppColors.textDarkSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Xóa vĩnh viễn'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    try {
      final authService = ref.read(authServiceProvider);
      final fcmService = ref.read(fcmServiceProvider);
      final userRepo = ref.read(userRepositoryProvider);
      final currentUser = authService.currentUser;

      if (currentUser != null) {
        try {
          final token = fcmService.fcmToken;
          if (token != null && token.isNotEmpty) {
            await userRepo.unregisterFcmToken(currentUser.uid, token);
          }
        } catch (_) {}

        await userRepo.deleteUser(currentUser.uid);
      }

      fcmService.onTokenChanged = null;
      await authService.deleteAccount();

      if (context.mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      logger.e('Delete account error', error: e);
      if (context.mounted) {
        final msg = e.toString().contains('requires-recent-login')
            ? 'Phiên đăng nhập đã cũ. Vui lòng đăng xuất và đăng nhập lại trước khi xóa tài khoản.'
            : 'Lỗi xóa tài khoản: $e';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  String _buildManagedArtistsLabel({
    required List<ArtistModel> artists,
    required List<String> fallbackIds,
  }) {
    final names = artists.map((a) => a.name).where((n) => n.trim().isNotEmpty).toList();
    if (names.isEmpty) return _formatIdList(fallbackIds);

    // Avoid huge lines if there are many artists.
    if (names.length <= 3) return names.join(', ');
    return '${names.take(3).join(', ')}... (+${names.length - 3} khác)';
  }

  String _formatIdList(List<String> ids) {
    if (ids.isEmpty) return '—';
    if (ids.length <= 3) return ids.join(', ');
    return '${ids.take(3).join(', ')}... (+${ids.length - 3} khác)';
  }

}

class _InfoCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _InfoCard({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderDark, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _KeyValueRow extends StatelessWidget {
  final String label;
  final String value;

  const _KeyValueRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              '$label:',
              style: TextStyle(
                color: AppColors.textDarkSecondary.withValues(alpha: 0.8),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

