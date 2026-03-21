/**
 * Script to check user data and permissions
 */

const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://cg-calendar-9c69d-default-rtdb.firebaseio.com'
});

const db = admin.firestore();

async function checkUserData() {
  try {
    // Get user qlineenee@gmail.com
    const usersSnapshot = await db.collection('users')
      .where('email', '==', 'qlineenee@gmail.com')
      .limit(1)
      .get();
    
    if (usersSnapshot.empty) {
      console.log('❌ User not found');
      process.exit(1);
    }
    
    const userDoc = usersSnapshot.docs[0];
    const userData = userDoc.data();
    
    console.log('\n' + '='.repeat(60));
    console.log('👤 USER DATA');
    console.log('='.repeat(60));
    console.log('ID:', userDoc.id);
    console.log('Email:', userData.email);
    console.log('Full Name:', userData.fullName || 'N/A');
    console.log('Role:', userData.role);
    console.log('Status:', userData.status);
    console.log('Artist ID:', userData.artistId || 'N/A');
    console.log('Managed Artist IDs:', userData.managedArtistIds || 'N/A');
    
    if (userData.managedArtistIds && userData.managedArtistIds.length > 0) {
      console.log('\n📋 MANAGED ARTISTS:');
      for (const artistId of userData.managedArtistIds) {
        const artistDoc = await db.collection('artists').doc(artistId).get();
        if (artistDoc.exists) {
          console.log(`  - ${artistDoc.data().name} (${artistId})`);
        } else {
          console.log(`  - ⚠️  Artist ${artistId} not found`);
        }
      }
    }
    
    console.log('\n' + '='.repeat(60));
    console.log('✅ Permissions Check:');
    console.log('='.repeat(60));
    
    if (userData.role === 'editor' && userData.status === 'active') {
      if (userData.managedArtistIds && userData.managedArtistIds.length > 0) {
        console.log('✅ User can create events for artists:', userData.managedArtistIds);
        console.log('\n💡 When creating an event, make sure to select one of these artists!');
      } else {
        console.log('❌ User has no managedArtistIds!');
        console.log('   Contact super_editor to assign artists to this user.');
      }
    } else {
      console.log(`⚠️  User role: ${userData.role}, status: ${userData.status}`);
      console.log('   User may not have permission to create events.');
    }
    
  } catch (error) {
    console.error('❌ Error:', error.message);
  }
  
  process.exit(0);
}

checkUserData();
