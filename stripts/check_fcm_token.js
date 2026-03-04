/**
 * Script để lấy FCM Token từ Firestore
 */

const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://cg-calendar-9c69d-default-rtdb.firebaseio.com'
});

const db = admin.firestore();

async function getFCMToken() {
  try {
    // Lấy user qlineenee@gmail.com
    const usersSnapshot = await db.collection('users')
      .where('email', '==', 'qlineenee@gmail.com')
      .limit(1)
      .get();
    
    if (usersSnapshot.empty) {
      console.log('❌ Không tìm thấy user');
      process.exit(1);
    }
    
    const userDoc = usersSnapshot.docs[0];
    const userData = userDoc.data();
    
    console.log('✅ User found:', userDoc.id);
    console.log('📧 Email:', userData.email);
    console.log('👤 Name:', userData.fullName);
    console.log('🔑 Role:', userData.role);
    
    if (userData.fcmToken) {
      console.log('\n🎯 FCM TOKEN:');
      console.log(userData.fcmToken);
      console.log('\n✅ Copy token này để test gửi notification!');
    } else {
      console.log('\n⚠️  FCM Token chưa được lưu vào Firestore');
      console.log('   Có thể FCM chưa được initialize hoặc có lỗi');
      console.log('\n💡 Giải pháp:');
      console.log('   1. Đóng và mở lại app');
      console.log('   2. Hoặc chạy: flutter run để xem logs chi tiết');
    }
    
  } catch (error) {
    console.error('❌ Lỗi:', error.message);
  }
  
  process.exit(0);
}

getFCMToken();
