# FreshPunk - Developer Handoff Package

> **Last Updated:** October 24, 2025  
> **Version:** 1.0.1+2  
> **Project Owner:** dleon  
> **Developer:** Stefan

---

## 📋 Quick Links

- **Repository:** https://github.com/leonovd-bit/flutter_application_1
- **Branch to Deploy:** `main`
- **Live Web App:** https://freshpunk-48db1.web.app
- **Firebase Console:** https://console.firebase.google.com/project/freshpunk-48db1/overview

---

## 🏗️ Tech Stack

### Frontend
- **Framework:** Flutter 3.8.1+ (Dart)
  - Multi-platform: Web, iOS, Android, Desktop (Windows/macOS)
- **State Management:** Provider
- **UI:** Material Design 3 with custom theming

### Backend & Services
- **Firebase Suite:**
  - **Firebase Auth** - User authentication (email/password, Google, Apple Sign-In)
  - **Cloud Firestore** - NoSQL database (users, meals, orders, subscriptions)
  - **Firebase Storage** - Image and asset storage
  - **Cloud Functions (Node.js 20)** - Serverless backend (region: us-east4)
  - **Firebase Hosting** - Web app hosting with SPA routing
  - **Firebase Messaging (FCM)** - Push notifications
  - **Firebase Data Connect** - GraphQL data layer

### Payment & Integrations
- **Stripe** - Payment processing and subscription management
  - Test Mode: `pk_test_*`
  - Live Mode: `pk_live_*`
- **Google Maps API** - Location services, geocoding, address autocomplete
- **DoorDash API** - Delivery integration (optional)

### Development Tools
- **Version Control:** Git + GitHub
- **CI/CD:** Firebase Hosting auto-deploy
- **Linting:** flutter_lints ^6.0.0
- **Environment:** flutter_dotenv for config management

---

## 📦 Project Structure

```
flutter_application_1/
├── lib/
│   ├── main.dart                    # App entry point
│   ├── app_v3/                      # Main app code (V3 architecture)
│   │   ├── pages/                   # UI screens
│   │   ├── services/                # Business logic & API clients
│   │   ├── models/                  # Data models
│   │   ├── widgets/                 # Reusable components
│   │   ├── theme/                   # Design system
│   │   └── config/                  # Environment & API configs
│   └── firebase_options.dart        # Firebase SDK config
├── functions/                        # Cloud Functions (Node.js)
│   ├── src/
│   │   └── index.ts                 # Stripe webhooks, callable functions
│   ├── package.json
│   └── tsconfig.json
├── firestore.rules                  # Firestore security rules
├── firestore.indexes.json           # Database indexes
├── firebase.json                    # Firebase project config
├── pubspec.yaml                     # Flutter dependencies
└── assets/
    ├── images/                      # App images
    ├── data/                        # JSON seed data
    └── .env                         # Environment variables (NOT in repo)
```

---

## 🔐 Environment Variables (.env.example)

**Create a `.env` file in the project root with these keys:**

```bash
# Firebase
FIREBASE_PROJECT_ID=
FIREBASE_API_KEY=
FIREBASE_AUTH_DOMAIN=
FIREBASE_STORAGE_BUCKET=
FIREBASE_MESSAGING_SENDER_ID=
FIREBASE_APP_ID=

# Stripe (https://dashboard.stripe.com/apikeys)
STRIPE_PUBLISHABLE_KEY_TEST=pk_test_
STRIPE_SECRET_KEY_TEST=sk_test_
STRIPE_PUBLISHABLE_KEY_LIVE=pk_live_
STRIPE_SECRET_KEY_LIVE=sk_live_
STRIPE_WEBHOOK_SECRET=whsec_

# Google Maps API (https://console.cloud.google.com/apis/credentials)
GOOGLE_MAPS_API_KEY_ANDROID=
GOOGLE_MAPS_API_KEY_IOS=
GOOGLE_MAPS_API_KEY_WEB=

# DoorDash (optional, for delivery integration)
DOORDASH_DEVELOPER_ID=
DOORDASH_KEY_ID=
DOORDASH_SIGNING_SECRET=

# Firebase Cloud Functions Region
CLOUD_FUNCTIONS_REGION=us-east4

# App Environment
ENVIRONMENT=development  # or 'production'
```

**Important:** These values are **not included** in the repository. You'll need to get them from:
- Firebase Console
- Stripe Dashboard
- Google Cloud Console
- DoorDash Developer Portal (if using)

---

## 🚀 Getting Started

### Prerequisites
```bash
# Install Flutter SDK
flutter doctor

# Install Node.js 20+ (for Cloud Functions)
node --version

# Install Firebase CLI
npm install -g firebase-tools
firebase login
```

### Setup Steps

1. **Clone the repository:**
   ```bash
   git clone https://github.com/leonovd-bit/flutter_application_1.git
   cd flutter_application_1
   git checkout main
   ```

2. **Install Flutter dependencies:**
   ```bash
   flutter pub get
   ```

3. **Create `.env` file:**
   ```bash
   # Copy the example and fill in your values
   cp .env.example .env
   ```

4. **Install Cloud Functions dependencies:**
   ```bash
   cd functions
   npm install
   cd ..
   ```

5. **Run the app locally:**
   ```bash
   # Web
   flutter run -d chrome

   # Desktop (Windows)
   flutter run -d windows

   # Mobile (with emulator running)
   flutter run -d <device-id>
   ```

6. **Deploy to Firebase:**
   ```bash
   # Build web
   flutter build web --release

   # Deploy hosting + functions
   firebase deploy --project freshpunk-48db1
   ```

---

## 🗄️ Database Schema (Firestore)

### Collections

#### `users`
```json
{
  "uid": "string",
  "email": "string",
  "displayName": "string",
  "photoURL": "string",
  "role": "user | admin | restaurant",
  "activeMealPlan": "string (plan ID)",
  "currentAddress": "map",
  "preferences": "map",
  "createdAt": "timestamp",
  "lastLogin": "timestamp"
}
```

#### `meals`
```json
{
  "id": "string",
  "name": "string",
  "description": "string",
  "category": "breakfast | lunch | dinner | snack",
  "imageUrl": "string",
  "calories": "number",
  "protein": "number",
  "carbs": "number",
  "fat": "number",
  "ingredients": ["array of strings"],
  "allergens": ["array of strings"],
  "dietaryTags": ["vegetarian", "vegan", "gluten-free", etc.],
  "price": "number",
  "available": "boolean"
}
```

#### `users/{uid}/subscriptions`
```json
{
  "id": "string",
  "stripeSubscriptionId": "string",
  "planId": "string",
  "planName": "string",
  "status": "active | paused | canceled",
  "monthlyAmount": "number",
  "currentPeriodStart": "timestamp",
  "currentPeriodEnd": "timestamp",
  "createdAt": "timestamp"
}
```

#### `users/{uid}/orders`
```json
{
  "id": "string",
  "userId": "string",
  "deliveryDate": "timestamp",
  "deliveryTime": "string",
  "meals": ["array of meal objects"],
  "totalPrice": "number",
  "status": "pending | confirmed | preparing | delivered | canceled",
  "address": "map",
  "createdAt": "timestamp"
}
```

#### `mealPlans`
```json
{
  "id": "string",
  "name": "string",
  "displayName": "string",
  "description": "string",
  "mealsPerDay": "number",
  "daysPerWeek": "number",
  "monthlyPrice": "number",
  "stripePriceId": "string",
  "features": ["array of strings"],
  "available": "boolean"
}
```

---

## 🔌 API Integrations

### Cloud Functions (Callable)
Located in `functions/src/index.ts`

#### Stripe Functions
- **`createSubscription`** - Create new Stripe subscription
- **`updateSubscription`** - Update subscription plan
- **`cancelSubscription`** - Cancel active subscription
- **`pauseSubscription`** - Pause subscription billing
- **`resumeSubscription`** - Resume paused subscription
- **`addPaymentMethod`** - Add payment method to customer
- **`setDefaultPaymentMethod`** - Set default payment method
- **`listPaymentMethods`** - Get customer payment methods

#### Admin Functions
- **`makeUserAdmin`** - Grant admin role (requires auth)
- **`ping`** - Health check endpoint

#### Webhooks
- **`stripeWebhook`** - Handle Stripe events (subscription updates, payments)

### Frontend Service Clients
- **`OrderFunctionsService`** - Wraps Cloud Functions calls
- **`FirestoreServiceV3`** - Database CRUD operations
- **`StripeService`** - Payment UI initialization
- **`FCMServiceV3`** - Push notification setup

---

## 🐛 Known Issues & Bugs

### High Priority
1. **Desktop Firebase Auth Reauthentication Timeout**
   - **Issue:** `reauthenticateWithCredential()` hangs indefinitely on Windows desktop
   - **Workaround:** Use web app for account deletion operations
   - **Status:** Timeout handler added (10s), user guided to web
   - **Fix Needed:** Investigate Firebase Auth desktop SDK or switch to web-only auth

2. **Meal Image Loading Performance**
   - **Issue:** Large meal images (>500KB) slow down home page load
   - **Workaround:** Assets preloaded; consider image optimization
   - **Status:** Tree-shaking reduces icon fonts by 98%
   - **Fix Needed:** Implement lazy loading or CDN with WebP format

### Medium Priority
3. **Admin Seed Functions Not Exposed**
   - **Issue:** Admin-only seed meal buttons commented out in settings
   - **Workaround:** Run seed scripts manually or via Firebase Console
   - **Status:** Code exists but hidden from UI for production cleanliness
   - **Fix Needed:** Create dedicated admin dashboard or CLI tool

4. **Cloud Functions Cold Start Latency**
   - **Issue:** First call after idle can take 5-10 seconds
   - **Workaround:** Keep functions warm with scheduled pings (not implemented)
   - **Status:** Acceptable for MVP; users see loading indicators
   - **Fix Needed:** Upgrade to Cloud Functions Gen 2 with min instances (costs money)

### Low Priority
5. **Missing Test Coverage**
   - **Issue:** No unit or widget tests implemented
   - **Status:** Manual testing only
   - **Fix Needed:** Add `flutter_test` suite for core services

6. **Linter Warnings (362 issues)**
   - **Issue:** Mostly `avoid_print`, `unused_import`, deprecation warnings
   - **Status:** App builds and runs fine; no blockers
   - **Fix Needed:** Clean up with `flutter analyze --no-fatal-infos` and fix

---

## 📊 Test Data Export

### Meals Data
**File:** `assets/data/meals.json`

Sample structure:
```json
[
  {
    "id": "meal_001",
    "name": "Chicken Caesar Salad",
    "description": "Fresh romaine lettuce with grilled chicken, parmesan, and Caesar dressing",
    "category": "lunch",
    "imageUrl": "assets/images/meals/chicken-caesar.jpg",
    "calories": 420,
    "protein": 35,
    "carbs": 12,
    "fat": 28,
    "ingredients": ["Romaine Lettuce", "Grilled Chicken", "Parmesan", "Caesar Dressing", "Croutons"],
    "allergens": ["dairy", "gluten"],
    "dietaryTags": ["high-protein"],
    "price": 12.99,
    "available": true
  }
]
```

### Users (Test Accounts)
**Admin Account:**
- Email: `admin@freshpunk.com`
- Password: (get from Stefan separately)
- Role: `admin`
- UID: `zXY2a1OsecVQmg3ghiyJBGSfuOM2`

**Test User:**
- Email: `test@example.com`
- Password: (get from Stefan separately)
- Role: `user`

### Meal Plans
```json
[
  {
    "id": "plan_nutritious_jr",
    "name": "NutritiousJr",
    "displayName": "Nutritious Jr.",
    "description": "Perfect for light eaters",
    "mealsPerDay": 2,
    "daysPerWeek": 5,
    "monthlyPrice": 199.99,
    "stripePriceId": "price_xxxxx",
    "features": ["2 meals/day", "5 days/week", "Balanced nutrition"],
    "available": true
  },
  {
    "id": "plan_diet_knight",
    "name": "DietKnight",
    "displayName": "Diet Knight",
    "description": "Our most popular plan",
    "mealsPerDay": 3,
    "daysPerWeek": 5,
    "monthlyPrice": 299.99,
    "stripePriceId": "price_yyyyy",
    "features": ["3 meals/day", "5 days/week", "Premium ingredients"],
    "available": true
  }
]
```

---

## 🔗 Required Access for Stefan

### GitHub
- **Repo:** https://github.com/leonovd-bit/flutter_application_1
- **Role:** Collaborator (Write access)
- **Action:** Invite Stefan to repository
  ```
  Settings → Collaborators → Add people → stefan@email.com
  ```

### Firebase
- **Project:** freshpunk-48db1
- **Role:** Editor or Owner
- **Action:** Add Stefan in Firebase Console
  ```
  Firebase Console → Project Settings → Users and permissions → Add member
  ```

### Stripe
- **Account:** FreshPunk Stripe Account
- **Role:** Developer
- **Action:** Invite Stefan in Stripe Dashboard
  ```
  Stripe Dashboard → Settings → Team → Invite teammate
  Permissions: View test data, View live data, Manage products
  ```

### Google Cloud Console (for Maps API)
- **Project:** freshpunk-48db1
- **Role:** Editor
- **Action:** Add Stefan in IAM
  ```
  Google Cloud Console → IAM & Admin → Add principal
  Role: Editor or Viewer (depending on needs)
  ```

---

## 🚢 Deployment Instructions

### Web Deployment (Firebase Hosting)
```bash
# 1. Build the web app
flutter build web --release

# 2. Deploy to Firebase Hosting
firebase deploy --only hosting --project freshpunk-48db1

# 3. Verify deployment
# Open: https://freshpunk-48db1.web.app
```

### Cloud Functions Deployment
```bash
# 1. Navigate to functions directory
cd functions

# 2. Install dependencies
npm install

# 3. Build TypeScript
npm run build

# 4. Deploy functions
firebase deploy --only functions --project freshpunk-48db1

# 5. Verify functions are live
firebase functions:list
```

### Mobile App Deployment (Future)
```bash
# Android
flutter build apk --release
# APK location: build/app/outputs/flutter-apk/app-release.apk

# iOS
flutter build ios --release
# Open ios/Runner.xcworkspace in Xcode and archive
```

---

## 📞 Support & Documentation

### Internal Documentation
- **Style Guide:** `FRESHPUNK_STYLE_GUIDE.md`
- **Development Guide:** `DEVELOPMENT_GUIDE.md`
- **Production Deployment:** `PRODUCTION_DEPLOYMENT_GUIDE.md`
- **Stripe Backend API:** `STRIPE_BACKEND_API.md`

### External Resources
- **Flutter Docs:** https://docs.flutter.dev
- **Firebase Docs:** https://firebase.google.com/docs
- **Stripe API:** https://stripe.com/docs/api
- **Google Maps Flutter:** https://pub.dev/packages/google_maps_flutter

### Contact
- **Project Owner:** dleon
- **Repository:** Issues tab on GitHub
- **Firebase Support:** Firebase Console → Support

---

## 🎯 Alternatives to Current Stack

### If you want to avoid Vercel/Supabase (currently NOT used):
✅ **Current stack already avoids these:**
- **Instead of Vercel:** Using **Firebase Hosting** (free tier, integrated with Firebase)
- **Instead of Supabase:** Using **Cloud Firestore** (NoSQL) + **Cloud Functions** (serverless backend)

### If you need to add these services:
- **Vercel:** Could host a separate Next.js admin dashboard (not currently in project)
- **Supabase:** Could replace Firestore with PostgreSQL (requires migration)

**Recommendation:** Stick with current Firebase stack—it's fully integrated, scalable, and already deployed.

---

## ✅ Handoff Checklist

- [ ] Stefan has GitHub repo access
- [ ] Stefan invited to Firebase project (Editor role)
- [ ] Stefan invited to Stripe account (Developer role)
- [ ] Stefan has Google Cloud Console access (for Maps API keys)
- [ ] Stefan has `.env` file with all secrets
- [ ] Stefan can run `flutter run -d chrome` successfully
- [ ] Stefan can deploy to Firebase Hosting
- [ ] Stefan has access to test accounts (admin + user)
- [ ] Stefan has reviewed known bugs list
- [ ] Stefan has read `DEVELOPMENT_GUIDE.md` and `PRODUCTION_DEPLOYMENT_GUIDE.md`

---

**🎉 Ready to Go!** If you have questions, create an issue in GitHub or reach out directly.
