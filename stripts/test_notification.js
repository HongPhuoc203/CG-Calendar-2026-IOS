/**
 * Script để test gửi push notification đến một device cụ thể
 * 
 * Usage:
 * 1. Lấy FCM token từ app logs
 * 2. Thay thế FCM_TOKEN_HERE bằng token thực
 * 3. Run: node test_notification.js
 */

const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://cg-calendar-9c69d-default-rtdb.firebaseio.com'
});

// ===== CONFIGURATION =====
// FCM Token từ Firestore
const FCM_TOKEN = 'cHEa78aUQe-YRK1Uy3AGI8:APA91bEYHJuSLuK0pb1qLwT_NZ0NJM73k7vRFwt0eXau8lrQSXqdpFa6rxX4sWnU_84TBCOP7OGA1G5S_YipaYs63xiziJgFgL9z1ZFbJ0L3aa3Tu7YNu8g';

const EVENT_ID = 'test-event-123';
const EVENT_NAME = 'Test Event từ Node.js';

// ===== SEND NOTIFICATION =====
async function sendTestNotification() {
  const message = {
    token: FCM_TOKEN,
    notification: {
      title: '🔔 Test Notification',
      body: `${EVENT_NAME} - Đây là test từ Node.js script`,
    },
    data: {
      type: 'reminder',
      eventId: EVENT_ID,
      reminderTime: new Date().toISOString(),
    },
    android: {
      priority: 'high',
      notification: {
        channelId: 'cg_calendar_reminders',
        sound: 'default',
        icon: '@mipmap/ic_launcher',
        color: '#4285F4',
      },
    },
  };

  try {
    console.log('📤 Đang gửi notification...');
    console.log('Token:', FCM_TOKEN.substring(0, 20) + '...');
    
    const response = await admin.messaging().send(message);
    
    console.log('✅ Gửi thành công!');
    console.log('Response:', response);
    console.log('\n🎉 Kiểm tra điện thoại để xem notification!');
  } catch (error) {
    console.error('❌ Lỗi khi gửi:', error.message);
    if (error.code === 'messaging/invalid-registration-token') {
      console.error('⚠️  FCM Token không hợp lệ. Vui lòng kiểm tra lại token.');
    }
  }
  
  process.exit(0);
}

// Run
sendTestNotification();
