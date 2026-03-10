import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/services/gemini_service.dart';
import '../data/models/user_model.dart';
import 'auth_provider.dart';
import 'repositories_providers.dart';

// ─────────────────────────────────────────────────────────
// GeminiService singleton provider
// ─────────────────────────────────────────────────────────

final geminiServiceProvider = Provider.autoDispose<GeminiService>((ref) {
  return GeminiService();
});

// ─────────────────────────────────────────────────────────
// Chat state
// ─────────────────────────────────────────────────────────

class AiChatState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final String? error;

  const AiChatState({
    this.messages = const [],
    this.isLoading = false,
    this.error,
  });

  AiChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    String? error,
  }) {
    return AiChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// ─────────────────────────────────────────────────────────
// Chat Notifier (không dùng ref.listen trong constructor)
// ─────────────────────────────────────────────────────────

class AiChatNotifier extends StateNotifier<AiChatState> {
  final GeminiService _gemini;
  final Ref _ref;
  bool _initialized = false;

  AiChatNotifier(this._gemini, this._ref) : super(const AiChatState());

  /// Gọi sau khi user profile sẵn sàng
  void initIfNeeded(UserModel user) {
    if (_initialized) return;
    _initialized = true;
    _gemini.initialize(user);
    _addBotMessage(_buildWelcomeMessage(user.role.name));
  }

  String _buildWelcomeMessage(String role) {
    switch (role) {
      case 'super_editor':
        return 'Xin chào! Tôi là AI assistant của CG Calendar 🤖\n\nTôi có thể giúp bạn:\n• Tra cứu lịch trình toàn bộ nghệ sĩ\n• Phân tích doanh thu & chi phí\n• Tìm kiếm sự kiện cụ thể\n• Thống kê và báo cáo\n\nBạn muốn hỏi gì?';
      case 'editor':
        return 'Xin chào! Tôi là AI assistant của CG Calendar 🤖\n\nTôi có thể giúp bạn:\n• Tra cứu lịch trình nghệ sĩ bạn quản lý\n• Phân tích doanh thu & chi phí\n• Tìm sự kiện cần chuẩn bị\n• Kiểm tra checklist công việc\n\nBạn muốn hỏi gì?';
      default:
        return 'Xin chào! Tôi là AI assistant của CG Calendar 🤖\n\nTôi có thể giúp bạn tra cứu lịch trình sự kiện của mình.\n\nBạn muốn hỏi gì?';
    }
  }

  void _addBotMessage(String text) {
    state = state.copyWith(
      messages: [
        ...state.messages,
        ChatMessage(text: text, isUser: false, timestamp: DateTime.now()),
      ],
    );
  }

  Future<void> sendMessage(String message) async {
    if (message.trim().isEmpty) return;

    final userProfile = _ref.read(currentUserProfileProvider).value;
    if (userProfile == null) return;

    initIfNeeded(userProfile);

    state = state.copyWith(
      messages: [
        ...state.messages,
        ChatMessage(text: message, isUser: true, timestamp: DateTime.now()),
      ],
      isLoading: true,
      error: null,
    );

    try {
      final eventRepo = _ref.read(eventRepositoryProvider);
      final artistRepo = _ref.read(artistRepositoryProvider);

      // Truyền callbacks — Gemini sẽ tự gọi khi cần dữ liệu
      final response = await _gemini.sendMessage(
        userMessage: message,
        currentUser: userProfile,
        fetchEvents: (start, end) => eventRepo.getEventsByDateRange(start, end),
        fetchArtists: () => artistRepo.getAllArtists(),
      );

      state = state.copyWith(
        messages: [
          ...state.messages,
          ChatMessage(text: response, isUser: false, timestamp: DateTime.now()),
        ],
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Lỗi: $e',
        messages: [
          ...state.messages,
          ChatMessage(
            text: 'Xin lỗi, có lỗi xảy ra. Vui lòng thử lại.',
            isUser: false,
            timestamp: DateTime.now(),
          ),
        ],
      );
    }
  }

  void clearChat() {
    final userProfile = _ref.read(currentUserProfileProvider).value;
    if (userProfile != null) {
      _gemini.resetChat(userProfile);
    }
    _initialized = false;
    state = const AiChatState();
    if (userProfile != null) {
      initIfNeeded(userProfile);
    }
  }
}

// ─────────────────────────────────────────────────────────
// Provider — ref.listen ở đây thay vì trong constructor
// ─────────────────────────────────────────────────────────

final aiChatProvider =
    StateNotifierProvider.autoDispose<AiChatNotifier, AiChatState>((ref) {
  final gemini = ref.watch(geminiServiceProvider);
  final notifier = AiChatNotifier(gemini, ref);

  // Dùng ref.listen ở provider scope (đúng Riverpod pattern)
  ref.listen<AsyncValue<UserModel?>>(
    currentUserProfileProvider,
    (_, next) {
      final user = next.value;
      if (user != null) {
        notifier.initIfNeeded(user);
      }
    },
    fireImmediately: true,
  );

  return notifier;
});
