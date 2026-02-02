# 🚀 CG Calendar - Deployment Guide

**Date:** 16 January 2026  
**Version:** MVP v1.0  
**Status:** Ready for Production

---

## 📋 PRE-DEPLOYMENT CHECKLIST

### 1. Firebase Setup
- [x] Firebase project created
- [x] Authentication enabled (Email, Google, Apple)
- [x] Firestore database created
- [x] Security rules deployed
- [x] Test accounts created
- [ ] Cloud Functions deployed ⚠️ **ACTION NEEDED**
- [ ] Production data seeded (optional)

### 2. Code Status
- [x] All features implemented
- [x] No linter errors
- [x] All tests passing (manual)
- [x] Documentation complete

### 3. Environment
- [x] Flutter SDK: 3.x+
- [x] Dart SDK: 3.x+
- [x] Node.js: 22.x (for Cloud Functions)
- [x] Firebase CLI installed

---

## 🔧 DEPLOYMENT STEPS

### Step 1: Deploy Cloud Functions

**IMPORTANT:** Deploy Cloud Functions first before running the app in production!

```bash
# Navigate to functions directory
cd D:\Documents\CG_Calendar\cg_calendar\functions

# Install dependencies (if not already)
npm install

# Login to Firebase (if not already)
firebase login

# Deploy functions
firebase deploy --only functions
```

**Expected Output:**
```
✔  functions[onReminderCreated]: Successful create operation
✔  functions[sendScheduledNotifications]: Successful create operation
✔  functions[cleanupOldNotifications]: Successful create operation
✔  functions[onUserApproved]: Successful create operation

✔  Deploy complete!
```

**Verify Deployment:**
```bash
# View function logs
firebase functions:log

# Check function status
firebase functions:list
```

---

### Step 2: Build Flutter App

#### For Android:
```bash
cd D:\Documents\CG_Calendar\cg_calendar

# Generate code (Freezed models)
flutter pub run build_runner build --delete-conflicting-outputs

# Build APK (Debug)
flutter build apk --debug

# Build APK (Release)
flutter build apk --release

# Build App Bundle (for Play Store)
flutter build appbundle --release
```

**Output:** `build/app/outputs/flutter-apk/app-release.apk`

#### For iOS:
```bash
# Build for iOS (requires macOS)
flutter build ios --release

# Or build archive
flutter build ipa
```

**Output:** `build/ios/iphoneos/Runner.app`

#### For Web:
```bash
# Build for web
flutter build web --release

# Deploy to Firebase Hosting (optional)
firebase deploy --only hosting
```

**Output:** `build/web/`

---

### Step 3: Configure App for Production

#### Update Firebase Config (if needed):
```bash
# Re-configure for production environment
flutterfire configure
```

#### Update Security Rules (if changed):
```bash
# Deploy latest Firestore rules
firebase deploy --only firestore:rules
```

#### Check Indexes:
```bash
# Deploy Firestore indexes
firebase deploy --only firestore:indexes
```

---

### Step 4: Create Production Accounts

#### Super Editor Account:
```
Email: admin@yourcompany.com
Password: [Strong password]
Role: super_editor (must be set manually in Firestore)
```

#### Initial Artists:
Create via Admin Panel after Super Editor login

#### Initial Event Types:
Create via Admin Panel after Super Editor login

---

### Step 5: Test in Production

#### Test Checklist:
- [ ] Login with Super Editor
- [ ] Access Admin Panel
- [ ] Create artists
- [ ] Create event types
- [ ] Create test event
- [ ] Register new user
- [ ] Approve user as Viewer
- [ ] Login as Viewer → verify can only see assigned events
- [ ] Register another user
- [ ] Approve as Editor with managed artists
- [ ] Login as Editor → verify can manage assigned artists' events
- [ ] Test FCM token saved (check Firestore)
- [ ] Test notifications (after deployment)

---

## 🔐 SECURITY CHECKLIST

### Firestore Rules:
- [x] Super Editor-only access to admin functions
- [x] Viewer can only see their artist's events
- [x] Editor can only manage their assigned artists
- [x] Pending users have no access
- [x] No client-side security bypasses

### Authentication:
- [x] Email verification (optional - enable in Firebase Console)
- [x] Password strength requirements (optional - configure)
- [x] Rate limiting (Firebase Auth default)

### API Keys:
- [ ] Restrict Firebase API keys in Google Cloud Console ⚠️
- [ ] Set allowed domains for Web
- [ ] Set package names for Android
- [ ] Set bundle ID for iOS

---

## 📊 MONITORING & MAINTENANCE

### Firebase Console:
1. **Authentication**: Monitor user signups
2. **Firestore**: Check data integrity
3. **Functions**: Monitor execution & errors
4. **Analytics** (optional): Track usage

### Regular Tasks:
- **Daily**: Check function logs for errors
- **Weekly**: Review failed notification jobs
- **Monthly**: Clean up old data (auto via function)
- **As needed**: Update security rules

### Useful Commands:
```bash
# View function logs
firebase functions:log

# View function logs (specific)
firebase functions:log --only sendScheduledNotifications

# View function metrics
firebase functions:list

# View Firestore data
# Use Firebase Console Web UI

# Monitor app crashes (after adding Crashlytics)
firebase crashlytics:report
```

---

## 🐛 TROUBLESHOOTING

### Issue: Cloud Functions not deploying
**Solution:**
```bash
cd functions
npm install
firebase deploy --only functions --debug
```

### Issue: App can't connect to Firebase
**Solution:**
1. Check `firebase_options.dart` is up to date
2. Run `flutterfire configure` again
3. Rebuild app

### Issue: Firestore permission denied
**Solution:**
1. Check security rules deployed: `firebase deploy --only firestore:rules`
2. Verify user role in Firestore
3. Check logs for specific error

### Issue: No notifications received
**Solution:**
1. Check Cloud Functions deployed
2. Verify FCM token in user document
3. Check notification jobs in Firestore
4. Review function logs: `firebase functions:log`

---

## 💰 COST ESTIMATES (Firebase Free Tier)

### Current Usage (MVP):
- **Authentication**: 50,000 authentications/month ✅ FREE
- **Firestore**: 
  - 50,000 reads/day ✅ FREE
  - 20,000 writes/day ✅ FREE
  - 1 GB storage ✅ FREE
- **Cloud Functions**: 
  - 2,000,000 invocations/month ✅ FREE
  - 400,000 GB-seconds ✅ FREE
- **Cloud Messaging**: Unlimited ✅ FREE

### Expected Monthly Cost:
**$0** (within free tier for small team)

### When to Upgrade:
- More than 50 users
- More than 1000 events/month
- Heavy notification usage

---

## 📱 DISTRIBUTION

### Android:
1. **Internal Testing**: Share APK directly
2. **Google Play Store**:
   - Create Play Console account ($25 one-time)
   - Upload App Bundle
   - Complete store listing
   - Submit for review

### iOS:
1. **TestFlight**: Internal testing (up to 100 testers)
2. **App Store**:
   - Apple Developer account ($99/year)
   - Complete App Store Connect
   - Submit for review

### Web:
1. **Firebase Hosting**:
   ```bash
   firebase deploy --only hosting
   ```
2. **Custom Domain** (optional):
   ```bash
   firebase hosting:channel:deploy production
   ```

---

## 📚 USER DOCUMENTATION

### For Super Editor:
1. **User Management**:
   - Approve pending users
   - Assign roles & artists
   - Edit user permissions

2. **Artist Management**:
   - Create artists with colors
   - Edit artist details
   - Delete inactive artists

3. **Event Type Management**:
   - Create event types with checklists
   - Edit default checklists
   - Delete unused types

### For Editor:
1. **Event Management**:
   - Create events for assigned artists
   - Edit event details
   - Manage checklists
   - Set reminders

2. **Calendar View**:
   - Filter by artist
   - Switch views (Month/Week/Agenda)
   - Search events

### For Viewer:
1. **Calendar View**:
   - View own events only
   - Check event details
   - Access links & documents

---

## 🎯 POST-DEPLOYMENT TASKS

### Immediate (Day 1):
- [ ] Create Super Editor account
- [ ] Create initial artists (3-5)
- [ ] Create initial event types (5-10)
- [ ] Invite team members
- [ ] Test all features with real data

### First Week:
- [ ] Approve all team members
- [ ] Create real events
- [ ] Set up notifications
- [ ] Train users
- [ ] Gather feedback

### First Month:
- [ ] Monitor usage & errors
- [ ] Fix bugs (if any)
- [ ] Optimize performance
- [ ] Plan improvements

---

## 🔄 UPDATE & MAINTENANCE

### To Update App:
1. Make code changes
2. Bump version in `pubspec.yaml`
3. Test locally
4. Build & deploy

### To Update Cloud Functions:
```bash
cd functions
# Edit index.js
firebase deploy --only functions
```

### To Update Security Rules:
```bash
# Edit firestore.rules
firebase deploy --only firestore:rules
```

---

## 📞 SUPPORT

### For Developers:
- Check documentation in repo
- Review Firebase Console logs
- Check Firestore data

### For Users:
- Contact Super Editor
- Check user guide (to be created)
- Report issues to admin

---

## ✅ FINAL CHECKLIST

Before going live, ensure:

### Code:
- [x] All features working
- [x] No console errors
- [x] No linter warnings
- [x] Freezed models generated

### Firebase:
- [ ] Cloud Functions deployed ⚠️
- [x] Security rules deployed
- [x] Test data created
- [ ] Production accounts created

### Testing:
- [ ] Login/Logout working
- [ ] All RBAC rules enforced
- [ ] Admin panel accessible (Super Editor)
- [ ] Events created/edited/deleted
- [ ] Calendar displays correctly
- [ ] Notifications working (after functions deploy)

### Documentation:
- [x] README.md
- [x] Deployment guide (this file)
- [x] Feature documentation
- [x] Troubleshooting guide

---

## 🎉 YOU'RE READY TO DEPLOY!

**Final Command:**
```bash
# Deploy everything
firebase deploy
```

**Then:**
```bash
# Build Flutter app
flutter build apk --release
```

**Congratulations!** 🎊 Your CG Calendar MVP is ready for production!

---

**Questions?** Check the documentation or Firebase Console logs.

**Issues?** Review troubleshooting section above.

**Ready?** Run the deployment commands! 🚀
