# 📅 CG Calendar

**Hệ thống quản lý lịch trình nội bộ cho nghệ sĩ**

[![Flutter](https://img.shields.io/badge/Flutter-3.7+-blue.svg)](https://flutter.dev/)
[![Firebase](https://img.shields.io/badge/Firebase-Latest-orange.svg)](https://firebase.google.com/)
[![Riverpod](https://img.shields.io/badge/Riverpod-2.4+-purple.svg)](https://riverpod.dev/)

---

## 🎯 Mục tiêu

CG Calendar là ứng dụng quản lý lịch trình dành riêng cho:
- 🎤 **Nghệ sĩ** (Viewer role)
- 👔 **Quản lý nghệ sĩ** (Editor role)
- 👑 **Quản lý tổng** (Super Editor role - 1 người)

### Tính năng chính:
- ✅ Calendar tổng cho tất cả nghệ sĩ
- ✅ Multi-artist events
- ✅ Checklist linh hoạt theo loại sự kiện
- ✅ Push notifications nhắc lịch
- ✅ Phân quyền RBAC chặt chẽ
- ✅ Drive links cho hợp đồng/tài liệu
- ✅ Cross-platform: Android, iOS, Web

---

## 🏗️ Tech Stack

| Layer | Technology |
|-------|-----------|
| **Frontend** | Flutter 3.7+ |
| **State Management** | Riverpod 2.4+ |
| **Backend** | Firebase (Firestore, Auth, Functions) |
| **Authentication** | Email/Password, Google, Apple |
| **Notifications** | Firebase Cloud Messaging |
| **Architecture** | Clean Architecture + Repository Pattern |
| **Models** | Freezed (Immutable + JSON) |

---

## 🚀 Quick Start

### 1. Prerequisites
- Flutter SDK 3.7 or later
- Firebase account
- Dart 3.0+

### 2. Installation

```bash
# Clone repository
git clone <your-repo-url>
cd cg_calendar

# Install dependencies
flutter pub get

# Generate Freezed code
flutter pub run build_runner build --delete-conflicting-outputs
```

### 3. Firebase Setup

```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Configure Firebase
flutterfire configure

# Deploy Firestore Rules
firebase deploy --only firestore:rules
```

### 4. Run App

```bash
# Android
flutter run -d android

# iOS
flutter run -d ios

# Web
flutter run -d chrome
```

---

## 📁 Project Structure

```
lib/
├── core/                  # Constants, enums, utils, errors
├── data/                  # Models, repositories, services
├── providers/             # Riverpod state management
├── presentation/          # UI screens & widgets (Phase 2)
└── main.dart              # App entry point

firestore.rules            # Security rules
pubspec.yaml               # Dependencies

📚 Documentation:
├── QUICK_START.md              ⚡ Bắt đầu nhanh
├── SETUP_GUIDE.md              🔧 Hướng dẫn setup chi tiết
├── PROJECT_STRUCTURE.md        📊 Kiến trúc project
└── CLOUD_FUNCTIONS_GUIDE.md    ☁️ Cloud Functions
```

---

## 🔐 Phân quyền (RBAC)

| Role | Quyền |
|------|-------|
| **Pending** | Chỉ thấy "Đang chờ duyệt" |
| **Viewer** (Nghệ sĩ) | Xem calendar, checklist, links |
| **Editor** (Quản lý) | + Tạo/sửa/xóa events của nghệ sĩ mình quản lý |
| **Super Editor** | + Toàn quyền + duyệt user + quản lý hệ thống |

### Quy tắc quan trọng:
- ✅ User KHÔNG tự gán role
- ✅ Editor chỉ sửa event nếu: `event.artistIds ∩ managedArtistIds ≠ ∅`
- ✅ Security enforced bằng Firestore Rules (không chỉ UI)

---

## 📊 Database Schema

### Collections:

**users** - Thông tin người dùng
```
{
  email, role, status, managedArtistIds, fcmToken
}
```

**artists** - Nghệ sĩ
```
{
  name, colorHex, avatarUrl, isActive
}
```

**events** - Sự kiện
```
{
  title, startTime, endTime, artistIds[], 
  eventTypeId, checklistItems[], links[]
}
```

**event_types** - Template checklist
```
{
  name, defaultChecklistItems[], customFieldTemplates[]
}
```

**reminders** - Nhắc lịch
```
{
  eventId, value, unit, recipientUserIds[], triggerTime
}
```

**notification_jobs** - Push queue (Cloud Functions)
```
{
  eventId, recipientUserId, scheduledTime, status
}
```

---

## 🔔 Notification Flow

```
Manager tạo Event + Reminders
    ↓
Cloud Function: onReminderCreated
    ↓
Tạo notification_jobs cho mỗi recipient
    ↓
Scheduler: chạy mỗi 5 phút
    ↓
Query jobs có triggerTime <= now
    ↓
Gửi FCM push notification
    ↓
Mark jobs & reminders as sent
```

---

## 🎨 Screenshots (Coming Soon)

- [ ] Login Screen
- [ ] Calendar View
- [ ] Event Details
- [ ] Admin Panel

---

## 📈 Development Status

### ✅ Completed (Phase 1 - Foundation)
- [x] Project structure
- [x] Models (Freezed)
- [x] Repositories & Services
- [x] Riverpod Providers
- [x] Firestore Security Rules
- [x] Documentation

### ⏳ In Progress (Phase 2 - UI)
- [ ] Authentication screens
- [ ] Calendar view
- [ ] Event CRUD
- [ ] Admin panel

### 📅 Planned (Phase 3 - Advanced)
- [ ] Cloud Functions (Notifications)
- [ ] Push notifications
- [ ] Audit logs
- [ ] Export calendar

---

## 🧪 Testing

```bash
# Run tests
flutter test

# Run with coverage
flutter test --coverage

# Integration tests
flutter test integration_test
```

---

## 📦 Build

### Android (APK)
```bash
flutter build apk --release --split-per-abi
```

### iOS (IPA)
```bash
flutter build ios --release
# Open Xcode to archive
```

### Web
```bash
flutter build web --release
firebase deploy --only hosting
```

---

## 🔧 Configuration Files

| File | Purpose |
|------|---------|
| `pubspec.yaml` | Dependencies |
| `firestore.rules` | Security rules |
| `firebase.json` | Firebase config |
| `analysis_options.yaml` | Linter rules |

---

## 📚 Documentation

- **[QUICK_START.md](QUICK_START.md)** - Bắt đầu ngay lập tức
- **[SETUP_GUIDE.md](SETUP_GUIDE.md)** - Hướng dẫn setup chi tiết
- **[PROJECT_STRUCTURE.md](PROJECT_STRUCTURE.md)** - Kiến trúc & design patterns
- **[CLOUD_FUNCTIONS_GUIDE.md](CLOUD_FUNCTIONS_GUIDE.md)** - Cloud Functions setup

---

## 🐛 Known Issues

- [ ] Freezed models cần generate lần đầu
- [ ] iOS: Cần config Apple Sign-In
- [ ] Web: Push notifications chưa hỗ trợ đầy đủ

---

## 🤝 Contributing

1. Fork the project
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Open a Pull Request

---

## 📄 License

This project is private and proprietary.

---

## 👥 Team

- **Super Editor**: Quản lý tổng (1 người)
- **Editors**: Quản lý nghệ sĩ
- **Viewers**: Nghệ sĩ

---

## 📞 Support

Nếu gặp vấn đề, check:
1. Documentation files (*.md)
2. Firebase Console logs
3. Flutter logs: `flutter logs`

---

## 🎯 Roadmap

### MVP (6 tuần)
- [x] Foundation ✅ (Tuần 1-2)
- [ ] UI Screens ⏳ (Tuần 3-4)
- [ ] Notifications ⏳ (Tuần 5)
- [ ] Testing ⏳ (Tuần 6)

### Post-MVP
- [ ] Audit logs
- [ ] Export calendar (PDF, iCal)
- [ ] Dark mode
- [ ] Multi-language support
- [ ] Analytics dashboard

---

## 🌟 Features Highlight

### ✨ Unique Selling Points:
1. **Checklist linh hoạt** - Mỗi loại sự kiện có template riêng
2. **Multi-artist events** - 1 event gắn nhiều nghệ sĩ
3. **Phân quyền chặt chẽ** - RBAC với Firestore Rules
4. **Cross-platform** - 1 codebase cho 3 platform
5. **Real-time sync** - Firestore Streams
6. **Không phụ thuộc Google Calendar** - Source of truth riêng

---

**Made with ❤️ using Flutter & Firebase**

**Status:** 🟢 Active Development | Foundation Complete ✅

---

## 📊 Progress

```
████████████████████░░░░░░░░░░░░ 40% Complete

✅ Architecture & Setup
✅ Models & Logic  
✅ State Management
⏳ UI Development
⏳ Cloud Functions
⏳ Testing
```

---

**Last Updated:** January 2, 2026
