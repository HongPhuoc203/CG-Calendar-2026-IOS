# Firestore Setup Guide

## 📋 REQUIRED FIRESTORE INDEXES

Để ứng dụng hoạt động đúng, bạn cần tạo các composite indexes sau trên Firebase Console.

### Cách tạo Indexes:

1. Truy cập Firebase Console: https://console.firebase.google.com
2. Chọn project của bạn
3. Vào **Firestore Database** → **Indexes** tab
4. Click **Create Index**
5. Nhập thông tin theo từng index bên dưới

---

## 🔍 INDEXES CẦN TẠO

### 1. Notifications - Query by User & Time
**Collection:** `notifications`

| Field | Order |
|-------|-------|
| userId | Ascending |
| createdAt | Descending |

**Query Scope:** Collection

**Usage:** Stream all notifications for a user, sorted by newest first

---

### 2. Notifications - Query Unread
**Collection:** `notifications`

| Field | Order |
|-------|-------|
| userId | Ascending |
| isRead | Ascending |
| createdAt | Descending |

**Query Scope:** Collection

**Usage:** Filter unread notifications for a user

---

### 3. Notifications - Query by Type
**Collection:** `notifications`

| Field | Order |
|-------|-------|
| userId | Ascending |
| type | Ascending |
| createdAt | Descending |

**Query Scope:** Collection

**Usage:** Filter notifications by type (event_reminder, task_urgent, etc.)

---

### 4. Events - Query by Artist & Time
**Collection:** `events`

| Field | Order |
|-------|-------|
| artistIds | Array |
| startTime | Ascending |

**Query Scope:** Collection

**Usage:** Get events for specific artists, filter urgent events, upcoming events

**Note:** Firebase yêu cầu index cho queries có cả `array-contains-any` và `orderBy`/`where` khác

---

## 🗂️ FIRESTORE COLLECTIONS STRUCTURE

### Collection: `notifications`
```javascript
notifications/
  {notificationId}/
    userId: string           // User nhận notification
    title: string           // Tiêu đề
    body: string            // Nội dung
    type: string            // "event_reminder" | "task_urgent" | "revenue_update" | "system_notification"
    relatedId: string?      // ID liên quan (eventId, etc.)
    isRead: boolean         // Đã đọc chưa
    createdAt: timestamp    // Thời gian tạo
```

**Example Document:**
```json
{
  "userId": "user_abc123",
  "title": "Nhắc nhở sự kiện",
  "body": "Sự kiện 'Concert' sẽ bắt đầu trong 1 giờ",
  "type": "event_reminder",
  "relatedId": "event_xyz789",
  "isRead": false,
  "createdAt": "2026-02-11T10:00:00Z"
}
```

---

### Collection: `events` (Existing - No Changes)
```javascript
events/
  {eventId}/
    title: string
    description: string?
    startTime: timestamp
    endTime: timestamp
    location: string?
    artistIds: array<string>    // Array of artist IDs
    eventTypeId: string
    checklistItems: array<object>
    customFields: map
    links: array<object>
    notes: string?
    finance: object?            // { revenue: number, expenses: array }
    createdBy: string
    createdAt: timestamp
    updatedAt: timestamp
```

**Note:** Index cần thiết do có query:
- `where('artistIds', arrayContainsAny: artistIds)`
- `where('startTime', isGreaterThanOrEqualTo: ...)`

---

## 🔐 FIRESTORE SECURITY RULES

### Notifications Rules
```javascript
match /notifications/{notificationId} {
  // Chỉ user được assigned mới đọc được notification của mình
  allow read: if request.auth != null && 
                 resource.data.userId == request.auth.uid;
  
  // Chỉ user được assigned mới update (mark as read)
  allow update: if request.auth != null && 
                   resource.data.userId == request.auth.uid &&
                   request.resource.data.diff(resource.data).affectedKeys().hasOnly(['isRead']);
  
  // Cloud Functions có thể tạo notifications
  allow create: if request.auth.token.admin == true;
  
  // User có thể xóa notifications của mình
  allow delete: if request.auth != null && 
                   resource.data.userId == request.auth.uid;
}
```

### Events Rules (Already exists - ensure these are set)
```javascript
match /events/{eventId} {
  // Helper function to check user role
  function getUserRole() {
    return get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role;
  }
  
  function getUserArtistId() {
    return get(/databases/$(database)/documents/users/$(request.auth.uid)).data.artistId;
  }
  
  function getUserManagedArtists() {
    return get(/databases/$(database)/documents/users/$(request.auth.uid)).data.managedArtistIds;
  }
  
  // Read: depends on role
  allow read: if request.auth != null && (
    getUserRole() == 'super_editor' ||
    (getUserRole() == 'editor' && 
     resource.data.artistIds.hasAny(getUserManagedArtists())) ||
    (getUserRole() == 'viewer' && 
     getUserArtistId() in resource.data.artistIds)
  );
  
  // Write: only editors and super editors
  allow create, update: if request.auth != null && (
    getUserRole() == 'super_editor' ||
    getUserRole() == 'editor'
  );
  
  // Delete: only super editor
  allow delete: if request.auth != null && 
                   getUserRole() == 'super_editor';
}
```

---

## ⚡ TESTING INDEXES

Sau khi tạo indexes, bạn có thể test bằng cách:

### 1. Test Notifications Query
```dart
// In Firestore Console, run this query:
notifications
  .where('userId', '==', 'test_user_id')
  .orderBy('createdAt', 'desc')
  .limit(10)
```

### 2. Test Unread Notifications
```dart
notifications
  .where('userId', '==', 'test_user_id')
  .where('isRead', '==', false)
  .orderBy('createdAt', 'desc')
```

### 3. Test Events by Artist
```dart
events
  .where('artistIds', 'array-contains-any', ['artist1', 'artist2'])
  .where('startTime', '>=', Timestamp.now())
  .where('startTime', '<=', Timestamp.fromDate(DateTime.now().add(Duration(days: 7))))
```

---

## 📊 MONITORING

### Check Index Usage
1. Firebase Console → Firestore → Usage tab
2. Xem "Composite Index" usage
3. Check query performance

### Common Issues

#### Issue 1: Query fails with "index required" error
**Solution:** 
- Click vào error message trong logs
- Firebase sẽ có link để tạo index tự động
- Hoặc tạo thủ công theo hướng dẫn trên

#### Issue 2: Index đang building (building state)
**Solution:**
- Đợi vài phút để index hoàn thành
- Index status sẽ chuyển từ "Building" → "Enabled"
- Với database nhỏ (~100-1000 docs), thường < 5 phút

#### Issue 3: Queries trả về empty results
**Solution:**
- Check xem có data trong collection không
- Check security rules có đúng không
- Check userId matching với auth.uid

---

## 🎯 INITIALIZATION CHECKLIST

- [ ] Tạo 4 composite indexes trên Firebase Console
- [ ] Đợi tất cả indexes status = "Enabled"
- [ ] Update Firestore Security Rules
- [ ] Test queries từ Firestore Console
- [ ] Run app và test notifications flow
- [ ] Test role-based filtering
- [ ] Check error logs cho missing indexes

---

## 💡 TIPS

1. **Index Auto-creation:**
   - Khi app chạy query mà chưa có index, Firebase sẽ log error với link tạo index
   - Click vào link đó để tạo index tự động

2. **Development vs Production:**
   - Tạo indexes riêng cho mỗi environment
   - Development indexes có thể xóa sau khi test

3. **Cost Optimization:**
   - Indexes consume storage & read/write operations
   - Chỉ tạo indexes thực sự cần thiết
   - Monitor usage trong Firebase Console

4. **Backup:**
   - Export Firestore data định kỳ
   - Sử dụng Firebase scheduled backups

---

## 📞 SUPPORT

Nếu gặp vấn đề với Firestore indexes:

1. Check Firebase Console → Firestore → Indexes tab
2. Xem logs trong Firebase Console → Functions (nếu dùng Cloud Functions)
3. Check Flutter debug logs cho error messages
4. Firebase Documentation: https://firebase.google.com/docs/firestore/query-data/indexing

---

**✅ Sau khi setup xong Firestore indexes, app sẽ hoạt động hoàn toàn!**
