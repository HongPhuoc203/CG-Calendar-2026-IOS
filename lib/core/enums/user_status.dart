/// User account status
enum UserStatus {
  active,
  inactive,
  suspended;

  String get displayName {
    switch (this) {
      case UserStatus.active:
        return 'Đang hoạt động';
      case UserStatus.inactive:
        return 'Không hoạt động';
      case UserStatus.suspended:
        return 'Bị đình chỉ';
    }
  }

  static UserStatus fromString(String status) {
    switch (status) {
      case 'active':
        return UserStatus.active;
      case 'inactive':
        return UserStatus.inactive;
      case 'suspended':
        return UserStatus.suspended;
      default:
        return UserStatus.active;
    }
  }

  String toFirestore() {
    switch (this) {
      case UserStatus.active:
        return 'active';
      case UserStatus.inactive:
        return 'inactive';
      case UserStatus.suspended:
        return 'suspended';
    }
  }
}

