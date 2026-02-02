import 'package:cloud_firestore/cloud_firestore.dart';

/// Helper functions for Firestore data conversion
class FirestoreHelpers {
  /// Convert Firestore Timestamp or String to DateTime
  static DateTime? toDateTime(dynamic value) {
    if (value == null) return null;
    
    if (value is Timestamp) {
      return value.toDate();
    }
    
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        return null;
      }
    }
    
    return null;
  }
  
  /// Convert DateTime to Firestore Timestamp
  static Timestamp? toTimestamp(DateTime? dateTime) {
    if (dateTime == null) return null;
    return Timestamp.fromDate(dateTime);
  }
}
