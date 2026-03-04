# 🎯 CG Calendar Dashboard - Complete Implementation Guide

## 📖 OVERVIEW

Hệ thống Dashboard hoàn chỉnh cho CG Calendar với các tính năng:
- 🏠 **Dashboard/Home Screen**: Tổng quan thống kê, sự kiện hôm nay, việc gấp
- 🔔 **Notifications**: Quản lý thông báo real-time
- 💰 **Revenue Analytics**: Phân tích doanh thu chi tiết
- 👤 **Profile**: Quản lý tài khoản

## 🚀 QUICK START

### 1. Setup Firestore Indexes
Đọc file `FIRESTORE_SETUP.md` để tạo các composite indexes cần thiết.

**Required Indexes:**
- notifications: userId + createdAt
- notifications: userId + isRead + createdAt  
- notifications: userId + type + createdAt
- events: artistIds (array) + startTime

### 2. Dependencies
Tất cả dependencies đã được thêm vào `pubspec.yaml`:
```yaml
fl_chart: ^0.69.0        # Charts
badges: ^3.1.2           # Notification badges
timeago: ^3.7.0          # Time formatting
```

Run:
```bash
flutter pub get
```

### 3. Run the App
```bash
flutter run
```

---

## 📁 PROJECT STRUCTURE

```
lib/
├── data/
│   ├── models/
│   │   ├── notification_model.dart          ⭐ NEW
│   │   ├── dashboard_stats_model.dart       ⭐ NEW
│   │   ├── event_model.dart                 (updated)
│   │   └── ...
│   └── repositories/
│       ├── notification_repository.dart      ⭐ NEW
│       ├── revenue_repository.dart           ⭐ NEW
│       ├── event_repository.dart            (updated - urgent, today, upcoming)
│       └── ...
├── providers/
│   ├── notifications_provider.dart          ⭐ NEW
│   ├── dashboard_provider.dart              ⭐ NEW
│   └── repositories_providers.dart          (updated)
└── presentation/
    ├── home/                                ⭐ NEW
    │   ├── home_screen.dart
    │   └── widgets/
    │       ├── stat_card.dart
    │       ├── section_header.dart
    │       ├── compact_event_card.dart
    │       └── revenue_chart.dart
    ├── notifications/                       ⭐ NEW
    │   └── notifications_screen.dart
    ├── revenue/                             ⭐ NEW
    │   └── revenue_screen.dart
    ├── profile/                             ⭐ NEW
    │   └── profile_screen.dart
    ├── main/                                ⭐ NEW
    │   └── main_screen.dart                (Bottom Navigation)
    └── auth/
        └── auth_wrapper.dart                (updated - routes to MainScreen)
```

---

## 🎨 SCREENS OVERVIEW

### 1. Home Screen (Dashboard)
**Path:** `lib/presentation/home/home_screen.dart`

**Features:**
- Quick stats cards (4 metrics)
- Today's events list
- Urgent tasks list
- Revenue chart for current month
- Pull to refresh
- Notification bell with badge

**Data Providers:**
- `dashboardStatsProvider`
- `urgentEventsProvider`
- `todayEventsProvider`
- `revenueStatsProvider`

---

### 2. Notifications Screen
**Path:** `lib/presentation/notifications/notifications_screen.dart`

**Features:**
- Real-time notification stream
- Filter toggle (unread only)
- Swipe to mark as read
- Mark all as read
- Tap to view related event
- Time ago formatting (Vietnamese)
- Different icons per notification type

**Notification Types:**
- 📅 Event Reminder
- ⚠️ Task Urgent
- 📈 Revenue Update
- ℹ️ System Notification

---

### 3. Revenue Screen
**Path:** `lib/presentation/revenue/revenue_screen.dart`

**Features:**
- Time frame selector (Today, Week, Month)
- Summary cards (Total revenue, expenses, profit)
- Interactive line chart
- Revenue breakdown by artist
- Detailed metrics

**Data Providers:**
- `revenueStatsProvider`
- `selectedRevenueTimeFrameProvider`

---

### 4. Profile Screen
**Path:** `lib/presentation/profile/profile_screen.dart`

**Features:**
- User info display
- Role badge
- Menu items (Profile, Notifications, Admin, Help)
- Logout button
- Version display

---

### 5. Main Screen (Bottom Navigation)
**Path:** `lib/presentation/main/main_screen.dart`

**Tabs:**
- 🏠 Home (Dashboard)
- 📅 Calendar (Existing)
- 💰 Revenue
- 👤 Profile

---

## 🔐 ROLE-BASED ACCESS

Tất cả data tự động filter theo role:

| Role | Access |
|------|--------|
| **Pending** | No data access |
| **Viewer (Nghệ sĩ)** | Chỉ thấy data của `artistId` của mình |
| **Editor** | Thấy data của `managedArtistIds` |
| **Super Editor** | Thấy TẤT CẢ data |

**Implementation:**
- Logic filtering trong `dashboard_provider.dart`
- Providers tự động áp dụng dựa trên `currentUserProfileProvider`

---

## 📊 DATA MODELS

### DashboardStatsModel
```dart
{
  totalRevenue: double,
  totalExpenses: double,
  upcomingEventsCount: int,
  urgentTasksCount: int,
  unreadNotificationsCount: int,
}

Computed:
- netIncome
- profitMargin
- hasUrgentItems
- hasUnreadNotifications
```

### NotificationModel
```dart
{
  id: string,
  userId: string,
  title: string,
  body: string,
  type: NotificationType,
  relatedId: string?,
  isRead: bool,
  createdAt: DateTime,
}
```

### RevenueStatsModel
```dart
{
  totalRevenue: double,
  totalExpenses: double,
  revenueByDate: List<RevenueByDate>,
  revenueByArtist: List<RevenueByArtist>,
  fromDate: DateTime,
  toDate: DateTime,
}

Computed:
- netIncome
- averageDailyRevenue
```

---

## 🔄 KEY PROVIDERS

### Dashboard Provider
```dart
// Overall stats
dashboardStatsProvider

// Urgent events (48h, incomplete checklist)
urgentEventsProvider

// Today's events
todayEventsProvider

// Upcoming events (7 days)
upcomingEventsProvider

// Revenue stats
revenueStatsProvider
selectedRevenueTimeFrameProvider
```

### Notifications Provider
```dart
// All notifications stream
notificationsStreamProvider

// Unread only stream
unreadNotificationsStreamProvider

// Unread count
unreadNotificationsCountProvider

// Mark as read
markNotificationAsReadProvider(notificationId)
markAllNotificationsAsReadProvider
```

---

## 🎯 USAGE EXAMPLES

### Display Dashboard Stats
```dart
final stats = ref.watch(dashboardStatsProvider);

stats.when(
  data: (data) => Column(
    children: [
      Text('Revenue: ${NumberFormatter.formatCurrency(data.totalRevenue)}'),
      Text('Urgent: ${data.urgentTasksCount}'),
    ],
  ),
  loading: () => CircularProgressIndicator(),
  error: (err, stack) => Text('Error: $err'),
);
```

### Show Notification Badge
```dart
final unreadCount = ref.watch(unreadNotificationsCountProvider);

badges.Badge(
  showBadge: unreadCount.value ?? 0 > 0,
  badgeContent: Text('${unreadCount.value}'),
  child: Icon(Icons.notifications),
);
```

### Create a Notification (from Cloud Functions)
```dart
final notification = NotificationModel(
  id: uuid.v4(),
  userId: targetUserId,
  title: 'Nhắc nhở sự kiện',
  body: 'Sự kiện "${event.title}" sẽ bắt đầu trong 1 giờ',
  type: NotificationType.eventReminder,
  relatedId: event.id,
  isRead: false,
  createdAt: DateTime.now(),
);

await notificationRepository.createNotification(notification);
```

---

## ✅ TESTING CHECKLIST

### Pre-flight Checks
- [ ] Firebase project setup
- [ ] Firestore indexes created and enabled
- [ ] Security rules updated
- [ ] Auth working properly
- [ ] At least 1 user with each role for testing

### Home Screen Tests
- [ ] Stats cards display correct numbers
- [ ] Notification badge shows unread count
- [ ] Today's events appear (if any events today)
- [ ] Urgent tasks appear (if any urgent events)
- [ ] Revenue chart renders
- [ ] Pull to refresh works
- [ ] Tap event → navigates to details

### Notifications Tests
- [ ] Notifications stream real-time
- [ ] Filter toggle works
- [ ] Swipe to mark as read
- [ ] Mark all as read
- [ ] Tap notification → marks read & navigates
- [ ] Correct icons/colors per type
- [ ] Empty state shows when no notifications

### Revenue Tests
- [ ] Time frame selector changes data
- [ ] Summary cards show correct totals
- [ ] Chart displays properly
- [ ] Revenue by artist breakdown shows
- [ ] Details section accurate
- [ ] Pull to refresh updates

### Profile Tests
- [ ] Avatar/name/email display
- [ ] Role badge shows correct role
- [ ] Admin panel only for Super Editor
- [ ] Logout works

### Bottom Navigation Tests
- [ ] All 4 tabs accessible
- [ ] Active tab highlights
- [ ] Tab state preserved on switch

### Role-based Tests
- [ ] Viewer sees only their artist's data
- [ ] Editor sees managed artists' data
- [ ] Super Editor sees all data
- [ ] Pending sees no data

---

## 🐛 TROUBLESHOOTING

### Issue: "Index required" error
**Solution:** Tạo composite indexes theo `FIRESTORE_SETUP.md`

### Issue: Empty data on Dashboard
**Causes:**
1. No events in date range → Create test events
2. Role-based filtering → Check user has correct artistId/managedArtistIds
3. Firestore security rules → Check rules allow read

**Debug:**
```dart
// Add to dashboard_provider.dart
print('🔍 User role: ${user.role}');
print('🔍 Artist IDs: $artistIds');
```

### Issue: Notifications not appearing
**Causes:**
1. No notifications in Firestore → Create test notification
2. Wrong userId → Check notification.userId matches auth.uid
3. Index not ready → Wait for index building

**Test Notification:**
```javascript
// In Firestore Console, add document to notifications:
{
  userId: "your_user_uid",
  title: "Test Notification",
  body: "This is a test",
  type: "system_notification",
  isRead: false,
  createdAt: "2026-02-11T10:00:00Z"
}
```

### Issue: Chart not rendering
**Causes:**
1. No revenue data → Add finance data to events
2. Empty revenueByDate → Check date range has events
3. Chart library issue → Check fl_chart version

### Issue: Bottom nav not switching
**Check:** IndexedStack index updating correctly

---

## 📈 PERFORMANCE TIPS

1. **Limit Queries:**
   - Notifications: Limit 50 recent
   - Events: Filter by date range
   - Use pagination for large lists

2. **Cache Strategy:**
   - Providers auto-cache with Riverpod
   - Use `.family` providers for parameterized data
   - Invalidate on refresh

3. **Firestore Optimization:**
   - Create necessary indexes
   - Use `limit()` on queries
   - Avoid reading entire collections

4. **UI Optimization:**
   - Use `const` constructors where possible
   - Lazy load lists
   - Optimize chart rendering (limit data points)

---

## 🔮 FUTURE ENHANCEMENTS

### Phase 4 (Optional):
1. **Search & Filters**
   - Search events in home
   - Advanced filters for revenue

2. **Export & Reports**
   - Export revenue to CSV/PDF
   - Email reports

3. **Push Notifications**
   - FCM integration for notifications
   - Background notification handling

4. **Offline Mode**
   - Cache data locally
   - Sync when online

5. **Analytics Dashboard**
   - Charts for event types
   - Artist performance metrics
   - Trends over time

---

## 📚 DOCUMENTATION FILES

- `DASHBOARD_IMPLEMENTATION.md` - Phase 1 & 2 (Data + Providers)
- `UI_IMPLEMENTATION.md` - Phase 3 (UI Components & Screens)
- `FIRESTORE_SETUP.md` - Firestore indexes & security rules
- `README_DASHBOARD.md` - This file (Overview & Guide)

---

## 🎉 COMPLETION STATUS

### ✅ Phase 1: Data Layer (100%)
- [x] NotificationModel
- [x] DashboardStatsModel
- [x] RevenueStatsModel
- [x] NotificationRepository
- [x] RevenueRepository
- [x] EventRepository extended

### ✅ Phase 2: Providers (100%)
- [x] notifications_provider.dart
- [x] dashboard_provider.dart
- [x] Role-based filtering
- [x] Real-time streams

### ✅ Phase 3: UI (100%)
- [x] HomeScreen
- [x] NotificationsScreen
- [x] RevenueScreen
- [x] ProfileScreen
- [x] MainScreen (Bottom Nav)
- [x] 4 Reusable widgets
- [x] Charts integration
- [x] Badges integration

### ✅ Integration (100%)
- [x] Auth routing updated
- [x] No linter errors
- [x] Dependencies added
- [x] Documentation complete

---

## 💬 SUPPORT

Nếu gặp vấn đề:
1. Check documentation files
2. Review error logs
3. Test with simple data first
4. Check Firebase Console for errors

---

**🚀 Dashboard Implementation Complete!**

Tất cả tính năng đã được implement đầy đủ và sẵn sàng để testing/demo!
