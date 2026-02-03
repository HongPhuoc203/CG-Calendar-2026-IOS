# 📱 HƯỚNG DẪN TEST PUSH NOTIFICATIONS TRÊN ANDROID

## 🎯 Mục đích
Guide này hướng dẫn chi tiết cách test push notifications (thông báo nhắc nhở) trên thiết bị Android.

---

## ✅ BƯỚC 1: CÀI ĐẶT DEPENDENCIES

```bash
cd D:\Documents\CG_Calendar\cg_calendar
flutter pub get
```

---

## ✅ BƯỚC 2: CHẠY APP TRÊN ANDROID EMULATOR

### Kiểm tra devices có sẵn:
```bash
flutter devices
```

### Chạy app trên emulator:
```bash
flutter run -d emulator-5554
```

Hoặc đơn giản:
```bash
flutter run
# Chọn Android emulator từ danh sách
```

---

## ✅ BƯỚC 3: KIỂM TRA FCM TOKEN

Khi app khởi động, mở **Debug Console** và tìm dòng:

```
I/flutter: FCM token obtained: xxxxxx...
I/flutter: FCM initialized successfully
```

**Lưu lại FCM token này** để test thủ công từ Firebase Console.

---

## ✅ BƯỚC 4: TEST NOTIFICATIONS VIA APP

### 4.1. Đăng nhập vào app
- Sử dụng tài khoản: `editor@gmail.com` / `Abcd123@`
- Hoặc: `supereditor@gmail.com` / `Abcd123@`

### 4.2. Tạo Event với Reminder
1. Nhấn nút **"+"** (Floating Action Button)
2. Điền thông tin event:
   - **Tên sự kiện**: Test Event Notification
   - **Nghệ sĩ**: Chọn 1 nghệ sĩ
   - **Ngày**: Chọn ngày **trong tương lai** (ví dụ: 2 ngày sau)
   - **Loại sự kiện**: Chọn 1 loại
   - **Địa điểm**: Test Location
3. Scroll xuống **phần "Nhắc nhở"**
4. Chọn các reminder options:
   - ✅ **2 ngày trước**
   - ✅ **1 ngày trước**
   - ✅ **12 tiếng trước**
5. Nhấn **"Lưu"**

### 4.3. Kiểm tra Reminders đã được tạo
1. Vào **Event Details** (nhấn vào event vừa tạo)
2. Scroll xuống phần **"Nhắc nhở"**
3. Xác nhận các reminder đã được tạo:
   ```
   📅 2 ngày trước
   📅 1 ngày trước
   📅 12 tiếng trước
   ```

---

## ✅ BƯỚC 5: TEST NOTIFICATIONS VIA FIREBASE CONSOLE (THỦ CÔNG)

### 5.1. Mở Firebase Console
1. Truy cập: https://console.firebase.google.com
2. Chọn project **CG Calendar**
3. Vào **Messaging** (trên menu bên trái)

### 5.2. Gửi Test Notification
1. Nhấn **"Create your first campaign"** hoặc **"New campaign"**
2. Chọn **"Firebase Notification messages"**
3. Điền thông tin:

   **Notification text:**
   - **Title**: `🔔 Test Reminder`
   - **Text**: `This is a test notification from Firebase Console`

4. Nhấn **"Send test message"**

5. **Add FCM token:**
   - Paste **FCM token** từ Debug Console (Bước 3)
   - Nhấn **"+"** để thêm token
   - Nhấn **"Test"**

### 5.3. Kiểm tra kết quả
- **App đang FOREGROUND (mở)**: Notification sẽ hiện trên màn hình Android (local notification)
- **App đang BACKGROUND (minimize)**: Notification sẽ hiện trên notification tray
- **App đã TERMINATED (đóng hẳn)**: Notification sẽ hiện trên notification tray

---

## ✅ BƯỚC 6: TEST CLOUD FUNCTIONS (SCHEDULED NOTIFICATIONS)

### 6.1. Deploy Cloud Functions (nếu chưa)
```bash
cd D:\Documents\CG_Calendar\cg_calendar\functions
firebase deploy --only functions
```

### 6.2. Kiểm tra Functions đã deploy
```bash
firebase functions:list
```

Phải thấy các functions:
- ✅ `onReminderCreated`
- ✅ `sendScheduledNotifications`
- ✅ `cleanupOldNotifications`
- ✅ `onUserApproved`

### 6.3. Trigger Functions thủ công (Test)

**Option 1: Đợi đến thời gian trigger thực tế**
- Khi tạo reminder **"12 tiếng trước"**, Cloud Function sẽ tự động gửi notification vào thời điểm đó
- Kiểm tra Firebase Console > Functions > Logs để xem execution logs

**Option 2: Test ngay lập tức**
1. Truy cập Firebase Console > **Firestore Database**
2. Vào collection **`notification_jobs`**
3. Tìm document của reminder vừa tạo
4. **Sửa `triggerTime`** thành thời gian hiện tại (hoặc 1-2 phút sau)
5. Đợi Cloud Function `sendScheduledNotifications` chạy (chạy mỗi 5 phút)
6. Kiểm tra notification trên device

---

## ✅ BƯỚC 7: VERIFY NOTIFICATIONS

### 7.1. Notification hiển thị đúng
- [ ] Notification có **icon** (CG Calendar icon)
- [ ] Notification có **title** (tên event)
- [ ] Notification có **body** (message reminder)
- [ ] Notification có **vibration** (rung)
- [ ] Notification có **sound** (âm thanh)

### 7.2. Tap vào notification
- [ ] App mở lên (nếu đang closed)
- [ ] App navigate đến **Event Details** screen (coming soon - TODO)

### 7.3. Notification trong các trạng thái
- [ ] **Foreground**: Local notification hiển thị
- [ ] **Background**: Notification tray hiển thị
- [ ] **Terminated**: Notification tray hiển thị

---

## 🐛 TROUBLESHOOTING

### Không nhận được notification?

1. **Kiểm tra FCM token có được lấy không:**
   ```
   I/flutter: FCM token obtained: xxxxx...
   ```

2. **Kiểm tra permissions trong AndroidManifest.xml:**
   ```xml
   <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
   <uses-permission android:name="android.permission.INTERNET"/>
   ```

3. **Kiểm tra Google Services JSON:**
   ```bash
   # File phải tồn tại:
   android/app/google-services.json
   ```

4. **Kiểm tra Cloud Functions logs:**
   ```bash
   firebase functions:log
   ```

5. **Kiểm tra Firestore data:**
   - Vào Firebase Console > Firestore
   - Collection: `notification_jobs`
   - Verify document có `triggerTime`, `eventId`, `fcmToken`

6. **Rebuild app:**
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

---

## 📝 NOTIFICATION DATA STRUCTURE

### RemoteMessage.data format:
```json
{
  "type": "reminder",
  "eventId": "event-id-here",
  "reminderTime": "2026-02-15T10:00:00.000Z"
}
```

### RemoteMessage.notification format:
```json
{
  "title": "🔔 Nhắc nhở sự kiện",
  "body": "Event Name - 2 ngày trước sự kiện"
}
```

---

## ✅ CHECKLIST HOÀN THÀNH

### Configuration:
- [x] AndroidManifest.xml đã có permissions
- [x] AndroidManifest.xml đã có FCM metadata
- [x] google-services.json đã được add
- [x] flutter_local_notifications đã được cài
- [x] FCM notification channel đã được tạo

### Code:
- [x] FCMService đã được initialize trong main.dart
- [x] Background message handler đã được setup
- [x] Foreground message handler đã được setup
- [x] Local notifications đã được setup cho Android

### Cloud Functions:
- [x] onReminderCreated function
- [x] sendScheduledNotifications function (cron job)
- [x] cleanupOldNotifications function

### UI:
- [x] Create/Edit Event screen có reminder options
- [x] Event Details screen hiển thị reminders
- [ ] TODO: Navigation đến event khi tap notification

---

## 🎉 SUCCESS CRITERIA

✅ Khi test thành công, bạn sẽ thấy:

1. **Debug Console:**
   ```
   I/flutter: FCM token obtained: xxxxx...
   I/flutter: FCM initialized successfully
   I/flutter: Local notifications initialized
   ```

2. **Notification hiển thị:**
   - Icon: CG Calendar
   - Title: 🔔 Nhắc nhở sự kiện
   - Body: Event Name - X trước sự kiện
   - Vibration + Sound

3. **Firebase Console > Functions > Logs:**
   ```
   Function execution took 1234 ms, finished with status: 'ok'
   Notification sent to token: xxxxx...
   ```

4. **User experience:**
   - User tạo event với reminder
   - Đến thời gian trigger → Notification tự động gửi
   - User tap notification → App mở và navigate đến event details

---

## 📚 TÀI LIỆU THAM KHẢO

- [Firebase Cloud Messaging (FCM) - Flutter](https://firebase.flutter.dev/docs/messaging/overview)
- [Flutter Local Notifications](https://pub.dev/packages/flutter_local_notifications)
- [Firebase Cloud Functions](https://firebase.google.com/docs/functions)
- [Android Notification Channels](https://developer.android.com/develop/ui/views/notifications/channels)

---

**Happy Testing! 🚀**
