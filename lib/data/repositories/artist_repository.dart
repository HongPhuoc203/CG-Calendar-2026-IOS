import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/artist_model.dart';
import '../services/firestore_service.dart';
import '../../core/constants/app_constants.dart';
import '../../core/errors/failures.dart';

/// Repository for artist operations
class ArtistRepository {
  final FirestoreService _firestoreService;

  ArtistRepository(this._firestoreService);

  /// Get all active artists
  Future<List<ArtistModel>> getAllArtists() async {
    try {
      final snapshot = await _firestoreService.getCollection(
        AppConstants.artistsCollection,
        queryBuilder: (ref) => ref.where('isActive', isEqualTo: true),
      );

      return snapshot.docs
          .map((doc) => ArtistModelX.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw FirestoreFailure('Lỗi lấy danh sách nghệ sĩ: $e');
    }
  }

  /// Stream all active artists
  Stream<List<ArtistModel>> streamAllArtists() {
    return _firestoreService.streamCollection(
      AppConstants.artistsCollection,
      queryBuilder: (ref) => ref.where('isActive', isEqualTo: true),
    ).map((snapshot) => snapshot.docs
        .map((doc) => ArtistModelX.fromFirestore(doc.data(), doc.id))
        .toList());
  }

  /// Get artist by ID
  Future<ArtistModel?> getArtistById(String artistId) async {
    try {
      final doc = await _firestoreService.getDocument(
        AppConstants.artistsCollection,
        artistId,
      );

      if (!doc.exists) return null;

      return ArtistModelX.fromFirestore(doc.data()!, doc.id);
    } catch (e) {
      throw FirestoreFailure('Lỗi lấy thông tin nghệ sĩ: $e');
    }
  }

  /// Get multiple artists by IDs
  Future<List<ArtistModel>> getArtistsByIds(List<String> artistIds) async {
    if (artistIds.isEmpty) return [];

    try {
      final snapshot = await _firestoreService.getCollection(
        AppConstants.artistsCollection,
        queryBuilder: (ref) => ref.where(
          FieldPath.documentId,
          whereIn: artistIds,
        ),
      );

      return snapshot.docs
          .map((doc) => ArtistModelX.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw FirestoreFailure('Lỗi lấy danh sách nghệ sĩ: $e');
    }
  }

  /// Create artist
  Future<String> createArtist(ArtistModel artist) async {
    try {
      final data = artist.toFirestore();
      data['createdAt'] = DateTime.now().toIso8601String();
      data['updatedAt'] = DateTime.now().toIso8601String();

      return await _firestoreService.createDocument(
        AppConstants.artistsCollection,
        data,
      );
    } catch (e) {
      throw FirestoreFailure('Lỗi tạo nghệ sĩ: $e');
    }
  }

  /// Update artist
  Future<void> updateArtist(ArtistModel artist) async {
    try {
      final data = artist.toFirestore();
      data['updatedAt'] = DateTime.now().toIso8601String();

      await _firestoreService.updateDocument(
        AppConstants.artistsCollection,
        artist.id,
        data,
      );
    } catch (e) {
      throw FirestoreFailure('Lỗi cập nhật nghệ sĩ: $e');
    }
  }

  /// Delete artist (soft delete - set isActive to false)
  Future<void> deleteArtist(String artistId) async {
    try {
      await _firestoreService.updateDocument(
        AppConstants.artistsCollection,
        artistId,
        {
          'isActive': false,
          'updatedAt': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      throw FirestoreFailure('Lỗi xóa nghệ sĩ: $e');
    }
  }
}

