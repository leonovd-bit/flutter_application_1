# FreshPunk Backend Developer Handoff Guide

## Overview
This document provides a comprehensive overview of all backend components, APIs, Firebase configuration, and code areas that require developer review for the FreshPunk meal delivery application.

## 🔥 Firebase Configuration & Services

### 1. Firebase Project Setup
- **Project ID**: `freshpunk-48db1`
- **Region**: `us-east4` (configured in functions)
- **Console**: https://console.firebase.google.com/project/freshpunk-48db1

### 2. Firebase Services Used
- **Authentication**: Email/password, Google, Apple Sign-In
- **Firestore**: User profiles, meals, orders, subscriptions
- **Cloud Functions**: Payment processing, admin functions, webhooks
- **Hosting**: Web app deployment
- **App Hosting**: Alternative hosting option configured

### 3. Critical Firebase Files to Review
```
├── firebase.json                    # Hosting & functions config
├── firestore.rules                  # Database security rules
├── firestore.indexes.json          # Database indexes
├── functions/src/index.ts           # All Cloud Functions
└── lib/firebase_options.dart       # Client configuration
```

## ⚡ Cloud Functions (Backend API)

### Location: `functions/src/index.ts`

### 1. Payment Integration Functions
```typescript
// Stripe integration - REQUIRES REVIEW
- createPaymentIntent()      # Creates payment intents
- createCustomer()           # Creates Stripe customers
- createSubscription()       # Handles recurring subscriptions
- createSetupIntent()        # Payment method setup
- cancelSubscription()       # Subscription cancellation
- updateSubscription()       # Subscription modifications
- pauseSubscription()        # Temporary pause
- resumeSubscription()       # Resume paused subscription
- getBillingOptions()        # Billing configuration
- listPaymentMethods()       # Customer payment methods
- detachPaymentMethod()      # Remove payment methods
- setDefaultPaymentMethod()  # Set primary payment method
```

### 2. Order Management Functions
```typescript
- placeOrder()              # Order creation and processing
- cancelOrder()             # Order cancellation
- onOrderUpdated()          # Order status change triggers
```

### 3. Admin & Utility Functions
```typescript
- grantAdmin()              # Admin privilege management
- registerFcmToken()        # Push notification tokens
- ping()                    # Health check endpoint
- stripeWebhook()           # Stripe webhook handler
```

### 4. Secret Management
**Environment Variables Used:**
- `STRIPE_SECRET_KEY` - Stripe API key
- Configured in Firebase Functions secrets

## 🔐 Authentication & Security

### 1. Auth Implementation
**Location**: `lib/app_v3/services/`
- `auth_service_v3.dart` - Main authentication service
- `offline_auth_service_v3.dart` - Offline auth fallback
- `admin_service.dart` - Admin claim verification

### 2. Security Rules (CRITICAL REVIEW NEEDED)
**File**: `firestore.rules`
- User data isolation rules
- Admin-only collection access
- Order and subscription security

### 3. Custom Claims
- Admin users have `admin: true` claim
- Managed via `grantAdmin()` Cloud Function

## 💳 Payment Processing (Stripe Integration)

### 1. Stripe Configuration
**Service**: `lib/app_v3/services/stripe_service_v3.dart`
- Payment intent creation
- Subscription management
- Payment method handling
- Webhook processing

### 2. Critical Payment Flows
```dart
// Client-side payment processing
- StripeServiceV3.createPaymentIntent()
- StripeServiceV3.confirmPayment()
- StripeServiceV3.createSubscription()
```

### 3. Webhook Endpoint
**URL**: https://stripewebhook-zp46qvhbwa-uk.a.run.app
**Handler**: `stripeWebhook()` function in Cloud Functions

## 🗃️ Database Schema (Firestore)

### 1. Core Collections
```
users/                      # User profiles and preferences
├── {userId}/
│   ├── profile             # Basic user info
│   ├── subscription        # Subscription details
│   ├── addresses          # Delivery addresses
│   └── preferences        # Meal preferences

meals/                      # Available meals catalog
├── {mealId}/
│   ├── name, description
│   ├── ingredients, nutrition
│   └── pricing, availability

orders/                     # Order history and tracking
├── {orderId}/
│   ├── userId, status
│   ├── items, pricing
│   └── delivery details

subscriptions/              # Active subscriptions
├── {subscriptionId}/
│   ├── userId, planId
│   ├── billing cycle
│   └── status
```

### 2. Data Services (REQUIRES REVIEW)
**Location**: `lib/app_v3/services/`
- `meal_service_v3.dart` - Meal catalog management
- `order_service_v3.dart` - Order processing
- `subscription_service_v3.dart` - Subscription handling
- `user_profile_service_v3.dart` - User data management

## 🔧 API Integrations

### 1. External APIs
- **Stripe API**: Payment processing
- **Firebase APIs**: All backend services
- **FCM**: Push notifications

### 2. Internal API Structure
**Base URL**: Functions are deployed to `us-east4` region
**Authentication**: Firebase ID tokens

## 📱 Platform-Specific Considerations

### 1. Web Platform
- Uses Firebase JS SDK
- Hosted at: https://freshpunk-48db1.web.app
- Configured for SPA routing

### 2. Mobile Platforms
- iOS: Apple Sign-In integration
- Android: Google Sign-In integration
- FCM push notifications

### 3. Desktop (Windows)
- Uses Flutter desktop Firebase plugins
- Conditional web imports for platform compatibility

## 🚨 Critical Areas Requiring Developer Review

### 1. IMMEDIATE SECURITY REVIEW
```
🔴 HIGH PRIORITY
- firestore.rules - Database security rules
- functions/src/index.ts - All payment functions
- Stripe webhook signature verification
- Admin privilege escalation paths
```

### 2. PAYMENT PROCESSING AUDIT
```
🟡 MEDIUM PRIORITY
- Stripe integration error handling
- Payment failure recovery flows
- Subscription billing edge cases
- Refund and cancellation logic
```

### 3. DATA INTEGRITY
```
🟢 LOW PRIORITY BUT IMPORTANT
- User data isolation verification
- Order state consistency
- Subscription lifecycle management
- Meal catalog updates
```

## 🛠️ Development Setup

### 1. Required Tools
- Flutter SDK (latest stable)
- Firebase CLI
- Node.js (for Cloud Functions)
- Stripe CLI (for webhook testing)

### 2. Environment Setup
```bash
# Install dependencies
flutter pub get
cd functions && npm install

# Deploy functions
firebase deploy --only functions

# Deploy hosting
flutter build web --release
firebase deploy --only hosting
```

### 3. Testing Environments
- **Development**: Local Firebase emulators
- **Staging**: Firebase project with test Stripe keys
- **Production**: `freshpunk-48db1` project

## 📋 Developer Checklist

### Backend Security Audit
- [ ] Review Firestore security rules
- [ ] Audit Cloud Function permissions
- [ ] Verify Stripe webhook signatures
- [ ] Check admin privilege escalation
- [ ] Review payment error handling

### API Review
- [ ] Test all payment flows end-to-end
- [ ] Verify subscription lifecycle
- [ ] Check order processing logic
- [ ] Test error scenarios
- [ ] Validate data isolation

### Performance & Scalability
- [ ] Review database queries and indexes
- [ ] Check Cloud Function cold start times
- [ ] Audit Firebase usage and costs
- [ ] Optimize large data operations

### Documentation & Monitoring
- [ ] Add comprehensive error logging
- [ ] Set up Firebase monitoring
- [ ] Document API contracts
- [ ] Create runbooks for common issues

## 📞 Support & Contacts

### Critical Issues
- **Firebase Console**: Access required for project management
- **Stripe Dashboard**: Payment monitoring and configuration
- **Error Monitoring**: Firebase Crashlytics for client errors

### Code Repositories
- **Main Repository**: `leonovd-bit/flutter_application_1`
- **Branch**: `main`
- **Deployment**: Automated via Firebase CLI

---

**Last Updated**: October 3, 2025
**Next Review**: Schedule quarterly security audits