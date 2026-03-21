import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/artist_model.dart';
import '../../providers/artists_provider.dart';
import '../../providers/repositories_providers.dart';

/// Artist Management Screen - CRUD operations for artists
class ArtistManagementScreen extends ConsumerWidget {
  const ArtistManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artistsAsync = ref.watch(artistsStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: artistsAsync.when(
        data: (artists) {
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(artistsStreamProvider);
            },
            child: artists.isEmpty
                ? _buildEmptyState(context, ref)
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: artists.length,
                    itemBuilder: (context, index) {
                      return _ArtistCard(artist: artists[index]);
                    },
                  ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (error, stack) => Center(
          child: Text(
            'Error: $error',
            style: const TextStyle(color: AppColors.error),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateArtistDialog(context, ref),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_off,
            size: 64,
            color: AppColors.textDarkSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No artists yet',
            style: TextStyle(
              color: AppColors.textDarkSecondary.withValues(alpha: 0.7),
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showCreateArtistDialog(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('Create First Artist'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateArtistDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => const _ArtistFormDialog(),
    );
  }
}

/// Card displaying artist information
class _ArtistCard extends ConsumerWidget {
  final ArtistModel artist;

  const _ArtistCard({required this.artist});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ArtistModelX(artist).color,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: ArtistModelX(artist).color.withValues(alpha: 0.2),
            child: Text(
              artist.name.substring(0, 1).toUpperCase(),
              style: TextStyle(
                color: ArtistModelX(artist).color,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  artist.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: ArtistModelX(artist).color,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      artist.colorHex,
                      style: const TextStyle(
                        color: AppColors.textDarkSecondary,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, size: 20),
            color: AppColors.primary,
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => _ArtistFormDialog(artist: artist),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete, size: 20),
            color: AppColors.error,
            onPressed: () => _showDeleteDialog(context, ref),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: const Text('Delete Artist?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to delete ${artist.name}? This action cannot be undone.',
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
                final artistRepo = ref.read(artistRepositoryProvider);
                await artistRepo.deleteArtist(artist.id);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Artist deleted'),
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
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

/// Dialog for creating/editing artist
class _ArtistFormDialog extends ConsumerStatefulWidget {
  final ArtistModel? artist;

  const _ArtistFormDialog({this.artist});

  @override
  ConsumerState<_ArtistFormDialog> createState() => _ArtistFormDialogState();
}

class _ArtistFormDialogState extends ConsumerState<_ArtistFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String _selectedColor = AppColors.artistColors[0].value.toRadixString(16).substring(2);
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.artist != null) {
      _nameController.text = widget.artist!.name;
      _selectedColor = widget.artist!.colorHex.replaceFirst('#', '');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.artist != null;

    return AlertDialog(
      backgroundColor: AppColors.surfaceDark,
      title: Text(
        isEditing ? 'Edit Artist' : 'Create Artist',
        style: const TextStyle(color: Colors.white),
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Artist Name',
                hintText: 'Enter artist name',
                labelStyle: TextStyle(color: AppColors.textDarkSecondary),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter artist name';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            const Text(
              'Color:',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AppColors.artistColors.map((color) {
                final colorCode = color.value.toRadixString(16).substring(2);
                final isSelected = _selectedColor == colorCode;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedColor = colorCode;
                    });
                  },
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.transparent,
                        width: 3,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 24)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            Text(
              '#$_selectedColor',
              style: const TextStyle(
                color: AppColors.textDarkSecondary,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
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
          onPressed: _isLoading ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
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
              : Text(isEditing ? 'Update' : 'Create'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final artistRepo = ref.read(artistRepositoryProvider);
      
      final artist = ArtistModel(
        id: widget.artist?.id ?? const Uuid().v4(),
        name: _nameController.text.trim(),
        colorHex: '#$_selectedColor',
        createdAt: widget.artist?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (widget.artist != null) {
        await artistRepo.updateArtist(artist);
      } else {
        await artistRepo.createArtist(artist);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.artist != null ? 'Artist updated' : 'Artist created'),
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
