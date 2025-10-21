# Payment Flow - Current State

## Overview
The app currently has **TWO SEPARATE PAYMENT FLOWS** - one for AI onboarding and one for manual onboarding. The manual flow does NOT collect payment during setup, while the AI flow does.

---

## 🤖 AI Onboarding Payment Flow

### Navigation Path:
```
OnboardingChoicePageV3 
  → AIOnboardingPageV3 (multi-step wizard)
  → PaymentMethodsPageV3 (Step 8/8 - "Payment setup")
  → HomePageV3 (after completion)
```

### Step-by-Step:
1. **User chooses "AI-Powered Setup"** on OnboardingChoicePageV3
2. **AI Onboarding Page** guides user through 8 steps:
   - Step 1: Name
   - Step 2: Dietary restrictions
   - Step 3: Meal preferences
   - Step 4: Protein preferences
   - Step 5: Allergies
   - Step 6: AI recommendations
   - Step 7: Delivery address
   - **Step 8: Payment setup** ← PAYMENT IS COLLECTED HERE
3. **Payment Step UI** (`_buildPaymentStep()` in ai_onboarding_page_v3.dart):
   - Shows "Set Payment" button
   - When clicked, calls `_navigateToPayment()`
4. **PaymentMethodsPageV3** is opened with `isOnboarding: true` flag
5. **User adds card** via Stripe Payment Sheet
6. **After successful payment**, `onPaymentComplete()` callback triggers `_completeSetup()`
7. **User navigates to HomePageV3**

### Code Reference:
```dart
// ai_onboarding_page_v3.dart line 1530
void _navigateToPayment() {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => PaymentMethodsPageV3(
        onPaymentComplete: () {
          _completeSetup(); // Saves AI preferences, navigates to home
        },
        isOnboarding: true,
      ),
    ),
  );
}
```

✅ **Payment IS collected during AI onboarding**

---

## 📋 Manual Onboarding Payment Flow

### Navigation Path:
```
OnboardingChoicePageV3 
  → ChooseMealPlanPageV3
  → DeliverySchedulePageV5
  → MealSchedulePageV3
  → PaymentPageV3 ← MOCK PAYMENT (NO ACTUAL CARD COLLECTION)
  → HomePageV3
```

### Step-by-Step:
1. **User chooses "Manual Setup"** on OnboardingChoicePageV3
2. **Choose Meal Plan** - Select Standard/Premium/Pro + Protein+ option
3. **Delivery Schedule** - Configure delivery times and addresses per day
4. **Meal Schedule** - Select individual meals for each delivery
5. **Payment Page** - Shows subscription summary
6. **User clicks "Start Subscription"** button
7. **_processMockPayment()** simulates payment (2 second delay)
8. **No actual card collection** - just shows "Payment successful!" message
9. **Orders are generated** via OrderGenerationService
10. **User navigates to HomePageV3**

### Code Reference:
```dart
// payment_page_v3.dart line 520
Future<void> _processMockPayment() async {
  // Mock payment processing delay
  await Future.delayed(const Duration(seconds: 2));
  
  // Show success message
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Payment successful! Welcome to FreshPunk!'),
        backgroundColor: AppThemeV3.success,
      ),
    );
  }
}
```

❌ **Payment is NOT collected during manual onboarding** - it's mocked!

---

## 💳 Payment Methods Management (Post-Onboarding)

After completing onboarding, users can manage payment methods via:

```
HomePageV3 
  → PageViewerV3 (Settings tab)
  → SettingsPageV3
  → ManageSubscriptionPageV3
  → PaymentMethodsPageV3
```

### Payment Methods Features:
- **Add Card** - Opens Stripe Payment Sheet via `StripeService.addPaymentMethod()`
- **List Cards** - Shows saved cards via `StripeService.listPaymentMethods()`
- **Remove Card** - Detaches payment method via `StripeService.detachPaymentMethod()`
- **Set Default** - Updates default payment via `StripeService.setDefaultPaymentMethod()`

---

## 🔧 Stripe Integration Architecture

### Client-Side (Flutter):
**File:** `lib/app_v3/services/stripe_service.dart`

```dart
class StripeService {
  // Initialize Stripe SDK with publishable key
  Future<void> init()
  
  // Add payment method during onboarding or settings
  Future<bool> addPaymentMethod(BuildContext context)
  
  // List all payment methods for current user
  Future<List<Map<String, dynamic>>> listPaymentMethods()
  
  // Remove payment method
  Future<bool> detachPaymentMethod(String paymentMethodId)
  
  // Set default payment method
  Future<bool> setDefaultPaymentMethod(String paymentMethodId)
}
```

### Backend (Firebase Cloud Functions):
**File:** `functions/src/index.ts`

#### Available Functions:
1. **createCustomer** - Creates Stripe customer for new user
2. **createSetupIntent** - Creates setup intent for saving cards
3. **createPaymentIntent** - Creates payment intent for one-time charges
4. **createSubscription** - Creates recurring subscription
5. **listPaymentMethods** - Retrieves user's saved cards
6. **detachPaymentMethod** - Removes a payment method
7. **setDefaultPaymentMethod** - Sets default card for subscriptions
8. **cancelSubscription** - Cancels user subscription
9. **pauseSubscription** - Temporarily pauses subscription
10. **resumeSubscription** - Resumes paused subscription

### Stripe Configuration (.env):
```
STRIPE_PUBLISHABLE_KEY=pk_test_...
STRIPE_SECRET_KEY=sk_test_...

# Subscription Price IDs
STRIPE_PRICE_1_MEAL=price_1...
STRIPE_PRICE_2_MEAL=price_2...
STRIPE_PRICE_3_MEAL=price_3...
```

---

## 🚨 Current Issues

### Issue #1: Inconsistent Payment Collection
- **AI Onboarding:** Collects payment method ✅
- **Manual Onboarding:** Skips payment collection ❌

### Issue #2: Mock Payment in Manual Flow
- PaymentPageV3 shows "Secured by Stripe" but doesn't actually collect payment
- Uses `_processMockPayment()` with fake 2-second delay
- Users complete onboarding WITHOUT adding a card

### Issue #3: Order Generation Without Payment
- Manual flow generates orders in Firestore without payment method
- Orders created via OrderGenerationService but no subscription in Stripe
- No recurring billing setup for manual onboarding users

---

## 💡 Recommendations

### Option 1: Add Payment to Manual Flow (Recommended)
**Insert PaymentMethodsPageV3 BEFORE PaymentPageV3:**

```
ChooseMealPlanPageV3 
  → DeliverySchedulePageV5
  → MealSchedulePageV3
  → PaymentMethodsPageV3 ← NEW: Collect card here
  → PaymentPageV3 (confirmation + create subscription)
  → HomePageV3
```

**Changes Required:**
1. Update `meal_schedule_page_v3_fixed.dart` to navigate to PaymentMethodsPageV3 first
2. Pass `isOnboarding: true` flag
3. After card added, proceed to PaymentPageV3 for subscription creation
4. Replace `_processMockPayment()` with actual Stripe subscription creation

### Option 2: Remove Mock Payment
**Skip PaymentPageV3 entirely, use ManageSubscriptionPageV3 post-onboarding:**

```
ChooseMealPlanPageV3 
  → DeliverySchedulePageV5
  → MealSchedulePageV3
  → HomePageV3 (with "Add Payment Method" banner)
```

**Changes Required:**
1. Save meal plan/schedule but mark subscription as "pending payment"
2. Show prominent banner on HomePageV3: "⚠️ Complete payment to start deliveries"
3. Users add payment via Settings → Manage Subscription → Payment Methods
4. After payment added, create subscription via Stripe API

### Option 3: Make AI Flow Match Manual Flow (Not Recommended)
- Remove payment step from AI onboarding
- Both flows skip payment during setup
- Collect payment post-onboarding via ManageSubscriptionPageV3

---

## 🔍 Code Locations

### Payment Collection:
- **AI Flow:** `lib/app_v3/pages/ai_onboarding_page_v3.dart` (line 1530)
- **Manual Flow:** `lib/app_v3/pages/payment_page_v3.dart` (line 520 - MOCK)
- **Settings:** `lib/app_v3/pages/payment_methods_page_v3.dart`

### Stripe Service:
- **Client:** `lib/app_v3/services/stripe_service.dart`
- **Backend:** `functions/src/index.ts`
- **Config:** `.env` file (Stripe keys + price IDs)

### Navigation:
- **AI:** OnboardingChoicePageV3 → AIOnboardingPageV3 → PaymentMethodsPageV3 → Home
- **Manual:** OnboardingChoicePageV3 → ChooseMealPlan → DeliverySchedule → MealSchedule → PaymentPage (mock) → Home

---

## 📊 Current State Summary

| Feature | AI Onboarding | Manual Onboarding |
|---------|--------------|-------------------|
| Payment Collected? | ✅ Yes (PaymentMethodsPageV3) | ❌ No (Mock payment) |
| Stripe Integration | ✅ Real Stripe API | ❌ Fake delay |
| Subscription Created | ✅ Via PaymentMethodsPageV3 | ❌ Not created |
| Card on File | ✅ Yes | ❌ No |
| Orders Generated | ✅ Yes | ✅ Yes (but no billing) |
| Ready for Production | ✅ Yes | ❌ No - needs real payment |

**Bottom Line:** Manual onboarding flow needs payment collection added before it can be used in production.
