/// User roles in the system
enum UserRole {
  viewer,
  editor,
  superEditor,
  guest;

  String get displayName {
    switch (this) {
      case UserRole.viewer:
        return 'Nghệ sĩ';
      case UserRole.editor:
        return 'Quản lý nghệ sĩ';
      case UserRole.superEditor:
        return 'Quản lý tổng';
      case UserRole.guest:
        return 'Khách';
    }
  }

  /// Check if user can edit events
  bool get canEdit => this == UserRole.editor || this == UserRole.superEditor;

  /// Check if user can manage system (approve users, manage event types)
  bool get canManageSystem => this == UserRole.superEditor;

  /// Check if user can view events
  bool get canViewEvents => true;

  // Chỉ xem được màn hình lịch
  bool get isGuestOnly  => this == UserRole.guest;

  /// Convert from string (from Firestore)
  static UserRole fromString(String role) {
    switch (role) {
      case 'viewer':
        return UserRole.viewer;
      case 'editor':
        return UserRole.editor;
      case 'super_editor':
        return UserRole.superEditor;
      case 'guest':
        return UserRole.guest;
      default:
        return UserRole.guest;
    }
  }

  /// Convert to string (for Firestore)
  String toFirestore() {
    switch (this) {
      case UserRole.viewer:
        return 'viewer';
      case UserRole.editor:
        return 'editor';
      case UserRole.superEditor:
        return 'super_editor';
      case UserRole.guest:
        return 'guest';
    }
  }
}

