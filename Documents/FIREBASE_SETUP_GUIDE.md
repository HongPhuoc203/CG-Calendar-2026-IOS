# 🔥 Firebase Setup Guide - CG Calendar

## 📋 Tổng Quan

Hướng dẫn setup Firebase project cho CG Calendar bao gồm:
- ✅ Tạo Firebase project
- ✅ Enable Authentication (Email, Google, Apple)
- ✅ Tạo Firestore Database
- ✅ Deploy Security Rules
- ✅ Tạo test accounts
- ✅ Tạo sample data

---

## 🚀 Bước 1: Tạo Firebase Project

### 1.1. Truy cập Firebase Console
1. Vào [Firebase Console](https://console.firebase.google.com/)
2. Click **"Add project"** hoặc **"Create a project"**

### 1.2. Đặt tên Project
- **Project name**: `CG Calendar` (hoặc tên bạn muốn)
- Click **Continue**

### 1.3. Google Analytics (Optional)
- Bạn có thể **bật** hoặc **tắt** Google Analytics
- Nếu bật, chọn hoặc tạo Analytics account
- Click **Continue** → **Create project**

### 1.4. Chờ Firebase tạo project (30-60 giây)
- Click **Continue** khi hoàn tất

---

## 📱 Bước 2: Thêm Apps vào Project

### 2.1. Thêm Android App

1. Trong Firebase Console, click icon **Android** (hoặc **Add app** → **Android**)
2. **Android package name**: 
   ```
   com.cgcalendar.app
   ```
   (Hoặc check trong `android/app/build.gradle` → `applicationId`)
3. **App nickname** (optional): `CG Calendar Android`
4. **Debug signing certificate SHA-1** (optional - bỏ qua lúc này)
5. Click **Register app**

6. **Download `google-services.json`**:
   - Click **Download google-services.json**
   - Copy file vào: `android/app/google-services.json`

7. Click **Next** → **Next** → **Continue to console**

### 2.2. Thêm iOS App (nếu cần)

1. Click icon **iOS** (hoặc **Add app** → **iOS**)
2. **iOS bundle ID**: 
   ```
   com.cgcalendar.app
   ```
   (Check trong `ios/Runner.xcodeproj` hoặc `ios/Runner/Info.plist`)
3. **App nickname**: `CG Calendar iOS`
4. Click **Register app**

5. **Download `GoogleService-Info.plist`**:
   - Click **Download GoogleService-Info.plist**
   - Mở Xcode → Drag file vào `ios/Runner/` folder
   - ✅ Check "Copy items if needed"

6. Click **Next** → **Next** → **Continue to console**

### 2.3. Thêm Web App

1. Click icon **Web** (</>) (hoặc **Add app** → **Web**)
2. **App nickname**: `CG Calendar Web`
3. ✅ Check **"Also set up Firebase Hosting"** (optional)
4. Click **Register app**

5. **Copy Firebase config**:
   ```javascript
   const firebaseConfig = {
     apiKey: "AIza...",
     authDomain: "cg-calendar.firebaseapp.com",
     projectId: "cg-calendar",
     storageBucket: "cg-calendar.appspot.com",
     messagingSenderId: "123456789",
     appId: "1:123456789:web:abc..."
   };
   ```
   (Sẽ dùng cho FlutterFire CLI)

6. Click **Continue to console**

---

## 🔧 Bước 3: Setup FlutterFire CLI

### 3.1. Cài đặt FlutterFire CLI

```bash
# Cài đặt globally
dart pub global activate flutterfire_cli

# Verify installation
flutterfire --version
```

### 3.2. Login Firebase

```bash
# Login với Google account
firebase login

# Hoặc login với token
firebase login --no-localhost
```

### 3.3. Configure Flutter App

```bash
# Di chuyển vào project
cd D:\Documents\CG_Calendar\cg_calendar

# Chạy FlutterFire configure
flutterfire configure
```

**Làm theo wizard:**
1. Chọn Firebase project: **CG Calendar**
2. Chọn platforms: 
   - ✅ Android
   - ✅ iOS (nếu có Mac)
   - ✅ Web
3. FlutterFire sẽ tự động:
   - Tạo `lib/firebase_options.dart`
   - Update `pubspec.yaml` (nếu cần)
   - Link với Firebase project

---

## 🔐 Bước 4: Enable Authentication

### 4.1. Vào Authentication

1. Trong Firebase Console → **Authentication**
2. Click **Get started**

### 4.2. Enable Email/Password

1. Click tab **Sign-in method**
2. Click **Email/Password**
3. ✅ Enable **Email/Password** (toggle ON)
4. ✅ Enable **Email link (passwordless sign-in)** (optional)
5. Click **Save**

### 4.3. Enable Google Sign-In

1. Click **Google**
2. Enable toggle
2. **Project support email**: Chọn email của bạn
3. Click **Save**
4. **SHA-1 certificate** (cho Android):
   ```bash
   cd android
   ./gradlew signingReport
   ```
   - Copy SHA-1 fingerprint
   - Paste vào: Firebase Console → Project Settings → Your apps → Android app → SHA certificate fingerprints

### 4.4. Enable Apple Sign-In (iOS only)

1. Click **Apple**
2. Enable toggle
3. **Apple Services ID**: (Cần Apple Developer account)
4. Click **Save**

---

## 💾 Bước 5: Tạo Firestore Database

### 5.1. Vào Firestore Database

1. Firebase Console → **Firestore Database**
2. Click **Create database**

### 5.2. Chọn Mode

- Chọn **Start in production mode**
- (Security Rules sẽ được deploy sau)

### 5.3. Chọn Location

- **Location**: Chọn gần nhất (ví dụ: `asia-southeast1` - Singapore)
- Click **Enable**

### 5.4. Chờ database khởi tạo (30-60 giây)

---

## 🛡️ Bước 6: Deploy Security Rules

### 6.1. Setup Firebase CLI (nếu chưa có)

```bash
# Cài đặt Firebase CLI
npm install -g firebase-tools

# Login
firebase login
```

### 6.2. Initialize Firebase trong Project

```bash
cd D:\Documents\CG_Calendar\cg_calendar

# Initialize
firebase init
```

**Chọn:**
- ✅ **Firestore** (Space để chọn)
- ✅ **Functions** (optional - cho notifications sau)
- ✅ **Hosting** (optional)

**Firestore setup:**
- **Firestore Rules file**: `firestore.rules` (đã có sẵn)
- **Firestore indexes file**: `firestore.indexes.json` (tạo mới)

### 6.3. Deploy Rules

```bash
# Deploy Security Rules
firebase deploy --only firestore:rules

# Verify
firebase firestore:rules get
```

---

## 👥 Bước 7: Tạo Test Accounts

### 7.1. Sử dụng Script (Khuyến nghị)

Tôi sẽ tạo script để tự động tạo 3 accounts. Xem file `setup_test_accounts.js`

### 7.2. Hoặc tạo thủ công trong Console

1. Firebase Console → **Authentication** → **Users**
2. Click **Add user**
3. Tạo từng user:
   - **Email**: `viewer@gmail.com`
   - **Password**: `Abcd123@`
   - Click **Add user**
   - Lặp lại cho `editor@gmail.com` và `supereditor@gmail.com`

---

## 📊 Bước 8: Tạo Sample Data

Sau khi tạo users, chạy script `setup_sample_data.js` để tạo:
- ✅ Artists (3-5 nghệ sĩ)
- ✅ Event Types (4-5 loại sự kiện)
- ✅ Events (5-10 sự kiện mẫu)

---

## ✅ Checklist Hoàn Thành

- [ ] Firebase project đã tạo
- [ ] Android app đã thêm + `google-services.json` đã copy
- [ ] iOS app đã thêm (nếu cần) + `GoogleService-Info.plist` đã copy
- [ ] Web app đã thêm
- [ ] FlutterFire CLI đã configure (`firebase_options.dart` đã tạo)
- [ ] Email/Password authentication đã enable
- [ ] Google Sign-In đã enable
- [ ] Firestore Database đã tạo
- [ ] Security Rules đã deploy
- [ ] Test accounts đã tạo (3 users)
- [ ] Sample data đã import

---

## 🐛 Troubleshooting

### Lỗi: "Firebase not initialized"
- Đảm bảo đã chạy `flutterfire configure`
- Check file `lib/firebase_options.dart` tồn tại

### Lỗi: "SHA-1 not found"
- Chạy: `cd android && ./gradlew signingReport`
- Copy SHA-1 vào Firebase Console

### Lỗi: "Permission denied" khi đọc Firestore
- Check Security Rules đã deploy: `firebase firestore:rules get`
- Verify rules file `firestore.rules` đúng

### Lỗi: "User not found" khi login
- Check Authentication → Users có user chưa
- Verify email đúng format

---

## 📚 Resources

- [Firebase Console](https://console.firebase.google.com/)
- [FlutterFire Documentation](https://firebase.flutter.dev/)
- [Firestore Security Rules](https://firebase.google.com/docs/firestore/security/get-started)

---

**Next:** Chạy scripts để tạo test accounts và sample data! 🚀

