/// App-wide constants
class AppConstants {
  // Timezone
  static const String defaultTimezone = 'Asia/Ho_Chi_Minh';
  
  // Firestore Collections
  static const String usersCollection = 'users';
  static const String artistsCollection = 'artists';
  static const String eventsCollection = 'events';
  static const String eventTypesCollection = 'event_types';
  static const String remindersCollection = 'reminders';
  static const String notificationJobsCollection = 'notification_jobs';
  static const String notificationsCollection = 'notifications';
  
  // Date Formats
  static const String dateFormat = 'dd/MM/yyyy';
  static const String timeFormat = 'HH:mm';
  static const String dateTimeFormat = 'dd/MM/yyyy HH:mm';
  
  // Notification Channels
  static const String notificationChannelId = 'cg_calendar_channel';
  static const String notificationChannelName = 'CG Calendar Notifications';
  static const String notificationChannelDescription = 'Notifications for upcoming events';
  
  // Pagination
  static const int eventsPerPage = 50;
  
  // Max values
  static const int maxArtistsPerEvent = 10;
  static const int maxRemindersPerEvent = 5;
}

