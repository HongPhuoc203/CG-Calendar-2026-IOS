import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import '../constants/app_constants.dart';

/// Utility functions for date/time operations
class DateTimeUtils {
  /// Format DateTime to display date
  static String formatDate(DateTime date) {
    return DateFormat(AppConstants.dateFormat).format(date);
  }

  /// Format DateTime to display time
  static String formatTime(DateTime date) {
    return DateFormat(AppConstants.timeFormat).format(date);
  }

  /// Format DateTime to display date and time
  static String formatDateTime(DateTime date) {
    return DateFormat(AppConstants.dateTimeFormat).format(date);
  }

  /// Get current time in Vietnam timezone
  static DateTime nowInVietnam() {
    final location = tz.getLocation(AppConstants.defaultTimezone);
    return tz.TZDateTime.now(location);
  }

  /// Convert DateTime to Vietnam timezone
  static DateTime toVietnamTime(DateTime date) {
    final location = tz.getLocation(AppConstants.defaultTimezone);
    return tz.TZDateTime.from(date, location);
  }

  /// Check if date is today
  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  /// Check if date is in the past
  static bool isPast(DateTime date) {
    return date.isBefore(DateTime.now());
  }

  /// Get start of day
  static DateTime startOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  /// Get end of day
  static DateTime endOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day, 23, 59, 59);
  }

  /// Get relative time string (e.g., "2 giờ nữa", "3 ngày trước")
  static String getRelativeTime(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now);

    if (difference.isNegative) {
      // Past
      final absDiff = difference.abs();
      if (absDiff.inDays > 0) {
        return '${absDiff.inDays} ngày trước';
      } else if (absDiff.inHours > 0) {
        return '${absDiff.inHours} giờ trước';
      } else if (absDiff.inMinutes > 0) {
        return '${absDiff.inMinutes} phút trước';
      } else {
        return 'Vừa xong';
      }
    } else {
      // Future
      if (difference.inDays > 0) {
        return '${difference.inDays} ngày nữa';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} giờ nữa';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} phút nữa';
      } else {
        return 'Bây giờ';
      }
    }
  }
}

