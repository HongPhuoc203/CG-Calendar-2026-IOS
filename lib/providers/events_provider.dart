import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/event_model.dart';
import '../core/enums/user_role.dart';
import 'repositories_providers.dart';
import 'artists_provider.dart';
import 'auth_provider.dart';

/// Provider for events stream with role-aware filtering
///
/// - Pending: không thấy event nào (stream rỗng)
/// - Viewer: chỉ thấy event của chính nghệ sĩ (user.artistId)
/// - Editor: mặc định thấy events của managedArtistIds
/// - Super Editor: thấy tất cả events
///
/// Ngoài ra, nếu user chọn filter nghệ sĩ (selectedArtistIds), filter đó sẽ được ưu tiên.
final eventsStreamProvider = StreamProvider.autoDispose<List<EventModel>>((ref) {
  final eventRepository = ref.watch(eventRepositoryProvider);
  final selectedArtistIds = ref.watch(selectedArtistIdsProvider);
  final userProfileAsync = ref.watch(currentUserProfileProvider);

  // Lấy user hiện tại (nếu đã load)
  final user = userProfileAsync.asData?.value;

  // DEBUG: Log user data
  print('🔍 [EventsProvider] User: ${user?.email}');
  print('🔍 [EventsProvider] Role: ${user?.role}');
  print('🔍 [EventsProvider] ArtistId: ${user?.artistId}');

  // Tính toán danh sách artistIds dùng để filter
  List<String> roleBasedArtistIds = [];

  if (user != null) {
    switch (user.role) {
      case UserRole.pending:
        // Không thấy event nào
        roleBasedArtistIds = [];
        break;
      case UserRole.viewer:
        if (user.artistId != null) {
          roleBasedArtistIds = [user.artistId!];
          print('🔍 [EventsProvider] Viewer artistId: ${user.artistId}');
        } else {
          print('⚠️ [EventsProvider] Viewer has NO artistId!');
        }
        break;
      case UserRole.editor:
        roleBasedArtistIds = user.managedArtistIds;
        break;
      case UserRole.superEditor:
        // Không filter theo role
        roleBasedArtistIds = [];
        break;
    }
  }

  // Viewer và Editor KHÔNG được chọn filter thủ công
  // Chỉ Super Editor mới được dùng selectedArtistIds
  final effectiveArtistIds = (user?.role == UserRole.superEditor && selectedArtistIds.isNotEmpty)
      ? selectedArtistIds
      : roleBasedArtistIds;

  print('🔍 [EventsProvider] Querying events with artistIds: $effectiveArtistIds');

  return eventRepository.streamEvents(
    artistIds: effectiveArtistIds.isNotEmpty ? effectiveArtistIds : null,
  );
});

/// Provider for events by date range — real-time stream with role-aware filtering.
/// Automatically reflects creates/updates/deletes on ALL devices without manual refresh.
final eventsByDateRangeProvider = StreamProvider.autoDispose.family<List<EventModel>, DateRange>(
  (ref, dateRange) {
    final eventRepository = ref.watch(eventRepositoryProvider);
    final userProfileAsync = ref.watch(currentUserProfileProvider);
    final selectedArtistIds = ref.watch(selectedArtistIdsProvider);

    final user = userProfileAsync.asData?.value;

    // Compute role-based artist filter (same logic as eventsStreamProvider)
    List<String> roleBasedArtistIds = [];
    if (user != null) {
      switch (user.role) {
        case UserRole.pending:
          roleBasedArtistIds = [];
          break;
        case UserRole.viewer:
          if (user.artistId != null) roleBasedArtistIds = [user.artistId!];
          break;
        case UserRole.editor:
          roleBasedArtistIds = user.managedArtistIds;
          break;
        case UserRole.superEditor:
          roleBasedArtistIds = [];
          break;
      }
    }

    final effectiveArtistIds = (user?.role == UserRole.superEditor && selectedArtistIds.isNotEmpty)
        ? selectedArtistIds
        : roleBasedArtistIds;

    return eventRepository.streamEvents(
      artistIds: effectiveArtistIds.isNotEmpty ? effectiveArtistIds : null,
      startDate: dateRange.start,
      endDate: dateRange.end,
    );
  },
);

/// Provider for a specific event by ID
final eventByIdProvider = FutureProvider.family<EventModel?, String>((ref, eventId) {
  final eventRepository = ref.watch(eventRepositoryProvider);
  return eventRepository.getEventById(eventId);
});

/// State provider for selected date (for calendar)
final selectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

/// State provider for calendar view mode
final calendarViewModeProvider = StateProvider<CalendarViewMode>((ref) => CalendarViewMode.month);

/// Helper class for date range
class DateRange {
  final DateTime start;
  final DateTime end;

  DateRange(this.start, this.end);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DateRange &&
          runtimeType == other.runtimeType &&
          start == other.start &&
          end == other.end;

  @override
  int get hashCode => start.hashCode ^ end.hashCode;
}

/// Enum for calendar view modes
enum CalendarViewMode {
  month,
  week,
  agenda,
}

