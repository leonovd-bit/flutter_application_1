# Investigation: Two User Documents During Signup

## Question
Why does signup create two documents in Firestore?
1. One in `users/{userId}` with all user info + subcollections (delivery_schedules, invoices, orders)
2. Another in `subscriptions/{userId}` with just subscription data

## Answer: Intentional Two-Location Pattern

Yes, this is intentional but has some issues. Here's what's actually happening:

---

## Timeline: When Documents Are Created

### 1. **SIGNUP FLOW** (Frontend - Dart)
**File:** `lib/app_v3/pages/auth/signup_page_v3.dart` lines 753-820

```dart
// User creates account with email/password
final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(...)

// Update Firebase Auth display name
await credential.user?.updateDisplayName(_nameController.text.trim())

// Call _updateUserProfile() → FirestoreServiceV3.updateUserProfile()
```

**Result:** Creates/updates `users/{userId}` document with:
- `id`, `email`, `fullName`, `phoneNumber`
- `createdAt`, `updatedAt`, `isActive`
- `preferences`, `profileImageUrl`

**Status of `subscriptions/{userId}` at this point:** NOT CREATED YET

---

### 2. **PAYMENT FLOW** (Frontend - Dart)
**File:** `lib/app_v3/pages/payment/payment_page_v3.dart`

User selects meal plan and proceeds to payment. Code calls:

```dart
final callable = functions.httpsCallable('createCustomer');
final result = await callable.call({
  'email': email,
  'name': name,
});
customerId = result.data['customer']['id'];  // Returns Stripe customer ID like "cus_xxx"

// Store it in users doc
await _firestore.collection('users').doc(userId).set({
  'stripeCustomerId': customerId,
  ...
}, SetOptions(merge: true));
```

**Result:** Adds `stripeCustomerId` field to existing `users/{userId}` document.

---

### 3. **STRIPE WEBHOOK FIRES** (Backend - TypeScript)
**File:** `functions/src/index.ts` lines 1399-1430

When user completes payment in Stripe, Stripe sends `customer.subscription.created` webhook:

```typescript
async function handleSubscriptionCreated(event: any) {
  const subscription = event.data.object;  // Stripe subscription object
  const customerId = subscription.customer;

  // Find user by Stripe customer ID
  const usersSnapshot = await db.collection("users")
    .where("stripeCustomerId", "==", customerId)
    .limit(1)
    .get();

  if (!usersSnapshot.empty) {
    const userId = usersSnapshot.docs[0].id;

    // 🔴 CREATE TOP-LEVEL SUBSCRIPTIONS DOC
    await db.collection("subscriptions").doc(userId).set({
      id: subscription.id,
      userId: userId,
      stripeSubscriptionId: subscription.id,
      status: subscription.status,
      stripePriceId: subscription.items.data[0]?.price?.id,
      currentPeriodStart: new Date(subscription.current_period_start * 1000),
      currentPeriodEnd: new Date(subscription.current_period_end * 1000),
      cancelAtPeriodEnd: subscription.cancel_at_period_end,
      createdAt: FieldValue.serverTimestamp(),
    }, {merge: true});
  }
}
```

**Result:** Creates `subscriptions/{userId}` document with subscription metadata.

---

### 4. **SUBSCRIPTION UPDATES** (Backend - TypeScript)
**File:** `functions/src/index.ts` lines 840-881

Multiple Cloud Functions also write to BOTH locations:
- `updateSubscription()` - lines 795-797
- `pauseSubscription()` - lines 840, 843
- `resumeSubscription()` - lines 879, 881

```typescript
// Pattern repeated everywhere:
await db.collection("users").doc(uid)
  .collection("subscriptions").doc(updated.id)
  .set(subPayload, {merge: true});

// 🔴 PLUS ALSO WRITE TO TOP-LEVEL
await db.collection("subscriptions").doc(uid).set(subPayload, {merge: true});
```

This creates **TWO copies** of every subscription update!

---

## Document Locations & What They Contain

### Location 1: `users/{userId}`
**Purpose:** User account profile (persistent, never deleted)

**Data:**
```json
{
  "id": "user123",
  "email": "user@example.com",
  "fullName": "John Doe",
  "phoneNumber": "+1234567890",
  "stripeCustomerId": "cus_abc123",  // Added after payment
  "createdAt": "2026-01-27T...",
  "updatedAt": "2026-01-27T...",
  "isActive": true,
  "preferences": { ... }
}
```

**Subcollections:**
- `addresses/` - saved delivery addresses
- `delivery_schedules/` - active meal plan schedules
- `orders/` - order history
- `subscriptions/{subscriptionId}` - ⚠️ NESTED COPY (see below)

---

### Location 2: `subscriptions/{userId}`
**Purpose:** Quick lookup of active subscription (caching/optimization)

**Data:**
```json
{
  "id": "sub_stripe123",
  "userId": "user123",
  "stripeSubscriptionId": "sub_stripe123",
  "status": "active",
  "stripePriceId": "price_abc",
  "currentPeriodStart": "2026-01-27T...",
  "currentPeriodEnd": "2026-02-27T...",
  "cancelAtPeriodEnd": false,
  "createdAt": "2026-01-27T..."
}
```

**Document ID:** The user ID (not subscription ID) - allows fast lookup by user

---

### Location 3: `users/{userId}/subscriptions/{subscriptionId}` (NESTED)
**Purpose:** Legacy/nested copy from older code

Same data as location 2 but nested in user subcollection.

---

## Problem: THREE Locations Being Synced

Your code is maintaining subscription data in **3 separate places**:

1. ✅ **`users/{userId}/subscriptions/{subscriptionId}`** - Nested in user doc (legacy)
2. ✅ **`subscriptions/{userId}`** - Top-level canonical (newer)  
3. ⚠️ **Dart code** - `FirestoreServiceV3.updateActiveSubscriptionPlan()` also writes to location 2

### Evidence of Triple Writing

**TypeScript (functions/src/index.ts):**
```typescript
// updateSubscription
await db.collection("users").doc(uid)
  .collection("subscriptions").doc(updated.id)
  .set(subPayload, {merge: true});  // Location 1 ✅
await db.collection("subscriptions").doc(uid)
  .set(subPayload, {merge: true});  // Location 2 ✅
```

**Dart (lib/app_v3/services/auth/firestore_service_v3.dart line 317):**
```dart
await _firestore.collection(_subscriptionsCollection).doc(userId).set({
  'userId': userId,
  'planId': plan.id,
  'planName': plan.name,
  'planDisplayName': plan.displayName,
  'status': 'active',
  'updatedAt': FieldValue.serverTimestamp(),
}, SetOptions(merge: true));  // Also writes to location 2! ⚠️
```

---

## Timing: NOT Related to Payment Split

This has **nothing to do with Stripe vs Square split payouts.**

The split payout logic is in:
- `functions/src/invoice-functions.ts` - Calculates FreshPunk vs restaurant split
- `functions/src/order-functions.ts` - Splits payments when order is created

The dual documents are purely for **subscription state management** and **query optimization**.

---

## Why Two Documents?

### Original Design Intention
1. **`users/{userId}`** = Full user profile with all subcollections
   - Used for account settings pages
   - Contains everything but heavier to query
   
2. **`subscriptions/{userId}`** = Lightweight subscription cache
   - Fast read for "is this user currently subscribed?"
   - Mirror of Stripe subscription state
   - Synced automatically by webhooks
   - Query by userId directly (not nested query)

### Real Reason For Duplication
It's actually a **legacy migration in progress**:
- Old code uses nested `users/{userId}/subscriptions/{subscriptionId}` (location 1)
- New code added top-level `subscriptions/{userId}` for faster queries (location 2)
- **Both are being maintained** to avoid breaking existing code

---

## How Signup Triggers Both

### Path to Two Documents

```
1. User signs up with email/password
   ↓
2. _updateUserProfile() creates users/{userId}
   ↓
3. User selects meal plan and pays
   ↓
4. Payment creates Stripe customer + stores stripeCustomerId in users/{userId}
   ↓
5. Stripe webhook fires → handleSubscriptionCreated()
   ↓
6. Backend queries users by stripeCustomerId
   ↓
7. Backend creates subscriptions/{userId} document
   ↓
8. [RESULT] Two documents now exist for this user
```

---

## Code Locations Summary

| What | Where | Line | What It Does |
|------|-------|------|--------------|
| User profile created | `firestore_service_v3.dart` | 27-38 | Writes `users/{userId}` |
| Subscription lookup | `firestore_service_v3.dart` | 305-330 | Reads from `subscriptions/{userId}` |
| Subscription writes (Dart) | `firestore_service_v3.dart` | 313-326 | Writes to `subscriptions/{userId}` |
| Stripe webhook handler | `functions/src/index.ts` | 1399-1430 | Creates `subscriptions/{userId}` |
| Subscription pause | `functions/src/index.ts` | 840, 843 | Writes to BOTH locations |
| Subscription resume | `functions/src/index.ts` | 879, 881 | Writes to BOTH locations |
| Subscription update | `functions/src/index.ts` | 795, 797 | Writes to nested location |

---

## Is This Intentional or Bug?

**It's intentional but messy:**

✅ **Intentional**: Maintaining `subscriptions/{userId}` as fast lookup cache
⚠️ **Messy**: Also maintaining nested `users/{userId}/subscriptions/{subscriptionId}` 
⚠️ **Wasteful**: Dart code writes to same document that backend webhooks sync
⚠️ **Risky**: Two sources of truth = potential sync issues

---

## Recommendations

### To Clean Up:
1. **Stop writing from Dart**: Remove `FirestoreServiceV3.updateActiveSubscriptionPlan()` calls
2. **Use webhook as single source**: Only backend updates `subscriptions/{userId}`
3. **Remove nested copy**: Stop writing to `users/{userId}/subscriptions/{subscriptionId}`
4. **Add data validation**: Check that both locations stay in sync (if keeping both)

### To Use Correctly:
- Frontend reads from `subscriptions/{userId}` for subscription status
- Frontend never writes to it (let backend webhooks handle it)
- Backend updates `subscriptions/{userId}` only from Stripe webhooks

---

## Summary

**Two documents exist because:**
1. Stripe webhooks create `subscriptions/{userId}` when subscription starts
2. Dart code also writes to it during payment flow
3. This is a legacy pattern being maintained during migration from nested to top-level storage
4. **NOT related to payment splitting** (that's in invoice/order functions)

The pattern works but should be cleaned up to have a single source of truth.
