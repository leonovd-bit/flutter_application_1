# FreshPunk - ACTUAL Firebase Schema

Based on real Firestore inspection on January 27, 2026.

## Collections in Firebase

### 1. `users` Collection
User profiles with meal plan preferences embedded.

**Sample Document:**
```
userId: "snqYwfqDa9Zt6CeAcVqjpE6lBml3"
- id: string
- email: string
- fullName: string
- phoneNumber: string
- phoneNumberVerified: boolean
- phoneNumberVerifiedAt: timestamp
- profileImageUrl: string
- isActive: boolean
- preferences: {
    notifications: boolean,
    emailUpdates: boolean,
    smsUpdates: boolean
  }
- currentMealPlanId: string (e.g., "1", "2", "3")
- currentPlanName: string
- currentPlanDisplayName: string
- currentMealsPerDay: number
- currentPricePerMeal: number
- stripeCustomerId: string
- squareCustomerId: string
- createdAt: timestamp
- updatedAt: timestamp
- lastLoginAt: timestamp
```

### 2. `addresses` Collection
User delivery addresses.

**Fields:**
- `id`: string
- `userId`: string - Reference to user
- `label`: string - Nickname (e.g., "Home", "Work")
- `streetAddress`: string
- `streetAddress2`: string - Apt/suite
- `city`: string
- `state`: string
- `zipCode`: string
- `country`: string (default: "US")
- `isDefault`: boolean
- `verified`: boolean
- `createdAt`: timestamp

### 3. `subscriptions` Collection
User subscription/plan selection metadata.

**Sample Document (from screenshot):**
```
userId: "snqYwfqDa9Zt6CeAcVqjpE6lBml3"
- id: string
- planId: string (e.g., "1")
- planName: string (e.g., "standard")
- planDisplayName: string (e.g., "Standard")
- status: string ("active", "inactive", "paused", "canceled")
- stripeSubscriptionId: string (optional)
- stripePriceId: string (optional)
- currentPeriodStart: timestamp (optional)
- currentPeriodEnd: timestamp (optional)
- nextBillingDate: timestamp (optional)
- cancelAtPeriodEnd: boolean
- pauseBehavior: string (optional)
- userId: string
- createdAt: timestamp
- updatedAt: timestamp
```

### 4. `meals` Collection
Available meals from restaurants.

**Fields:**
- `id`: string
- `name`: string
- `description`: string
- `price`: number (in dollars)
- `ingredients`: array of strings
- `allergens`: array of strings
- `imageUrl`: string
- `mealType`: string ("breakfast", "lunch", "dinner")
- `restaurant`: string (restaurant name)
- `restaurantId`: string (reference to restaurant_partners)
- `menuCategory`: string ("premade", "custom")
- `squareItemId`: string
- `squareVariationId`: string
- `isAvailable`: boolean
- `createdAt`: timestamp
- `updatedAt`: timestamp

### 5. `orders` Collection
Individual meal orders.

**Fields:**
- `id`: string
- `userId`: string
- `restaurantId`: string
- `mealPlanId`: string (if from subscription)
- `meals`: array of meal objects:
  - `id`: string
  - `name`: string
  - `price`: number
  - `restaurantId`: string
  - `squareItemId`: string
  - `squareVariationId`: string
- `customerName`: string
- `customerEmail`: string
- `customerPhone`: string
- `deliveryAddress`: object or string
- `totalAmount`: number (in dollars)
- `status`: string ("pending", "confirmed", "preparing", "outForDelivery", "delivered", "cancelled")
- `paymentStatus`: string ("unpaid", "paid", "refunded")
- `squarePaymentId`: string
- `squareOrders`: object (per restaurant):
  - `{restaurantId}`:
    - `squareOrderId`: string
    - `status`: string
    - `forwardedAt`: timestamp
    - `lastError`: string
- `orderDate`: timestamp
- `deliveryDate`: timestamp
- `estimatedDeliveryTime`: timestamp
- `dispatchTriggeredAt`: timestamp
- `userConfirmed`: boolean
- `userConfirmedAt`: timestamp
- `notes`: string
- `trackingNumber`: string
- `createdAt`: timestamp
- `updatedAt`: timestamp

### 6. `restaurant_partners` Collection
Restaurant partner data and Square OAuth credentials.

**Fields:**
- `id`: string
- `restaurantName`: string
- `status`: string ("pending", "active", "suspended", "inactive")
- `email`: string
- `phoneNumber`: string
- `address`: object:
  - `street`: string
  - `city`: string
  - `state`: string
  - `zip`: string
- `squareMerchantId`: string
- `squareAccessToken`: string (ENCRYPTED)
- `squareRefreshToken`: string (ENCRYPTED)
- `squareLocationId`: string
- `tokenExpiresAt`: timestamp
- `menuItemCount`: number
- `lastMenuSync`: timestamp
- `deliveryConfig`: object:
  - `handlingTime`: number (minutes)
  - `prepTimeDuration`: string (ISO 8601)
  - `deliveryRadius`: number (miles)
- `notificationEmail`: string
- `createdAt`: timestamp
- `updatedAt`: timestamp

### 7. `restaurant_applications` Collection
Restaurant signup applications (pending partnerships).

### 8. `restaurant_notifications` Collection  
Notifications sent to restaurants about orders/subscriptions.

**Fields:**
- `id`: string
- `restaurantId`: string
- `type`: string ("order_confirmed", "order_shipped", "subscription_created")
- `title`: string
- `body`: string
- `orderId`: string (if order-related)
- `subscriptionId`: string (if subscription-related)
- `read`: boolean
- `readAt`: timestamp
- `createdAt`: timestamp
- `expiresAt`: timestamp

### 9. `order_tracking` Collection
Real-time order location and delivery status.

**Fields:**
- `orderId`: string (document ID)
- `driverLat`: number
- `driverLng`: number
- `status`: string ("pending", "in_transit", "delivered")
- `updatedAt`: timestamp

### 10. `order_forward_index` Collection
Indexed lookup for orders forwarded to Square by restaurant.

### 11. `audit_logs` Collection
System activity and security audit trail.

**Fields:**
- `id`: string
- `action`: string (what was done)
- `userId`: string (who did it, null for system)
- `details`: object (sanitized action details)
- `isSuccess`: boolean
- `errorMessage`: string
- `timestamp`: timestamp
- `ip`: string (request IP if applicable)

### 12. `square_webhook_events` Collection
Log of Square webhook events received.

**Fields:**
- `id`: string
- `eventId`: string (Square event ID)
- `eventType`: string
- `data`: object (webhook payload)
- `processed`: boolean
- `errorMessage`: string
- `timestamp`: timestamp

### 13. `_test_writes` Collection
Testing/diagnostics collection.

---

## Key Data Flow Summary

### User Registration
1. User signs up via Firebase Auth
2. `createUserProfile()` writes to `users` collection
3. User profile includes basic info (email, name, phone)

### Meal Plan Selection
1. User selects plan in UI
2. Updates **`users/{userId}`** document with:
   - `currentMealPlanId`
   - `currentPlanName`
   - `currentPlanDisplayName`
   - `currentMealsPerDay`
   - `currentPricePerMeal`
3. Also writes to **`subscriptions/{userId}`** for tracking
4. **Delivery schedule is NOT persisted** - it's a local variable passed between pages

### Order Creation
1. User places order
2. Creates document in **`orders`** collection
3. If meal from restaurant with Square integration:
   - Calls `forwardOrderToSquare()`
   - Sends to Square API
   - Updates `orders.squareOrders[restaurantId]` with Square order ID

### Payment
1. Stripe processes payment
2. Webhook received at `stripeWebhook()`
3. Records payment in **`payments`** collection (if exists) or updates order
4. Updates restaurant earnings in **`restaurant_earnings`** collection (if exists)

### Notifications
1. Order status changes
2. Firestore triggers send email to restaurant via Gmail
3. Logs in **`restaurant_notifications`** collection
4. FCM push sent to user devices

---

## What's NOT in Firebase (but code references it)

- ❌ `meal_plans` collection - defined but empty
- ❌ `delivery_schedules` collection - defined but empty
- ❌ `payments` collection - may not be created
- ❌ `invoices` collection - may not be created
- ❌ `restaurant_earnings` collection - may not be created

These are scaffolded in code but not actively used in current implementation.
