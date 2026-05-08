import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/enums/user_role.dart';
import '../../data/models/user_model.dart';
import '../../providers/repositories_providers.dart';
import '../../providers/artists_provider.dart';

/// Provider for all users stream
final allUsersStreamProvider = StreamProvider<List<UserModel>>((ref) {
  final userRepo = ref.watch(userRepositoryProvider);
  return userRepo.streamAllUsers();
});

/// User Management Screen - Manage users and assign roles
class UserManagementScreen extends ConsumerWidget {
  const UserManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(allUsersStreamProvider);

    return usersAsync.when(
      data: (users) {
        // Sort users: Guest first, then alphabetical by name
        final sortedUsers = List<UserModel>.from(users)..sort((a, b) {
          if (a.role == UserRole.guest && b.role != UserRole.guest) return -1;
          if (a.role != UserRole.guest && b.role == UserRole.guest) return 1;
          return (a.displayName ?? '').compareTo(b.displayName ?? '');
        });

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(allUsersStreamProvider);
          },
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader(
                  'Quản lý người dùng',
                  '${sortedUsers.length} thành viên',
                  AppColors.primary,
                ),
                const SizedBox(height: 16),
                if (sortedUsers.isEmpty)
                  const Center(
                    child: Text(
                      'Không có người dùng nào',
                      style: TextStyle(color: AppColors.textDarkSecondary),
                    ),
                  )
                else
                  ...sortedUsers.map((user) => _ActiveUserCard(user: user)),
              ],
            ),
          ),
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              'Error: $error',
              style: const TextStyle(color: AppColors.error),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle, Color color) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                color: AppColors.textDarkSecondary.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Dialog for editing user role and assignments
class _EditUserDialog extends ConsumerStatefulWidget {
  final UserModel user;

  const _EditUserDialog({required this.user});

  @override
  ConsumerState<_EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends ConsumerState<_EditUserDialog> {
  late UserRole _selectedRole;
  String? _selectedArtistId;
  List<String> _selectedManagedArtistIds = [];
  bool _isLoading = false;
  bool _canViewRevenue = false;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.user.role == UserRole.guest ? UserRole.viewer : widget.user.role;
    _selectedArtistId = widget.user.artistId;
    _selectedManagedArtistIds = List.from(widget.user.managedArtistIds);
    _canViewRevenue = widget.user.canViewRevenue;
  }

  @override
  Widget build(BuildContext context) {
    final artistsAsync = ref.watch(artistsStreamProvider);

    return AlertDialog(
      backgroundColor: AppColors.surfaceDark,
      title: const Text('Phân quyền người dùng', style: TextStyle(color: Colors.white)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.user.displayName ?? 'Unknown',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              widget.user.email,
              style: const TextStyle(
                color: AppColors.textDarkSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Chọn vai trò:',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ...[UserRole.viewer, UserRole.editor, UserRole.superEditor, UserRole.guest].map((role) {
              return RadioListTile<UserRole>(
                value: role,
                groupValue: _selectedRole,
                onChanged: (value) {
                  setState(() {
                    _selectedRole = value!;
                    if (_selectedRole != UserRole.viewer) _selectedArtistId = null;
                    if (_selectedRole != UserRole.editor) _selectedManagedArtistIds = [];
                  });
                },
                title: Text(
                  role.displayName,
                  style: const TextStyle(color: Colors.white),
                ),
                activeColor: AppColors.primary,
                contentPadding: EdgeInsets.zero,
              );
            }),
            const SizedBox(height: 16),
            // Artist selection for Viewer
            if (_selectedRole == UserRole.viewer)
              artistsAsync.when(
                data: (artists) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Gán nghệ sĩ:',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _selectedArtistId,
                        dropdownColor: AppColors.surfaceDark,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Chọn nghệ sĩ',
                          hintStyle: TextStyle(color: AppColors.textDarkSecondary),
                        ),
                        items: artists.map((artist) {
                          return DropdownMenuItem(
                            value: artist.id,
                            child: Text(artist.name),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedArtistId = value;
                          });
                        },
                      ),
                    ],
                  );
                },
                loading: () => const CircularProgressIndicator(),
                error: (_, __) => const Text('Error loading artists'),
              ),
            // Multi-artist selection for Editor
            if (_selectedRole == UserRole.editor)
              artistsAsync.when(
                data: (artists) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Quản lý nghệ sĩ:',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: artists.map((artist) {
                          final isSelected = _selectedManagedArtistIds.contains(artist.id);
                          return FilterChip(
                            selected: isSelected,
                            label: Text(artist.name),
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedManagedArtistIds.add(artist.id);
                                } else {
                                  _selectedManagedArtistIds.remove(artist.id);
                                }
                              });
                            },
                            selectedColor: AppColors.primary.withValues(alpha: 0.3),
                            checkmarkColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                          );
                        }).toList(),
                      ),
                    ],
                  );
                },
                loading: () => const CircularProgressIndicator(),
                error: (_, __) => const Text('Error loading artists'),
              ),
            // Quyền xem doanh thu — chỉ hiện khi role là Editor
            if (_selectedRole == UserRole.editor) ...[
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _canViewRevenue
                        ? AppColors.success.withValues(alpha: 0.4)
                        : AppColors.borderDark,
                  ),
                ),
                child: SwitchListTile(
                  value: _canViewRevenue,
                  onChanged: (v) => setState(() => _canViewRevenue = v),
                  activeColor: AppColors.success,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  title: const Text(
                    'Xem doanh thu',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    _canViewRevenue
                        ? 'Được phép xem doanh thu nghệ sĩ quản lý'
                        : 'Không được xem doanh thu',
                    style: TextStyle(
                      color: _canViewRevenue
                          ? AppColors.success
                          : AppColors.textDarkSecondary,
                      fontSize: 12,
                    ),
                  ),
                  secondary: Icon(
                    Icons.bar_chart_rounded,
                    color: _canViewRevenue
                        ? AppColors.success
                        : AppColors.textDarkSecondary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        if (widget.user.role != UserRole.superEditor)
          TextButton(
            onPressed: _isLoading ? null : _deleteUser,
            child: const Text('Xóa', style: TextStyle(color: AppColors.error)),
          ),
        ElevatedButton(
          onPressed: _isLoading ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
              : const Text('Cập nhật'),
        ),
      ],
    );
  }

  Future<void> _deleteUser() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: const Text('Xóa người dùng?', style: TextStyle(color: Colors.white)),
        content: Text('Bạn có chắc chắn muốn xóa ${widget.user.displayName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      final userRepo = ref.read(userRepositoryProvider);
      await userRepo.deleteUser(widget.user.id);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xóa người dùng')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    // Validation
    if (_selectedRole == UserRole.viewer && _selectedArtistId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn nghệ sĩ cho vai trò Nghệ sĩ'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_selectedRole == UserRole.editor && _selectedManagedArtistIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn ít nhất một nghệ sĩ quản lý'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userRepo = ref.read(userRepositoryProvider);
      
      final updatedUser = widget.user.copyWith(
        role: _selectedRole,
        artistId: _selectedRole == UserRole.viewer ? _selectedArtistId : null,
        managedArtistIds: _selectedRole == UserRole.editor
            ? _selectedManagedArtistIds
            : [],
        // Chỉ Editor mới có ý nghĩa; các role khác reset về false
        canViewRevenue: _selectedRole == UserRole.editor ? _canViewRevenue : false,
        updatedAt: DateTime.now(),
      );

      await userRepo.updateUser(updatedUser);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã cập nhật vai trò: ${_selectedRole.displayName}'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

/// Card for active user - with edit role action
class _ActiveUserCard extends ConsumerWidget {
  final UserModel user;

  const _ActiveUserCard({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artistsAsync = ref.watch(artistsStreamProvider);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: _getRoleColor(user.role).withValues(alpha: 0.2),
            child: Text(
              user.displayName?.substring(0, 1).toUpperCase() ?? 'U',
              style: TextStyle(
                color: _getRoleColor(user.role),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName ?? 'Unknown',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user.email,
                  style: const TextStyle(
                    color: AppColors.textDarkSecondary,
                    fontSize: 14,
                  ),
                ),
                // Show linked artists
                if (artistsAsync.hasValue) ...[
                  const SizedBox(height: 4),
                  _buildArtistInfo(artistsAsync.value!),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getRoleColor(user.role).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  user.role.displayName.toUpperCase(),
                  style: TextStyle(
                    color: _getRoleColor(user.role),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (user.role == UserRole.editor) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: user.canViewRevenue
                        ? AppColors.success.withValues(alpha: 0.15)
                        : AppColors.textDarkSecondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: user.canViewRevenue
                          ? AppColors.success.withValues(alpha: 0.4)
                          : AppColors.borderDark,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        user.canViewRevenue
                            ? Icons.bar_chart_rounded
                            : Icons.bar_chart_outlined,
                        size: 10,
                        color: user.canViewRevenue
                            ? AppColors.success
                            : AppColors.textDarkSecondary,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        user.canViewRevenue ? 'Xem DT' : 'No DT',
                        style: TextStyle(
                          color: user.canViewRevenue
                              ? AppColors.success
                              : AppColors.textDarkSecondary,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.edit, size: 20),
            color: AppColors.primary,
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => _EditUserDialog(user: user),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildArtistInfo(List<dynamic> artists) {
    String info = '';
    Color color = AppColors.textDarkSecondary;
    
    if (user.role == UserRole.viewer && user.artistId != null) {
      // Find artist name for viewer
      try {
        final matchedArtists = artists.where((a) => a.id == user.artistId).toList();
        if (matchedArtists.isNotEmpty) {
          final artist = matchedArtists.first;
          info = '🎨 Nghệ sĩ: ${artist.name}';
          color = AppColors.info.withValues(alpha: 0.8);
        }
      } catch (e) {
        // Artist not found
      }
    } else if (user.role == UserRole.editor && user.managedArtistIds.isNotEmpty) {
      // Find artist names for editor
      try {
        final managedArtists = artists.where(
          (a) => user.managedArtistIds.contains(a.id)
        ).toList();
        if (managedArtists.isNotEmpty) {
          final names = managedArtists.map((a) => a.name).join(', ');
          info = '👥 Quản lý: $names';
          color = AppColors.warning.withValues(alpha: 0.8);
        }
      } catch (e) {
        // Artists not found
      }
    }
    
    if (info.isEmpty) return const SizedBox.shrink();
    
    return Text(
      info,
      style: TextStyle(
        color: color,
        fontSize: 12,
        fontStyle: FontStyle.italic,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.viewer:
        return AppColors.info;
      case UserRole.editor:
        return AppColors.warning;
      case UserRole.superEditor:
        return AppColors.error;
      case UserRole.guest:
        return AppColors.textDarkSecondary;
    }
  }
}
