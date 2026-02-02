# 🎨 UI Screens - Quick Test Guide

## ✅ Đã Hoàn Thành

### 1. **Splash Screen** ✨
- Animated logo với glow effect
- Background gradient
- Version info

### 2. **Login Screen** 🔐
- Email/Password login
- Google Sign-In button
- Apple Sign-In button
- Error message display
- Password visibility toggle
- Forgot password link

### 3. **Main Calendar Overview** 📅
- TableCalendar integration
- Month/Week/List view switcher
- Artist filter panel
- Event markers
- Selected day events list
- Today button
- Profile avatar with online status
- Search & Filter buttons

### 4. **Demo Navigation** 🚀
- Bottom navigation để switch giữa screens
- Screen name indicator ở top-right
- Prev/Next buttons

---

## 🏃 Chạy App

### Bước 1: Generate Freezed Code
```bash
cd D:\Documents\CG_Calendar\cg_calendar
flutter pub run build_runner build --delete-conflicting-outputs
```

### Bước 2: Chạy App
```bash
flutter run
```

---

## 🎯 Demo Mode

App hiện đang ở **DEMO MODE** với navigation buttons ở dưới:
- ◀️ Previous Screen
- ▶️ Next Screen
- Screen counter (1/3, 2/3, 3/3)

### Các Screens trong Demo:
1. **Splash Screen** - Màn chào với animation
2. **Login Screen** - Form đăng nhập đầy đủ
3. **Calendar Screen** - Calendar tổng với events (sample data)

---

## 📝 Lưu Ý

### Calendar Screen
- **Cần có Firebase** để load events thật
- Hiện tại sẽ hiển thị loading hoặc empty state
- Artist filter sẽ cần data từ Firestore

### Để có data mẫu:
1. Tạo Firebase project
2. Thêm sample artists vào Firestore collection `artists`
3. Thêm sample events vào collection `events`

### Sample Artist Document:
```json
{
  "name": "Artist A",
  "colorHex": "#10b981",
  "avatarUrl": null,
  "isActive": true,
  "createdAt": "2026-01-03T10:00:00Z",
  "updatedAt": "2026-01-03T10:00:00Z"
}
```

### Sample Event Document:
```json
{
  "title": "Voice Training",
  "description": "Studio recording session",
  "startTime": "2026-01-15T09:00:00Z",
  "endTime": "2026-01-15T12:00:00Z",
  "location": "Studio A",
  "artistIds": ["artist_id_here"],
  "eventTypeId": "type_id_here",
  "checklistItems": [],
  "customFields": {},
  "links": [],
  "createdBy": "user_id",
  "createdAt": "2026-01-03T10:00:00Z",
  "updatedAt": "2026-01-03T10:00:00Z"
}
```

---

## 🎨 Design System

### Colors (từ Stitch):
- **Primary**: `#195de6` (Blue)
- **Background Dark**: `#111621`
- **Surface Dark**: `#1A2233`
- **Border Dark**: `#374151`

### Typography:
- **Font**: Inter
- **Headlines**: Bold, 20-32px
- **Body**: Regular, 14-16px
- **Meta**: 12px, lighter

### Components:
- **Border Radius**: 12px (inputs, cards)
- **Button Height**: 48px
- **Icon Size**: 20-24px

---

## 🐛 Troubleshooting

### 1. Build Runner Errors
```bash
flutter pub run build_runner clean
flutter pub run build_runner build --delete-conflicting-outputs
```

### 2. Firebase Not Connected
- Calendar sẽ hiển thị loading spinner
- Login buttons sẽ show error
- Cần setup Firebase project trước

### 3. Hot Reload Issues
- Restart app nếu theme không update
- Clear app data nếu có cache issues

---

## 🚀 Next Steps

### Để có app hoàn chỉnh:
1. ✅ Setup Firebase project
2. ✅ Deploy Firestore Rules
3. ✅ Add sample data (artists, events)
4. ⏳ Build Pending Approval screen
5. ⏳ Build Event Details screen
6. ⏳ Build Create/Edit Event screen
7. ⏳ Implement real navigation với Go Router
8. ⏳ Add authentication flow

---

## 📱 Expected Behavior

### Splash Screen
- Shows for 2-3 seconds
- Fade in animation
- Logo glow effect

### Login Screen
- Email validation
- Password min 6 chars
- Error message on failed login
- Social login buttons

### Calendar Screen
- Month view default
- Can switch to Week/List
- Click on day to see events
- Filter button shows artist panel
- Today button jumps to current date

---

**Status:** 🟢 Ready to Test!

**Screens Built:** 3/17 screens từ Stitch design

**Foundation:** ✅ Complete

