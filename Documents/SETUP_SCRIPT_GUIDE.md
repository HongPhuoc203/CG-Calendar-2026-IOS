# 🔥 Firebase Setup Script - Hướng Dẫn

## 📋 Prerequisites

1. ✅ Firebase project đã tạo
2. ✅ Node.js đã cài đặt
3. ✅ Firebase CLI đã login

---

## 🚀 Cách Chạy Script

### Bước 1: Cài đặt Dependencies

```bash
cd D:\Documents\CG_Calendar\cg_calendar
npm install
```

### Bước 2: Lấy Service Account Key

1. Vào [Firebase Console](https://console.firebase.google.com/)
2. Chọn project **CG Calendar**
3. Click **⚙️ Project Settings** (icon bánh răng)
4. Tab **Service Accounts**
5. Click **Generate new private key**
6. Download file JSON
7. **Rename** file thành: `serviceAccountKey.json`
8. **Copy** vào thư mục: `D:\Documents\CG_Calendar\cg_calendar\`

⚠️ **QUAN TRỌNG:** File này chứa credentials quan trọng, **KHÔNG commit vào Git!**

### Bước 3: Chạy Script

```bash
npm run setup
```

Hoặc:

```bash
node setup_firebase.js
```

---

## 📊 Script Sẽ Tạo:

### 1. **Test Accounts** (3 users)
- ✅ `viewer@gmail.com` / `Abcd123@` (Role: Viewer)
- ✅ `editor@gmail.com` / `Abcd123@` (Role: Editor, manages 2 artists)
- ✅ `supereditor@gmail.com` / `Abcd123@` (Role: Super Editor)

### 2. **Artists** (5 nghệ sĩ)
- ✅ John Doe (Emerald - #10b981)
- ✅ Jane Smith (Amber - #f59e0b)
- ✅ Mike Johnson (Violet - #8b5cf6)
- ✅ Sarah Williams (Pink - #ec4899)
- ✅ David Lee (Blue - #3b82f6)

### 3. **Event Types** (5 loại)
- ✅ Biểu diễn
- ✅ Livestream
- ✅ Chụp hình
- ✅ Họp nhãn
- ✅ Travel

### 4. **Events** (5 sự kiện mẫu)
- ✅ Voice Training (5 days from now)
- ✅ Promo Photoshoot (7 days from now)
- ✅ Livestream Concert (10 days from now)
- ✅ Flight to LAX (12 days from now)
- ✅ Meeting with Label (3 days from now)

---

## ✅ Kết Quả

Sau khi chạy script, bạn sẽ có:

```
✅ 3 test accounts trong Firebase Auth
✅ 5 artists trong Firestore
✅ 5 event types trong Firestore
✅ 5 events trong Firestore
✅ Editor được assign 2 artists để quản lý
```

---

## 🔍 Verify Data

### Check trong Firebase Console:

1. **Authentication → Users**: Sẽ thấy 3 users
2. **Firestore → artists**: Sẽ thấy 5 documents
3. **Firestore → event_types**: Sẽ thấy 5 documents
4. **Firestore → events**: Sẽ thấy 5 documents
5. **Firestore → users**: Sẽ thấy 3 user documents với roles

---

## 🐛 Troubleshooting

### Lỗi: "Cannot find module 'firebase-admin'"
```bash
npm install
```

### Lỗi: "Service account key not found"
- Đảm bảo file `serviceAccountKey.json` ở đúng thư mục
- Check tên file đúng: `serviceAccountKey.json` (không có space)

### Lỗi: "Permission denied"
- Check Service Account có quyền:
  - Authentication Admin
  - Cloud Firestore Admin
- Hoặc dùng Owner account để chạy script

### Lỗi: "User already exists"
- Script sẽ skip user đã tồn tại
- Nếu muốn reset, xóa user trong Firebase Console trước

---

## 🔐 Security Note

⚠️ **KHÔNG BAO GIỜ commit `serviceAccountKey.json` vào Git!**

Thêm vào `.gitignore`:
```
serviceAccountKey.json
*.json
!package.json
!pubspec.yaml
```

---

## 📝 Next Steps

Sau khi chạy script:

1. ✅ Test login với 3 accounts
2. ✅ Check Calendar screen có hiển thị events
3. ✅ Test filter artists
4. ✅ Test create/edit event (với Editor/Super Editor)

---

**Ready to setup! 🚀**

