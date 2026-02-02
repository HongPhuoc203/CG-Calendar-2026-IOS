# 🚀 CG Calendar - Setup Guide

## 📋 Hướng dẫn Setup Project

### 1. Cài đặt Dependencies

```bash
# Cài đặt Flutter packages
flutter pub get

# Chạy code generation cho Freezed models
flutter pub run build_runner build --delete-conflicting-outputs
```

### 2. Cấu hình Firebase

#### 2.1. Tạo Firebase Project
1. Truy cập [Firebase Console](https://console.firebase.google.com/)
2. Tạo project mới hoặc chọn project hiện có
3. Thêm các apps (Android, iOS, Web)

#### 2.2. Cài đặt Firebase CLI
```bash
# Cài đặt Firebase CLI
npm install -g firebase-tools

# Đăng nhập
firebase login

# Khởi tạo Firebase trong project
firebase init
```

#### 2.3. Enable Firebase Services
- ✅ **Authentication**: Email/Password, Google, Apple
- ✅ **Firestore Database**: Chế độ Production
- ✅ **Cloud Functions**: Node.js
- ✅ **Firebase Cloud Messaging**: Push notifications
- ✅ **Firebase Storage**: Upload ảnh avatar

### 3. Deploy Firestore Security Rules

```bash
# Deploy rules
firebase deploy --only firestore:rules

# Kiểm tra rules
firebase firestore:rules get
```

**Firestore Rules được lưu tại:** `firestore.rules`

### 4. Cấu hình Authentication

#### Google Sign-In
1. Vào Firebase Console > Authentication > Sign-in method
2. Enable **Google** provider
3. Thêm SHA-1 certificate fingerprint (cho Android)

```bash
# Lấy SHA-1 cho debug
cd android
./gradlew signingReport
```

#### Apple Sign-In
1. Enable **Apple** provider trong Firebase Console
2. Cấu hình Apple Developer Account
3. Tạo Service ID và Key
4. Thêm vào Firebase Console

### 5. Setup Cloud Functions (cho Notifications)

```bash
# Di chuyển vào thư mục functions
cd functions

# Cài đặt dependencies
npm install

# Deploy functions
firebase deploy --only functions
```

### 6. Chạy ứng dụng

```bash
# Android
flutter run -d android

# iOS
flutter run -d ios

# Web
flutter run -d chrome

# Build release
flutter build apk --release        # Android
flutter build ios --release        # iOS
flutter build web --release        # Web
```

---

## 📁 Cấu trúc Project

```
lib/
├── core/
│   ├── constants/          # App constants, colors
│   ├── enums/             # User roles, statuses, reminder units
│   ├── utils/             # Date utils, helpers
│   └── errors/            # Failure classes
│
├── data/
│   ├── models/            # Data models (Freezed)
│   │   ├── user_model.dart
│   │   ├── artist_model.dart
│   │   ├── event_model.dart
│   │   ├── event_type_model.dart
│   │   ├── reminder_model.dart
│   │   └── notification_job_model.dart
│   │
│   ├── repositories/      # Data access layer
│   │   ├── user_repository.dart
│   │   ├── artist_repository.dart
│   │   ├── event_repository.dart
│   │   ├── event_type_repository.dart
│   │   └── reminder_repository.dart
│   │
│   └── services/          # External services
│       ├── auth_service.dart
│       └── firestore_service.dart
│
├── providers/             # Riverpod state management
│   ├── services_providers.dart
│   ├── repositories_providers.dart
│   ├── auth_provider.dart
│   ├── artists_provider.dart
│   ├── events_provider.dart
│   ├── event_types_provider.dart
│   ├── reminders_provider.dart
│   └── theme_provider.dart
│
├── presentation/          # UI layer (chưa tạo - Phase 2)
│   ├── auth/
│   ├── calendar/
│   ├── events/
│   ├── admin/
│   └── widgets/
│
└── main.dart
```

---

## 🔐 Firestore Security Rules - Giải thích

### Quy tắc phân quyền:

#### 1. **Users Collection**
- User chỉ đọc được profile của mình
- Không thể tự gán role (prevent privilege escalation)
- Super Editor có thể xem và cập nhật tất cả users
- User có thể tự cập nhật FCM token

#### 2. **Artists Collection**
- Tất cả user (trừ pending) có thể xem
- Chỉ Super Editor mới có quyền CRUD

#### 3. **Events Collection**
- Tất cả user (trừ pending) có thể xem
- Super Editor có toàn quyền
- Editor chỉ có thể sửa/xóa events liên quan đến nghệ sĩ mình quản lý
- Quy tắc quan trọng: `event.artistIds ∩ user.managedArtistIds ≠ ∅`

#### 4. **Event Types Collection**
- Tất cả user có thể xem
- Chỉ Super Editor mới có quyền CRUD

#### 5. **Reminders Collection**
- User có thể xem reminders của events họ có quyền
- Editor và Super Editor có thể CRUD

#### 6. **Notification Jobs Collection**
- User chỉ đọc được notification của mình
- Không có quyền ghi từ client
- Chỉ Cloud Functions (service account) mới tạo được

---

## 🎯 Các Models chính

### 1. UserModel
```dart
- id: String
- email: String
- role: UserRole (pending/viewer/editor/super_editor)
- status: UserStatus (active/inactive/suspended)
- managedArtistIds: List<String> (cho Editor)
- fcmToken: String? (cho push notification)
```

### 2. ArtistModel
```dart
- id: String
- name: String
- colorHex: String (màu đại diện trên calendar)
- avatarUrl: String?
- isActive: bool
```

### 3. EventModel
```dart
- id: String
- title: String
- startTime: DateTime
- endTime: DateTime
- artistIds: List<String> (nhiều nghệ sĩ)
- eventTypeId: String
- checklistItems: List<ChecklistItem>
- customFields: Map<String, dynamic>
- links: List<EventLink> (Drive links)
```

### 4. EventTypeModel
```dart
- id: String
- name: String
- defaultChecklistItems: List<String>
- customFieldTemplates: List<CustomFieldTemplate>
```

### 5. ReminderModel
```dart
- id: String
- eventId: String
- value: int (e.g., 1, 2, 12)
- unit: ReminderUnit (minutes/hours/days)
- recipientUserIds: List<String>
- triggerTime: DateTime
```

---

## 🔄 Luồng đăng nhập & duyệt user

### Lần đầu đăng nhập:
1. User đăng nhập (Email/Google/Apple)
2. App kiểm tra `users/{uid}` trong Firestore
3. Nếu chưa có → tạo với `role: pending`
4. Hiển thị màn "Đang chờ duyệt"

### Super Editor duyệt user:
1. Vào Admin Panel
2. Xem danh sách `pending`
3. Chọn user và gán:
   - Role: viewer/editor/super_editor
   - managedArtistIds (nếu là editor)
4. User reload → có quyền truy cập

---

## 📱 Push Notification Flow

### 1. Manager tạo Event với Reminders
- Chọn thời gian nhắc (1h, 12h, 1d, 2d trước event)
- Chọn người nhận (nghệ sĩ, manager, super editor)

### 2. Cloud Function tự động:
```javascript
// Khi reminder được tạo
exports.onReminderCreated = functions.firestore
  .document('reminders/{reminderId}')
  .onCreate(async (snap, context) => {
    // Tạo notification_jobs cho từng recipient
    // Tính toán triggerTime
  });
```

### 3. Scheduler chạy định kỳ:
```javascript
// Chạy mỗi 5 phút
exports.sendScheduledNotifications = functions.pubsub
  .schedule('every 5 minutes')
  .onRun(async (context) => {
    // Query notification_jobs có triggerTime <= now
    // Gửi FCM push
    // Mark as sent
  });
```

---

## ⚠️ Lưu ý quan trọng

### 1. Bảo mật
- ✅ LUÔN enforce quyền bằng Security Rules, không chỉ UI
- ✅ Client KHÔNG BAO GIỜ được tự gán role
- ✅ Editor chỉ sửa event nếu có nghệ sĩ trong managedArtistIds
- ✅ Notification jobs chỉ được tạo bởi Cloud Functions

### 2. Performance
- Sử dụng `StreamProvider` cho real-time data
- Cache artists và event types
- Pagination cho events (limit 50/page)
- Index Firestore queries (sẽ prompt khi chạy query phức tạp)

### 3. Timezone
- Mặc định: **Asia/Ho_Chi_Minh**
- Tất cả DateTime lưu dưới dạng ISO8601 string
- Convert sang TZ khi hiển thị

### 4. Multi-artist Events
- Event có thể gắn nhiều nghệ sĩ
- Hiển thị màu của nghệ sĩ đầu tiên (hoặc gradient)
- Filter calendar theo multi-select

---

## 🧪 Testing

```bash
# Run unit tests
flutter test

# Run integration tests
flutter test integration_test

# Run with coverage
flutter test --coverage
```

---

## 📦 Build & Deploy

### Android (APK)
```bash
flutter build apk --release --split-per-abi
```

### iOS (App Store)
```bash
flutter build ios --release
# Mở Xcode để archive và upload
```

### Web (Hosting)
```bash
flutter build web --release
firebase deploy --only hosting
```

---

## 🐛 Troubleshooting

### Lỗi thường gặp:

#### 1. "Failed to read Firestore document"
- Kiểm tra Security Rules
- Xác nhận user có role phù hợp

#### 2. "Google Sign-In failed"
- Kiểm tra SHA-1 certificate
- Enable Google provider trong Firebase

#### 3. "Freezed code generation error"
- Chạy: `flutter pub run build_runner clean`
- Rồi: `flutter pub run build_runner build --delete-conflicting-outputs`

#### 4. "Timezone initialization failed"
- Đảm bảo gọi `tz.initializeTimeZones()` trong `main()`

---

## 📚 Resources

- [Flutter Documentation](https://flutter.dev/docs)
- [Firebase for Flutter](https://firebase.flutter.dev/)
- [Riverpod Documentation](https://riverpod.dev/)
- [Freezed Package](https://pub.dev/packages/freezed)
- [Table Calendar](https://pub.dev/packages/table_calendar)

---

## 👥 Team & Roles

- **Super Editor**: 1 người (toàn quyền)
- **Editor**: Quản lý nghệ sĩ (nhiều người)
- **Viewer**: Nghệ sĩ (chỉ xem)
- **Pending**: User mới (chờ duyệt)

---

**Chúc bạn build app thành công! 🎉**

