import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/errors/failures.dart';
import '../../providers/services_providers.dart';
import '../../providers/repositories_providers.dart'; // ✅ THÊM import này
import 'register_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ✅ THÊM METHOD NÀY: đăng ký FCM token sau khi login thành công.
  //
  // Gọi sau authService.signInWithEmailPassword() để:
  //   1. Lấy FCM token hiện tại của thiết bị này
  //   2. Append vào fcmTokens trong Firestore (arrayUnion — không xóa token thiết bị khác)
  //   3. Setup callback onTokenChanged để tự động cập nhật khi Firebase refresh token
  //
  // Nếu thất bại → chỉ log warning, KHÔNG throw, KHÔNG block luồng login.
  Future<void> _registerFcmToken(String userId) async {
    try {
      final fcmService = ref.read(fcmServiceProvider);
      final userRepo = ref.read(userRepositoryProvider);

      // FCMService.initialize() đã gọi getToken() trước đó khi app khởi động.
      // Nếu chưa có (thiết bị cũ / lần đầu) thì gọi lại getToken().
      final token = fcmService.fcmToken ?? await fcmService.getToken();
      if (token == null || token.isEmpty) return;

      // Lưu token vào Firestore (arrayUnion → không ghi đè)
      await userRepo.registerFcmToken(userId, token);

      // Thiết lập callback: khi Firebase tự refresh token,
      // FCMService sẽ gọi callback này để tự động cập nhật Firestore.
      fcmService.onTokenChanged = (newToken, oldToken) async {
        if (oldToken != null && oldToken.isNotEmpty) {
          await userRepo.unregisterFcmToken(userId, oldToken);
        }
        await userRepo.registerFcmToken(userId, newToken);
      };
    } catch (e) {
      // Non-critical: FCM token không ảnh hưởng đến luồng đăng nhập chính.
      debugPrint('⚠️ _registerFcmToken failed (non-critical): $e');
    }
  }

  Future<void> _handleEmailLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = ref.read(authServiceProvider);

      // Bước 1: Đăng nhập Firebase Auth
      final user = await authService.signInWithEmailPassword(
        _emailController.text.trim(),
        _passwordController.text,
      );

      // ✅ Bước 2: Đăng ký FCM token cho thiết bị này
      // Gọi NGAY SAU khi có uid, trước khi Navigator pop/push.
      await _registerFcmToken(user.uid);

      if (mounted) {
        // Navigation được handle bởi AuthStateListener (không thay đổi)
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e is AuthFailure
              ? e.message
              : 'Đăng nhập thất bại. Vui lòng thử lại';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 40),
                    _buildEmailField(),
                    const SizedBox(height: 20),
                    _buildPasswordField(),
                    const SizedBox(height: 20),
                    if (_errorMessage != null) ...[
                      _buildErrorMessage(),
                      const SizedBox(height: 20),
                    ],
                    _buildLoginButton(),
                    const SizedBox(height: 16),
                    _buildActions(),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Don\'t have an account? ',
                          style: TextStyle(
                            color: AppColors.textDarkSecondary
                                .withValues(alpha: 0.7),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const RegisterScreen(),
                              ),
                            );
                          },
                          child: const Text(
                            'Sign Up',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Text(
          'Star Base',
          style: Theme.of(context).textTheme.displayLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: AppColors.borderDark, width: 1),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.library_music,
                    size: 20, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  'Nền tảng vận hành và quản lý nghệ sĩ toàn diện',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textDarkSecondary,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.6,
                        height: 1.3,
                      ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmailField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Email Address',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textDarkSecondary,
                fontWeight: FontWeight.w500,
              ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: 'name@cg-management.com'),
          validator: (value) {
            if (value == null || value.isEmpty) return 'Vui lòng nhập email';
            if (!value.contains('@')) return 'Email không hợp lệ';
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Password',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textDarkSecondary,
                fontWeight: FontWeight.w500,
              ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: '••••••••',
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                color: AppColors.textDarkSecondary,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) return 'Vui lòng nhập mật khẩu';
            if (value.length < 6) return 'Mật khẩu phải có ít nhất 6 ký tự';
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.errorDark.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.error,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleEmailLogin,
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text('Log In'),
      ),
    );
  }

  Widget _buildActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        TextButton(
          onPressed: () {
            // TODO: Implement forgot password
          },
          child: const Text('Forgot password?'),
        ),
        IconButton(
          onPressed: () {
            // TODO: Implement biometric auth
          },
          icon: const Icon(Icons.face,
              color: AppColors.textDarkSecondary, size: 28),
        ),
      ],
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      height: 48,
      child: OutlinedButton(
        onPressed: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24),
            const SizedBox(width: 8),
            Text(label),
          ],
        ),
      ),
    );
  }
}