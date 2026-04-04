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

/// Provider to initialize FCM and Local Notifications when user is authenticated.
///
/// Key guarantees:
///   1. onTokenChanged is wired up FIRST so every future token refresh is
///      automatically persisted to Firestore (old token removed, new token added).
///   2. requestPermission() is always called explicitly and its result is logged,
///      even if fcmService.initialize() failed part-way through.
///   3. getToken() result is always logged — null means permission was denied
///      (iOS) or GMS is unavailable; non-null tokens are saved via arrayUnion.
///   4. All errors include a full stack trace so failures are diagnosable.
final fcmInitializerProvider = FutureProvider.family<void, String?>((ref, userId) async {
  if (userId == null) return;

  final fcmService  = ref.read(fcmServiceProvider);
  final localScheduler = ref.read(localNotificationSchedulerProvider);
  final userRepo   = ref.read(userRepositoryProvider);

  // ── Step 1: wire up token-refresh callback BEFORE initialize() ──────────
  // FCMService.initialize() starts the onTokenRefresh listener. If onTokenChanged
  // is null at that point the refreshed token is dropped. Set it first.
  fcmService.onTokenChanged = (newToken, oldToken) async {
    logger.i('[FCM] Token refreshed — old: ${oldToken?.substring(0, 20) ?? 'none'}, '
        'new: ${newToken.substring(0, 20)}... userId: $userId');
    try {
      if (oldToken != null && oldToken.isNotEmpty) {
        await userRepo.unregisterFcmToken(userId, oldToken);
      }
      await userRepo.registerFcmToken(userId, newToken);
      logger.i('[FCM] Refreshed token saved to Firestore for userId: $userId');
    } catch (e, st) {
      logger.e('[FCM] Failed to persist refreshed token', error: e, stackTrace: st);
    }
  };

  // ── Step 2: initialize FCM service (sets up local-notification plugin,
  //           requests system permission, begins onTokenRefresh listener) ──
  try {
    logger.i('[FCM] Starting FCMService.initialize() for userId: $userId');
    await fcmService.initialize();
    logger.i('[FCM] FCMService.initialize() completed');
  } catch (e, st) {
    // initialize() has its own internal try-catch and normally never throws,
    // but guard here in case the platform layer throws directly.
    logger.e('[FCM] FCMService.initialize() threw unexpectedly', error: e, stackTrace: st);
  }

  // ── Step 3: initialize local notification scheduler ─────────────────────
  try {
    await localScheduler.initialize();
    logger.i('[FCM] LocalNotificationScheduler initialized');
  } catch (e, st) {
    logger.e('[FCM] LocalNotificationScheduler.initialize() failed', error: e, stackTrace: st);
  }

  // ── Step 4: request battery optimization exemption ──────────────────────
  try {
    await localScheduler.requestBatteryOptimizationExemption();
  } catch (e, st) {
    logger.e('[FCM] requestBatteryOptimizationExemption() failed', error: e, stackTrace: st);
  }

  // ── Step 5: explicitly check/re-request permission and log the result ───
  // Even if initialize() failed internally before calling requestPermission(),
  // we call it here so the dialog is shown and the status is known.
  try {
    final settings = await fcmService.requestPermission();
    logger.i('[FCM] Notification permission status: ${settings.authorizationStatus} '
        'for userId: $userId');
  } catch (e, st) {
    logger.e('[FCM] requestPermission() failed', error: e, stackTrace: st);
  }

  // ── Step 6: get token and persist to Firestore ───────────────────────────
  try {
    final token = await fcmService.getToken();

    if (token == null) {
      // Most common causes:
      //   iOS  — notification permission was denied by the user.
      //   Any  — no internet at this exact moment (token unavailable).
      //   Any  — Firebase project misconfiguration / no GMS on device.
      logger.w('[FCM] getToken() returned null — notification permission may be '
          'denied, or no connectivity. userId: $userId. '
          'The token will be registered on the next onTokenRefresh event.');
      return;
    }

    logger.i('[FCM] Token obtained: ${token.substring(0, 20)}... userId: $userId');
    await userRepo.registerFcmToken(userId, token);
    logger.i('[FCM] Token saved to Firestore (arrayUnion) for userId: $userId');
  } catch (e, st) {
    logger.e('[FCM] getToken/registerFcmToken failed', error: e, stackTrace: st);
  }
});

/// Provider to sync Firestore reminders → local notifications (no composite index needed).
///
/// Flow:
///   1. Login: fetch all pending reminders where userId ∈ recipientUserIds → schedule locally.
///   2. Real-time: Firestore stream watches for any reminder change → re-sync.
///   3. Logout/dispose: stop listener, cancel all scheduled local notifications.
///
/// This covers all recipient types:
///   - super_editor: included in every event's recipientUserIds (canManageSystem = true)
///   - editor: included if they manage ≥1 artist in the event
///   - viewer: included if their artistId is in the event's artistIds
///   - creator: always included
final reminderSyncInitializerProvider = FutureProvider.family<void, String?>((ref, userId) async {
  if (userId == null) return;

  try {
    final syncService = ref.read(reminderSyncServiceProvider);
    final reminderRepo = ref.read(reminderRepositoryProvider);
    final eventRepo = ref.read(eventRepositoryProvider);
    final scheduler = ref.read(localNotificationSchedulerProvider);

    // Initial full sync from Firestore
    await syncService.syncAndSchedule(
      userId: userId,
      reminderRepo: reminderRepo,
      eventRepo: eventRepo,
      scheduler: scheduler,
    );

    // Start real-time listener for future changes
    syncService.startListening(
      userId: userId,
      reminderRepo: reminderRepo,
      eventRepo: eventRepo,
      scheduler: scheduler,
    );

    ref.onDispose(() => syncService.stopListening());
  } catch (e) {
    logger.e('Failed to initialize ReminderSync', error: e);
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
            
            // Initialize FCM + sync reminders for all devices of this user
            ref.watch(fcmInitializerProvider(user.uid));
            ref.watch(reminderSyncInitializerProvider(user.uid));

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
