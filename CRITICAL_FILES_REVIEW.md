# Critical Backend Files for Developer Review

## 🔴 IMMEDIATE SECURITY REVIEW (24-48 hours)

### 1. Firestore Security Rules
**File**: `firestore.rules`
**Issues**: Database access control and user data isolation
**Lines**: Entire file needs review
**Priority**: CRITICAL

### 2. Cloud Functions - Payment Processing  
**File**: `functions/src/index.ts`
**Critical Functions**:
- `stripeWebhook()` - Lines 700-800 (webhook signature verification)
- `createPaymentIntent()` - Lines 200-250 (payment validation)
- `createSubscription()` - Lines 300-350 (billing logic)
- `grantAdmin()` - Lines 750-780 (admin privilege escalation)

### 3. Stripe Service Integration
**File**: `lib/app_v3/services/stripe_service_v3.dart`
**Issues**: Client-side payment error handling and validation
**Priority**: HIGH

## 🟡 MEDIUM PRIORITY (1-2 weeks)

### 4. Firebase Client Services
**Files**:
- `lib/app_v3/services/meal_service_v3.dart` - Meal catalog management
- `lib/app_v3/services/order_service_v3.dart` - Order processing logic  
- `lib/app_v3/services/user_profile_service_v3.dart` - User data isolation
- `lib/app_v3/services/subscription_service_v3.dart` - Subscription lifecycle

### 5. Database Indexes and Performance
**File**: `firestore.indexes.json`
**Issues**: Query optimization and composite indexes
**Priority**: MEDIUM

### 6. Authentication Services
**Files**:
- `lib/app_v3/services/auth_service_v3.dart` - Main auth logic
- `lib/app_v3/services/offline_auth_service_v3.dart` - Offline fallback
- `lib/app_v3/services/admin_service.dart` - Admin verification

## 🟢 LOWER PRIORITY (Ongoing)

### 7. Configuration Files
**Files**:
- `firebase.json` - Hosting and functions configuration
- `lib/firebase_options.dart` - Client Firebase configuration
- `pubspec.yaml` - Dependencies and versions

### 8. Error Handling & Monitoring
**Files**: Throughout the codebase
**Focus**: Client-side error recovery and user experience

## 📋 Specific Code Sections Requiring Attention

### Stripe Webhook Security (URGENT)
```typescript
// functions/src/index.ts - stripeWebhook function
export const stripeWebhook = onRequest({...}, async (req, res) => {
  const sig = req.get('stripe-signature');
  // ❌ VERIFY: Is signature validation implemented?
  // ❌ CHECK: Event deduplication logic
  // ❌ REVIEW: Error handling and logging
});
```

### Admin Bootstrap Bypass (URGENT)
```typescript
// functions/src/index.ts - grantAdmin function  
const OWNER_EMAIL = "davleonovets@gmail.com";
const bootstrapAllowed = bootstrap === true && email === OWNER_EMAIL;
// ❌ REMOVE: This temporary bypass after setup
// ❌ IMPLEMENT: Proper admin invitation system
```

### Payment Error Handling (HIGH)
```dart
// lib/app_v3/services/stripe_service_v3.dart
// ❌ REVIEW: All try-catch blocks in payment functions
// ❌ CHECK: User feedback for payment failures
// ❌ VERIFY: Rollback logic for partial failures
```

### Firestore Security Rules (CRITICAL)
```javascript
// firestore.rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // ❌ AUDIT: All collection access rules
    // ❌ VERIFY: User data isolation
    // ❌ CHECK: Admin-only collection access
  }
}
```

## 🚀 Quick Start for Developer

### 1. Clone and Setup
```bash
git clone [repository]
cd flutter_application_1
flutter pub get
cd functions && npm install
```

### 2. Review Critical Files First
```bash
# Start with these files in order:
1. firestore.rules
2. functions/src/index.ts (focus on payment functions)
3. lib/app_v3/services/stripe_service_v3.dart
4. lib/app_v3/services/auth_service_v3.dart
```

### 3. Test Environment Setup
```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login and select project
firebase login
firebase use freshpunk-48db1

# Start local emulators for testing
firebase emulators:start
```

### 4. Immediate Security Checks
```bash
# Check Firestore rules
firebase firestore:rules:get

# Review Cloud Function deployments  
firebase functions:list

# Verify Stripe webhook endpoint
curl https://stripewebhook-zp46qvhbwa-uk.a.run.app
```

## 📞 Emergency Contacts & Access

### Firebase Console
- **URL**: https://console.firebase.google.com/project/freshpunk-48db1
- **Access**: Requires project owner to grant permissions

### Stripe Dashboard  
- **Environment**: Production keys in use
- **Webhook URL**: https://stripewebhook-zp46qvhbwa-uk.a.run.app

### Repository
- **GitHub**: leonovd-bit/flutter_application_1
- **Branch**: main
- **Last Deploy**: Check Firebase Hosting for latest deployment

---

**IMPORTANT**: Start with security review of `firestore.rules` and `stripeWebhook()` function before any other development work.