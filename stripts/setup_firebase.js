

const admin = require('firebase-admin');
const readline = require('readline');

// ============================================
// CONFIGURATION
// ============================================

// Service Account Key path (download từ Firebase Console)
// Project Settings → Service Accounts → Generate new private key
const SERVICE_ACCOUNT_PATH = './serviceAccountKey.json';

// Test Accounts
const TEST_ACCOUNTS = [
  {
    email: 'viewer@gmail.com',
    password: 'Abcd123@',
    role: 'viewer',
    displayName: 'Test Viewer',
  },
  {
    email: 'editor@gmail.com',
    password: 'Abcd123@',
    role: 'editor',
    displayName: 'Test Editor',
    managedArtistIds: [], // Sẽ được set sau khi tạo artists
  },
  {
    email: 'supereditor@gmail.com',
    password: 'Abcd123@',
    role: 'super_editor',
    displayName: 'Test Super Editor',
  },
];

// ============================================
// SAMPLE DATA
// ============================================

const SAMPLE_ARTISTS = [
  {
    name: 'John Doe',
    colorHex: '#10b981', // Emerald
    avatarUrl: null,
    bio: 'Pop singer and songwriter',
    phoneNumber: '+84901234567',
    isActive: true,
  },
  {
    name: 'Jane Smith',
    colorHex: '#f59e0b', // Amber
    avatarUrl: null,
    bio: 'R&B artist',
    phoneNumber: '+84901234568',
    isActive: true,
  },
  {
    name: 'Mike Johnson',
    colorHex: '#8b5cf6', // Violet
    avatarUrl: null,
    bio: 'Hip-hop rapper',
    phoneNumber: '+84901234569',
    isActive: true,
  },
  {
    name: 'Sarah Williams',
    colorHex: '#ec4899', // Pink
    avatarUrl: null,
    bio: 'Jazz vocalist',
    phoneNumber: '+84901234570',
    isActive: true,
  },
  {
    name: 'David Lee',
    colorHex: '#3b82f6', // Blue
    avatarUrl: null,
    bio: 'Rock guitarist',
    phoneNumber: '+84901234571',
    isActive: true,
  },
];

const SAMPLE_EVENT_TYPES = [
  {
    name: 'Biểu diễn',
    description: 'Sự kiện biểu diễn trực tiếp',
    iconName: 'mic',
    defaultChecklistItems: [
      'Chuẩn bị trang phục',
      'Soundcheck',
      'Makeup',
      'Kiểm tra thiết bị',
    ],
    customFieldTemplates: [],
    isActive: true,
  },
  {
    name: 'Livestream',
    description: 'Livestream trên mạng xã hội',
    iconName: 'videocam',
    defaultChecklistItems: [
      'Setup camera',
      'Kiểm tra internet',
      'Chuẩn bị nội dung',
      'Test stream',
    ],
    customFieldTemplates: [
      {
        key: 'platform',
        label: 'Platform',
        fieldType: 'text',
        isRequired: true,
      },
      {
        key: 'duration',
        label: 'Thời lượng (phút)',
        fieldType: 'number',
        isRequired: false,
      },
    ],
    isActive: true,
  },
  {
    name: 'Chụp hình',
    description: 'Photoshoot cho album/promo',
    iconName: 'camera_alt',
    defaultChecklistItems: [
      'Chuẩn bị trang phục',
      'Makeup',
      'Kiểm tra concept',
      'Location scouting',
    ],
    customFieldTemplates: [
      {
        key: 'photographer',
        label: 'Photographer',
        fieldType: 'text',
        isRequired: true,
      },
      {
        key: 'concept',
        label: 'Concept',
        fieldType: 'text',
        isRequired: false,
      },
    ],
    isActive: true,
  },
  {
    name: 'Họp nhãn',
    description: 'Meeting với label/management',
    iconName: 'groups',
    defaultChecklistItems: [
      'Chuẩn bị tài liệu',
      'Agenda review',
      'Questions list',
    ],
    customFieldTemplates: [],
    isActive: true,
  },
  {
    name: 'Travel',
    description: 'Di chuyển/du lịch',
    iconName: 'flight',
    defaultChecklistItems: [
      'Book flight',
      'Book hotel',
      'Visa (nếu cần)',
      'Packing list',
    ],
    customFieldTemplates: [
      {
        key: 'destination',
        label: 'Destination',
        fieldType: 'text',
        isRequired: true,
      },
      {
        key: 'flight_number',
        label: 'Flight Number',
        fieldType: 'text',
        isRequired: false,
      },
    ],
    isActive: true,
  },
];

// ============================================
// HELPER FUNCTIONS
// ============================================

function getTimestamp() {
  return admin.firestore.Timestamp.now();
}

function getDateString(daysFromNow) {
  const date = new Date();
  date.setDate(date.getDate() + daysFromNow);
  return date.toISOString();
}

// ============================================
// MAIN FUNCTIONS
// ============================================

async function initializeFirebase() {
  try {
    const serviceAccount = require(SERVICE_ACCOUNT_PATH);
    
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });
    
    console.log('✅ Firebase Admin initialized');
    return true;
  } catch (error) {
    console.error('❌ Error initializing Firebase:', error.message);
    console.log('\n📝 Hướng dẫn:');
    console.log('1. Vào Firebase Console → Project Settings → Service Accounts');
    console.log('2. Click "Generate new private key"');
    console.log('3. Save file as "serviceAccountKey.json" trong thư mục này');
    return false;
  }
}

async function createTestAccounts() {
  console.log('\n👥 Creating test accounts...');
  
  const db = admin.firestore();
  const auth = admin.auth();
  
  for (const account of TEST_ACCOUNTS) {
    try {
      // Check if user already exists
      let user;
      try {
        user = await auth.getUserByEmail(account.email);
        console.log(`   ⚠️  User ${account.email} already exists, skipping...`);
      } catch (error) {
        // User doesn't exist, create new
        user = await auth.createUser({
          email: account.email,
          password: account.password,
          displayName: account.displayName,
          emailVerified: true,
        });
        console.log(`   ✅ Created user: ${account.email}`);
      }
      
      // Create/Update user document in Firestore
      const userData = {
        email: account.email,
        displayName: account.displayName,
        role: account.role,
        status: 'active',
        managedArtistIds: account.managedArtistIds || [],
        createdAt: getTimestamp(),
        updatedAt: getTimestamp(),
      };
      
      await db.collection('users').doc(user.uid).set(userData, { merge: true });
      console.log(`   ✅ Created user document: ${account.email} (${account.role})`);
      
    } catch (error) {
      console.error(`   ❌ Error creating ${account.email}:`, error.message);
    }
  }
  
  console.log('✅ Test accounts setup complete!\n');
}

async function createArtists() {
  console.log('🎤 Creating artists...');
  
  const db = admin.firestore();
  const artistIds = [];
  
  for (const artist of SAMPLE_ARTISTS) {
    try {
      const docRef = db.collection('artists').doc();
      const artistData = {
        ...artist,
        createdAt: getTimestamp(),
        updatedAt: getTimestamp(),
      };
      
      await docRef.set(artistData);
      artistIds.push(docRef.id);
      console.log(`   ✅ Created artist: ${artist.name} (${docRef.id})`);
    } catch (error) {
      console.error(`   ❌ Error creating artist ${artist.name}:`, error.message);
    }
  }
  
  console.log(`✅ Created ${artistIds.length} artists\n`);
  return artistIds;
}

async function createEventTypes() {
  console.log('📋 Creating event types...');
  
  const db = admin.firestore();
  const eventTypeIds = [];
  
  for (const eventType of SAMPLE_EVENT_TYPES) {
    try {
      const docRef = db.collection('event_types').doc();
      const eventTypeData = {
        ...eventType,
        createdAt: getTimestamp(),
        updatedAt: getTimestamp(),
      };
      
      await docRef.set(eventTypeData);
      eventTypeIds.push(docRef.id);
      console.log(`   ✅ Created event type: ${eventType.name} (${docRef.id})`);
    } catch (error) {
      console.error(`   ❌ Error creating event type ${eventType.name}:`, error.message);
    }
  }
  
  console.log(`✅ Created ${eventTypeIds.length} event types\n`);
  return eventTypeIds;
}

async function createEvents(artistIds, eventTypeIds, userIds) {
  console.log('📅 Creating sample events...');
  
  const db = admin.firestore();
  const superEditorId = userIds.find((_, i) => TEST_ACCOUNTS[i].role === 'super_editor');
  
  // Sample events
  const sampleEvents = [
    {
      title: 'Voice Training',
      description: 'Weekly voice training session',
      startTime: getDateString(5), // 5 days from now
      endTime: getDateString(5),
      location: 'Studio A',
      artistIds: [artistIds[0]], // John Doe
      eventTypeId: eventTypeIds[0], // Biểu diễn
      checklistItems: [
        { id: '1', title: 'Chuẩn bị trang phục', isCompleted: false },
        { id: '2', title: 'Soundcheck', isCompleted: false },
      ],
      customFields: {},
      links: [],
      notes: 'Focus on breathing techniques',
      createdBy: superEditorId,
    },
    {
      title: 'Promo Photoshoot',
      description: 'Album cover photoshoot',
      startTime: getDateString(7),
      endTime: getDateString(7),
      location: 'Downtown Loft',
      artistIds: [artistIds[1], artistIds[2]], // Jane & Mike
      eventTypeId: eventTypeIds[2], // Chụp hình
      checklistItems: [
        { id: '1', title: 'Chuẩn bị trang phục', isCompleted: false },
        { id: '2', title: 'Makeup', isCompleted: false },
      ],
      customFields: {
        photographer: 'John Smith',
        concept: 'Urban style',
      },
      links: [],
      notes: '',
      createdBy: superEditorId,
    },
    {
      title: 'Livestream Concert',
      description: 'Online concert on YouTube',
      startTime: getDateString(10),
      endTime: getDateString(10),
      location: 'Home Studio',
      artistIds: [artistIds[0], artistIds[3]], // John & Sarah
      eventTypeId: eventTypeIds[1], // Livestream
      checklistItems: [
        { id: '1', title: 'Setup camera', isCompleted: false },
        { id: '2', title: 'Kiểm tra internet', isCompleted: false },
      ],
      customFields: {
        platform: 'YouTube',
        duration: 60,
      },
      links: [
        { id: '1', title: 'Stream Link', url: 'https://youtube.com/live/...', type: 'other' },
      ],
      notes: '',
      createdBy: superEditorId,
    },
    {
      title: 'Flight to LAX',
      description: 'Travel to Los Angeles',
      startTime: getDateString(12),
      endTime: getDateString(12),
      location: 'Airport',
      artistIds: [artistIds[0]], // John Doe
      eventTypeId: eventTypeIds[4], // Travel
      checklistItems: [
        { id: '1', title: 'Book flight', isCompleted: true },
        { id: '2', title: 'Book hotel', isCompleted: false },
      ],
      customFields: {
        destination: 'Los Angeles',
        flight_number: 'VN123',
      },
      links: [],
      notes: 'Business class',
      createdBy: superEditorId,
    },
    {
      title: 'Meeting with Label',
      description: 'Quarterly review meeting',
      startTime: getDateString(3),
      endTime: getDateString(3),
      location: 'CG Management Office',
      artistIds: [artistIds[1], artistIds[2], artistIds[3]], // Jane, Mike, Sarah
      eventTypeId: eventTypeIds[3], // Họp nhãn
      checklistItems: [
        { id: '1', title: 'Chuẩn bị tài liệu', isCompleted: false },
        { id: '2', title: 'Agenda review', isCompleted: false },
      ],
      customFields: {},
      links: [],
      notes: '',
      createdBy: superEditorId,
    },
  ];
  
  // Adjust endTime to be 3 hours after startTime
  for (const event of sampleEvents) {
    const start = new Date(event.startTime);
    start.setHours(start.getHours() + 3);
    event.endTime = start.toISOString();
  }
  
  let count = 0;
  for (const event of sampleEvents) {
    try {
      const docRef = db.collection('events').doc();
      const eventData = {
        ...event,
        startTime: admin.firestore.Timestamp.fromDate(new Date(event.startTime)),
        endTime: admin.firestore.Timestamp.fromDate(new Date(event.endTime)),
        createdAt: getTimestamp(),
        updatedAt: getTimestamp(),
      };
      
      await docRef.set(eventData);
      count++;
      console.log(`   ✅ Created event: ${event.title}`);
    } catch (error) {
      console.error(`   ❌ Error creating event ${event.title}:`, error.message);
    }
  }
  
  console.log(`✅ Created ${count} events\n`);
}

async function updateEditorManagedArtists(artistIds) {
  console.log('👔 Updating Editor managed artists...');
  
  const db = admin.firestore();
  const auth = admin.auth();
  
  try {
    // Get editor user
    const editor = await auth.getUserByEmail('editor@gmail.com');
    
    // Assign first 2 artists to editor
    await db.collection('users').doc(editor.uid).update({
      managedArtistIds: artistIds.slice(0, 2), // First 2 artists
      updatedAt: getTimestamp(),
    });
    
    console.log(`   ✅ Editor now manages: ${artistIds.slice(0, 2).length} artists\n`);
  } catch (error) {
    console.error(`   ❌ Error updating editor:`, error.message);
  }
}

async function updateViewerArtist(artistIds) {
  console.log('🎤 Linking Viewer to artist...');

  const db = admin.firestore();
  const auth = admin.auth();

  try {
    // Link viewer to first artist (for demo)
    const viewer = await auth.getUserByEmail('viewer@gmail.com');

    await db.collection('users').doc(viewer.uid).update({
      artistId: artistIds[0],
      updatedAt: getTimestamp(),
    });

    console.log(`   ✅ Viewer linked to artistId: ${artistIds[0]}\n`);
  } catch (error) {
    console.error(`   ❌ Error linking viewer to artist:`, error.message);
  }
}

// ============================================
// MAIN EXECUTION
// ============================================

async function main() {
  console.log('🚀 CG Calendar - Firebase Setup Script');
  console.log('=====================================\n');
  
  // Initialize Firebase
  const initialized = await initializeFirebase();
  if (!initialized) {
    process.exit(1);
  }
  
  try {
    // 1. Create test accounts
    await createTestAccounts();
    
    // 2. Get user IDs for events
    const auth = admin.auth();
    const userIds = [];
    for (const account of TEST_ACCOUNTS) {
      try {
        const user = await auth.getUserByEmail(account.email);
        userIds.push(user.uid);
      } catch (error) {
        console.error(`Error getting user ${account.email}:`, error.message);
      }
    }
    
    // 3. Create artists
    const artistIds = await createArtists();
    
    // 4. Create event types
    const eventTypeIds = await createEventTypes();
    
    // 5. Update editor + viewer with managed artists / artistId
    await updateEditorManagedArtists(artistIds);
    await updateViewerArtist(artistIds);
    
    // 6. Create events
    await createEvents(artistIds, eventTypeIds, userIds);
    
    console.log('🎉 Setup complete!');
    console.log('\n📝 Test Accounts:');
    console.log('   Viewer: viewer@gmail.com / Abcd123@');
    console.log('   Editor: editor@gmail.com / Abcd123@');
    console.log('   Super Editor: supereditor@gmail.com / Abcd123@');
    console.log('\n✅ All data has been created in Firebase!');
    
  } catch (error) {
    console.error('❌ Error during setup:', error);
  } finally {
    process.exit(0);
  }
}

// Run script
main();

