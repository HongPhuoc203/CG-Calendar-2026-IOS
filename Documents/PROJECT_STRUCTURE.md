# 📊 CG Calendar - Project Architecture

## 🏗️ Clean Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                    PRESENTATION LAYER                    │
│                  (UI + State Management)                 │
│                                                          │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐              │
│  │  Screens │  │  Widgets │  │ Providers│              │
│  └──────────┘  └──────────┘  └──────────┘              │
└─────────────────────────────────────────────────────────┘
                         ↕
┌─────────────────────────────────────────────────────────┐
│                      DATA LAYER                          │
│              (Repositories + Services)                   │
│                                                          │
│  ┌──────────────┐  ┌──────────────┐                     │
│  │ Repositories │  │  Services    │                     │
│  │  (Logic)     │  │ (Firebase)   │                     │
│  └──────────────┘  └──────────────┘                     │
└─────────────────────────────────────────────────────────┘
                         ↕
┌─────────────────────────────────────────────────────────┐
│                      MODELS LAYER                        │
│                  (Data Structures)                       │
│                                                          │
│  ┌──────────────────────────────────────┐              │
│  │  Freezed Models + JSON Serialization │              │
│  └──────────────────────────────────────┘              │
└─────────────────────────────────────────────────────────┘
                         ↕
┌─────────────────────────────────────────────────────────┐
│                   FIREBASE BACKEND                       │
│           (Firestore + Auth + Functions)                │
└─────────────────────────────────────────────────────────┘
```

---

## 📂 Detailed Folder Structure

```
cg_calendar/
│
├── lib/
│   │
│   ├── core/                           # Core utilities
│   │   ├── constants/
│   │   │   ├── app_constants.dart      # Collections, formats, limits
│   │   │   └── app_colors.dart         # Color palette
│   │   │
│   │   ├── enums/
│   │   │   ├── user_role.dart          # pending/viewer/editor/super_editor
│   │   │   ├── user_status.dart        # active/inactive/suspended
│   │   │   └── reminder_unit.dart      # minutes/hours/days
│   │   │
│   │   ├── utils/
│   │   │   └── date_utils.dart         # Timezone, formatting
│   │   │
│   │   └── errors/
│   │       └── failures.dart           # Custom exceptions
│   │
│   ├── data/                           # Data layer
│   │   │
│   │   ├── models/                     # Freezed models
│   │   │   ├── user_model.dart         # User profile
│   │   │   ├── artist_model.dart       # Artist info
│   │   │   ├── event_model.dart        # Event + checklist
│   │   │   ├── event_type_model.dart   # Event templates
│   │   │   ├── reminder_model.dart     # Reminder settings
│   │   │   └── notification_job_model.dart # Push queue
│   │   │
│   │   ├── repositories/               # Business logic
│   │   │   ├── user_repository.dart
│   │   │   ├── artist_repository.dart
│   │   │   ├── event_repository.dart
│   │   │   ├── event_type_repository.dart
│   │   │   └── reminder_repository.dart
│   │   │
│   │   └── services/                   # External services
│   │       ├── auth_service.dart       # Firebase Auth wrapper
│   │       └── firestore_service.dart  # Firestore wrapper
│   │
│   ├── providers/                      # Riverpod state management
│   │   ├── services_providers.dart     # Service instances
│   │   ├── repositories_providers.dart # Repository instances
│   │   ├── auth_provider.dart          # Auth state
│   │   ├── artists_provider.dart       # Artists state
│   │   ├── events_provider.dart        # Events state
│   │   ├── event_types_provider.dart   # Event types state
│   │   ├── reminders_provider.dart     # Reminders state
│   │   └── theme_provider.dart         # App theme
│   │
│   ├── presentation/                   # UI layer (Phase 2)
│   │   ├── auth/                       # Login, pending approval
│   │   ├── calendar/                   # Calendar views
│   │   ├── events/                     # Event CRUD
│   │   ├── admin/                      # User management
│   │   └── widgets/                    # Shared components
│   │
│   └── main.dart                       # App entry point
│
├── android/                            # Android platform
├── ios/                                # iOS platform
├── web/                                # Web platform
│
├── firestore.rules                     # Security rules ⚠️ CRITICAL
├── pubspec.yaml                        # Dependencies
├── SETUP_GUIDE.md                      # Setup instructions
└── PROJECT_STRUCTURE.md                # This file
```

---

## 🔄 Data Flow

### Example: Load Events for Calendar

```
1. UI (CalendarScreen)
   ↓ calls
2. Provider (eventsStreamProvider)
   ↓ watches
3. Repository (EventRepository)
   ↓ queries
4. Service (FirestoreService)
   ↓ fetches from
5. Firebase Firestore
   ↓ returns data
6. Model (EventModel.fromFirestore)
   ↓ maps to
7. Provider (updates state)
   ↓ notifies
8. UI (rebuilds with new data)
```

### Example: Create Event (with Permission Check)

```
1. UI (CreateEventScreen)
   ↓ user inputs data
2. Provider (currentUserProfileProvider)
   ↓ checks role
3. If Editor:
   - Check artistIds ∩ managedArtistIds ≠ ∅
4. Repository (EventRepository.createEvent)
   ↓ writes to
5. Firestore
   ↓ Security Rules validate
6. If valid:
   - Document created
   - Stream notifies listeners
7. UI updates automatically
```

---

## 🎯 Key Design Patterns

### 1. **Repository Pattern**
- Abstracts data access logic
- Single source of truth for each entity
- Example: `UserRepository`, `EventRepository`

### 2. **Provider Pattern (Riverpod)**
- Dependency injection
- State management
- Auto-dispose for memory efficiency

### 3. **Freezed Pattern**
- Immutable models
- CopyWith for updates
- JSON serialization
- Union types for state

### 4. **Stream-based Real-time Updates**
```dart
// Events update automatically when Firestore changes
final eventsStreamProvider = StreamProvider<List<EventModel>>((ref) {
  return eventRepository.streamEvents();
});
```

---

## 🔐 Security Architecture

### Three Layers of Security:

#### 1. **Client-side Validation (UI)**
- Hide/show buttons based on role
- Disable inputs for viewers
- Example: Hide "Edit" button if not editor

#### 2. **Application Logic (Repository)**
- Validate business rules
- Check permissions before write
- Example: Verify artistIds before update

#### 3. **Server-side Enforcement (Firestore Rules)** ⚠️ **MOST IMPORTANT**
- Final authority on permissions
- Cannot be bypassed by client
- Example:
```javascript
allow update: if hasRole('editor') 
              && canManageArtists(resource.data.artistIds)
```

> 🚨 **Never trust client-side checks alone!**
> Always enforce permissions in Firestore Rules.

---

## 📊 Database Schema

### Firestore Collections:

```
/users/{userId}
  - email: string
  - role: string (pending/viewer/editor/super_editor)
  - status: string (active/inactive/suspended)
  - managedArtistIds: array<string>
  - fcmToken: string
  - createdAt: timestamp
  - updatedAt: timestamp

/artists/{artistId}
  - name: string
  - colorHex: string
  - avatarUrl: string
  - isActive: boolean
  - createdAt: timestamp
  - updatedAt: timestamp

/events/{eventId}
  - title: string
  - description: string
  - startTime: timestamp
  - endTime: timestamp
  - location: string
  - artistIds: array<string>
  - eventTypeId: string
  - checklistItems: array<map>
  - customFields: map
  - links: array<map>
  - createdBy: string
  - createdAt: timestamp
  - updatedAt: timestamp

/event_types/{typeId}
  - name: string
  - description: string
  - iconName: string
  - defaultChecklistItems: array<string>
  - customFieldTemplates: array<map>
  - isActive: boolean
  - createdAt: timestamp
  - updatedAt: timestamp

/reminders/{reminderId}
  - eventId: string
  - value: number
  - unit: string (minutes/hours/days)
  - recipientUserIds: array<string>
  - triggerTime: timestamp
  - isSent: boolean
  - sentAt: timestamp
  - createdAt: timestamp

/notification_jobs/{jobId}
  - reminderId: string
  - eventId: string
  - eventTitle: string
  - recipientUserId: string
  - scheduledTime: timestamp
  - status: string (pending/sent/failed)
  - sentAt: timestamp
  - createdAt: timestamp
```

---

## 🔍 Firestore Indexes Required

```javascript
// Composite indexes needed:

// 1. Events by date range
collection: events
fields: [startTime (Ascending), __name__ (Ascending)]

// 2. Events by artists
collection: events
fields: [artistIds (Arrays), startTime (Ascending)]

// 3. Reminders by event
collection: reminders
fields: [eventId (Ascending), triggerTime (Ascending)]

// 4. Pending notification jobs
collection: notification_jobs
fields: [status (Ascending), scheduledTime (Ascending)]
```

> Firebase will prompt you to create these when you first run queries.

---

## 🧩 Provider Dependencies

```
themeProvider (no deps)
   ↓
authServiceProvider → authStateProvider
   ↓                        ↓
firestoreServiceProvider    currentUserIdProvider
   ↓                        ↓
[repositories]             currentUserProfileProvider
   ↓                        ↓
[entity providers]         canEditProvider, isSuperEditorProvider
```

---

## 📱 Screen Flow (Phase 2 - Not implemented yet)

```
SplashScreen
    ↓
AuthChecker
    ├─→ LoginScreen (if not authenticated)
    │       ├─→ EmailLoginScreen
    │       ├─→ GoogleSignIn
    │       └─→ AppleSignIn
    │
    └─→ RoleChecker (if authenticated)
            ├─→ PendingApprovalScreen (if role = pending)
            │
            └─→ MainScreen (if role != pending)
                    ├─→ CalendarView (Month/Week/Agenda)
                    │       └─→ EventDetailsScreen
                    │               ├─→ EditEventScreen (if canEdit)
                    │               └─→ ChecklistScreen
                    │
                    ├─→ CreateEventScreen (if canEdit)
                    │
                    └─→ AdminPanel (if isSuperEditor)
                            ├─→ UserManagementScreen
                            ├─→ ArtistManagementScreen
                            └─→ EventTypeManagementScreen
```

---

## 🎨 UI/UX Guidelines (Phase 2)

### Color Coding:
- **Pending**: Yellow/Orange
- **Viewer**: Green
- **Editor**: Blue
- **Super Editor**: Pink/Purple

### Calendar:
- Multi-artist events: Show first artist color + "+X" badge
- Filter panel: Multi-select chips with artist colors
- Past events: Slightly grayed out
- Today: Bold border

### Event Details:
- Checklist: Checkboxes (editable if canEdit)
- Links: Drive icon + clickable
- Artists: Avatar chips
- Reminders: Clock icon + time before event

---

## 🚀 Next Steps (Phase 2)

1. ✅ Setup project structure (DONE)
2. ✅ Create models and providers (DONE)
3. ✅ Write Firestore Rules (DONE)
4. ⏳ Build Authentication UI
5. ⏳ Build Calendar View
6. ⏳ Build Event CRUD
7. ⏳ Build Admin Panel
8. ⏳ Implement Push Notifications
9. ⏳ Testing & Bug Fixes
10. ⏳ Deploy to stores

---

**Current Status: Foundation Complete ✅**
**Ready for UI Development 🎨**

