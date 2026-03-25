import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/enums/user_role.dart';
import '../../providers/auth_provider.dart';
import '../../providers/artists_provider.dart';
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

