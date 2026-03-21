import 'package:freezed_annotation/freezed_annotation.dart';
import '../../core/enums/user_role.dart';
import '../../core/enums/user_status.dart';
import '../../core/utils/firestore_helpers.dart';

part 'user_model.freezed.dart';
part 'user_model.g.dart';

@freezed
class UserModel with _$UserModel {
  const factory UserModel({
    required String id,
    required String email,
    String? displayName,
    String? photoUrl,

    /// Role of the user in the system
    required UserRole role,

    /// Account status (active / inactive / suspended)
    required UserStatus status,

    /// For VIEWER: the artist this user represents (only see this artist's events)
    String? artistId,

    /// For EDITOR: list of artists this user manages
    @Default([]) List<String> managedArtistIds,

    /// Last known FCM token for push notifications
    String? fcmToken,

    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _UserModel;

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);

  /// Create a new user with pending role (for first-time login)
  factory UserModel.newUser({
    required String id,
    required String email,
    String? displayName,
    String? photoUrl,
  }) {
    return UserModel(
      id: id,
      email: email,
      displayName: displayName,
      photoUrl: photoUrl,
      role: UserRole.pending,
      status: UserStatus.active,
      artistId: null,
      managedArtistIds: [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}

/// Extension for Firestore conversion
extension UserModelX on UserModel {
  /// Convert to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'role': role.toFirestore(),
      'status': status.toFirestore(),
      'artistId': artistId,
      'managedArtistIds': managedArtistIds,
      'fcmToken': fcmToken,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  /// Create from Firestore document
  static UserModel fromFirestore(Map<String, dynamic> data, String id) {
    return UserModel(
      id: id,
      email: data['email'] as String,
      displayName: data['displayName'] as String?,
      photoUrl: data['photoUrl'] as String?,
      role: UserRole.fromString(data['role'] as String),
      status: UserStatus.fromString(data['status'] as String? ?? 'active'),
      artistId: data['artistId'] as String?,
      managedArtistIds: List<String>.from(data['managedArtistIds'] ?? []),
      fcmToken: data['fcmToken'] as String?,
      createdAt: FirestoreHelpers.toDateTime(data['createdAt']),
      updatedAt: FirestoreHelpers.toDateTime(data['updatedAt']),
    );
  }
}

