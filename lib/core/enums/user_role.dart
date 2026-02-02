/// User roles in the system
enum UserRole {
  pending,
  viewer,
  editor,
  superEditor;

  String get displayName {
    switch (this) {
      case UserRole.pending:
        return 'Đang chờ duyệt';
      case UserRole.viewer:
        return 'Nghệ sĩ';
      case UserRole.editor:
        return 'Quản lý nghệ sĩ';
      case UserRole.superEditor:
        return 'Quản lý tổng';
    }
  }

  /// Check if user can edit events
  bool get canEdit => this == UserRole.editor || this == UserRole.superEditor;

  /// Check if user can manage system (approve users, manage event types)
  bool get canManageSystem => this == UserRole.superEditor;

  /// Check if user can view events
  bool get canViewEvents => this != UserRole.pending;

  /// Convert from string (from Firestore)
  static UserRole fromString(String role) {
    switch (role) {
      case 'pending':
        return UserRole.pending;
      case 'viewer':
        return UserRole.viewer;
      case 'editor':
        return UserRole.editor;
      case 'super_editor':
        return UserRole.superEditor;
      default:
        return UserRole.pending;
    }
  }

  /// Convert to string (for Firestore)
  String toFirestore() {
    switch (this) {
      case UserRole.pending:
        return 'pending';
      case UserRole.viewer:
        return 'viewer';
      case UserRole.editor:
        return 'editor';
      case UserRole.superEditor:
        return 'super_editor';
    }
  }
}

