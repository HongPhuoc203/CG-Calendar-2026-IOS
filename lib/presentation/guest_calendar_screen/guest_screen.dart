import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/event_model.dart';
import '../../providers/events_provider.dart';
import '../../providers/artists_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/services_providers.dart';
import '../profile/profile_screen.dart';

/// Màn hình lịch dành riêng cho Role: Guest.
///
/// Quyền hạn:
///   ✅ Xem lịch tháng/tuần với event bars
///   ✅ Xem danh sách sự kiện trong ngày (title, giờ, nghệ sĩ)
///   ❌ Không xem được chi tiết sự kiện (location, finance, notes...)
///   ❌ Không tạo / sửa / xóa sự kiện
///   ❌ Không truy cập Admin Panel hay các màn hình khác
class GuestCalendarScreen extends ConsumerStatefulWidget {
  const GuestCalendarScreen({super.key});

  @override
  ConsumerState<GuestCalendarScreen> createState() =>
      _GuestCalendarScreenState();
}

class _GuestCalendarScreenState extends ConsumerState<GuestCalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(eventsStreamProvider);
    final artistsAsync = ref.watch(artistsStreamProvider);
    final currentUser = ref.watch(currentUserProfileProvider).value;

    // Danh sách các từ khóa nghệ sĩ cần ẩn khỏi lịch Guest
    final blockedKeywords = ['mr chu', 'tăng duy tân', 'chi pu'];

    // Lấy tập hợp ID của tất cả các nghệ sĩ bị chặn dựa theo danh sách từ khóa
    final blockedArtistIds = artistsAsync.valueOrNull
        ?.where((a) {
          final artistNameLower = a.name.trim().toLowerCase();
          return blockedKeywords.any((keyword) => artistNameLower.contains(keyword));
        })
        .map((a) => a.id)
        .toSet();

    // Lọc bỏ toàn bộ sự kiện có chứa ít nhất một nghệ sĩ bị chặn
    final filteredAsync = eventsAsync.whenData((events) {
      if (blockedArtistIds == null || blockedArtistIds.isEmpty) return events;
      return events
          .where((e) => e.artistIds.every((id) => !blockedArtistIds.contains(id)))
          .toList();
    });

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(currentUser),
            _buildViewSwitcher(),
            Expanded(
              child: filteredAsync.when(
                data: (events) => _buildCalendarContent(events),
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
                error: (error, _) => Center(
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
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HEADER — tên + nút profile
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildHeader(dynamic user) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.borderDark, width: 1),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.surfaceDark,
              backgroundImage: user?.photoUrl != null
                  ? NetworkImage(user!.photoUrl as String)
                  : null,
              child: user?.photoUrl == null
                  ? Text(
                      (user?.displayName ?? 'G')
                          .substring(0, 1)
                          .toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              user?.displayName ?? 'Guest',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.person_outline,
                size: 20,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // VIEW SWITCHER
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildViewSwitcher() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
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
                  _buildSegmentBtn('Tháng', CalendarFormat.month),
                  _buildSegmentBtn('Tuần', CalendarFormat.week),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextButton.icon(
              onPressed: () => setState(() {
                _focusedDay = DateTime.now();
                _selectedDay = DateTime.now();
              }),
              icon: const Icon(Icons.calendar_today,
                  size: 16, color: AppColors.primary),
              label: const Text(
                'Hôm nay',
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

  Widget _buildSegmentBtn(String label, CalendarFormat format) {
    final isSelected = _calendarFormat == format;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _calendarFormat = format),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF344465)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              color:
              isSelected ? Colors.white : AppColors.textDarkSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CALENDAR CONTENT
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildCalendarContent(List<EventModel> events) {
    final dayEvents =
    _getEventsForDay(_selectedDay ?? DateTime.now(), events);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildCalendar(events),
          const SizedBox(height: 16),
          _buildEventsList(dayEvents),
        ],
      ),
    );
  }

  Widget _buildCalendar(List<EventModel> events) {
    final slotMap = _computeSlotAssignments(events);
    final maxBars = slotMap.isEmpty ? 0 : slotMap.values.reduce(math.max) + 1;
    final rowH = math.max(
      _kMinRowH,
      _kDayNumH +
          maxBars * _kBarH +
          (maxBars > 1 ? (maxBars - 1) * _kBarGap : 0),
    );

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
        startingDayOfWeek: StartingDayOfWeek.monday,
        rowHeight: rowH,
        eventLoader: (day) => _getEventsForDay(day, events),
        onDaySelected: (selected, focused) => setState(() {
          _selectedDay = selected;
          _focusedDay = focused;
        }),
        onPageChanged: (focused) => _focusedDay = focused,
        calendarBuilders: CalendarBuilders(
          defaultBuilder: (ctx, day, _) =>
              _buildDayCell(ctx, day, events, slotMap, maxBars, rowH),
          todayBuilder: (ctx, day, _) =>
              _buildDayCell(ctx, day, events, slotMap, maxBars, rowH, isToday: true),
          selectedBuilder: (ctx, day, _) =>
              _buildDayCell(ctx, day, events, slotMap, maxBars, rowH, isSelected: true),
          outsideBuilder: (ctx, day, _) =>
              _buildDayCell(ctx, day, events, slotMap, maxBars, rowH, isOutside: true),
        ),
        calendarStyle: CalendarStyle(
          markersMaxCount: 0,
          defaultTextStyle: const TextStyle(color: Colors.white),
          weekendTextStyle: const TextStyle(color: Colors.white),
          outsideTextStyle:
          TextStyle(color: Colors.white.withValues(alpha: 0.3)),
        ),
        headerStyle: const HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold),
          leftChevronIcon:
          Icon(Icons.chevron_left, color: AppColors.textDarkSecondary),
          rightChevronIcon:
          Icon(Icons.chevron_right, color: AppColors.textDarkSecondary),
        ),
        daysOfWeekStyle: DaysOfWeekStyle(
          weekdayStyle: TextStyle(
              color: AppColors.textDarkSecondary.withValues(alpha: 0.7),
              fontSize: 11,
              fontWeight: FontWeight.w600),
          weekendStyle: TextStyle(
              color: AppColors.textDarkSecondary.withValues(alpha: 0.7),
              fontSize: 11,
              fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // EVENT LIST — tóm tắt, không có location / finance / notes
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildEventsList(List<EventModel> events) {
    if (events.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.event_busy,
                size: 48,
                color: AppColors.textDarkSecondary.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              'Không có sự kiện',
              style: TextStyle(
                  color:
                  AppColors.textDarkSecondary.withValues(alpha: 0.7),
                  fontSize: 16,
                  fontWeight: FontWeight.w500),
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
              DateFormat('EEE, d MMM').format(_selectedDay!),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            Text('${events.length} sự kiện',
                style: const TextStyle(
                    color: AppColors.textDarkSecondary, fontSize: 14)),
          ],
        ),
        const SizedBox(height: 12),
        ...events.map((e) => _buildGuestEventCard(e)),
      ],
    );
  }

  /// Card sự kiện dành cho Guest:
  /// - Hiển thị: tiêu đề, giờ, tên nghệ sĩ
  /// - Ẩn: location, finance, notes, checklist
  /// - Tap → bottom sheet "Nội dung giới hạn" thay vì EventDetailsScreen
  Widget _buildGuestEventCard(EventModel event) {
    final artistsAsync =
    ref.watch(artistsByIdsProvider(event.artistIds));
    final accentColor = AppColors.artistColors[
    event.id.hashCode.abs() % AppColors.artistColors.length];

    return InkWell(
      onTap: () => _showLimitedAccessSheet(event),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(12),
          border: Border(
            left: BorderSide(color: accentColor, width: 4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (event.isAllDay)
                  _buildPill('Cả ngày', AppColors.primary)
                else
                  Text(
                    '${DateFormat('HH:mm').format(event.startTime)}'
                        ' – ${DateFormat('HH:mm').format(event.endTime)}',
                    style: const TextStyle(
                        color: AppColors.textDarkSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    event.title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            artistsAsync.when(
              data: (artists) {
                if (artists.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: artists.map((artist) {
                      final color = AppColors.artistColors[
                      artist.id.hashCode.abs() %
                          AppColors.artistColors.length];
                      return Chip(
                        label: Text(artist.name,
                            style: const TextStyle(fontSize: 10)),
                        backgroundColor: color.withValues(alpha: 0.2),
                        side: BorderSide(color: color),
                        padding: EdgeInsets.zero,
                        labelPadding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 0),
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

  Widget _buildPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BOTTOM SHEET "Nội dung giới hạn"
  // Hiện ra khi Guest tap vào event card thay vì mở EventDetailsScreen
  // ─────────────────────────────────────────────────────────────────────────

  void _showLimitedAccessSheet(EventModel event) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderDark,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              event.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              event.isAllDay
                  ? 'Cả ngày  •  ${DateFormat('d/M/yyyy').format(event.startTime)}'
                  : '${DateFormat('HH:mm').format(event.startTime)} – '
                  '${DateFormat('HH:mm').format(event.endTime)}  •  '
                  '${DateFormat('d/M/yyyy').format(event.startTime)}',
              style: const TextStyle(
                  color: AppColors.textDarkSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.surfaceDark,
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: AppColors.borderDark),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Đóng',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PROFILE MENU — chỉ có thông tin + đăng xuất
  // ─────────────────────────────────────────────────────────────────────────

  void _showProfileMenu() {
    final user = ref.read(currentUserProfileProvider).value;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor:
                  AppColors.warning.withValues(alpha: 0.2),
                  child: Text(
                    (user?.displayName ?? 'G')
                        .substring(0, 1)
                        .toUpperCase(),
                    style: const TextStyle(
                        color: AppColors.warning,
                        fontSize: 22,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.displayName ?? 'Starbase',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user?.email ?? '',
                        style: const TextStyle(
                            color: AppColors.textDarkSecondary,
                            fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(color: AppColors.borderDark),
            const SizedBox(height: 16),
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
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.logout),
                label: const Text('Đăng xuất',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _logout() async {
    try {
      final authService = ref.read(authServiceProvider);
      await authService.signOut();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Lỗi đăng xuất: $e'),
              backgroundColor: AppColors.error),
        );
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CALENDAR CELL BUILDERS
  // ─────────────────────────────────────────────────────────────────────────

  static const double _kMinRowH = 65.0;
  static const double _kDayNumH = 36.0;
  static const double _kBarH = 13.0;
  static const double _kBarGap = 2.0;

  Color _barColor(EventModel event) => AppColors.artistColors[
  event.id.hashCode.abs() % AppColors.artistColors.length];

  bool _isBarStart(EventModel event, DateTime day) =>
      isSameDay(event.startTime, day) || day.weekday == DateTime.monday;

  bool _isBarEnd(EventModel event, DateTime day) =>
      isSameDay(event.endTime, day) || day.weekday == DateTime.sunday;

  bool _dayInRange(EventModel event, DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    final s = DateTime(event.startTime.year, event.startTime.month,
        event.startTime.day);
    final e = DateTime(
        event.endTime.year, event.endTime.month, event.endTime.day);
    return !d.isBefore(s) && !d.isAfter(e);
  }

  bool _isMultiDay(EventModel event) {
    final s = DateTime(event.startTime.year, event.startTime.month,
        event.startTime.day);
    final e = DateTime(
        event.endTime.year, event.endTime.month, event.endTime.day);
    return e.isAfter(s);
  }

  bool _datesOverlap(EventModel a, EventModel b) {
    final aS = DateTime(a.startTime.year, a.startTime.month, a.startTime.day);
    final aE = DateTime(a.endTime.year, a.endTime.month, a.endTime.day);
    final bS = DateTime(b.startTime.year, b.startTime.month, b.startTime.day);
    final bE = DateTime(b.endTime.year, b.endTime.month, b.endTime.day);
    return !aE.isBefore(bS) && !bE.isBefore(aS);
  }

  /// Gán slot index ổn định cho mỗi multi-day event
  /// để các bar thẳng hàng theo chiều ngang qua các ô trong cùng hàng tuần.
  Map<String, int> _computeSlotAssignments(List<EventModel> allEvents) {
    final multiDay = allEvents.where(_isMultiDay).toList()
      ..sort((a, b) {
        final c = a.startTime.compareTo(b.startTime);
        return c != 0 ? c : a.id.compareTo(b.id);
      });

    final assignments = <String, int>{};
    final slots = <List<EventModel>>[];

    for (final event in multiDay) {
      int slotIdx = 0;
      while (slotIdx < slots.length &&
          slots[slotIdx].any((e) => _datesOverlap(e, event))) {
        slotIdx++;
      }
      if (slotIdx == slots.length) slots.add([]);
      slots[slotIdx].add(event);
      assignments[event.id] = slotIdx;
    }
    return assignments;
  }

  List<EventModel> _getEventsForDay(
      DateTime day, List<EventModel> all) {
    final check = DateTime(day.year, day.month, day.day);
    return all.where((e) {
      final s = DateTime(e.startTime.year, e.startTime.month,
          e.startTime.day);
      final en =
      DateTime(e.endTime.year, e.endTime.month, e.endTime.day);
      return !check.isBefore(s) && !check.isAfter(en);
    }).toList();
  }

  Widget _buildDayCell(
      BuildContext context,
      DateTime day,
      List<EventModel> allEvents,
      Map<String, int> slotMap,
      int maxBars,
      double rowH, {
        bool isToday = false,
        bool isSelected = false,
        bool isOutside = false,
      }) {
    final multiDay = allEvents
        .where((e) => _isMultiDay(e) && _dayInRange(e, day))
        .toList();

    final singleDay = allEvents
        .where((e) => !_isMultiDay(e) && isSameDay(e.startTime, day))
        .toList();

    // Xây dựng map slot → event cho ngày này
    final eventsBySlot = <int, EventModel>{};
    for (final event in multiDay) {
      final slot = slotMap[event.id];
      if (slot != null && slot < maxBars) {
        eventsBySlot[slot] = event;
      }
    }

    return SizedBox(
      height: rowH,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Số ngày — với dots overlay khi có cả bars lẫn single-day events
          SizedBox(
            height: _kDayNumH,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: isSelected
                      ? const BoxDecoration(
                          color: AppColors.primary, shape: BoxShape.circle)
                      : isToday
                          ? BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.35),
                              shape: BoxShape.circle)
                          : null,
                  child: Text(
                    '${day.day}',
                    style: TextStyle(
                      color: isOutside
                          ? Colors.white.withValues(alpha: 0.25)
                          : Colors.white,
                      fontWeight: isSelected || isToday
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (singleDay.isNotEmpty && multiDay.isNotEmpty)
                  Positioned(
                    bottom: 1,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: singleDay
                          .take(3)
                          .map((_) => Container(
                                width: 4,
                                height: 4,
                                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                ),
                              ))
                          .toList(),
                    ),
                  ),
              ],
            ),
          ),
          // Bars — slot-aligned, gap đặt TRƯỚC mỗi bar trừ bar đầu tiên
          if (multiDay.isNotEmpty)
            for (int slot = 0; slot < maxBars; slot++) ...[
              if (slot > 0) SizedBox(height: _kBarGap),
              if (eventsBySlot.containsKey(slot))
                _buildBarSlice(eventsBySlot[slot]!, day)
              else
                SizedBox(height: _kBarH),
            ],
          // Dots cho single-day events khi không có bars
          if (singleDay.isNotEmpty && multiDay.isEmpty)
            Align(
              child: Wrap(
                spacing: 3,
                children: singleDay
                    .take(3)
                    .map((_) => Container(
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary,
                          ),
                        ))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBarSlice(EventModel event, DateTime day) {
    final start = _isBarStart(event, day);
    final end = _isBarEnd(event, day);
    return Container(
      height: _kBarH,
      margin: EdgeInsets.only(
        left: start ? 1.5 : 0,
        right: end ? 1.5 : 0,
      ),
      decoration: BoxDecoration(
        color: _barColor(event),
        borderRadius: BorderRadius.horizontal(
          left: start ? const Radius.circular(6) : Radius.zero,
          right: end ? const Radius.circular(6) : Radius.zero,
        ),
      ),
      alignment: Alignment.centerLeft,
      child: start
          ? Padding(
        padding: const EdgeInsets.only(left: 5, right: 2),
        child: Text(
          event.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            height: 1.0,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      )
          : null,
    );
  }
}
