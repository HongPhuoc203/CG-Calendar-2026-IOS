/**
 * Script để gửi custom notification với thông tin tùy chỉnh
 * Dùng khi chưa có Cloud Functions
 */

const admin = require('firebase-admin');
const readline = require('readline');

// Initialize Firebase Admin SDK
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://cg-calendar-9c69d-default-rtdb.firebaseio.com'
});

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

// FCM Token
const FCM_TOKEN = 'dd20PLAuRqmoj_HQjsoJG8:APA91bEQRkGzyWcHBYyVXmpkFYShlbRo7EBnfh5Z9XcElZxv5Po6m-UyuLGnfsLAEPLNzeyvqFiTMxMP-X2XOSVq_oHCyGqUe0_E0D_aGo-vsVRZGU1Ead4';

async function sendCustomNotification() {
  console.log('\n📝 NHẬP THÔNG TIN NOTIFICATION:\n');
  
  rl.question('Tên sự kiện: ', (eventName) => {
    rl.question('Thời gian nhắc (ví dụ: 2 ngày trước): ', (reminderTime) => {
      
      const message = {
        token: FCM_TOKEN,
        notification: {
          title: '🔔 Nhắc nhở sự kiện',
          body: `${eventName} - ${reminderTime} sự kiện`,
        },
        data: {
          type: 'reminder',
          eventId: 'custom-test-' + Date.now(),
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
      
      console.log('\n📤 Đang gửi notification...');
      
      admin.messaging().send(message)
        .then((response) => {
          console.log('✅ Gửi thành công!');
          console.log('Response:', response);
          console.log('\n🎉 Kiểm tra điện thoại!');
          rl.close();
          process.exit(0);
        })
        .catch((error) => {
          console.error('❌ Lỗi:', error.message);
          rl.close();
          process.exit(1);
        });
    });
  });
}

sendCustomNotification();
