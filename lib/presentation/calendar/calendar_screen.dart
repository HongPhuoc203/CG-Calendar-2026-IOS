import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/enums/user_role.dart';
import '../../data/models/event_model.dart';
import '../../data/models/artist_model.dart';
import '../../providers/events_provider.dart';
import '../../providers/artists_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/services_providers.dart';
import '../event_details/event_details_screen.dart';
import '../create_edit_event/create_edit_event_screen.dart';
import '../admin/admin_panel_screen.dart';

/// Main Calendar Overview - Matches Stitch Design
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(eventsStreamProvider);
    final artistsAsync = ref.watch(artistsStreamProvider);
    final selectedArtistIds = ref.watch(selectedArtistIdsProvider);
    final currentUser = ref.watch(currentUserProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(context, currentUser.value, selectedArtistIds),
            
            // View Switcher
            _buildViewSwitcher(),
            
            // Calendar
            Expanded(
              child: eventsAsync.when(
                data: (events) => _buildCalendarContent(events, artistsAsync.value ?? []),
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                  ),
                ),
                error: (error, stack) => Center(
                  child: Text(
                    'Lỗi tải dữ liệu: $error',
                    style: const TextStyle(color: AppColors.error),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      // FAB: Only show for Editor & Super Editor
      floatingActionButton: currentUser.when(
        data: (user) {
          // Only Editor and Super Editor can create events
          if (user != null && 
              (user.role == UserRole.editor || user.role == UserRole.superEditor)) {
            return FloatingActionButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CreateEditEventScreen(),
                  ),
                );
                // Refresh if event was created
                if (result == true) {
                  ref.invalidate(eventsStreamProvider);
                }
              },
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add, color: Colors.white),
            );
          }
          return null; // Hide for Viewer
        },
        loading: () => null,
        error: (_, __) => null,
      ),
    );
  }

  Widget _buildHeader(BuildContext context, dynamic user, List<String> selectedArtistIds) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppColors.borderDark,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Profile Avatar with Logout
          GestureDetector(
            onTap: () => _showProfileMenu(context),
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.surfaceDark,
                  backgroundImage: user?.photoUrl != null
                      ? NetworkImage(user!.photoUrl)
                      : null,
                  child: user?.photoUrl == null
                      ? Text(
                          user?.displayName?.substring(0, 1).toUpperCase() ?? 'U',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.backgroundDark,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Display user's full name
          Text(
            user?.displayName ?? 'User',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const Spacer(),
          // Search Button
          IconButton(
            onPressed: () {
              // TODO: Implement search
            },
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.search,
                size: 20,
                color: Colors.white,
              ),
            ),
          ),
          // Filter Button - Only for Super Editor
          if (user != null && user.role == UserRole.superEditor)
            IconButton(
              onPressed: () {
                _showFilterPanel(context);
              },
              icon: Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceDark,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.filter_list,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                  if (selectedArtistIds.isNotEmpty)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildViewSwitcher() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Segmented Control
          Expanded(
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  _buildSegmentButton('Month', CalendarFormat.month),
                  _buildSegmentButton('Week', CalendarFormat.week),
                  _buildSegmentButton('List', CalendarFormat.twoWeeks),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Today Button
          Container(
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _focusedDay = DateTime.now();
                  _selectedDay = DateTime.now();
                });
              },
              icon: const Icon(
                Icons.calendar_today,
                size: 16,
                color: AppColors.primary,
              ),
              label: const Text(
                'Today',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentButton(String label, CalendarFormat format) {
    final isSelected = _calendarFormat == format;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _calendarFormat = format;
          });
        },
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF344465) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : AppColors.textDarkSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarContent(List<EventModel> events, List artists) {
    final eventsForSelectedDay = _getEventsForDay(_selectedDay ?? DateTime.now(), events);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Calendar
          _buildCalendar(events),
          const SizedBox(height: 16),
          
          // Selected Day Events
          if (_selectedDay != null) _buildEventsList(eventsForSelectedDay),
        ],
      ),
    );
  }

  Widget _buildCalendar(List<EventModel> events) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceDark.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(8),
      child: TableCalendar(
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDay,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        calendarFormat: _calendarFormat,
        eventLoader: (day) => _getEventsForDay(day, events),
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
          });
        },
        onPageChanged: (focusedDay) {
          _focusedDay = focusedDay;
        },
        calendarStyle: CalendarStyle(
          // Today
          todayDecoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
          todayTextStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
          
          // Selected
          selectedDecoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          selectedTextStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
          
          // Default
          defaultTextStyle: const TextStyle(color: Colors.white),
          weekendTextStyle: const TextStyle(color: Colors.white),
          outsideTextStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
          
          // Markers
          markerDecoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          markersMaxCount: 3,
        ),
        headerStyle: HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          leftChevronIcon: const Icon(
            Icons.chevron_left,
            color: AppColors.textDarkSecondary,
          ),
          rightChevronIcon: const Icon(
            Icons.chevron_right,
            color: AppColors.textDarkSecondary,
          ),
        ),
        daysOfWeekStyle: DaysOfWeekStyle(
          weekdayStyle: TextStyle(
            color: AppColors.textDarkSecondary.withValues(alpha: 0.7),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
          weekendStyle: TextStyle(
            color: AppColors.textDarkSecondary.withValues(alpha: 0.7),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildEventsList(List<EventModel> events) {
    if (events.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.event_busy,
              size: 48,
              color: AppColors.textDarkSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Không có sự kiện',
              style: TextStyle(
                color: AppColors.textDarkSecondary.withValues(alpha: 0.7),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              DateFormat('EEE, MMM d').format(_selectedDay!),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${events.length} Events',
              style: const TextStyle(
                color: AppColors.textDarkSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...events.map((event) => _buildEventCard(event)),
      ],
    );
  }

  Widget _buildEventCard(EventModel event) {
    final artistsAsync = ref.watch(artistsByIdsProvider(event.artistIds));
    
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EventDetailsScreen(event: event),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(12),
          border: Border(
            left: BorderSide(
              color: AppColors.artistColors[event.artistIds.length % AppColors.artistColors.length],
              width: 4,
            ),
          ),
        ),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                DateFormat('HH:mm').format(event.startTime),
                style: const TextStyle(
                  color: AppColors.textDarkSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  event.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (event.location != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 14,
                  color: AppColors.textDarkSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  event.location!,
                  style: const TextStyle(
                    color: AppColors.textDarkSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
          artistsAsync.when(
            data: (artists) {
              if (artists.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 4,
                  children: artists.map((artist) {
                    return Chip(
                      label: Text(
                        artist.name,
                        style: const TextStyle(fontSize: 10),
                      ),
                      backgroundColor: artist.color.withValues(alpha: 0.2),
                      side: BorderSide(color: artist.color),
                      padding: EdgeInsets.zero,
                      labelPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                      visualDensity: VisualDensity.compact,
                    );
                  }).toList(),
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      ),
    );
  }

  List<EventModel> _getEventsForDay(DateTime day, List<EventModel> allEvents) {
    return allEvents.where((event) {
      final eventDate = DateTime(
        event.startTime.year,
        event.startTime.month,
        event.startTime.day,
      );
      final checkDate = DateTime(day.year, day.month, day.day);
      return eventDate == checkDate;
    }).toList();
  }

  void _showFilterPanel(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return const ArtistFilterPanel();
      },
    );
  }

  void _showProfileMenu(BuildContext context) {
    final currentUser = ref.read(currentUserProfileProvider).value;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // User Info
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                    child: Text(
                      currentUser?.displayName?.substring(0, 1).toUpperCase() ?? 'U',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 24,
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
                          currentUser?.displayName ?? 'User',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          currentUser?.email ?? '',
                          style: const TextStyle(
                            color: AppColors.textDarkSecondary,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            currentUser?.role.displayName ?? '',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(color: AppColors.borderDark),
              const SizedBox(height: 16),
              
              // Admin Panel Button (Super Editor only)
              if (currentUser?.role == UserRole.superEditor) ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AdminPanelScreen(),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.warning,
                      side: const BorderSide(color: AppColors.warning),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.admin_panel_settings),
                    label: const Text(
                      'Admin Panel',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              
              // Logout Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _logout();
                  },
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
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _logout() async {
    try {
      final authService = ref.read(authServiceProvider);
      await authService.signOut();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã đăng xuất thành công'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
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

/// Artist Filter Panel
class ArtistFilterPanel extends ConsumerWidget {
  const ArtistFilterPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artistsAsync = ref.watch(artistsStreamProvider);
    final selectedIds = ref.watch(selectedArtistIdsProvider);

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Filter by Artist',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          artistsAsync.when(
            data: (artists) {
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: artists.map((artist) {
                  final isSelected = selectedIds.contains(artist.id);
                  return FilterChip(
                    label: Text(artist.name),
                    selected: isSelected,
                    onSelected: (selected) {
                      final notifier = ref.read(selectedArtistIdsProvider.notifier);
                      if (selected) {
                        notifier.state = [...selectedIds, artist.id];
                      } else {
                        notifier.state = selectedIds.where((id) => id != artist.id).toList();
                      }
                    },
                    selectedColor: artist.color.withValues(alpha: 0.3),
                    checkmarkColor: artist.color,
                    side: BorderSide(color: artist.color),
                  );
                }).toList(),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Text('Error: $error'),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    ref.read(selectedArtistIdsProvider.notifier).state = [];
                    Navigator.pop(context);
                  },
                  child: const Text('Clear'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Apply'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

