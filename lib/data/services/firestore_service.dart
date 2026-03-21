import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/errors/failures.dart';

/// Base Firestore service with common operations
class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  FirebaseFirestore get firestore => _firestore;

  /// Get a document by ID
  Future<DocumentSnapshot<Map<String, dynamic>>> getDocument(
    String collection,
    String docId,
  ) async {
    try {
      return await _firestore.collection(collection).doc(docId).get();
    } catch (e) {
      throw FirestoreFailure('Lỗi lấy dữ liệu: $e');
    }
  }

  /// Get all documents in a collection
  Future<QuerySnapshot<Map<String, dynamic>>> getCollection(
    String collection, {
    Query<Map<String, dynamic>>? Function(CollectionReference<Map<String, dynamic>>)? queryBuilder,
  }) async {
    try {
      CollectionReference<Map<String, dynamic>> collectionRef =
          _firestore.collection(collection);

      if (queryBuilder != null) {
        return await queryBuilder(collectionRef)!.get();
      }

      return await collectionRef.get();
    } catch (e) {
      throw FirestoreFailure('Lỗi lấy danh sách: $e');
    }
  }

  /// Create a document
  Future<String> createDocument(
    String collection,
    Map<String, dynamic> data, {
    String? docId,
  }) async {
    try {
      if (docId != null) {
        await _firestore.collection(collection).doc(docId).set(data);
        return docId;
      } else {
        final docRef = await _firestore.collection(collection).add(data);
        return docRef.id;
      }
    } catch (e) {
      throw FirestoreFailure('Lỗi tạo dữ liệu: $e');
    }
  }

  /// Update a document
  Future<void> updateDocument(
    String collection,
    String docId,
    Map<String, dynamic> data,
  ) async {
    try {
      await _firestore.collection(collection).doc(docId).update(data);
    } catch (e) {
      throw FirestoreFailure('Lỗi cập nhật: $e');
    }
  }

  /// Delete a document
  Future<void> deleteDocument(String collection, String docId) async {
    try {
      await _firestore.collection(collection).doc(docId).delete();
    } catch (e) {
      throw FirestoreFailure('Lỗi xóa dữ liệu: $e');
    }
  }

  /// Stream a document
  Stream<DocumentSnapshot<Map<String, dynamic>>> streamDocument(
    String collection,
    String docId,
  ) {
    return _firestore.collection(collection).doc(docId).snapshots();
  }

  /// Stream a collection
  Stream<QuerySnapshot<Map<String, dynamic>>> streamCollection(
    String collection, {
    Query<Map<String, dynamic>>? Function(CollectionReference<Map<String, dynamic>>)? queryBuilder,
  }) {
    CollectionReference<Map<String, dynamic>> collectionRef =
        _firestore.collection(collection);

    if (queryBuilder != null) {
      return queryBuilder(collectionRef)!.snapshots();
    }

    return collectionRef.snapshots();
  }

  /// Batch write operations
  WriteBatch batch() => _firestore.batch();
}

