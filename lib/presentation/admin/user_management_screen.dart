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

/// User Management Screen - Manage users, approve pending, assign roles
class UserManagementScreen extends ConsumerWidget {
  const UserManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(allUsersStreamProvider);

    return usersAsync.when(
      data: (users) {
        final pendingUsers = users.where((u) => u.role == UserRole.pending).toList();
        final activeUsers = users.where((u) => u.role != UserRole.pending).toList();

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(allUsersStreamProvider);
          },
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (pendingUsers.isNotEmpty) ...[
                  _buildSectionHeader(
                    'Pending Approval',
                    '${pendingUsers.length} users waiting',
                    AppColors.warning,
                  ),
                  const SizedBox(height: 16),
                  ...pendingUsers.map((user) => _PendingUserCard(user: user)),
                  const SizedBox(height: 32),
                ],
                _buildSectionHeader(
                  'Active Users',
                  '${activeUsers.length} users',
                  AppColors.success,
                ),
                const SizedBox(height: 16),
                if (activeUsers.isEmpty)
                  const Center(
                    child: Text(
                      'No active users',
                      style: TextStyle(color: AppColors.textDarkSecondary),
                    ),
                  )
                else
                  ...activeUsers.map((user) => _ActiveUserCard(user: user)),
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

/// Card for pending user - with approve/reject actions
class _PendingUserCard extends ConsumerWidget {
  final UserModel user;

  const _PendingUserCard({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.warning.withValues(alpha: 0.2),
                child: Text(
                  user.displayName?.substring(0, 1).toUpperCase() ?? 'U',
                  style: const TextStyle(
                    color: AppColors.warning,
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
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'PENDING',
                  style: TextStyle(
                    color: AppColors.warning,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _showRejectDialog(context, ref),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                  ),
                  child: const Text('Reject'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _showApproveDialog(context, ref),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Approve'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showApproveDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => _ApproveUserDialog(user: user),
    );
  }

  void _showRejectDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: const Text('Reject User?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to reject ${user.displayName}?',
          style: const TextStyle(color: AppColors.textDarkSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final userRepo = ref.read(userRepositoryProvider);
                await userRepo.deleteUser(user.id);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('User rejected'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }
}

/// Dialog for approving user and assigning role
class _ApproveUserDialog extends ConsumerStatefulWidget {
  final UserModel user;

  const _ApproveUserDialog({required this.user});

  @override
  ConsumerState<_ApproveUserDialog> createState() => _ApproveUserDialogState();
}

class _ApproveUserDialogState extends ConsumerState<_ApproveUserDialog> {
  UserRole _selectedRole = UserRole.viewer;
  String? _selectedArtistId;
  List<String> _selectedManagedArtistIds = [];
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final artistsAsync = ref.watch(artistsStreamProvider);

    return AlertDialog(
      backgroundColor: AppColors.surfaceDark,
      title: const Text('Approve User', style: TextStyle(color: Colors.white)),
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
              'Select Role:',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ...[UserRole.viewer, UserRole.editor, UserRole.superEditor].map((role) {
              return RadioListTile<UserRole>(
                value: role,
                groupValue: _selectedRole,
                onChanged: (value) {
                  setState(() {
                    _selectedRole = value!;
                    // Reset selections when role changes
                    _selectedArtistId = null;
                    _selectedManagedArtistIds = [];
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
                        'Assign Artist:',
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
                          hintText: 'Select artist',
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
                        'Assign Managed Artists:',
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
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _approve,
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
              : const Text('Approve'),
        ),
      ],
    );
  }

  Future<void> _approve() async {
    // Validation
    if (_selectedRole == UserRole.viewer && _selectedArtistId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an artist for Viewer'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_selectedRole == UserRole.editor && _selectedManagedArtistIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one managed artist for Editor'),
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
        updatedAt: DateTime.now(),
      );

      await userRepo.updateUser(updatedUser);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.user.displayName} approved as ${_selectedRole.displayName}'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
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
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 4,
            ),
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
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.edit, size: 20),
            color: AppColors.primary,
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => _ApproveUserDialog(user: user),
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
      case UserRole.pending:
        return AppColors.textDarkSecondary;
    }
  }
}
