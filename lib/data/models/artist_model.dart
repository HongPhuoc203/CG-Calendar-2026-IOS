import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter/material.dart';
import '../../core/utils/firestore_helpers.dart';

part 'artist_model.freezed.dart';
part 'artist_model.g.dart';

@freezed
class ArtistModel with _$ArtistModel {
  const factory ArtistModel({
    required String id,
    required String name,
    required String colorHex, // Color stored as hex string
    String? avatarUrl,
    String? bio,
    String? phoneNumber,
    @Default(true) bool isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _ArtistModel;

  factory ArtistModel.fromJson(Map<String, dynamic> json) =>
      _$ArtistModelFromJson(json);
}

/// Extension for additional functionality
extension ArtistModelX on ArtistModel {
  /// Get color from hex string
  Color get color => Color(int.parse(colorHex.replaceAll('#', '0xFF')));

  /// Convert to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'colorHex': colorHex,
      'avatarUrl': avatarUrl,
      'bio': bio,
      'phoneNumber': phoneNumber,
      'isActive': isActive,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  /// Create from Firestore document
  static ArtistModel fromFirestore(Map<String, dynamic> data, String id) {
    return ArtistModel(
      id: id,
      name: data['name'] as String,
      colorHex: data['colorHex'] as String,
      avatarUrl: data['avatarUrl'] as String?,
      bio: data['bio'] as String?,
      phoneNumber: data['phoneNumber'] as String?,
      isActive: data['isActive'] as bool? ?? true,
      createdAt: FirestoreHelpers.toDateTime(data['createdAt']),
      updatedAt: FirestoreHelpers.toDateTime(data['updatedAt']),
    );
  }
}

