import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/user_model.dart';
import 'repositories_providers.dart';
import 'services_providers.dart';

/// Provider to auto-create user document on first login
final autoCreateUserProvider = FutureProvider<void>((ref) async {
  final authService = ref.watch(authServiceProvider);
  final userRepository = ref.watch(userRepositoryProvider);
  
  final currentUser = authService.currentUser;
  
  if (currentUser != null) {
    // Check if user document exists
    final userDoc = await userRepository.getUserById(currentUser.uid);
    
    if (userDoc == null) {
      // Create new user document with pending role
      final newUser = UserModel.newUser(
        id: currentUser.uid,
        email: currentUser.email!,
        displayName: currentUser.displayName,
        photoUrl: currentUser.photoURL,
      );
      
      await userRepository.saveUser(newUser);
    }
  }
});
