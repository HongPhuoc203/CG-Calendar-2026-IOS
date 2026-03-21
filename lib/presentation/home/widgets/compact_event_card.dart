import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/artist_model.dart';
import '../../../data/models/event_model.dart';
import '../../../providers/artists_provider.dart';

/// Compact event card for dashboard lists
class CompactEventCard extends ConsumerWidget {
  final EventModel event;
  final VoidCallback? onTap;
  final bool showUrgentBadge;

  const CompactEventCard({
    super.key,
    required this.event,
    this.onTap,
    this.showUrgentBadge = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artistsAsync = ref.watch(artistsByIdsProvider(event.artistIds));
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(12),
          border: Border(
            left: BorderSide(
              color: showUrgentBadge 
                  ? AppColors.error 
                  : AppColors.artistColors[event.artistIds.length % AppColors.artistColors.length],
              width: 4,
            ),
          ),
        ),
        child: Row(
          children: [
            // Time
            Container(
              width: 60,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              decoration: BoxDecoration(
                color: AppColors.backgroundDark,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    DateFormat('HH:mm').format(event.startTime),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    DateFormat('dd/MM').format(event.startTime),
                    style: const TextStyle(
                      color: AppColors.textDarkSecondary,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          event.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (showUrgentBadge)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'GẤP',
                            style: TextStyle(
                              color: AppColors.error,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (event.location != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 12,
                          color: AppColors.textDarkSecondary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            event.location!,
                            style: const TextStyle(
                              color: AppColors.textDarkSecondary,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  
                  // Artists
                  artistsAsync.when(
                    data: (artists) {
                      if (artists.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: artists.take(2).map((artist) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: artist.color.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: artist.color.withValues(alpha: 0.5),
                                ),
                              ),
                              child: Text(
                                artist.name,
                                style: TextStyle(
                                  color: artist.color,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  
                  // Checklist progress
                  if (event.checklistItems.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.checklist_rounded,
                          size: 12,
                          color: _getChecklistColor(event),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${_getCompletedCount(event)}/${event.checklistItems.length}',
                          style: TextStyle(
                            color: _getChecklistColor(event),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            
            // Arrow
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

  int _getCompletedCount(EventModel event) {
    return event.checklistItems.where((item) => item.isCompleted).length;
  }

  Color _getChecklistColor(EventModel event) {
    final completed = _getCompletedCount(event);
    final total = event.checklistItems.length;
    
    if (completed == total) return AppColors.success;
    if (completed > total / 2) return AppColors.warning;
    return AppColors.error;
  }
}
