# ⚡ Quick Start - CG Calendar

## 🎯 Tổng quan

Bạn đã có **foundation hoàn chỉnh** của CG Calendar bao gồm:
- ✅ Cấu trúc project (Clean Architecture)
- ✅ Models với Freezed
- ✅ Repositories & Services
- ✅ Riverpod Providers
- ✅ Firestore Security Rules
- ✅ Tất cả dependencies

**Còn thiếu:** UI Screens (Phase 2)

---

## 🚀 Chạy App Ngay Lập Tức

### Bước 1: Generate Freezed Code

```bash
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
```

**Lưu ý:** Bạn sẽ thấy nhiều warnings về missing `.freezed.dart` và `.g.dart` files. Đây là **bình thường** - chúng sẽ được generate ở bước này.

### Bước 2: Chạy App

```bash
# Android
flutter run -d android

# iOS
flutter run -d ios

# Web
flutter run -d chrome
```

Nếu thành công, bạn sẽ thấy màn hình:
```
┌─────────────────────┐
│   📅 Calendar Icon   │
│    CG Calendar       │
│  Setup hoàn tất! ✅  │
│ 📱 Android | 🍎 iOS  │
└─────────────────────┘
```

---

## 🔥 Setup Firebase (Bắt buộc cho production)

### 1. Tạo Firebase Project

1. Vào [Firebase Console](https://console.firebase.google.com/)
2. Tạo project mới: **"CG Calendar"**
3. Enable Google Analytics (optional)

### 2. Thêm Apps

#### Android App
```bash
# Trong project root
firebase init

# Hoặc dùng FlutterFire CLI (khuyến nghị)
dart pub global activate flutterfire_cli
flutterfire configure
```

Làm theo wizard:
- Chọn project
- Chọn platforms (Android, iOS, Web)
- Firebase sẽ tự động tạo `firebase_options.dart`

#### iOS App
- Làm tương tự như Android
- Đảm bảo đã cài CocoaPods: `sudo gem install cocoapods`

#### Web App
- Làm tương tự
- Firebase sẽ update `web/index.html`

### 3. Enable Firebase Services

#### Authentication
```
Firebase Console > Authentication > Sign-in method
- Enable: Email/Password ✅
- Enable: Google ✅
- Enable: Apple ✅ (chỉ cần cho iOS)
```

#### Firestore Database
```
Firebase Console > Firestore Database > Create Database
- Start in: Production mode
- Location: asia-southeast1 (Singapore) hoặc asia-east1 (Taiwan)
```

#### Cloud Messaging
```
Firebase Console > Cloud Messaging
- Không cần config gì thêm (auto-enabled)
```

### 4. Deploy Security Rules

```bash
# Trong project root
firebase deploy --only firestore:rules
```

**Quan trọng:** Rules file đã có sẵn tại `firestore.rules`

---

## 📱 Config cho từng Platform

### Android (SHA-1 for Google Sign-In)

```bash
cd android
./gradlew signingReport

# Copy SHA-1 fingerprint
# Paste vào: Firebase Console > Project Settings > Your apps > Android app > SHA certificate fingerprints
```

### iOS (Apple Sign-In)

1. Vào Apple Developer Account
2. Tạo Service ID cho Sign in with Apple
3. Copy vào Firebase Console > Authentication > Apple provider

### Web (Additional Config)

Không cần config thêm - Firebase đã tự động setup.

---

## 🗂️ Cấu trúc Files

```
lib/
├── core/               ✅ DONE
├── data/               ✅ DONE
├── providers/          ✅ DONE
├── presentation/       ⏳ TODO (Phase 2)
└── main.dart           ✅ DONE

firestore.rules         ✅ DONE
pubspec.yaml            ✅ DONE

Docs:
├── SETUP_GUIDE.md              📚 Chi tiết setup
├── PROJECT_STRUCTURE.md        📊 Kiến trúc
├── CLOUD_FUNCTIONS_GUIDE.md    ☁️ Notifications
└── QUICK_START.md              ⚡ File này
```

---

## 🎨 Phase 2: Build UI (Chưa làm)

Để có app hoàn chỉnh, bạn cần tạo:

### 1. Authentication Screens
```
lib/presentation/auth/
├── login_screen.dart
├── email_login_screen.dart
├── pending_approval_screen.dart
└── widgets/
```

### 2. Calendar Screen
```
lib/presentation/calendar/
├── calendar_screen.dart
├── widgets/
│   ├── calendar_view.dart
│   ├── artist_filter.dart
│   └── event_card.dart
```

### 3. Event Screens
```
lib/presentation/events/
├── event_details_screen.dart
├── create_event_screen.dart
├── edit_event_screen.dart
└── widgets/
```

### 4. Admin Panel
```
lib/presentation/admin/
├── user_management_screen.dart
├── artist_management_screen.dart
└── event_type_management_screen.dart
```

---

## 🧪 Test với Sample Data

### Tạo dữ liệu mẫu trong Firestore Console:

#### 1. Collection: `artists`

```json
{
  "name": "Nghệ sĩ A",
  "colorHex": "#FF6B6B",
  "avatarUrl": null,
  "isActive": true,
  "createdAt": "2026-01-02T10:00:00Z",
  "updatedAt": "2026-01-02T10:00:00Z"
}
```

#### 2. Collection: `event_types`

```json
{
  "name": "Biểu diễn",
  "description": "Sự kiện biểu diễn",
  "iconName": "mic",
  "defaultChecklistItems": [
    "Chuẩn bị trang phục",
    "Soundcheck",
    "Makeup"
  ],
  "customFieldTemplates": [],
  "isActive": true,
  "createdAt": "2026-01-02T10:00:00Z",
  "updatedAt": "2026-01-02T10:00:00Z"
}
```

#### 3. Collection: `users` (tự tạo khi đăng nhập lần đầu)

---

## 🐛 Troubleshooting

### 1. Build Runner Errors

```bash
# Clean và rebuild
flutter clean
flutter pub get
flutter pub run build_runner clean
flutter pub run build_runner build --delete-conflicting-outputs
```

### 2. Firebase Not Initialized

- Đảm bảo đã chạy `flutterfire configure`
- Kiểm tra file `firebase_options.dart` đã tồn tại
- Restart IDE

### 3. Gradle Build Failed (Android)

```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
flutter run
```

### 4. CocoaPods Error (iOS)

```bash
cd ios
pod deintegrate
pod install
cd ..
flutter run
```

---

## 📊 Kiểm tra Project Health

### Checklist:

- [ ] `flutter pub get` chạy thành công
- [ ] `flutter pub run build_runner build` không có errors
- [ ] `flutter run` build được app
- [ ] Firebase project đã tạo
- [ ] Authentication providers đã enable
- [ ] Firestore Database đã tạo
- [ ] Security Rules đã deploy
- [ ] SHA-1 đã thêm (Android)

### Verify Firebase Connection:

Trong app, check logs:
```bash
flutter run --verbose
```

Tìm dòng:
```
[VERBOSE] Firebase initialized successfully
```

---

## 🎯 Next Steps

### Immediate (để có app chạy được):
1. ✅ Setup Firebase project
2. ✅ Deploy Firestore Rules
3. ⏳ Build Login Screen
4. ⏳ Build Calendar View

### Sau đó:
5. ⏳ Implement CRUD Events
6. ⏳ Add Checklist functionality
7. ⏳ Setup Push Notifications
8. ⏳ Build Admin Panel

---

## 📞 Support & Resources

### Documentation:
- `SETUP_GUIDE.md` - Setup chi tiết
- `PROJECT_STRUCTURE.md` - Kiến trúc
- `CLOUD_FUNCTIONS_GUIDE.md` - Notifications

### External:
- [Flutter Docs](https://flutter.dev/docs)
- [Riverpod Docs](https://riverpod.dev)
- [Firebase Docs](https://firebase.google.com/docs)

---

## 💡 Pro Tips

1. **Dùng Hot Reload** khi dev UI: `r` trong terminal
2. **Debug với DevTools**: `flutter pub global activate devtools`
3. **Check Firestore Rules**: Dùng Rules Playground trong Console
4. **Monitor logs**: `flutter logs` trong terminal riêng
5. **VS Code Extensions**:
   - Flutter
   - Dart
   - Firebase
   - Error Lens

---

## ✅ Current Status

```
Foundation:           ████████████████████ 100%
Models & Logic:       ████████████████████ 100%
Security Rules:       ████████████████████ 100%
State Management:     ████████████████████ 100%

UI Screens:           ░░░░░░░░░░░░░░░░░░░░   0%
Cloud Functions:      ░░░░░░░░░░░░░░░░░░░░   0%
Push Notifications:   ░░░░░░░░░░░░░░░░░░░░   0%

Overall:              ████████░░░░░░░░░░░░  40%
```

**🎉 Bạn đã hoàn thành phần nền tảng quan trọng nhất!**

Tiếp theo là build UI - phần thú vị và trực quan hơn nhiều! 🎨

---

**Happy Coding! 🚀**

