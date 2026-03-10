import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';
import '../models/event_model.dart';
import '../models/artist_model.dart';
import '../../core/enums/user_role.dart';
import '../../core/utils/logger.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';


final _geminiApiKey = dotenv.env['GEMINI_API_KEY'] ?? '';

/// Một tin nhắn trong lịch sử chat
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

/// Callback types for data fetching
typedef FetchEventsCallback = Future<List<EventModel>> Function(
    DateTime start, DateTime end);
typedef FetchArtistsCallback = Future<List<ArtistModel>> Function();

// ─────────────────────────────────────────────
// Response Cache — TTL 5 phút, skip time-sensitive queries
// ─────────────────────────────────────────────

class _CachedResponse {
  final String response;
  final DateTime cachedAt;
  static const _ttl = Duration(minutes: 5);

  _CachedResponse(this.response) : cachedAt = DateTime.now();

  bool get isExpired => DateTime.now().difference(cachedAt) > _ttl;
}

// ─────────────────────────────────────────────
// Rate Limiter — sliding window, max 10 calls/phút
// ─────────────────────────────────────────────

class _RateLimiter {
  final int maxCalls;
  final Duration window;
  final _timestamps = <DateTime>[];

  _RateLimiter({this.maxCalls = 10, this.window = const Duration(minutes: 1)});

  /// true = được gọi, false = bị chặn
  bool tryAcquire() {
    final now = DateTime.now();
    _timestamps.removeWhere((t) => now.difference(t) > window);
    if (_timestamps.length >= maxCalls) return false;
    _timestamps.add(now);
    return true;
  }

  Duration get timeUntilReset {
    if (_timestamps.isEmpty) return Duration.zero;
    final wait = _timestamps.first.add(window).difference(DateTime.now());
    return wait.isNegative ? Duration.zero : wait;
  }
}

/// GeminiService sử dụng Function Calling:
/// AI phân tích câu hỏi → tự gọi đúng hàm fetch dữ liệu → trả lời
/// → tiết kiệm 80-90% token so với dump toàn bộ data
class GeminiService {
  GenerativeModel? _model;
  ChatSession? _chat;
  bool _isInitialized = false;

  List<ArtistModel> _cachedArtists = [];
  DateTime _artistsCachedAt = DateTime(2000);

  final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');
  final _currencyFormat = NumberFormat('#,###');
  final _responseCache = <String, _CachedResponse>{};
  final _rateLimiter = _RateLimiter(maxCalls: 10, window: const Duration(minutes: 1));

  static const _maxEventsPerQuery = 20;

  bool get isInitialized => _isInitialized;

  // ─────────────────────────────────────────────
  // Khởi tạo model với function declarations theo role
  // ─────────────────────────────────────────────

  void initialize(UserModel user) {
    final tools = _buildTools(user.role);

    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: _geminiApiKey,
      tools: tools,
      systemInstruction: Content.text(_buildSystemPrompt(user)),
      generationConfig: GenerationConfig(
        temperature: 0.7,
        maxOutputTokens: 800,
      ),
    );

    _chat = _model!.startChat();
    _isInitialized = true;
    logger.i('GeminiService (Function Calling) initialized for: ${user.email}');
  }

  void resetChat(UserModel user) {
    _isInitialized = false;
    _messageCount = 0;
    initialize(user);
  }

  int _messageCount = 0;

  /// Reset chat session sau mỗi 10 lượt để tránh token tích lũy
  void _trimChatHistory(UserModel user) {
    _messageCount++;
    if (_messageCount >= 10) {
      logger.i('🔄 Auto-reset chat session sau 10 lượt');
      _messageCount = 0;
      _chat = _model!.startChat(); // Tạo session mới, giữ nguyên model
    }
  }

  // ─────────────────────────────────────────────
  // Gửi tin nhắn — Gemini tự quyết định gọi hàm gì
  // ─────────────────────────────────────────────

  Future<String> sendMessage({
    required String userMessage,
    required UserModel currentUser,
    required FetchEventsCallback fetchEvents,
    required FetchArtistsCallback fetchArtists,
  }) async {
    if (!_isInitialized || _chat == null) {
      initialize(currentUser);
    }

    // ── Bước 0a: Rate limiting ──
    if (!_rateLimiter.tryAcquire()) {
      final wait = _rateLimiter.timeUntilReset;
      logger.w('🚫 Rate limit reached. Reset in ${wait.inSeconds}s');
      return '⏳ Quá nhiều yêu cầu liên tiếp. Vui lòng chờ '
          '${wait.inSeconds} giây rồi thử lại.';
    }

    // ── Bước 0b: Response cache ──
    _cleanCache();
    final cacheKey =
        '${currentUser.role.name}:${userMessage.toLowerCase().trim()}';
    if (_isCacheable(userMessage)) {
      final cached = _responseCache[cacheKey];
      if (cached != null && !cached.isExpired) {
        logger.i(
            '📦 Cache hit: ${userMessage.substring(0, userMessage.length.clamp(0, 40))}');
        return cached.response;
      }
    }

    // Refresh artists cache mỗi 5 phút
    final now = DateTime.now();
    if (_cachedArtists.isEmpty ||
        now.difference(_artistsCachedAt) > const Duration(minutes: 5)) {
      _cachedArtists = await fetchArtists();
      _artistsCachedAt = now;
    }

    try {
      // Bước 1: Gửi câu hỏi (không kèm data)
      var response = await _chat!.sendMessage(Content.text(userMessage));

      // Bước 2: Xử lý function calls (tối đa 3 vòng để tránh loop)
      int iterations = 0;
      while (response.functionCalls.isNotEmpty && iterations < 3) {
        iterations++;
        final functionCall = response.functionCalls.first;
        logger.i('🔧 Gemini calls: ${functionCall.name} | args: ${functionCall.args}');

        final functionResult = await _executeFunction(
          name: functionCall.name,
          args: functionCall.args,
          user: currentUser,
          fetchEvents: fetchEvents,
        );

        response = await _chat!.sendMessage(
          Content.functionResponse(functionCall.name, functionResult),
        );
      }

      // Bước 3: Giới hạn lịch sử chat để tránh token tăng vô hạn
      _trimChatHistory(currentUser);

      final answer = response.text;
      if (answer == null || answer.isEmpty) {
        return 'Xin lỗi, tôi không thể xử lý câu hỏi này. Vui lòng thử lại.';
      }

      // Lưu vào cache nếu câu hỏi không nhạy cảm về thời gian
      if (_isCacheable(userMessage)) {
        _responseCache[cacheKey] = _CachedResponse(answer);
        logger.i(
            '💾 Cached: ${userMessage.substring(0, userMessage.length.clamp(0, 40))} (${_responseCache.length} entries)');
      }

      return answer;
    } catch (e) {
      final raw = e.toString();
      logger.e('Gemini raw error: $raw');

      if (raw.contains('RESOURCE_EXHAUSTED') || raw.contains('quota exceeded') || raw.contains('rateLimitExceeded')) {
        return '⚠️ Hết quota API Gemini hôm nay.\n\n'
            'Giải pháp:\n'
            '• Vào aistudio.google.com → tạo API key mới\n'
            '• Hoặc chờ đến 00:00 UTC ngày mai\n\n'
            'Chi tiết lỗi: $raw';
      }
      if (raw.contains('not found') || raw.contains('not supported')) {
        return '⚠️ Model không hỗ trợ.\nChi tiết: $raw';
      }
      if (raw.contains('API_KEY_INVALID') || raw.contains('PERMISSION_DENIED')) {
        return '⚠️ API key không hợp lệ. Vui lòng kiểm tra lại.';
      }
      return '⚠️ Lỗi kết nối AI:\n$raw';
    }
  }

  // ─────────────────────────────────────────────
  // Thực thi function call từ Gemini
  // ─────────────────────────────────────────────

  Future<Map<String, dynamic>> _executeFunction({
    required String name,
    required Map<String, dynamic> args,
    required UserModel user,
    required FetchEventsCallback fetchEvents,
  }) async {
    try {
      switch (name) {
        case 'getUpcomingEvents':
          final days = (args['days'] as num?)?.toInt() ?? 7;
          final now = DateTime.now();
          final events = await fetchEvents(now, now.add(Duration(days: days)));
          final filtered = _filterByRole(user, events);
          final limited = _limitEvents(filtered);
          return {
            'events': _formatEvents(limited, user),
            'total': filtered.length,
            'showing': limited.length,
          };

        case 'getPastEvents':
          final days = (args['days'] as num?)?.toInt() ?? 7;
          final now = DateTime.now();
          final events = await fetchEvents(now.subtract(Duration(days: days)), now);
          final filtered = _filterByRole(user, events);
          final limited = _limitEvents(filtered);
          return {
            'events': _formatEvents(limited, user),
            'total': filtered.length,
            'showing': limited.length,
          };

        case 'getEventsInRange':
          final startStr = args['startDate'] as String? ?? '';
          final endStr = args['endDate'] as String? ?? '';
          final start = _parseDate(startStr) ?? DateTime.now();
          final end = _parseDate(endStr) ?? DateTime.now().add(const Duration(days: 30));
          final events = await fetchEvents(start, end);
          final filtered = _filterByRole(user, events);
          final limited = _limitEvents(filtered);
          return {
            'events': _formatEvents(limited, user),
            'total': filtered.length,
            'showing': limited.length,
          };

        case 'getRevenueStats':
          // Chỉ editor và superEditor
          if (user.role == UserRole.viewer) {
            return {'error': 'Bạn không có quyền xem thông tin tài chính'};
          }
          final startStr = args['startDate'] as String? ?? '';
          final endStr = args['endDate'] as String? ?? '';
          final start = _parseDate(startStr) ?? DateTime(DateTime.now().year, DateTime.now().month, 1);
          final end = _parseDate(endStr) ?? DateTime.now();
          final events = await fetchEvents(start, end);
          final filtered = _filterByRole(user, events);
          return _calculateRevenue(filtered);

        case 'getArtistList':
          final artists = _getAllowedArtists(user, _cachedArtists);
          return {
            'artists': artists.map((a) => {'id': a.id, 'name': a.name}).toList(),
          };

        default:
          return {'error': 'Unknown function: $name'};
      }
    } catch (e) {
      logger.e('Function execution error', error: e);
      return {'error': 'Lỗi khi lấy dữ liệu: $e'};
    }
  }

  // ─────────────────────────────────────────────
  // Format dữ liệu trả về cho Gemini (compact)
  // ─────────────────────────────────────────────

  List<Map<String, dynamic>> _formatEvents(List<EventModel> events, UserModel user) {
    return events.map((e) {
      final artistNames = e.artistIds.map((id) {
        try {
          return _cachedArtists.firstWhere((a) => a.id == id).name;
        } catch (_) {
          return id;
        }
      }).join(', ');

      final completed = e.checklistItems.where((i) => i.isCompleted).length;
      final total = e.checklistItems.length;

      final result = <String, dynamic>{
        'title': e.title,
        'artists': artistNames,
        'start': _dateFormat.format(e.startTime),
        'end': _dateFormat.format(e.endTime),
        'location': e.location ?? '',
        'checklist': '$completed/$total',
        'notes': e.notes ?? '',
      };

      // Tài chính chỉ cho editor+
      if (user.role != UserRole.viewer && e.finance != null) {
        result['revenue'] = '${_currencyFormat.format(e.finance!.revenue)}₫';
        result['expenses'] = '${_currencyFormat.format(e.finance!.totalExpenses)}₫';
        result['profit'] = '${_currencyFormat.format(e.finance!.revenue - e.finance!.totalExpenses)}₫';
      }

      return result;
    }).toList();
  }

  Map<String, dynamic> _calculateRevenue(List<EventModel> events) {
    // Tính tổng trên toàn bộ dữ liệu để đảm bảo chính xác
    final totalRevenue =
        events.fold<double>(0, (s, e) => s + (e.finance?.revenue ?? 0));
    final totalExpenses =
        events.fold<double>(0, (s, e) => s + (e.finance?.totalExpenses ?? 0));

    // Chỉ trả về top-20 theo doanh thu cao nhất (tránh context quá dài)
    final topEvents = ([...events]
          ..sort((a, b) => (b.finance?.revenue ?? 0)
              .compareTo(a.finance?.revenue ?? 0)))
        .take(_maxEventsPerQuery)
        .toList();

    return {
      'totalEvents': events.length,
      'totalRevenue': '${_currencyFormat.format(totalRevenue)}₫',
      'totalExpenses': '${_currencyFormat.format(totalExpenses)}₫',
      'netProfit': '${_currencyFormat.format(totalRevenue - totalExpenses)}₫',
      'showingTop': topEvents.length,
      'byEvent': topEvents.map((e) => {
            'title': e.title,
            'revenue': '${_currencyFormat.format(e.finance?.revenue ?? 0)}₫',
            'profit':
                '${_currencyFormat.format((e.finance?.revenue ?? 0) - (e.finance?.totalExpenses ?? 0))}₫',
          }).toList(),
    };
  }

  // ─────────────────────────────────────────────
  // Cache & Rate Limit Helpers
  // ─────────────────────────────────────────────

  /// Xóa các entry đã hết hạn khỏi cache
  void _cleanCache() {
    _responseCache.removeWhere((_, v) => v.isExpired);
  }

  /// Không cache câu hỏi liên quan đến thời điểm hiện tại
  bool _isCacheable(String message) {
    final lower = message.toLowerCase();
    const timeSensitive = [
      'hôm nay', 'bây giờ', 'hiện tại', 'ngay lúc', 'vừa',
      'mới nhất', 'gần đây nhất', 'hôm nay',
    ];
    return !timeSensitive.any((k) => lower.contains(k));
  }

  /// Giới hạn tối đa _maxEventsPerQuery, ưu tiên event gần thời điểm hiện tại
  List<EventModel> _limitEvents(List<EventModel> events) {
    if (events.length <= _maxEventsPerQuery) return events;
    final now = DateTime.now();
    final sorted = [...events]
      ..sort((a, b) => a.startTime.difference(now).abs().compareTo(
            b.startTime.difference(now).abs(),
          ));
    logger.i(
        '📊 Event limit: ${events.length} → $_maxEventsPerQuery (closest to now)');
    return sorted.take(_maxEventsPerQuery).toList();
  }

  // ─────────────────────────────────────────────
  // Tool Declarations (định nghĩa hàm cho Gemini)
  // ─────────────────────────────────────────────

  List<Tool> _buildTools(UserRole role) {
    final declarations = <FunctionDeclaration>[
      FunctionDeclaration(
        'getUpcomingEvents',
        'Lấy danh sách sự kiện sắp tới trong N ngày tới kể từ hôm nay.',
        Schema(SchemaType.object, properties: {
          'days': Schema(SchemaType.integer,
              description: 'Số ngày muốn xem (mặc định 7, tối đa 60)'),
        }),
      ),
      FunctionDeclaration(
        'getPastEvents',
        'Lấy danh sách sự kiện đã diễn ra trong N ngày qua.',
        Schema(SchemaType.object, properties: {
          'days': Schema(SchemaType.integer,
              description: 'Số ngày trong quá khứ (mặc định 7, tối đa 30)'),
        }),
      ),
      FunctionDeclaration(
        'getEventsInRange',
        'Lấy sự kiện trong khoảng thời gian cụ thể.',
        Schema(SchemaType.object, properties: {
          'startDate': Schema(SchemaType.string,
              description: 'Ngày bắt đầu, định dạng yyyy-MM-dd'),
          'endDate': Schema(SchemaType.string,
              description: 'Ngày kết thúc, định dạng yyyy-MM-dd'),
        }, requiredProperties: ['startDate', 'endDate']),
      ),
      FunctionDeclaration(
        'getArtistList',
        'Lấy danh sách nghệ sĩ.',
        Schema(SchemaType.object, properties: {}),
      ),
    ];

    // Chỉ editor+ mới có tool doanh thu
    if (role != UserRole.viewer) {
      declarations.add(FunctionDeclaration(
        'getRevenueStats',
        'Lấy thống kê doanh thu, chi phí và lợi nhuận theo khoảng thời gian.',
        Schema(SchemaType.object, properties: {
          'startDate': Schema(SchemaType.string,
              description: 'Ngày bắt đầu, định dạng yyyy-MM-dd'),
          'endDate': Schema(SchemaType.string,
              description: 'Ngày kết thúc, định dạng yyyy-MM-dd'),
        }, requiredProperties: ['startDate', 'endDate']),
      ));
    }

    return [Tool(functionDeclarations: declarations)];
  }

  // ─────────────────────────────────────────────
  // System Prompt (ngắn gọn vì data fetch theo yêu cầu)
  // ─────────────────────────────────────────────

  String _buildSystemPrompt(UserModel user) {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final roleNote = switch (user.role) {
      UserRole.superEditor => 'Bạn có thể xem toàn bộ dữ liệu của tất cả nghệ sĩ.',
      UserRole.editor => 'Bạn chỉ được cung cấp dữ liệu của nghệ sĩ bạn quản lý.',
      UserRole.viewer => 'Bạn chỉ được xem lịch trình cá nhân, không có thông tin tài chính.',
      _ => 'Quyền truy cập hạn chế.',
    };

    return '''
Bạn là AI assistant của CG Calendar - hệ thống quản lý lịch trình nghệ sĩ.
Hôm nay: $today. Người dùng: ${user.displayName ?? user.email}.
$roleNote

CÁCH LÀM VIỆC:
- Khi cần dữ liệu lịch, HÃY GỌI function tương ứng thay vì đoán mò
- Chỉ trả lời dựa trên dữ liệu thực từ function calls
- Trả lời bằng Tiếng Việt, ngắn gọn và rõ ràng
- Định dạng số tiền: 1.200.000₫
''';
  }

  // ─────────────────────────────────────────────
  // RBAC Helpers
  // ─────────────────────────────────────────────

  List<EventModel> _filterByRole(UserModel user, List<EventModel> events) {
    switch (user.role) {
      case UserRole.superEditor:
        return events;
      case UserRole.editor:
        return events.where((e) =>
            e.artistIds.any((id) => user.managedArtistIds.contains(id))).toList();
      case UserRole.viewer:
        return user.artistId != null
            ? events.where((e) => e.artistIds.contains(user.artistId)).toList()
            : [];
      default:
        return [];
    }
  }

  List<ArtistModel> _getAllowedArtists(UserModel user, List<ArtistModel> artists) {
    switch (user.role) {
      case UserRole.superEditor:
        return artists;
      case UserRole.editor:
        return artists.where((a) => user.managedArtistIds.contains(a.id)).toList();
      case UserRole.viewer:
        return user.artistId != null
            ? artists.where((a) => a.id == user.artistId).toList()
            : [];
      default:
        return [];
    }
  }

  DateTime? _parseDate(String dateStr) {
    try {
      return DateTime.parse(dateStr);
    } catch (_) {
      return null;
    }
  }
}
