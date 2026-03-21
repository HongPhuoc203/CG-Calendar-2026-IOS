import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../data/services/gemini_service.dart';
import '../../providers/gemini_provider.dart';
import '../../providers/auth_provider.dart';

class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  // Suggested quick prompts theo role
  static const _superEditorPrompts = [
    '📊 Tháng này doanh thu tổng là bao nhiêu?',
    '📅 Tuần tới có những sự kiện nào?',
    '⚠️ Có sự kiện nào cần chuẩn bị gấp không?',
    '💰 Nghệ sĩ nào có doanh thu cao nhất?',
    '📋 Sự kiện nào chưa hoàn thành checklist?',
  ];

  static const _editorPrompts = [
    '📅 Tuần này nghệ sĩ của tôi có lịch gì?',
    '⚠️ Có việc gì cần làm gấp không?',
    '💰 Doanh thu tháng này của team tôi?',
    '📋 Checklist nào chưa hoàn thành?',
  ];

  static const _viewerPrompts = [
    '📅 Tôi có lịch gì tuần này?',
    '🗓️ Sự kiện tiếp theo của tôi là gì?',
    '📋 Tôi cần chuẩn bị gì cho sự kiện sắp tới?',
  ];

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;
    _controller.clear();
    ref.read(aiChatProvider.notifier).sendMessage(text);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(aiChatProvider);
    final userProfile = ref.watch(currentUserProfileProvider).value;
    final role = userProfile?.role.name ?? '';

    // Auto scroll khi có tin nhắn mới
    if (chatState.messages.isNotEmpty) {
      _scrollToBottom();
    }

    // Chọn suggested prompts theo role
    final prompts = role == 'super_editor'
        ? _superEditorPrompts
        : role == 'editor'
            ? _editorPrompts
            : _viewerPrompts;

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceDark,
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4285F4), Color(0xFF9C27B0)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Assistant',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Powered by Gemini',
                  style: TextStyle(
                    color: AppColors.textDarkSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.textDarkSecondary),
            tooltip: 'Xóa lịch sử chat',
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: AppColors.surfaceDark,
                  title: const Text('Xóa lịch sử?',
                      style: TextStyle(color: Colors.white)),
                  content: const Text(
                    'Toàn bộ lịch sử hội thoại sẽ bị xóa.',
                    style: TextStyle(color: AppColors.textDarkSecondary),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Hủy'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        ref.read(aiChatProvider.notifier).clearChat();
                      },
                      child: const Text('Xóa',
                          style: TextStyle(color: AppColors.error)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: chatState.messages.isEmpty
                ? _buildEmptyState(prompts)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 16),
                    itemCount: chatState.messages.length,
                    itemBuilder: (context, index) {
                      final msg = chatState.messages[index];
                      return _MessageBubble(message: msg);
                    },
                  ),
          ),

          // Loading indicator
          if (chatState.isLoading)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceDark,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _DotAnimation(),
                        const SizedBox(width: 6),
                        const Text(
                          'AI đang suy nghĩ...',
                          style: TextStyle(
                            color: AppColors.textDarkSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Quick prompts
          if (chatState.messages.length <= 1)
            _buildQuickPrompts(prompts),

          // Input bar
          _buildInputBar(chatState.isLoading),
        ],
      ),
    );
  }

  Widget _buildEmptyState(List<String> prompts) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4285F4), Color(0xFF9C27B0)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.auto_awesome,
                  color: Colors.white, size: 40),
            ),
            const SizedBox(height: 20),
            const Text(
              'AI Assistant',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Hỏi tôi về lịch trình, doanh thu\nhay bất cứ điều gì về calendar của bạn',
              style: TextStyle(
                color: AppColors.textDarkSecondary,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickPrompts(List<String> prompts) {
    return Container(
      height: 44,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: prompts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () => _sendMessage(prompts[index]),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.4)),
              ),
              child: Text(
                prompts[index],
                style: const TextStyle(
                  color: AppColors.primaryLight,
                  fontSize: 13,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputBar(bool isLoading) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      decoration: const BoxDecoration(
        color: AppColors.surfaceDark,
        border: Border(top: BorderSide(color: AppColors.borderDark)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              enabled: !isLoading,
              maxLines: 4,
              minLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: _sendMessage,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Hỏi AI về lịch của bạn...',
                hintStyle: const TextStyle(
                    color: AppColors.textDarkSecondary, fontSize: 14),
                filled: true,
                fillColor: AppColors.backgroundDark,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide:
                      const BorderSide(color: AppColors.borderDark, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: isLoading ? null : () => _sendMessage(_controller.text),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: isLoading
                    ? null
                    : const LinearGradient(
                        colors: [Color(0xFF4285F4), Color(0xFF9C27B0)],
                      ),
                color: isLoading ? AppColors.borderDark : null,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isLoading ? Icons.hourglass_empty : Icons.send_rounded,
                color: isLoading
                    ? AppColors.textDarkSecondary
                    : Colors.white,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Message Bubble Widget
// ─────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            // AI avatar
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 8, top: 2),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4285F4), Color(0xFF9C27B0)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.auto_awesome,
                  color: Colors.white, size: 16),
            ),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? AppColors.primary : AppColors.surfaceDark,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                border: isUser
                    ? null
                    : Border.all(color: AppColors.borderDark, width: 1),
              ),
              child: SelectableText(
                message.text,
                style: TextStyle(
                  color: isUser ? Colors.white : Colors.white,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Animated Loading Dots
// ─────────────────────────────────────────────

class _DotAnimation extends StatefulWidget {
  @override
  State<_DotAnimation> createState() => _DotAnimationState();
}

class _DotAnimationState extends State<_DotAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final offset = ((_controller.value * 3) - i).clamp(0.0, 1.0);
            final opacity = (1 - (offset - 0.5).abs() * 2).clamp(0.3, 1.0);
            return Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: opacity),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}
