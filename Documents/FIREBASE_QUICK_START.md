# 🚀 Firebase Quick Setup - CG Calendar

## ⚡ Quick Start (5 phút)

### 1. Tạo Firebase Project
1. Vào [Firebase Console](https://console.firebase.google.com/)
2. Click **"Add project"**
3. Tên: `CG Calendar`
4. Enable/Disable Analytics → **Create project**

### 2. Thêm Apps
1. Click **Android** icon → Package: `com.cgcalendar.app` → Register
2. Download `google-services.json` → Copy vào `android/app/`
3. Click **Web** icon → Register → Copy config (sẽ dùng cho FlutterFire)

### 3. Setup FlutterFire
```bash
cd D:\Documents\CG_Calendar\cg_calendar
dart pub global activate flutterfire_cli
flutterfire configure
```
Chọn project → Chọn platforms (Android, Web) → Done!

### 4. Enable Authentication
1. Firebase Console → **Authentication** → **Get started**
2. **Sign-in method** → Enable:
   - ✅ Email/Password
   - ✅ Google

### 5. Tạo Firestore Database
1. Firebase Console → **Firestore Database** → **Create database**
2. **Production mode** → Location: `asia-southeast1` → **Enable**

### 6. Deploy Security Rules
```bash
firebase init
# Chọn: Firestore
# Rules file: firestore.rules (đã có sẵn)

firebase deploy --only firestore:rules
```

### 7. Chạy Setup Script
```bash
# Cài dependencies
npm install

# Lấy Service Account Key:
# Firebase Console → Project Settings → Service Accounts → Generate new private key
# Save as: serviceAccountKey.json (trong project root)

# Chạy script
npm run setup
```

---

## ✅ Checklist

- [ ] Firebase project created
- [ ] Android app added + `google-services.json` copied
- [ ] Web app added
- [ ] FlutterFire configured (`firebase_options.dart` exists)
- [ ] Email/Password auth enabled
- [ ] Google Sign-In enabled
- [ ] Firestore database created
- [ ] Security Rules deployed
- [ ] Service Account Key downloaded
- [ ] Setup script run successfully
- [ ] 3 test accounts created
- [ ] Sample data imported

---

## 🧪 Test Accounts

Sau khi chạy script, bạn có:

| Email | Password | Role |
|-------|----------|------|
| `viewer@gmail.com` | `Abcd123@` | Viewer |
| `editor@gmail.com` | `Abcd123@` | Editor |
| `supereditor@gmail.com` | `Abcd123@` | Super Editor |

---

## 📊 Sample Data

- **5 Artists**: John Doe, Jane Smith, Mike Johnson, Sarah Williams, David Lee
- **5 Event Types**: Biểu diễn, Livestream, Chụp hình, Họp nhãn, Travel
- **5 Events**: Voice Training, Promo Photoshoot, Livestream Concert, Flight to LAX, Meeting with Label

---

## 🎯 Test App

```bash
# Run app
flutter run

# Login với:
# - viewer@gmail.com / Abcd123@
# - editor@gmail.com / Abcd123@
# - supereditor@gmail.com / Abcd123@
```

---

## 📚 Full Guides

- **Chi tiết setup**: `FIREBASE_SETUP_GUIDE.md`
- **Script hướng dẫn**: `SETUP_SCRIPT_GUIDE.md`

---

**Status:** 🟢 Ready to setup!



