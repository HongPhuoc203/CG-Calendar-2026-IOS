# 🎯 BƯỚC CHẠY DỰ ÁN - CG CALENDAR

Copy và paste từng lệnh theo thứ tự:

---

## 📍 BƯỚC 1: Generate Freezed Code

```powershell
cd D:\Documents\CG_Calendar\cg_calendar
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
```

**Đợi ~30-60 giây**. Sẽ thấy:
```
[INFO] Succeeded after 45.2s with 12 outputs
```

---

## 📍 BƯỚC 2: Kiểm tra không có lỗi

```powershell
flutter analyze
```

Nếu OK sẽ thấy:
```
No issues found!
```

---

## 📍 BƯỚC 3: Chạy app

```powershell
flutter run -d chrome
```

Hoặc (nếu có Android emulator):
```powershell
flutter run
```

---

## 📱 Kết quả mong đợi

### Lần 1 chạy (chưa setup Firebase):
- ❌ Sẽ có lỗi Firebase not initialized
- ✅ Cần setup Firebase trước

### Sau khi setup Firebase:
- ✅ Thấy **Login Screen**
- ✅ Đăng nhập → Tạo user pending
- ✅ Thấy **Pending Approval Screen**
- ✅ Login với test account → Vào **Calendar**

---

## 🔥 Setup Firebase (Nếu Chưa)

```powershell
# Step 1: Configure Firebase
flutterfire configure
# Chọn project "cgcalendar-2026" hoặc project bạn đã tạo

# Step 2: Deploy Rules
firebase deploy --only firestore:rules

# Step 3: Setup test accounts (Node.js required)
npm install
npm run setup
```

---

## ✅ Checklist

- [ ] `flutter pub get` - OK
- [ ] `build_runner` - Tạo 12 files
- [ ] `flutter analyze` - No errors
- [ ] `firebase_options.dart` exists
- [ ] `firestore.rules` deployed
- [ ] App runs successfully

---

## 🎮 Test Flow

1. **Chạy app** → Login Screen
2. **Đăng ký** → User với role=pending
3. **Thấy** Pending Screen ✅
4. **Chạy script** → Tạo test accounts
5. **Login lại** với `supereditor@gmail.com`
6. **Vào Calendar** → Thấy events ✅

---

Copy từng lệnh và paste vào terminal, cho tôi biết kết quả! 🚀
