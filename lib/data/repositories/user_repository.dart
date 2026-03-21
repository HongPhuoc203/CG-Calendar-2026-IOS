import '../models/user_model.dart';
import '../services/firestore_service.dart';
import '../../core/constants/app_constants.dart';
import '../../core/errors/failures.dart';

/// Repository for user operations
class UserRepository {
  final FirestoreService _firestoreService;

  UserRepository(this._firestoreService);

  /// Get user by ID
  Future<UserModel?> getUserById(String userId) async {
    try {
      final doc = await _firestoreService.getDocument(
        AppConstants.usersCollection,
        userId,
      );

      if (!doc.exists) return null;

      return UserModelX.fromFirestore(doc.data()!, doc.id);
    } catch (e) {
      throw FirestoreFailure('Lỗi lấy thông tin người dùng: $e');
    }
  }

  /// Stream user by ID
  Stream<UserModel?> streamUserById(String userId) {
    return _firestoreService
        .streamDocument(AppConstants.usersCollection, userId)
        .map((doc) {
      if (!doc.exists) return null;
      return UserModelX.fromFirestore(doc.data()!, doc.id);
    });
  }

  /// Create or update user
  Future<void> saveUser(UserModel user) async {
    try {
      await _firestoreService.createDocument(
        AppConstants.usersCollection,
        user.toFirestore(),
        docId: user.id,
      );
    } catch (e) {
      throw FirestoreFailure('Lỗi lưu người dùng: $e');
    }
  }

  /// Update user role and managed artists (Super Editor only)
  Future<void> updateUserRole({
    required String userId,
    required String role,
    List<String>? managedArtistIds,
  }) async {
    try {
      final data = <String, dynamic>{
        'role': role,
        'updatedAt': DateTime.now().toIso8601String(),
      };

      if (managedArtistIds != null) {
        data['managedArtistIds'] = managedArtistIds;
      }

      await _firestoreService.updateDocument(
        AppConstants.usersCollection,
        userId,
        data,
      );
    } catch (e) {
      throw FirestoreFailure('Lỗi cập nhật quyền: $e');
    }
  }

  /// Update FCM token
  Future<void> updateFcmToken(String userId, String token) async {
    try {
      await _firestoreService.updateDocument(
        AppConstants.usersCollection,
        userId,
        {
          'fcmToken': token,
          'updatedAt': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      throw FirestoreFailure('Lỗi cập nhật FCM token: $e');
    }
  }

  /// Get all pending users (for admin approval)
  Future<List<UserModel>> getPendingUsers() async {
    try {
      final snapshot = await _firestoreService.getCollection(
        AppConstants.usersCollection,
        queryBuilder: (ref) => ref.where('role', isEqualTo: 'pending'),
      );

      return snapshot.docs
          .map((doc) => UserModelX.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw FirestoreFailure('Lỗi lấy danh sách chờ duyệt: $e');
    }
  }

  /// Get all users (for admin)
  Stream<List<UserModel>> streamAllUsers() {
    return _firestoreService
        .streamCollection(AppConstants.usersCollection)
        .map((snapshot) => snapshot.docs
            .map((doc) => UserModelX.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  /// Update user status
  Future<void> updateUserStatus(String userId, String status) async {
    try {
      await _firestoreService.updateDocument(
        AppConstants.usersCollection,
        userId,
        {
          'status': status,
          'updatedAt': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      throw FirestoreFailure('Lỗi cập nhật trạng thái: $e');
    }
  }

  /// Update user (full update)
  Future<void> updateUser(UserModel user) async {
    try {
      final data = user.toFirestore();
      data['updatedAt'] = DateTime.now().toIso8601String();
      
      await _firestoreService.updateDocument(
        AppConstants.usersCollection,
        user.id,
        data,
      );
    } catch (e) {
      throw FirestoreFailure('Lỗi cập nhật user: $e');
    }
  }

  /// Delete user
  Future<void> deleteUser(String userId) async {
    try {
      await _firestoreService.deleteDocument(
        AppConstants.usersCollection,
        userId,
      );
    } catch (e) {
      throw FirestoreFailure('Lỗi xóa user: $e');
    }
  }

  /// Update user FCM token
  Future<void> updateUserFCMToken(String userId, String fcmToken) async {
    try {
      await _firestoreService.updateDocument(
        AppConstants.usersCollection,
        userId,
        {
          'fcmToken': fcmToken,
          'updatedAt': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      throw FirestoreFailure('Lỗi cập nhật FCM token: $e');
    }
  }

  /// Create new user (for registration)
  Future<void> createUser(UserModel user) async {
    try {
      final data = UserModelX(user).toFirestore();
      await _firestoreService.createDocument(
        AppConstants.usersCollection,
        data,
        docId: user.id,
      );
    } catch (e) {
      throw FirestoreFailure('Lỗi tạo user: $e');
    }
  }
}

