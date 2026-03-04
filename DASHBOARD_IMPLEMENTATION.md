# Dashboard Implementation - Phase 1 & 2 Complete

## ✅ Đã Hoàn Thành: Giai Đoạn 1 & 2 (Data Layer + Providers)

### 📦 DATA MODELS

#### 1. NotificationModel (`lib/data/models/notification_model.dart`)
- **Fields:**
  - `id`: String - ID thông báo
  - `userId`: String - Người nhận thông báo
  - `title`: String - Tiêu đề
  - `body`: String - Nội dung
  - `type`: NotificationType - Loại thông báo
  - `relatedId`: String? - ID liên quan (eventId, etc.)
  - `isRead`: bool - Đã đọc hay chưa
  - `createdAt`: DateTime - Thời gian tạo

- **NotificationType Enum:**
  - `eventReminder` - Nhắc nhở sự kiện
  - `taskUrgent` - Công việc gấp
  - `revenueUpdate` - Cập nhật doanh thu
  - `systemNotification` - Thông báo hệ thống

#### 2. DashboardStatsModel (`lib/data/models/dashboard_stats_model.dart`)
- **Fields:**
  - `totalRevenue`: double - Tổng doanh thu
  - `totalExpenses`: double - Tổng chi phí
  - `upcomingEventsCount`: int - Số sự kiện sắp tới
  - `urgentTasksCount`: int - Số việc gấp
  - `unreadNotificationsCount`: int - Số thông báo chưa đọc

- **Computed Properties:**
  - `netIncome` - Lợi nhuận (revenue - expenses)
  - `profitMargin` - % lợi nhuận
  - `hasUrgentItems` - Có việc gấp không
  - `hasUnreadNotifications` - Có thông báo chưa đọc không

#### 3. RevenueStatsModel (`lib/data/models/dashboard_stats_model.dart`)
- **Fields:**
  - `totalRevenue`: double
  - `totalExpenses`: double
  - `revenueByDate`: List<RevenueByDate> - Doanh thu theo ngày
  - `revenueByArtist`: List<RevenueByArtist> - Doanh thu theo nghệ sĩ
  - `fromDate`: DateTime
  - `toDate`: DateTime

- **Nested Models:**
  - `RevenueByDate` - Doanh thu theo từng ngày
  - `RevenueByArtist` - Doanh thu theo từng nghệ sĩ

---

### 🗄️ REPOSITORIES

#### 1. NotificationRepository (`lib/data/repositories/notification_repository.dart`)
**Methods:**
- `streamNotifications(userId)` - Stream notifications real-time
- `streamUnreadNotifications(userId)` - Stream chỉ thông báo chưa đọc
- `getUnreadCount(userId)` - Lấy số thông báo chưa đọc
- `markAsRead(notificationId)` - Đánh dấu đã đọc 1 thông báo
- `markAllAsRead(userId)` - Đánh dấu tất cả đã đọc
- `createNotification(notification)` - Tạo thông báo mới
- `deleteNotification(notificationId)` - Xóa thông báo
- `deleteAllReadNotifications(userId)` - Xóa tất cả đã đọc
- `streamNotificationsByType(userId, type)` - Stream theo loại

#### 2. RevenueRepository (`lib/data/repositories/revenue_repository.dart`)
**Methods:**
- `getRevenueStats(artistIds, fromDate, toDate)` - Lấy thống kê doanh thu theo khoảng thời gian
- `getCurrentMonthRevenue(artistIds)` - Doanh thu tháng hiện tại
- `getCurrentWeekRevenue(artistIds)` - Doanh thu tuần hiện tại
- `getTodayRevenue(artistIds)` - Doanh thu hôm nay

**Features:**
- Tự động group doanh thu theo ngày (cho charts)
- Tự động group doanh thu theo nghệ sĩ
- Lấy tên nghệ sĩ từ Firestore
- Sort theo revenue giảm dần

#### 3. EventRepository - Extended (`lib/data/repositories/event_repository.dart`)
**New Methods:**
- `getUrgentEvents(artistIds, hoursThreshold)` - Lấy events có checklist chưa hoàn thành và gần deadline
- `getTodayEvents(artistIds)` - Events hôm nay
- `getUpcomingEvents(artistIds, days)` - Events sắp tới (default 7 ngày)

---

### 🎯 PROVIDERS

#### 1. Notifications Provider (`lib/providers/notifications_provider.dart`)
**Providers:**
- `notificationsStreamProvider` - Stream tất cả thông báo
- `unreadNotificationsStreamProvider` - Stream thông báo chưa đọc
- `unreadNotificationsCountProvider` - Số lượng chưa đọc (real-time)
- `markNotificationAsReadProvider` - Mark 1 notification đã đọc
- `markAllNotificationsAsReadProvider` - Mark tất cả đã đọc
- `notificationsByTypeProvider` - Stream theo loại
- `createNotificationProvider` - Tạo thông báo
- `deleteNotificationProvider` - Xóa thông báo

**Role-based:** Tự động filter theo userId của user hiện tại

#### 2. Dashboard Provider (`lib/providers/dashboard_provider.dart`)
**Providers:**
- `dashboardStatsProvider` - Thống kê tổng quan dashboard
- `urgentEventsProvider` - Events gấp (checklist chưa xong + gần deadline)
- `todayEventsProvider` - Events hôm nay
- `upcomingEventsProvider` - Events sắp tới (7 ngày)
- `revenueStatsProvider` - Thống kê doanh thu theo timeframe
- `customDateRangeRevenueProvider` - Doanh thu theo khoảng tùy chỉnh

**Time Frames:**
- `RevenueTimeFrame.today` - Hôm nay
- `RevenueTimeFrame.week` - Tuần này
- `RevenueTimeFrame.month` - Tháng này
- `RevenueTimeFrame.custom` - Tùy chỉnh

**Role-based Filtering:**
- **Viewer (Nghệ sĩ)**: Chỉ thấy data của `artistId`
- **Editor**: Chỉ thấy data của `managedArtistIds`
- **Super Editor**: Thấy tất cả data
- **Pending**: Không thấy gì

---

### 📝 UPDATED FILES

#### Constants
- `lib/core/constants/app_constants.dart` - Thêm `notificationsCollection`

#### Repository Providers
- `lib/providers/repositories_providers.dart` - Thêm:
  - `notificationRepositoryProvider`
  - `revenueRepositoryProvider`

---

## 🔥 FIRESTORE SCHEMA REQUIRED

### Collection: `notifications`
```javascript
{
  id: "auto_generated",
  userId: "user_abc",           // Người nhận
  title: "Nhắc nhở sự kiện",
  body: "Event 'Concert' sẽ bắt đầu trong 1 giờ",
  type: "event_reminder",       // event_reminder | task_urgent | revenue_update | system_notification
  relatedId: "event_xyz",       // Optional: eventId liên quan
  isRead: false,
  createdAt: "2026-02-11T10:00:00Z"
}
```

### Firestore Indexes Required:
1. **notifications**: Composite index
   - Collection: `notifications`
   - Fields: `userId` (Ascending) + `createdAt` (Descending)

2. **notifications (unread)**: Composite index
   - Collection: `notifications`
   - Fields: `userId` (Ascending) + `isRead` (Ascending) + `createdAt` (Descending)

3. **notifications (by type)**: Composite index
   - Collection: `notifications`
   - Fields: `userId` (Ascending) + `type` (Ascending) + `createdAt` (Descending)

4. **events (urgent)**: Composite index
   - Collection: `events`
   - Fields: `artistIds` (Array) + `startTime` (Ascending)

---

## 📊 USAGE EXAMPLES

### Dashboard Stats
```dart
// In your widget
final dashboardStats = ref.watch(dashboardStatsProvider);

dashboardStats.when(
  data: (stats) => Column(
    children: [
      Text('Revenue: ${stats.totalRevenue}'),
      Text('Urgent Tasks: ${stats.urgentTasksCount}'),
      Text('Unread: ${stats.unreadNotificationsCount}'),
    ],
  ),
  loading: () => CircularProgressIndicator(),
  error: (err, stack) => Text('Error: $err'),
);
```

### Notifications
```dart
// Get unread count
final unreadCount = ref.watch(unreadNotificationsCountProvider);

// Get all notifications
final notifications = ref.watch(notificationsStreamProvider);

// Mark as read
await ref.read(markNotificationAsReadProvider(notificationId).future);
```

### Revenue Stats
```dart
// Change time frame
ref.read(selectedRevenueTimeFrameProvider.notifier).state = RevenueTimeFrame.month;

// Get revenue stats
final revenueStats = ref.watch(revenueStatsProvider);

revenueStats.when(
  data: (stats) => Column(
    children: [
      Text('Total: ${stats.totalRevenue}'),
      Text('Net Income: ${stats.netIncome}'),
      // Chart using stats.revenueByDate
    ],
  ),
  loading: () => CircularProgressIndicator(),
  error: (err, stack) => Text('Error: $err'),
);
```

---

## ✅ NEXT STEPS (Giai đoạn 3: UI)

1. **Home Screen** (`lib/presentation/home/home_screen.dart`)
   - Dashboard với Quick Stats Cards
   - Today's Events
   - Urgent Tasks
   - Mini Revenue Chart

2. **Notifications Screen** (`lib/presentation/notifications/notifications_screen.dart`)
   - List notifications
   - Swipe to mark as read
   - Badge với unread count
   - Navigate to related event

3. **Revenue Screen** (`lib/presentation/revenue/revenue_screen.dart`)
   - Time frame selector
   - Revenue chart (fl_chart)
   - Breakdown by artist
   - Export functionality

4. **Bottom Navigation Bar**
   - 🏠 Home (Dashboard)
   - 📅 Calendar (existing)
   - 💰 Revenue
   - 👤 Profile

---

## 🎉 SUMMARY

**Giai đoạn 1 & 2 đã hoàn thành 100%!**

✅ 3 Models mới (với Freezed + JSON serialization)
✅ 2 Repositories mới (Notification + Revenue)
✅ EventRepository extended (urgent events, today, upcoming)
✅ 2 Provider files (Notifications + Dashboard)
✅ Role-based filtering cho tất cả providers
✅ Code generation successful
✅ No linter errors

**Sẵn sàng cho Giai đoạn 3: Build UI!**
