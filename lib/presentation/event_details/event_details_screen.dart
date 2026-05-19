import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/enums/user_role.dart';
import '../../data/models/event_model.dart';
import '../../data/models/artist_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/artists_provider.dart';
import '../../providers/repositories_providers.dart';
import '../../providers/reminders_provider.dart';
import '../../providers/events_provider.dart';
import '../../data/models/reminder_model.dart';
import '../create_edit_event/create_edit_event_screen.dart';
import '../widgets/reminder_picker.dart';
import 'package:uuid/uuid.dart';
import '../../core/utils/number_formatter.dart';

/// Event Details Screen - Shows full event information with role-based permissions
class EventDetailsScreen extends ConsumerStatefulWidget {
  final EventModel event;
  final DateTime? selectedDate;

  const EventDetailsScreen({
    super.key,
    required this.event,
    this.selectedDate,
  });

  @override
  ConsumerState<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends ConsumerState<EventDetailsScreen> {
  late EventModel _currentEvent;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _currentEvent = widget.event;
  }

  Future<void> _toggleChecklistItem(ChecklistItem item) async {
    final currentUser = ref.read(authStateProvider).value;
    if (currentUser == null) return;

    setState(() {
      _isUpdating = true;
    });

    try {
      final updatedItems = _currentEvent.checklistItems.map((i) {
        if (i.id == item.id) {
          return i.copyWith(
            isCompleted: !i.isCompleted,
            completedAt: !i.isCompleted ? DateTime.now() : null,
            completedBy: !i.isCompleted ? currentUser.uid : null,
          );
        }
        return i;
      }).toList();

      final updatedEvent = _currentEvent.copyWith(
        checklistItems: updatedItems,
        updatedAt: DateTime.now(),
      );

      final eventRepo = ref.read(eventRepositoryProvider);
      await eventRepo.updateEvent(updatedEvent);

      setState(() {
        _currentEvent = updatedEvent;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(item.isCompleted ? 'Unchecked' : 'Checked'),
            duration: const Duration(seconds: 1),
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
      setState(() {
        _isUpdating = false;
      });
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot open link'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _deleteEvent() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: const Text(
          'Delete Event?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This action cannot be undone.',
          style: TextStyle(color: AppColors.textDarkSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final eventRepo = ref.read(eventRepositoryProvider);
        await eventRepo.deleteEvent(_currentEvent.id);

        // Force refresh events list
        ref.invalidate(eventsStreamProvider);

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Event deleted'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting event: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final artistsAsync = ref.watch(artistsByIdsProvider(_currentEvent.artistIds));
    final canEdit = ref.watch(canEditEventProvider(_currentEvent));
    final currentUserProfileAsync = ref.watch(currentUserProfileProvider);
    final isViewer = currentUserProfileAsync.maybeWhen(
      data: (user) => user?.role == UserRole.viewer,
      orElse: () => false,
    );

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Event Details',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (canEdit.value == true) ...[
            IconButton(
              icon: const Icon(Icons.edit, color: AppColors.primary),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CreateEditEventScreen(event: _currentEvent),
                  ),
                );
                // Refresh if event was updated
                if (result == true && mounted) {
                  // Reload event data
                  Navigator.pop(context); // Go back to calendar
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: AppColors.error),
              onPressed: _deleteEvent,
            ),
          ],
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            _buildHeaderSection(artistsAsync.value ?? []),

            const Divider(color: AppColors.borderDark, height: 1),

            // Details Section
            _buildDetailsSection(),

            // Checklist Section
            if (_currentEvent.checklistItems.isNotEmpty) ...[
              const Divider(color: AppColors.borderDark, height: 1),
              _buildChecklistSection(canEdit.value ?? false),
            ],

            // Custom Fields Section
            if (_currentEvent.customFields.isNotEmpty) ...[
              const Divider(color: AppColors.borderDark, height: 1),
              _buildCustomFieldsSection(),
            ],

            // Links Section
            if (!isViewer && _currentEvent.links.isNotEmpty) ...[
              const Divider(color: AppColors.borderDark, height: 1),
              _buildLinksSection(),
            ],

            // Notes Section
            if (_currentEvent.notes != null && _currentEvent.notes!.isNotEmpty) ...[
              const Divider(color: AppColors.borderDark, height: 1),
              _buildNotesSection(),
            ],

            // Reminders Section
            const Divider(color: AppColors.borderDark, height: 1),
            _buildRemindersSection(canEdit.value ?? false),

            // Finance Section
            if (_currentEvent.finance != null) ...[
              const Divider(color: AppColors.borderDark, height: 1),
              _buildFinanceSection(isViewer: isViewer),
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection(List<ArtistModel> artists) {
    return Container(
      padding: const EdgeInsets.all(24),
      color: AppColors.surfaceDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            _currentEvent.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Time
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.access_time,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatEventDate(_currentEvent),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (!_currentEvent.isAllDay)
                          Text(
                            '${DateFormat('HH:mm').format(_currentEvent.startTime)} - ${DateFormat('HH:mm').format(_currentEvent.endTime)}',
                            style: const TextStyle(
                              color: AppColors.textDarkSecondary,
                              fontSize: 14,
                            ),
                          ),
                        if (_currentEvent.isAllDay)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color:
                                  AppColors.primary.withValues(alpha: 0.5)),
                            ),
                            child: const Text(
                              'Cả ngày',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Location
          if (_currentEvent.location != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.location_on,
                    color: AppColors.info,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _currentEvent.location!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ],

          // Artists
          if (artists.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.people,
                    color: AppColors.warning,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: artists.map((artist) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: ArtistModelX(artist).color.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: ArtistModelX(artist).color,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          artist.name,
                          style: TextStyle(
                            color: ArtistModelX(artist).color,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailsSection() {
    if (_currentEvent.description == null || _currentEvent.description!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Description',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _currentEvent.description!,
            style: const TextStyle(
              color: AppColors.textDarkSecondary,
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChecklistSection(bool canEdit) {
    final completedCount = _currentEvent.checklistItems
        .where((item) => item.isCompleted)
        .length;
    final totalCount = _currentEvent.checklistItems.length;

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Checklist',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '$completedCount/$totalCount',
                style: TextStyle(
                  color: completedCount == totalCount
                      ? AppColors.success
                      : AppColors.textDarkSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: totalCount > 0 ? completedCount / totalCount : 0,
            backgroundColor: AppColors.surfaceDark,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.success),
          ),
          const SizedBox(height: 16),
          ...(_currentEvent.checklistItems.map((item) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(8),
              ),
              child: CheckboxListTile(
                value: item.isCompleted,
                onChanged: canEdit && !_isUpdating
                    ? (_) => _toggleChecklistItem(item)
                    : null,
                title: Text(
                  item.title,
                  style: TextStyle(
                    color: item.isCompleted
                        ? AppColors.textDarkSecondary
                        : Colors.white,
                    fontSize: 15,
                    decoration: item.isCompleted
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                  ),
                ),
                subtitle: item.completedAt != null
                    ? Text(
                  'Completed ${DateFormat('MMM d, HH:mm').format(item.completedAt!)}',
                  style: const TextStyle(
                    color: AppColors.textDarkSecondary,
                    fontSize: 12,
                  ),
                )
                    : null,
                activeColor: AppColors.success,
                checkColor: Colors.white,
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            );
          })),
          if (!canEdit) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: AppColors.textDarkSecondary.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 8),
                Text(
                  'View only - you don\'t have permission to edit',
                  style: TextStyle(
                    color: AppColors.textDarkSecondary.withValues(alpha: 0.7),
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCustomFieldsSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Additional Information',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ..._currentEvent.customFields.entries.map((entry) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      entry.key,
                      style: const TextStyle(
                        color: AppColors.textDarkSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 3,
                    child: Text(
                      entry.value.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildLinksSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Links & Documents',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ..._currentEvent.links.map((link) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () => _launchUrl(link.url),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceDark,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          link.type == 'drive'
                              ? Icons.folder_outlined
                              : Icons.link,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              link.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              link.url,
                              style: const TextStyle(
                                color: AppColors.textDarkSecondary,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.open_in_new,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildNotesSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Notes',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _currentEvent.notes!,
              style: const TextStyle(
                color: AppColors.textDarkSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRemindersSection(bool canEdit) {
    final remindersAsync = ref.watch(eventRemindersStreamProvider(_currentEvent.id));

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Thông báo',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (canEdit)
                IconButton(
                  icon: const Icon(Icons.add, color: AppColors.primary),
                  onPressed: () => _addReminders(),
                ),
            ],
          ),
          const SizedBox(height: 12),
          remindersAsync.when(
            data: (reminders) {
              if (reminders.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceDark,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.notifications_off_outlined,
                        color: AppColors.textDarkSecondary.withValues(alpha: 0.7),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Chưa có thông báo',
                        style: TextStyle(
                          color: AppColors.textDarkSecondary.withValues(alpha: 0.7),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: reminders.map((reminder) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceDark,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: reminder.isSent
                            ? AppColors.success.withValues(alpha: 0.3)
                            : AppColors.borderDark,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          reminder.isSent
                              ? Icons.check_circle
                              : Icons.notifications_active_outlined,
                          color: reminder.isSent ? AppColors.success : AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                reminder.displayText,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                DateFormat('d MMM, HH:mm').format(reminder.triggerTime),
                                style: const TextStyle(
                                  color: AppColors.textDarkSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (canEdit && !reminder.isSent)
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20),
                            color: AppColors.error,
                            onPressed: () => _deleteReminder(reminder.id),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) {
              return Text(
                'Lỗi: $error',
                style: const TextStyle(color: AppColors.error),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _addReminders() async {
    // Get current reminders first
    final currentRemindersAsync = ref.read(eventRemindersStreamProvider(_currentEvent.id));
    final currentReminders = currentRemindersAsync.value ?? [];

    // Convert to ReminderOption
    final selectedOptions = currentReminders.map((r) {
      return ReminderOption(
        label: r.displayText,
        value: r.value,
        unit: r.unit,
      );
    }).toList();

    await showReminderPicker(
      context: context,
      selectedReminders: selectedOptions,
      onRemindersChanged: (options) async {
        try {
          final reminderRepo = ref.read(reminderRepositoryProvider);

          // Delete all existing reminders
          await reminderRepo.deleteRemindersByEventId(_currentEvent.id);

          // Get all users who should receive reminders
          // For now, we'll notify all users who can view this event
          final currentUser = ref.read(authStateProvider).value;
          if (currentUser == null) return;

          // Create new reminders
          final reminders = options.map((option) {
            final triggerTime = _currentEvent.startTime.subtract(
              option.unit.toDuration(option.value),
            );

            return ReminderModel(
              id: const Uuid().v4(),
              eventId: _currentEvent.id,
              value: option.value,
              unit: option.unit,
              recipientUserIds: [currentUser.uid], // TODO: Add all relevant users
              triggerTime: triggerTime,
              isSent: false,
              createdAt: DateTime.now(),
            );
          }).toList();

          if (reminders.isNotEmpty) {
            await reminderRepo.createReminders(reminders);
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Đã cập nhật thông báo'),
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
        }
      },
    );
  }

  Future<void> _deleteReminder(String reminderId) async {
    try {
      final reminderRepo = ref.read(reminderRepositoryProvider);
      await reminderRepo.deleteReminder(reminderId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã xóa thông báo'),
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
    }
  }

  String _formatEventDate(EventModel event) {
    // If a specific date was selected from the calendar, show that date
    if (widget.selectedDate != null) {
      return DateFormat.yMMMMd().format(widget.selectedDate!);
    }

    final start = event.startTime;
    final end = event.endTime;

    // Check if it's the same day
    if (start.year == end.year && start.month == end.month && start.day == end.day) {
      return DateFormat.yMMMMd().format(start);
    }

    // Different days, same year
    if (start.year == end.year) {
      return '${DateFormat.MMMMd().format(start)} - ${DateFormat.yMMMMd().format(end)}';
    }

    // Different years
    return '${DateFormat.yMMMMd().format(start)} - ${DateFormat.yMMMMd().format(end)}';
  }

  Widget _buildFinanceSection({required bool isViewer}) {
    final finance = _currentEvent.finance!;
    final totalExpenses = EventFinanceX(finance).totalExpenses;
    final artistRevenueShare = finance.revenue * (finance.artistSharePercent / 100);
    const artistShareLabel = 'Nghệ sĩ';
    final netIncome = finance.revenue - totalExpenses - artistRevenueShare;

    if (isViewer) {
      return Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tài chính',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            // Artist share only (Viewer)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.person_outline,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        artistShareLabel,
                        style: TextStyle(
                          color: AppColors.textDarkSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    artistRevenueShare.toVND(),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 20,
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

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tài chính',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Revenue
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.attach_money,
                        color: AppColors.success,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Doanh thu',
                      style: TextStyle(
                        color: AppColors.textDarkSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                Text(
                  finance.revenue.toVND(),
                  style: const TextStyle(
                    color: AppColors.success,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Artist share
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.person_outline,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      artistShareLabel,
                      style: TextStyle(
                        color: AppColors.textDarkSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                Text(
                  artistRevenueShare.toVND(),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Expenses
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.remove_circle_outline,
                            color: AppColors.error,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Chi phí',
                          style: TextStyle(
                            color: AppColors.textDarkSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      totalExpenses.toVND(),
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                if (finance.expenses.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(color: AppColors.borderDark),
                  const SizedBox(height: 8),
                  ...finance.expenses.map((expense) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '  • ${expense.name}',
                              style: const TextStyle(
                                color: AppColors.textDarkSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Text(
                            expense.amount.toVND(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Net income
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: netIncome >= 0
                    ? [
                  AppColors.success.withValues(alpha: 0.2),
                  AppColors.success.withValues(alpha: 0.1),
                ]
                    : [
                  AppColors.error.withValues(alpha: 0.2),
                  AppColors.error.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: netIncome >= 0 ? AppColors.success : AppColors.error,
                width: 2,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Thu nhập ròng',
                      style: TextStyle(
                        color: AppColors.textDarkSecondary.withValues(alpha:0.9),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      netIncome.toVND(),
                      style: TextStyle(
                        color: netIncome >= 0 ? AppColors.success : AppColors.error,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Icon(
                  netIncome >= 0 ? Icons.trending_up : Icons.trending_down,
                  color: netIncome >= 0 ? AppColors.success : AppColors.error,
                  size: 48,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Provider to check if current user can edit this event
final canEditEventProvider = Provider.family<AsyncValue<bool>, EventModel>((ref, event) {
  final userProfileAsync = ref.watch(currentUserProfileProvider);

  return userProfileAsync.when(
    data: (user) {
      if (user == null) return const AsyncValue.data(false);

      // Super Editor can edit everything
      if (user.role == UserRole.superEditor) {
        return const AsyncValue.data(true);
      }

      // Editor can edit if event has any of their managed artists
      if (user.role == UserRole.editor) {
        final hasPermission = user.managedArtistIds.any(
              (artistId) => event.artistIds.contains(artistId),
        );
        return AsyncValue.data(hasPermission);
      }

      // Viewer cannot edit
      return const AsyncValue.data(false);
    },
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
  );
});