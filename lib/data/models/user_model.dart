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
    required UserRole role,
    required UserStatus status,

    /// For VIEWER: the artist this user represents
    String? artistId,

    /// For EDITOR: list of artists this user manages
    @Default([]) List<String> managedArtistIds,

    // ✅ FIX: String? fcmToken → List<String> fcmTokens
    // Hỗ trợ đăng nhập đồng thời trên nhiều thiết bị.
    @Default([]) List<String> fcmTokens,

    /// Quyền xem doanh thu — chỉ áp dụng cho EDITOR.
    /// SuperEditor luôn thấy; Viewer/Guest không thấy.
    /// Quản lí tổng (superEditor) có thể bật/tắt per-editor.
    @Default(false) bool canViewRevenue,

    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _UserModel;

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);

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
      role: UserRole.guest,
      status: UserStatus.active,
      fcmTokens: [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}

extension UserModelX on UserModel {
  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'role': role.toFirestore(),
      'status': status.toFirestore(),
      'artistId': artistId,
      'managedArtistIds': managedArtistIds,
      'fcmTokens': fcmTokens,
      'canViewRevenue': canViewRevenue,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

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

      // ✅ Backward-compatible: đọc được cả field cũ 'fcmToken' (String)
      // lẫn field mới 'fcmTokens' (List) — không cần migration script.
      fcmTokens: _parseFcmTokens(data),
      canViewRevenue: data['canViewRevenue'] as bool? ?? false,

      createdAt: FirestoreHelpers.toDateTime(data['createdAt']),
      updatedAt: FirestoreHelpers.toDateTime(data['updatedAt']),
    );
  }

  static List<String> _parseFcmTokens(Map<String, dynamic> data) {
    // Ưu tiên field mới
    if (data['fcmTokens'] != null) {
      return List<String>.from(data['fcmTokens']);
    }
    // Fallback về field cũ (dữ liệu Firestore chưa migrate)
    final old = data['fcmToken'] as String?;
    return (old != null && old.isNotEmpty) ? [old] : [];
  }
}