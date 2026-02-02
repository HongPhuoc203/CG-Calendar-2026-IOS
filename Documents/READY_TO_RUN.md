# 🎯 CG Calendar - Ready to Run!

## ✅ Đã Hoàn Thành

### 1. **Real Authentication Flow** ✨
- ✅ AuthWrapper với role-based routing
- ✅ Auto-create user document on first login
- ✅ Pending Approval Screen
- ✅ Login Screen với Email/Google/Apple
- ✅ Calendar Screen (main app)

### 2. **Role-Based Routing** 🔐
```
Not Logged In → Login Screen
    ↓
First Login → Auto create user with role=pending
    ↓
Role = pending → Pending Approval Screen
    ↓
Role = viewer/editor/super_editor → Calendar Screen
```

### 3. **Firestore Security Rules** 🛡️
- ✅ Updated với phân quyền mới
- ✅ Viewer chỉ xem event của nghệ sĩ mình (artistId)
- ✅ Editor xem event của managed artists
- ✅ Super Editor full access

---

## 🚀 Chạy App

### Bước 1: Generate Freezed Code (BẮT BUỘC)
```bash
cd D:\Documents\CG_Calendar\cg_calendar
flutter pub run build_runner build --delete-conflicting-outputs
```

### Bước 2: Chạy App
```bash
flutter run
```

Hoặc chọn device:
```bash
flutter run -d chrome        # Web
flutter run -d windows       # Windows Desktop
```

---

## 📱 Flow Khi Chạy

### Lần đầu (chưa login):
1. **Splash Screen** (loading)
2. **Login Screen** 
   - Đăng nhập Email/Password
   - Hoặc Google/Apple Sign-In

### Sau khi login lần đầu:
1. **Creating User Document** (1-2 giây)
2. **Pending Approval Screen**
   - Hiển thị: "Đang chờ duyệt"
   - User không làm gì được
   - Chờ Super Editor duyệt

### Sau khi được duyệt:
1. **Calendar Screen** (main app)
   - Viewer: Chỉ xem event của nghệ sĩ mình
   - Editor: Xem + CRUD events của managed artists
   - Super Editor: Full access

---

## 🔧 Setup Firebase (Nếu Chưa)

### Quick Setup:
```bash
# 1. Configure Firebase
flutterfire configure

# 2. Deploy Rules
firebase deploy --only firestore:rules

# 3. Create test accounts & sample data
npm install
npm run setup
```

### Test Accounts (sau khi chạy script):
- `viewer@gmail.com` / `Abcd123@` - Viewer role
- `editor@gmail.com` / `Abcd123@` - Editor role
- `supereditor@gmail.com` / `Abcd123@` - Super Editor role

---

## 🎯 Điểm Khác Demo Mode

| Feature | Demo Mode | Real Mode |
|---------|-----------|-----------|
| Navigation | Bottom buttons | Auto routing |
| Auth | Fake | Real Firebase Auth |
| Data | Static | Real Firestore |
| Roles | None | Pending/Viewer/Editor/Super |
| User Creation | Manual | Auto on first login |

---

## 🐛 Troubleshooting

### 1. "Missing *.freezed.dart files"
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### 2. "Firebase not initialized"
```bash
flutterfire configure
```

### 3. "Permission denied" (Firestore)
- Check: Rules đã deploy chưa?
- Check: User có role pending không? (pending không đọc được gì)

### 4. App stuck ở "Creating user document"
- Check: Firestore rules allow create user?
- Check: Network connection OK?

---

## ✅ Checklist

- [ ] Freezed code generated
- [ ] Firebase configured (`firebase_options.dart` exists)
- [ ] Firestore Rules deployed
- [ ] App runs without errors
- [ ] Can see Login Screen
- [ ] (Optional) Test accounts created

---

## 📝 Next Steps

1. **Chạy app** → Sẽ thấy Login Screen
2. **Đăng nhập** → Sẽ tạo user với role=pending
3. **Thấy Pending Screen** → Đúng!
4. **Chạy setup script** → Tạo test accounts
5. **Login với `supereditor@gmail.com`** → Vào được Calendar!

---

**Ready to run! 🚀**
