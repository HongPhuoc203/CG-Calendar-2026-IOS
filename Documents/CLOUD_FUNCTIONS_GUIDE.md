# ☁️ Cloud Functions for CG Calendar

## 📝 Overview

Cloud Functions xử lý logic server-side cho:
- ✅ Tự động tạo notification jobs khi có reminder
- ✅ Scheduler gửi push notifications đúng giờ
- ✅ Cleanup expired notifications

---

## 🚀 Setup Cloud Functions

### 1. Initialize Functions

```bash
# Trong thư mục project root
firebase init functions

# Chọn:
# - Language: JavaScript (hoặc TypeScript)
# - ESLint: Yes
# - Install dependencies: Yes
```

### 2. Cấu trúc Functions

```
functions/
├── index.js              # Main entry point
├── package.json          # Dependencies
├── .env                  # Environment variables (local)
└── .gitignore
```

---

## 📦 Dependencies

### package.json

```json
{
  "name": "functions",
  "description": "Cloud Functions for CG Calendar",
  "scripts": {
    "serve": "firebase emulators:start --only functions",
    "shell": "firebase functions:shell",
    "start": "npm run shell",
    "deploy": "firebase deploy --only functions",
    "logs": "firebase functions:log"
  },
  "engines": {
    "node": "18"
  },
  "main": "index.js",
  "dependencies": {
    "firebase-admin": "^12.0.0",
    "firebase-functions": "^4.5.0"
  },
  "devDependencies": {
    "eslint": "^8.15.0"
  }
}
```

---

## 💻 Cloud Functions Code

### functions/index.js

```javascript
const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();
const db = admin.firestore();
const messaging = admin.messaging();

// ============================================
// FUNCTION 1: Create Notification Jobs
// ============================================
// Trigger: Khi reminder được tạo
// Action: Tạo notification_jobs cho mỗi recipient

exports.onReminderCreated = functions.firestore
  .document('reminders/{reminderId}')
  .onCreate(async (snap, context) => {
    const reminder = snap.data();
    const reminderId = context.params.reminderId;

    try {
      // Get event details
      const eventDoc = await db.collection('events').doc(reminder.eventId).get();
      
      if (!eventDoc.exists) {
        console.error(`Event ${reminder.eventId} not found`);
        return null;
      }

      const event = eventDoc.data();
      const batch = db.batch();

      // Create notification job for each recipient
      for (const userId of reminder.recipientUserIds) {
        const jobRef = db.collection('notification_jobs').doc();
        
        batch.set(jobRef, {
          reminderId: reminderId,
          eventId: reminder.eventId,
          eventTitle: event.title,
          eventStartTime: event.startTime,
          recipientUserId: userId,
          scheduledTime: reminder.triggerTime,
          status: 'pending',
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      console.log(`Created ${reminder.recipientUserIds.length} notification jobs`);
      
      return null;
    } catch (error) {
      console.error('Error creating notification jobs:', error);
      return null;
    }
  });

// ============================================
// FUNCTION 2: Send Scheduled Notifications
// ============================================
// Trigger: Chạy mỗi 5 phút
// Action: Gửi FCM push cho jobs đến hạn

exports.sendScheduledNotifications = functions.pubsub
  .schedule('every 5 minutes')
  .timeZone('Asia/Ho_Chi_Minh')
  .onRun(async (context) => {
    const now = admin.firestore.Timestamp.now();
    
    try {
      // Query pending jobs that should be sent
      const jobsSnapshot = await db.collection('notification_jobs')
        .where('status', '==', 'pending')
        .where('scheduledTime', '<=', now)
        .limit(100) // Process 100 at a time
        .get();

      if (jobsSnapshot.empty) {
        console.log('No pending notifications to send');
        return null;
      }

      console.log(`Found ${jobsSnapshot.size} notifications to send`);

      const promises = jobsSnapshot.docs.map(async (jobDoc) => {
        const job = jobDoc.data();
        
        try {
          // Get user's FCM token
          const userDoc = await db.collection('users').doc(job.recipientUserId).get();
          
          if (!userDoc.exists) {
            throw new Error(`User ${job.recipientUserId} not found`);
          }

          const user = userDoc.data();
          
          if (!user.fcmToken) {
            throw new Error(`User ${job.recipientUserId} has no FCM token`);
          }

          // Calculate time until event
          const eventTime = new Date(job.eventStartTime);
          const timeUntil = getTimeUntilEvent(eventTime);

          // Send FCM notification
          const message = {
            token: user.fcmToken,
            notification: {
              title: '🔔 Nhắc lịch',
              body: `"${job.eventTitle}" sẽ diễn ra ${timeUntil}`,
            },
            data: {
              eventId: job.eventId,
              type: 'event_reminder',
            },
            android: {
              priority: 'high',
              notification: {
                sound: 'default',
                channelId: 'cg_calendar_channel',
              },
            },
            apns: {
              payload: {
                aps: {
                  sound: 'default',
                  badge: 1,
                },
              },
            },
          };

          await messaging.send(message);

          // Mark job as sent
          await jobDoc.ref.update({
            status: 'sent',
            sentAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          // Mark reminder as sent
          await db.collection('reminders').doc(job.reminderId).update({
            isSent: true,
            sentAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          console.log(`Sent notification to user ${job.recipientUserId}`);

        } catch (error) {
          console.error(`Failed to send notification for job ${jobDoc.id}:`, error);
          
          // Mark as failed
          await jobDoc.ref.update({
            status: 'failed',
            errorMessage: error.message,
          });
        }
      });

      await Promise.all(promises);
      console.log('Batch complete');
      
      return null;
    } catch (error) {
      console.error('Error in sendScheduledNotifications:', error);
      return null;
    }
  });

// ============================================
// FUNCTION 3: Cleanup Old Notifications
// ============================================
// Trigger: Chạy hàng ngày lúc 2:00 AM
// Action: Xóa notification jobs đã gửi > 30 ngày

exports.cleanupOldNotifications = functions.pubsub
  .schedule('0 2 * * *') // 2:00 AM daily
  .timeZone('Asia/Ho_Chi_Minh')
  .onRun(async (context) => {
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    try {
      const snapshot = await db.collection('notification_jobs')
        .where('status', 'in', ['sent', 'failed'])
        .where('sentAt', '<=', admin.firestore.Timestamp.fromDate(thirtyDaysAgo))
        .limit(500)
        .get();

      if (snapshot.empty) {
        console.log('No old notifications to clean up');
        return null;
      }

      const batch = db.batch();
      snapshot.docs.forEach((doc) => {
        batch.delete(doc.ref);
      });

      await batch.commit();
      console.log(`Cleaned up ${snapshot.size} old notification jobs`);
      
      return null;
    } catch (error) {
      console.error('Error cleaning up notifications:', error);
      return null;
    }
  });

// ============================================
// HELPER FUNCTIONS
// ============================================

function getTimeUntilEvent(eventTime) {
  const now = new Date();
  const diff = eventTime - now;
  
  const hours = Math.floor(diff / (1000 * 60 * 60));
  const minutes = Math.floor((diff % (1000 * 60 * 60)) / (1000 * 60));
  
  if (hours > 24) {
    const days = Math.floor(hours / 24);
    return `sau ${days} ngày nữa`;
  } else if (hours > 0) {
    return `sau ${hours} giờ nữa`;
  } else if (minutes > 0) {
    return `sau ${minutes} phút nữa`;
  } else {
    return 'ngay bây giờ';
  }
}

// ============================================
// FUNCTION 4: On User Approved (Optional)
// ============================================
// Auto-send welcome notification khi user được approve

exports.onUserApproved = functions.firestore
  .document('users/{userId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    
    // Check if role changed from pending to something else
    if (before.role === 'pending' && after.role !== 'pending') {
      const userId = context.params.userId;
      
      // Send welcome notification if user has FCM token
      if (after.fcmToken) {
        try {
          const message = {
            token: after.fcmToken,
            notification: {
              title: '🎉 Chào mừng đến CG Calendar!',
              body: `Tài khoản của bạn đã được phê duyệt với vai trò ${getRoleDisplayName(after.role)}.`,
            },
            data: {
              type: 'user_approved',
            },
          };
          
          await messaging.send(message);
          console.log(`Sent welcome notification to user ${userId}`);
        } catch (error) {
          console.error('Error sending welcome notification:', error);
        }
      }
    }
    
    return null;
  });

function getRoleDisplayName(role) {
  switch (role) {
    case 'viewer':
      return 'Nghệ sĩ';
    case 'editor':
      return 'Quản lý nghệ sĩ';
    case 'super_editor':
      return 'Quản lý tổng';
    default:
      return role;
  }
}
```

---

## 🔧 Environment Setup

### Local Development (Emulator)

```bash
# Start emulators
firebase emulators:start

# Test functions locally
firebase functions:shell

# In shell:
> onReminderCreated({eventId: 'test123', ...})
```

### Environment Variables

```bash
# Set config
firebase functions:config:set notification.enabled=true

# Get config
firebase functions:config:get

# Use in code:
const config = functions.config();
console.log(config.notification.enabled);
```

---

## 🚀 Deploy Functions

```bash
# Deploy all functions
firebase deploy --only functions

# Deploy specific function
firebase deploy --only functions:sendScheduledNotifications

# View logs
firebase functions:log

# View logs for specific function
firebase functions:log --only sendScheduledNotifications
```

---

## 📊 Monitoring & Debugging

### Firebase Console
- Functions > Dashboard
- View invocations, errors, execution time
- Set up alerts for failures

### Logs
```bash
# Real-time logs
firebase functions:log --follow

# Filter by function
firebase functions:log --only sendScheduledNotifications

# Filter by time
firebase functions:log --since 1h
```

---

## 💰 Cost Estimation

### Cloud Functions Pricing:
- **Invocations**: $0.40 per million (first 2M free)
- **Compute time**: ~$0.0000025 per 100ms GB-sec
- **Network**: $0.12 per GB (first 5GB free)

### Estimated costs cho 100 users:
- Reminders: ~500/month → **Free**
- Scheduler: ~8,640/month (5 min intervals) → **Free**
- Cleanup: ~30/month → **Free**

**Total: ~$0-2/month** (cho 100 users với push thường xuyên)

---

## ⚠️ Important Notes

### 1. Security
- Functions chạy với service account (admin privileges)
- Không cần Security Rules cho functions
- Validate input data trước khi xử lý

### 2. Error Handling
- Luôn wrap trong try-catch
- Log errors để debug
- Set status failed nếu gửi notification thất bại

### 3. Idempotency
- Reminder có thể trigger nhiều lần
- Check trạng thái trước khi xử lý
- Dùng transaction nếu cần

### 4. Performance
- Limit batch size (100-500 docs)
- Use Promise.all cho parallel processing
- Cleanup old data để tránh query chậm

### 5. Testing
- Test thoroughly với emulator
- Có test cases cho edge cases
- Monitor errors sau deploy

---

## 🧪 Testing

### Sample Test Data

```javascript
// Create test reminder
const testReminder = {
  eventId: 'event123',
  value: 1,
  unit: 'hours',
  recipientUserIds: ['user1', 'user2'],
  triggerTime: new Date(Date.now() + 60000), // 1 min from now
  isSent: false,
  createdAt: new Date(),
};

// Test in emulator
db.collection('reminders').add(testReminder);
```

---

## 📚 References

- [Firebase Cloud Functions Documentation](https://firebase.google.com/docs/functions)
- [Firebase Cloud Messaging](https://firebase.google.com/docs/cloud-messaging)
- [Scheduled Functions](https://firebase.google.com/docs/functions/schedule-functions)

---

**Ready to handle notifications! 🔔**

