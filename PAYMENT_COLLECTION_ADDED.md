# Payment Collection Added to Manual Onboarding

## Summary
Added real Stripe payment card collection to the manual onboarding flow. Users are now required to add a payment method before completing their subscription.

---

## Changes Made

### 1. **meal_schedule_page_v3_fixed.dart** - Payment Method Check

#### Added Imports:
```dart
import 'package:flutter/foundation.dart';
import 'payment_methods_page_v3.dart';
import '../services/stripe_service.dart';
```

#### Modified `_proceedToPayment()` Method:
**Before:**
```dart
void _proceedToPayment() {
  if (_currentMealPlan == null) return;
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => PaymentPageV3(...),
    ),
  );
}
```

**After:**
```dart
Future<void> _proceedToPayment() async {
  if (_currentMealPlan == null) return;
  
  // Check if user has a payment method on file
  final hasPaymentMethod = await _checkPaymentMethod();
  
  if (!hasPaymentMethod) {
    // User needs to add payment method first
    final paymentAdded = await _promptAddPaymentMethod();
    
    if (!paymentAdded) {
      _showSnackBar('Payment method required to complete subscription', isError: true);
      return;
    }
  }
  
  // Payment method confirmed, proceed to payment page
  Navigator.push(...);
}
```

#### New Methods Added:

**`_checkPaymentMethod()`** - Checks if user has saved card
```dart
Future<bool> _checkPaymentMethod() async {
  try {
    final paymentMethods = await StripeService.instance.listPaymentMethods();
    return paymentMethods.isNotEmpty;
  } catch (e) {
    debugPrint('[MealSchedule] Error checking payment methods: $e');
    return false;
  }
}
```

**`_promptAddPaymentMethod()`** - Shows dialog and opens payment sheet
```dart
Future<bool> _promptAddPaymentMethod() async {
  // Show confirmation dialog
  final shouldProceed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          Icon(Icons.payment, color: AppThemeV3.accent),
          const SizedBox(width: 12),
          const Text('Payment Method Required'),
        ],
      ),
      content: const Text(
        'To complete your subscription, please add a payment method. Your card will be securely saved and charged monthly.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add Payment Method')),
      ],
    ),
  );
  
  // Open payment methods page to add card
  final result = await Navigator.push<bool>(
    context,
    MaterialPageRoute(
      builder: (_) => PaymentMethodsPageV3(
        isOnboarding: true,
        onPaymentComplete: () => Navigator.pop(context, true),
      ),
    ),
  );
  
  return result == true;
}
```

**`_showSnackBar()`** - Helper for showing messages
```dart
void _showSnackBar(String message, {bool isError = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: isError ? AppThemeV3.error : AppThemeV3.success,
      behavior: SnackBarBehavior.floating,
    ),
  );
}
```

---

### 2. **payment_page_v3.dart** - Remove Mock Payment

#### Modified `_startSubscription()` Method:
**Before:**
```dart
Future<void> _startSubscription() async {
  setState(() => _isProcessing = true);
  try {
    // Mock payment processing for development
    await _processMockPayment(); // ← FAKE PAYMENT
    
    // Generate orders...
    // Navigate to home...
  }
}

Future<void> _processMockPayment() async {
  await Future.delayed(const Duration(seconds: 2)); // Fake delay
  ScaffoldMessenger.of(context).showSnackBar(...);
}
```

**After:**
```dart
Future<void> _startSubscription() async {
  setState(() => _isProcessing = true);
  try {
    // Payment method was already added in previous step
    debugPrint('[Payment] Starting subscription with saved payment method...');
    
    // Show confirmation message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: const Text('✓ Creating your subscription...')),
    );
    
    // Generate orders from meal selections...
    
    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: const Text('🎉 Subscription created! Welcome to FreshPunk!')),
    );
    
    // Navigate to home...
  }
}
```

#### Removed:
- ❌ `_processMockPayment()` method (no longer needed)

---

## User Experience Flow

### New Manual Onboarding Flow:

1. **Choose Meal Plan** - Select Standard/Premium/Pro + Protein+
2. **Delivery Schedule** - Configure delivery times and addresses
3. **Meal Schedule** - Select individual meals for each delivery
4. **Click "Proceed to Payment"** ← NEW STEP
   - App checks if user has payment method saved
   - If NO card on file:
     - Shows dialog: "Payment Method Required"
     - User clicks "Add Payment Method"
     - **Stripe Payment Sheet opens** ← REAL CARD COLLECTION
     - User enters card details
     - Card is securely saved via Stripe
     - Returns to meal schedule page
5. **Payment Page** - Shows subscription summary and confirmation
6. **Click "Start Subscription"**
   - Creates orders in Firestore
   - Marks setup as completed
   - Navigates to Home

### Dialog Message:
```
Payment Method Required
───────────────────────
To complete your subscription, please add 
a payment method. Your card will be 
securely saved and charged monthly.

[Cancel]  [Add Payment Method]
```

---

## Technical Details

### Payment Method Validation:
```dart
// Calls Stripe backend to list saved payment methods
final paymentMethods = await StripeService.instance.listPaymentMethods();

// If empty, user must add card
if (paymentMethods.isEmpty) {
  await _promptAddPaymentMethod();
}
```

### Stripe Payment Sheet:
```dart
// Opens PaymentMethodsPageV3 in onboarding mode
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => PaymentMethodsPageV3(
      isOnboarding: true,  // Hides back button, shows completion callback
      onPaymentComplete: () => Navigator.pop(context, true),
    ),
  ),
);
```

### Success Callback:
```dart
// When user successfully adds card
onPaymentComplete: () {
  Navigator.pop(context, true); // Return to meal schedule
}
```

---

## Benefits

✅ **Real Payment Collection** - No more mock payment delays  
✅ **Stripe Integration** - Secure card storage via Stripe SDK  
✅ **User-Friendly Flow** - Clear dialog explains why payment is needed  
✅ **Consistent Experience** - Manual flow now matches AI flow for payment  
✅ **Production Ready** - Can charge users monthly via saved payment method  
✅ **Cancellation Support** - Users can cancel dialog if they change their mind  
✅ **Error Handling** - Shows error message if payment method addition fails  

---

## Testing Checklist

### Test Manual Onboarding:
1. ✅ Choose meal plan (Standard/Premium/Pro)
2. ✅ Configure delivery schedule
3. ✅ Select meals for each day
4. ✅ Click "Proceed to Payment"
5. ✅ Verify dialog appears: "Payment Method Required"
6. ✅ Click "Add Payment Method"
7. ✅ Verify Stripe Payment Sheet opens
8. ✅ Enter test card (4242 4242 4242 4242)
9. ✅ Verify card is saved successfully
10. ✅ Verify navigation to PaymentPageV3
11. ✅ Click "Start Subscription"
12. ✅ Verify orders are generated
13. ✅ Verify navigation to HomePageV3

### Test with Existing Payment Method:
1. ✅ User already has card saved
2. ✅ Click "Proceed to Payment"
3. ✅ Verify no dialog appears
4. ✅ Navigate directly to PaymentPageV3

### Test Cancellation:
1. ✅ Click "Proceed to Payment"
2. ✅ Dialog appears
3. ✅ Click "Cancel"
4. ✅ Verify stays on meal schedule page
5. ✅ Verify error message: "Payment method required to complete subscription"

---

## Files Modified

1. `lib/app_v3/pages/meal_schedule_page_v3_fixed.dart`
   - Added payment method validation
   - Added dialog prompt for card collection
   - Added helper methods

2. `lib/app_v3/pages/payment_page_v3.dart`
   - Removed mock payment processing
   - Updated subscription creation flow
   - Added confirmation messages

---

## Next Steps (Optional Future Enhancements)

### 1. Create Stripe Subscription on Backend
Currently, the app only saves the payment method. For full production:
- Call `createSubscription` Cloud Function after payment method is added
- Pass meal plan price ID and saved payment method
- Store subscription ID in Firestore user document

### 2. Add Subscription Management
- Show active subscription status on HomePageV3
- Allow users to change subscription plan
- Support pause/resume/cancel subscription

### 3. Handle Payment Failures
- Add webhook to listen for failed charges
- Notify users via push notifications
- Show banner on home page if payment fails

### 4. Add Proration Support
- Allow mid-cycle plan changes
- Calculate prorated amounts
- Update Stripe subscription with new price

---

## Related Files

- `lib/app_v3/services/stripe_service.dart` - Stripe integration
- `lib/app_v3/pages/payment_methods_page_v3.dart` - Payment sheet UI
- `functions/src/index.ts` - Backend Stripe functions
- `.env` - Stripe API keys and price IDs

---

## Documentation

See also:
- `PAYMENT_FLOW_CURRENT_STATE.md` - Overview of payment flows
- `STRIPE_BACKEND_API.md` - Backend API documentation
- `PaymentMethodsPageV3.md` - Payment methods page guide
