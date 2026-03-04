# 🚀 HƯỚNG DẪN DEPLOY FLUTTER WEB LÊN FIREBASE HOSTING

## 🎯 Tổng quan

Deploy CG Calendar lên web công khai với:
- ✅ **Firebase Hosting** (miễn phí)
- ✅ **HTTPS/SSL** (tự động)
- ✅ **CDN global** (tốc độ cao)
- ✅ **Custom domain** (optional)

---

## 📋 BƯỚC 1: BUILD FLUTTER WEB

```bash
cd D:\Documents\CG_Calendar\cg_calendar
flutter build web --release
```

**Output:** `build/web/` folder chứa static files

---

## 📋 BƯỚC 2: CẤU HÌNH FIREBASE HOSTING

### 2.1. Kiểm tra firebase.json

File `firebase.json` phải có cấu hình hosting:

```json
{
  "hosting": {
    "public": "build/web",
    "ignore": [
      "firebase.json",
      "**/.*",
      "**/node_modules/**"
    ],
    "rewrites": [
      {
        "source": "**",
        "destination": "/index.html"
      }
    ]
  }
}
```

### 2.2. Tạo .firebaserc (nếu chưa có)

```json
{
  "projects": {
    "default": "cgcalendar-2026"
  }
}
```

---

## 📋 BƯỚC 3: DEPLOY LÊN FIREBASE HOSTING

### 3.1. Login Firebase (nếu chưa)

```bash
firebase login
```

### 3.2. Initialize Hosting (nếu chưa)

```bash
firebase init hosting
```

**Chọn:**
- Use existing project: `cgcalendar-2026`
- Public directory: `build/web`
- Single-page app: `Yes`
- Automatic builds with GitHub: `No` (có thể setup sau)

### 3.3. Deploy!

```bash
firebase deploy --only hosting
```

**Kết quả:**
```
✔  Deploy complete!

Project Console: https://console.firebase.google.com/project/cgcalendar-2026/overview
Hosting URL: https://cgcalendar-2026.web.app
```

---

## 🌐 BƯỚC 4: TRUY CẬP WEB APP

Sau khi deploy thành công, app sẽ có 2 URLs:

1. **Firebase subdomain:**
   - `https://cgcalendar-2026.web.app`
   - `https://cgcalendar-2026.firebaseapp.com`

2. **Custom domain** (optional - xem bước 5)

---

## 🔧 BƯỚC 5: SETUP CUSTOM DOMAIN (OPTIONAL)

### 5.1. Mở Firebase Console

```
https://console.firebase.google.com/project/cgcalendar-2026/hosting/main
```

### 5.2. Click "Add custom domain"

1. Nhập domain của bạn (ví dụ: `cgcalendar.com`)
2. Firebase sẽ cung cấp DNS records
3. Thêm records vào domain provider (GoDaddy, Namecheap, etc.)
4. Đợi DNS propagation (~24h)

### 5.3. Firebase tự động cấp SSL/HTTPS miễn phí!

---

## 🔐 BƯỚC 6: CẤU HÌNH FIREBASE AUTH CHO WEB

### 6.1. Thêm domain vào Firebase Auth

1. Mở Firebase Console → Authentication → Settings
2. Tab **"Authorized domains"**
3. Thêm domains:
   ```
   cgcalendar-2026.web.app
   cgcalendar-2026.firebaseapp.com
   [your-custom-domain.com]  # Nếu có
   localhost  # Cho development
   ```

### 6.2. Cấu hình Google Sign-In (nếu dùng)

1. Firebase Console → Authentication → Sign-in method → Google
2. **Web SDK configuration** → Copy Client ID
3. Thêm vào `web/index.html`:

```html
<head>
  <!-- ... other tags ... -->
  <meta name="google-signin-client_id" content="YOUR_CLIENT_ID.apps.googleusercontent.com">
</head>
```

4. **Authorized JavaScript origins:**
   - `https://cgcalendar-2026.web.app`
   - `https://cgcalendar-2026.firebaseapp.com`
   - `http://localhost` (development)

5. **Authorized redirect URIs:**
   - `https://cgcalendar-2026.web.app/__/auth/handler`
   - `https://cgcalendar-2026.firebaseapp.com/__/auth/handler`

---

## 🔄 BƯỚC 7: UPDATE APP (KHI CÓ THAY ĐỔI)

### 7.1. Build lại

```bash
flutter build web --release
```

### 7.2. Deploy lại

```bash
firebase deploy --only hosting
```

**Cực nhanh!** Chỉ mất ~30 giây.

---

## 📊 GIÁM SÁT & PHÂN TÍCH

### Xem thống kê truy cập

Firebase Console → Hosting → Usage tab

- Bandwidth used
- Requests count
- Response times
- Error rates

### Xem logs

```bash
firebase hosting:channel:list
```

---

## 💰 CHI PHÍ

### Firebase Hosting - Free Tier (Spark Plan)

| Resource | Free Tier | Vượt quá |
|----------|-----------|----------|
| Storage | 10 GB | $0.026/GB/month |
| Transfer | 360 MB/day | $0.15/GB |
| Custom domains | Unlimited | Free |
| SSL certificates | Automatic | Free |

**Dự án CG Calendar:**
- Build size: ~2-5 MB
- Storage: < 100 MB
- Users: < 1000/day
- **→ HOÀN TOÀN MIỄN PHÍ!** ✅

---

## 🛠️ TROUBLESHOOTING

### Lỗi: "You are not authorized to access this project"

```bash
firebase login --reauth
firebase use cgcalendar-2026
```

### Lỗi: "Failed to get Firebase project"

```bash
firebase projects:list
firebase use --add
```

### Lỗi: Google Sign-In không hoạt động trên web

1. Kiểm tra Client ID trong `web/index.html`
2. Kiểm tra Authorized domains trong Firebase Console
3. Clear browser cache và thử lại

### Lỗi: Firestore permissions denied

- Kiểm tra `firestore.rules` đã deploy chưa:
  ```bash
  firebase deploy --only firestore:rules
  ```

---

## 🎯 CHECKLIST DEPLOY

### Trước khi deploy:
- [ ] `flutter build web --release` thành công
- [ ] Test locally: `flutter run -d chrome`
- [ ] Firebase project đã setup
- [ ] `firebase.json` đã cấu hình đúng

### Sau khi deploy:
- [ ] Truy cập URL và test
- [ ] Test authentication (login/logout)
- [ ] Test CRUD operations (create/read/update/delete events)
- [ ] Test trên mobile browser (responsive)
- [ ] Test trên các browsers khác (Chrome, Firefox, Safari, Edge)
- [ ] Thêm authorized domains vào Firebase Auth
- [ ] Setup Google Analytics (optional)

---

## 🚀 AUTOMATIC DEPLOYMENT (ADVANCED)

### Setup GitHub Actions

Tự động deploy khi push code lên GitHub:

1. **Create GitHub repository**
2. **Add GitHub Actions workflow**

`.github/workflows/deploy.yml`:

```yaml
name: Deploy to Firebase Hosting

on:
  push:
    branches:
      - main

jobs:
  build_and_deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.38.9'
      
      - run: flutter pub get
      - run: flutter build web --release
      
      - uses: FirebaseExtended/action-hosting-deploy@v0
        with:
          repoToken: '${{ secrets.GITHUB_TOKEN }}'
          firebaseServiceAccount: '${{ secrets.FIREBASE_SERVICE_ACCOUNT }}'
          channelId: live
          projectId: cgcalendar-2026
```

3. **Add Firebase service account secret to GitHub**

---

## 📱 ALTERNATIVE HOSTING OPTIONS

### 1. Vercel (Miễn phí, nhanh)
```bash
npm install -g vercel
vercel --prod
```

### 2. Netlify (Miễn phí)
```bash
npm install -g netlify-cli
netlify deploy --prod --dir=build/web
```

### 3. GitHub Pages (Miễn phí)
```bash
flutter build web --base-href "/repo-name/"
# Push build/web to gh-pages branch
```

### 4. Cloudflare Pages (Miễn phí, tốc độ cao)
- Connect GitHub repo
- Auto-deploy on push

---

## 🎉 HOÀN TẤT!

App của bạn đã live trên internet!

**Share link với team:**
```
https://cgcalendar-2026.web.app
```

**Tính năng:**
- ✅ Authentication (Email/Password, Google, Apple)
- ✅ Calendar management
- ✅ Event CRUD
- ✅ Reminders (push notifications via FCM)
- ✅ Finance tracking
- ✅ Role-based access control
- ✅ Responsive UI
- ✅ Dark mode
- ✅ Real-time sync

**Enjoy! 🎊**
