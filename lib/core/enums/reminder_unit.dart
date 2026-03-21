/// Time unit for reminders
enum ReminderUnit {
  minutes,
  hours,
  days;

  String get displayName {
    switch (this) {
      case ReminderUnit.minutes:
        return 'phút';
      case ReminderUnit.hours:
        return 'giờ';
      case ReminderUnit.days:
        return 'ngày';
    }
  }

  static ReminderUnit fromString(String unit) {
    switch (unit) {
      case 'minutes':
        return ReminderUnit.minutes;
      case 'hours':
        return ReminderUnit.hours;
      case 'days':
        return ReminderUnit.days;
      default:
        return ReminderUnit.hours;
    }
  }

  String toFirestore() {
    switch (this) {
      case ReminderUnit.minutes:
        return 'minutes';
      case ReminderUnit.hours:
        return 'hours';
      case ReminderUnit.days:
        return 'days';
    }
  }

  /// Convert to duration
  Duration toDuration(int value) {
    switch (this) {
      case ReminderUnit.minutes:
        return Duration(minutes: value);
      case ReminderUnit.hours:
        return Duration(hours: value);
      case ReminderUnit.days:
        return Duration(days: value);
    }
  }
}

