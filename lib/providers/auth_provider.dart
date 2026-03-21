import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/user_model.dart';
import 'services_providers.dart';
import 'repositories_providers.dart';

/// Provider for Firebase Auth user stream
final authStateProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});

/// Provider for current user ID
final currentUserIdProvider = Provider<String?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) => user?.uid,
    loading: () => null,
    error: (_, __) => null,
  );
});

/// Provider for current user profile from Firestore
final currentUserProfileProvider = StreamProvider<UserModel?>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  
  if (userId == null) {
    return Stream.value(null);
  }
  
  final userRepository = ref.watch(userRepositoryProvider);
  return userRepository.streamUserById(userId);
});

/// Provider to check if user is authenticated
final isAuthenticatedProvider = Provider<bool>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) => user != null,
    loading: () => false,
    error: (_, __) => false,
  );
});

/// Provider to check if user can edit
final canEditProvider = Provider<bool>((ref) {
  final userProfile = ref.watch(currentUserProfileProvider);
  return userProfile.when(
    data: (user) => user?.role.canEdit ?? false,
    loading: () => false,
    error: (_, __) => false,
  );
});

/// Provider to check if user is Super Editor
final isSuperEditorProvider = Provider<bool>((ref) {
  final userProfile = ref.watch(currentUserProfileProvider);
  return userProfile.when(
    data: (user) => user?.role.canManageSystem ?? false,
    loading: () => false,
    error: (_, __) => false,
  );
});

/// Provider to check if user can view events
final canViewEventsProvider = Provider<bool>((ref) {
  final userProfile = ref.watch(currentUserProfileProvider);
  return userProfile.when(
    data: (user) => user?.role.canViewEvents ?? false,
    loading: () => false,
    error: (_, __) => false,
  );
});

