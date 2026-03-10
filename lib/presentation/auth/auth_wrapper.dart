import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/services_providers.dart';
import '../../data/models/user_model.dart';
import '../../providers/repositories_providers.dart';
import '../auth/login_screen.dart';
import '../auth/pending_approval_screen.dart';
import '../main/main_screen.dart';
import '../splash/splash_screen.dart';
import '../../core/utils/logger.dart';

/// Provider to initialize FCM and Local Notifications when user is authenticated
final fcmInitializerProvider = FutureProvider.family<void, String?>((ref, userId) async {
  if (userId == null) return;
  
  try {
    final fcmService = ref.read(fcmServiceProvider);
    final localScheduler = ref.read(localNotificationSchedulerProvider);
    final userRepo = ref.read(userRepositoryProvider);
    
    // Initialize FCM
    await fcmService.initialize();
    
    // Initialize Local Notification Scheduler
    await localScheduler.initialize();
    logger.i('Local notification scheduler initialized');

    // Request battery optimization exemption (critical for Samsung/MIUI/ColorOS)
    await localScheduler.requestBatteryOptimizationExemption();
    
    // Get token
    final token = await fcmService.getToken();
    
    // Save token to Firestore
    if (token != null) {
      await userRepo.updateUserFCMToken(userId, token);
      logger.i('FCM token saved for user: $userId');
    }
  } catch (e) {
    logger.e('Failed to initialize FCM/Notifications', error: e);
  }
});

/// Auth Wrapper - Routes users based on authentication state and role
class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    
    return authState.when(
      data: (user) {
        if (user == null) {
          // Not logged in -> Login Screen
          return const LoginScreen();
        }
        
        // Logged in -> Check user profile and role
        final userProfile = ref.watch(currentUserProfileProvider);
        
        return userProfile.when(
          data: (profile) {
            if (profile == null) {
              // User document doesn't exist yet -> Create it
              return _CreateUserDocumentScreen(userId: user.uid, user: user);
            }
            
            // Initialize FCM for authenticated users
            ref.watch(fcmInitializerProvider(user.uid));
            
            // Route based on role
            switch (profile.role.toFirestore()) {
              case 'pending':
                return const PendingApprovalScreen();
              case 'viewer':
              case 'editor':
              case 'super_editor':
                return const MainScreen();
              default:
                return const PendingApprovalScreen();
            }
          },
          loading: () => const _LoadingScreen(),
          error: (error, stack) => _ErrorScreen(error: error.toString()),
        );
      },
      loading: () => const SplashScreen(),
      error: (error, stack) => _ErrorScreen(error: error.toString()),
    );
  }
}

/// Loading screen while fetching user data
class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: AppColors.primary,
            ),
            SizedBox(height: 24),
            Text(
              'Đang tải...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Creating user document screen
class _CreateUserDocumentScreen extends ConsumerStatefulWidget {
  final String userId;
  final dynamic user;
  
  const _CreateUserDocumentScreen({
    required this.userId,
    required this.user,
  });

  @override
  ConsumerState<_CreateUserDocumentScreen> createState() => _CreateUserDocumentScreenState();
}

class _CreateUserDocumentScreenState extends ConsumerState<_CreateUserDocumentScreen> {
  @override
  void initState() {
    super.initState();
    _createUserDocument();
  }
  
  Future<void> _createUserDocument() async {
    try {
      final userRepository = ref.read(userRepositoryProvider);
      
      // Create new user document with pending role
      final newUser = UserModel.newUser(
        id: widget.userId,
        email: widget.user.email!,
        displayName: widget.user.displayName,
        photoUrl: widget.user.photoURL,
      );
      
      await userRepository.saveUser(newUser);
      
      // Force refresh to show pending screen
      if (mounted) {
        setState(() {});
      }
    } catch (e, stackTrace) {
      // Handle error
      logger.e('Error creating user document', error: e, stackTrace: stackTrace,);
    }
  }
 
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: AppColors.primary,
            ),
            SizedBox(height: 24),
            Text(
              'Đang thiết lập tài khoản...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Error screen
class _ErrorScreen extends ConsumerWidget {
  final String error;
  
  const _ErrorScreen({required this.error});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 80,
                color: AppColors.error,
              ),
              const SizedBox(height: 24),
              const Text(
                'Có lỗi xảy ra',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                error,
                style: const TextStyle(
                  color: AppColors.textDarkSecondary,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      try {
                        final authService = ref.read(authServiceProvider);
                        await authService.signOut();
                      } catch (e) {
                        logger.e('Logout error', error: e);
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textDarkSecondary,
                      side: const BorderSide(color: AppColors.borderDark),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                    ),
                    icon: const Icon(Icons.logout, size: 20),
                    label: const Text('Đăng xuất'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      // Force refresh by invalidating providers
                      ref.invalidate(authStateProvider);
                      ref.invalidate(currentUserProfileProvider);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                    ),
                    icon: const Icon(Icons.refresh, size: 20),
                    label: const Text('Thử lại'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
