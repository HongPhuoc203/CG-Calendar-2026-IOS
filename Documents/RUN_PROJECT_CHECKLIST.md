# 🚀 CG Calendar - Checklist Chạy Dự Án

## ✅ Checklist Trước Khi Chạy

- [ ] **1. Generate Freezed Code**
  ```bash
  flutter pub run build_runner build --delete-conflicting-outputs
  ```

- [ ] **2. Firebase Setup Complete**
  - [ ] Firebase project created
  - [ ] `firebase_options.dart` exists
  - [ ] Firestore Rules deployed
  - [ ] Test accounts created (optional)

- [ ] **3. Dependencies Installed**
  ```bash
  flutter pub get
  ```

- [ ] **4. No Linter Errors**
  ```bash
  flutter analyze
  ```

---

## 🏃 Chạy App

### Option 1: Script (Windows)
```bash
run.bat
```

### Option 2: Manual
```bash
flutter run
```

### Option 3: Specific Device
```bash
# List devices
flutter devices

# Run on specific device
flutter run -d chrome        # Web
flutter run -d windows       # Windows
flutter run -d <device-id>   # Android/iOS
```

---

## 🐛 Common Errors & Fixes

### 1. Freezed Code Not Generated
**Error:** `Missing *.freezed.dart or *.g.dart files`

**Fix:**
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### 2. Firebase Not Initialized
**Error:** `Firebase not initialized` or `firebase_options.dart not found`

**Fix:**
```bash
flutterfire configure
```

### 3. Missing Dependencies
**Error:** `Package not found`

**Fix:**
```bash
flutter clean
flutter pub get
```

### 4. Build Errors
**Error:** Build fails with compilation errors

**Fix:**
```bash
flutter clean
flutter pub get
flutter pub run build_runner clean
flutter pub run build_runner build --delete-conflicting-outputs
```

### 5. Hot Reload Not Working
**Fix:**
```bash
# Press 'R' in terminal for hot restart
# Or restart app completely
```

---

## 📝 Current Status

### ✅ Completed
- [x] Project structure
- [x] Models (User, Artist, Event, EventType, Reminder)
- [x] Repositories & Services
- [x] Providers (Riverpod)
- [x] Firestore Security Rules (updated for new RBAC)
- [x] UI Screens (Splash, Login, Calendar)
- [x] Setup script for Firebase

### ⏳ May Need Attention
- [ ] Freezed code generation
- [ ] Firebase connection
- [ ] Sample data in Firestore

---

## 🔍 Debug Commands

```bash
# Check for errors
flutter analyze

# Check for linter issues
flutter analyze --no-fatal-infos

# Run with verbose
flutter run --verbose

# View logs
flutter logs
```

---

## 📱 Expected Behavior

### Demo Mode
1. **Splash Screen** appears first
2. Use **bottom navigation** (◀️ ▶️) to switch screens
3. **Screen 1:** Splash with animation
4. **Screen 2:** Login form (functional)
5. **Screen 3:** Calendar (needs Firebase data)

### After Firebase Setup
1. Login with test accounts
2. See events on calendar
3. Filter by artists
4. View event details

---

**Next:** Run `flutter pub run build_runner build --delete-conflicting-outputs`
