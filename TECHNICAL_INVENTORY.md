# FreshPunk Application - Complete Technical Inventory

**Last Updated:** January 27, 2026  
**Project:** Flutter + Firebase + Cloud Functions + Square Integration

---

## 🗄️ FIRESTORE COLLECTIONS & DATA MODELS

**ACTUAL Collections in Firebase:**
1. `_test_writes` - Testing/diagnostics
2. `addresses` - User delivery addresses
3. `audit_logs` - System audit trail
4. `meals` - Available meal items
5. `order_forward_index` - Order-to-restaurant lookup
6. `order_tracking` - Real-time order location/status
7. `orders` - Order records
8. `restaurant_applications` - Restaurant signup applications
9. `restaurant_notifications` - Notifications to restaurants
10. `restaurant_partners` - Restaurant partner OAuth & config
11. `square_webhook_events` - Webhook event logs
12. `subscriptions` - User subscriptions/plan selection
13. `users` - User profiles and meal preferences

**NOT IN USE (defined in code but empty):**
- ❌ `meal_plans` 
- ❌ `delivery_schedules`

---

### Core User Collections

#### `users` Collection
**Purpose:** User profile and meal plan preferences  
**Fields:**
- `id` (string) - Firebase UID
- `email` (string) - User email address
- `fullName` (string) - User's full name
- `phoneNumber` (string) - Contact number
- `phoneNumberVerified` (boolean) - SMS verified
- `phoneNumberVerifiedAt` (timestamp)
- `profileImageUrl` (string) - User avatar/profile picture
- `isActive` (boolean) - Account status
- `preferences` (object) - User settings
  - `notifications` (boolean)
  - `emailUpdates` (boolean)
  - `smsUpdates` (boolean)
- **Meal Plan Preferences** (stored directly in user doc):
  - `currentMealPlanId` (string) - Which plan user selected (e.g., "1", "2", "3")
  - `currentPlanName` (string) - Plan name (e.g., "standard")
  - `currentPlanDisplayName` (string) - Display name (e.g., "Standard")
  - `currentMealsPerDay` (number) - How many meals/day
  - `currentPricePerMeal` (number) - Price per meal
- `stripeCustomerId` (string) - Stripe customer reference
- `squareCustomerId` (string) - Square customer reference
- `createdAt` (timestamp) - Account creation date
- `updatedAt` (timestamp) - Last profile update
- `lastLoginAt` (timestamp) - Last login timestamp
  - `timezone` (string)

#### `users/{userId}/fcmTokens` Subcollection
**Purpose:** Firebase Cloud Messaging tokens for push notifications  
**Fields:**
- `token` (string) - FCM device token
- `platform` (string) - "ios", "android", "web"
- `createdAt` (timestamp)
- `updatedAt` (timestamp)
- `isActive` (boolean)

---

### Meal Planning - Actual Data Storage

**⚠️ IMPORTANT:** Meal plan and delivery schedule data are **NOT stored in separate collections**. They're stored in different ways:

#### Meal Plan Selection
**Where Stored:** In `users/{userId}` document fields:
- `currentMealPlanId` (string) - Which plan user selected
- `currentPlanName` (string) - Display name
- `currentMealsPerDay` (number) - How many meals per day
- `currentPricePerMeal` (number) - Price per meal
- `updatedAt` (timestamp) - Last update

**How It's Set:**
1. User picks a plan in UI
2. Calls `SimpleMealPlanService.setActiveMealPlanSimple(userId, plan)`
3. Updates user document with those 4 fields above
4. Also updates `subscriptions` collection (separate - plan selection metadata)

#### Delivery Schedule
**Where Stored:** **Nowhere permanently** - it's a local/runtime variable!
- `weeklySchedule` is passed as a parameter between pages
- Example structure: `{"Monday": {"lunch": {"enabled": true, "time": "12:00"}}}`
- Used to generate orders but NOT persisted to Firebase
- Only fallback `_generateOrdersLegacy()` tries to write to `delivery_schedules` collection (which is never actually read in production)

#### `meal_plans` Collection (LEGACY/RESERVED)
**Purpose:** Reserved for future meal plan system  
**Status:** Defined in code (`firestore_service_v3.dart`, `meal_service_v3.dart`) but not actively populated  
**Note:** User's selected plan is stored in `subscriptions` collection instead

#### `meals` Collection
**Purpose:** Individual meal items available from restaurants  
**Fields:**
- `id` (string) - Meal document ID
- `name` (string) - Meal name
- `description` (string) - Detailed description
- `price` (number) - Price in dollars
- `ingredients` (array) - List of ingredients
- `allergens` (array) - Allergen information
- `imageUrl` (string) - Meal image URL
- `mealType` (string) - "breakfast", "lunch", "dinner"
- `restaurant` (string) - Restaurant name
- `restaurantId` (string) - Reference to restaurant_partners
- `menuCategory` (string) - Category in restaurant menu
- `squareItemId` (string) - Square catalog item ID
- `squareVariationId` (string) - Square catalog variation ID
- `isAvailable` (boolean)
- `createdAt` (timestamp)
- `updatedAt` (timestamp)

---

### Address Collections

#### `addresses` Subcollection (under users)
**Purpose:** Saved delivery addresses  
**Fields:**
- `id` (string) - Address ID
- `userId` (string) - Reference to user
- `label` (string) - Address nickname (e.g., "Home", "Work")
- `streetAddress` (string) - Street address line 1
- `streetAddress2` (string) - Apartment/suite number
- `city` (string) - City name
- `state` (string) - State abbreviation
- `zipCode` (string) - ZIP/postal code
- `country` (string) - Country (default: "US")
- `isDefault` (boolean) - Primary delivery address
- `createdAt` (timestamp)
- `verified` (boolean) - Address verified with Square

---

### Order Collections

#### `orders` Collection
**Purpose:** Individual meal orders  
**Fields:**
- `id` (string) - Order document ID
- `userId` (string) - Reference to user
- `restaurantId` (string) - Which restaurant fulfills
- `mealPlanId` (string) - Associated meal plan (if from subscription)
- `meals` (array) - Array of meal objects:
  - `id` (string) - Meal ID
  - `name` (string) - Meal name
  - `price` (number) - Individual meal price
  - `restaurantId` (string)
  - `squareItemId` (string)
  - `squareVariationId` (string)
- `customerName` (string) - Delivery recipient name
- `customerEmail` (string) - Customer email
- `customerPhone` (string) - Customer phone number
- `deliveryAddress` (object or string) - Delivery location
- `totalAmount` (number) - Order total in dollars
- `status` (string) - "pending", "confirmed", "preparing", "outForDelivery", "delivered", "cancelled"
- `paymentStatus` (string) - "unpaid", "paid", "refunded"
- `squarePaymentId` (string) - Square payment ID
- `squareOrders` (object) - Square order tracking by restaurant:
  - `{restaurantId}`:
    - `squareOrderId` (string)
    - `status` (string) - "forwarded", "accepted", "preparing", "ready", "completed"
    - `forwardedAt` (timestamp)
    - `lastError` (string) - Error message if forwarding failed
- `orderDate` (timestamp) - When order was created
- `deliveryDate` (timestamp) - Scheduled delivery date
- `estimatedDeliveryTime` (timestamp) - Estimated delivery time
- `dispatchTriggeredAt` (timestamp) - When order sent to kitchen
- `userConfirmed` (boolean) - User confirmed meal selection
- `userConfirmedAt` (timestamp) - When user confirmed
- `notes` (string) - Special instructions
- `trackingNumber` (string) - Shipping tracking if applicable
- `createdAt` (timestamp)
- `updatedAt` (timestamp)

---

### Subscription Collections

#### `subscriptions` Collection
**Purpose:** Track user's active meal plan subscription (plan selection metadata)  
**Status:** ACTIVELY USED - Stores which plan user is subscribed to  
**Location:** Top-level `/subscriptions/{userId}` collection  
**Also Mirrored:** `users/{userId}/subscriptions/{stripeSubscriptionId}` (nested, Stripe sync)  
**Fields:**
- `id` (string) - Subscription document ID (userId or Stripe subscription ID)
- `userId` (string) - Reference to user
- `planId` (string) - Plan identifier (e.g., "1", "2", "3")
- `planName` (string) - Plan name (e.g., "standard", "premium")
- `planDisplayName` (string) - User-facing plan name (e.g., "Standard")
- `status` (string) - "active", "inactive", "paused", "canceled"
- `stripeSubscriptionId` (string) - Stripe subscription ID (optional, if using Stripe)
- `stripePriceId` (string) - Stripe price ID (optional)
- `currentPeriodStart` (timestamp) - Billing period start (optional, Stripe sync)
- `currentPeriodEnd` (timestamp) - Billing period end (optional, Stripe sync)
- `nextBillingDate` (timestamp) - Next invoice date (from Stripe if present)
- `cancelAtPeriodEnd` (boolean) - Will cancel at period end (Stripe)
- `pauseBehavior` (string) - "mark_uncollectible" if paused (Stripe)
- `createdAt` (timestamp) - Subscription creation date
- `updatedAt` (timestamp) - Last update date
- `canceledAt` (timestamp) - When canceled (if applicable)
**Usage:**
- Read by: `manage_subscription_page_v3.dart`, `pause_resume_subscription_page_v1.dart`, `plan_subscription_page_v3.dart`
- Updated when: User selects/changes meal plan or pauses subscription
- Stripe webhook writes here when: Subscription status changes in Stripe

#### `invoices` Collection (Stripe)
**Purpose:** Invoice history and billing  
**Fields:**
- `id` (string) - Invoice document ID
- `stripeInvoiceId` (string) - Stripe invoice ID
- `userId` (string) - User reference
- `subscriptionId` (string) - Associated subscription
- `amount` (number) - Invoice total in cents
- `status` (string) - "draft", "open", "paid", "void", "uncollectible"
- `items` (array) - Line items
  - `description` (string)
  - `amount` (number)
  - `quantity` (number)
- `paidAt` (timestamp)
- `dueDate` (timestamp)
- `createdAt` (timestamp)
- `updatedAt` (timestamp)

---

### Payment Collections

#### `payments` Collection
**Purpose:** Payment transaction records  
**Fields:**
- `id` (string) - Payment document ID
- `orderId` (string) - Associated order
- `userId` (string) - User who paid
- `squarePaymentId` (string) - Square payment ID
- `squareTransactionId` (string) - Square transaction ID
- `amount` (number) - Payment amount in cents
- `status` (string) - "pending", "completed", "failed", "refunded"
- `paymentMethod` (object) - Payment method details
  - `type` (string) - "card", "cash", "bank_transfer"
  - `cardBrand` (string) - "VISA", "MASTERCARD", etc.
  - `last4` (string) - Last 4 digits
- `platformFee` (number) - FreshPunk fee in cents
- `restaurantEarnings` (number) - Amount sent to restaurant
- `createdAt` (timestamp)
- `completedAt` (timestamp)

---

### Restaurant Collections

#### `restaurant_partners` Collection
**Purpose:** Restaurant partner data and Square integration  
**Fields:**
- `id` (string) - Restaurant document ID
- `restaurantName` (string) - Display name
- `status` (string) - "pending", "active", "suspended", "inactive"
- `email` (string) - Contact email
- `phoneNumber` (string) - Contact phone
- `address` (object) - Restaurant location
  - `street` (string)
  - `city` (string)
  - `state` (string)
  - `zip` (string)
- `squareMerchantId` (string) - Square merchant account ID
- `squareAccessToken` (string) - OAuth token (ENCRYPTED)
- `squareRefreshToken` (string) - Refresh token (ENCRYPTED)
- `squareLocationId` (string) - Square location for orders
- `tokenExpiresAt` (timestamp) - OAuth token expiration
- `menuItemCount` (number) - Count of menu items synced
- `lastMenuSync` (timestamp) - Last Square menu sync
- `deliveryConfig` (object) - Delivery settings
  - `handlingTime` (number) - Prep time in minutes
  - `prepTimeDuration` (string) - ISO 8601 duration
  - `deliveryRadius` (number) - Max delivery distance in miles
- `notificationEmail` (string) - Where to send order notifications
- `createdAt` (timestamp)
- `updatedAt` (timestamp)

#### `restaurant_earnings` Collection
**Purpose:** Track restaurant revenue  
**Fields:**
- `id` (string) - Restaurant ID
- `totalCents` (number) - Cumulative earnings
- `monthlyEarnings` (object) - Monthly breakdown
  - `"YYYY-MM"`: (number) - Earnings for that month
- `updatedAt` (timestamp)

#### `sync_logs` Subcollection (under restaurant_partners)
**Purpose:** Menu sync audit trail  
**Fields:**
- `id` (string) - Log entry ID
- `restaurantId` (string) - Parent restaurant
- `action` (string) - "sync_started", "items_synced", "sync_completed", "sync_failed"
- `itemsCount` (number) - Items affected
- `status` (string) - "success", "partial", "failed"
- `errorMessage` (string) - Error details if failed
- `timestamp` (timestamp)

---

### Notification Collections

#### `notifications` Subcollection (under users)
**Purpose:** User notification history  
**Fields:**
- `id` (string) - Notification ID
- `userId` (string) - Recipient user
- `type` (string) - "order_confirmed", "order_shipped", "payment_received", "promotion", "system"
- `title` (string) - Notification title
- `body` (string) - Message body
- `orderId` (string) - Related order (if applicable)
- `actionUrl` (string) - Deep link or URL
- `read` (boolean)
- `readAt` (timestamp)
- `createdAt` (timestamp)
- `expiresAt` (timestamp) - When notification expires

#### `restaurant_notifications` Subcollection (under restaurant_partners)
**Purpose:** Notifications to restaurant about orders  
**Fields:**
- Same structure as user notifications, but for restaurant staff

---

### Audit & Logging

#### `audit_logs` Collection
**Purpose:** Security and activity audit trail  
**Fields:**
- `id` (string) - Log entry ID
- `action` (string) - What action was performed
- `userId` (string) - Who performed it (null for system)
- `details` (object) - Action details (sanitized)
- `isSuccess` (boolean)
- `errorMessage` (string) - If action failed
- `timestamp` (timestamp)
- `ip` (string) - Request IP (if applicable)

---

## ☁️ CLOUD FUNCTIONS (Firebase Functions)

### Region Configuration
- **Primary:** `us-central1` (120 second timeout default)
- **Secondary:** `us-east4` (for Square integration & scaling)
- **Memory:** 512MB default, 256MB for lightweight functions

### Authentication Functions (in `index.ts` & `firestore_service_v3.dart`)

#### `grantAdminAllowlist` (Callable)
**Purpose:** Grant admin role to users on allowlist  
**Auth:** Requires email on ADMIN_EMAIL_ALLOWLIST secret  
**Inputs:** None (uses auth context)  
**Outputs:** `{success: boolean}`  
**Rate Limit:** 5 attempts per 5 minutes  
**Audit:** Logs all attempts

#### `grantKitchenAccess` (Callable)
**Purpose:** Grant kitchen partner access to order dashboard  
**Auth:** Requires auth token  
**Inputs:** `{userId: string, restaurantId: string}`  
**Outputs:** `{success: boolean, accessToken: string}`  
**Security:** JWT token generation using JWT_SECRET

---

### User Management Functions

#### `createUserProfile()` (Firestore Service - Dart)
**Purpose:** Create new user account in Firestore  
**Inputs:** userId, email, fullName, phoneNumber  
**Outputs:** Void (writes to Firestore)  
**Called By:** Auth flow on sign-up

#### `getUserProfile()` (Firestore Service)
**Purpose:** Retrieve user profile  
**Inputs:** userId (string)  
**Outputs:** User data object

#### `updateUserProfile()` (Firestore Service)
**Purpose:** Update user information  
**Inputs:** userId, updates object  
**Outputs:** Success boolean

---

### Meal Management Functions

#### `listRestaurantMeals` (HTTP)
**Purpose:** Get all meals for a restaurant  
**HTTP Endpoint:** GET `/listRestaurantMeals?restaurantId=...`  
**Region:** us-central1  
**Auth:** Public (CORS enabled)  
**Inputs:** Query param: `restaurantId`  
**Outputs:** 
```json
{
  "restaurantId": "string",
  "mealCount": number,
  "meals": [
    {
      "id": "string",
      "name": "string",
      "price": number,
      "squareItemId": "string",
      "squareVariationId": "string"
    }
  ]
}
```

#### `createTestMeal` (HTTP POST)
**Purpose:** Create a test meal for a restaurant  
**HTTP Endpoint:** POST `/createTestMeal`  
**Auth:** Public (intended for testing)  
**Inputs:**
```json
{
  "restaurantId": "string",
  "name": "string",
  "description": "string",
  "price": number,
  "squareItemId": "string",
  "squareVariationId": "string"
}
```
**Outputs:** `{mealId: string, success: boolean}`

#### `diagnosticMeals` (HTTP)
**Purpose:** Inspect meal data structure  
**HTTP Endpoint:** GET `/diagnosticMeals`  
**Auth:** Public (debugging only)  
**Outputs:** Complete meal inventory with structure analysis

#### `createTestMeal()` (Firestore Service)
**Purpose:** Quick meal creation for testing  
**Inputs:** Meal data  
**Outputs:** Meal ID

---

### Order Management Functions

#### `generateOrderFromMealSelection` (Callable)
**Purpose:** Server-side order creation from user selections  
**Auth:** Requires user authentication  
**Inputs:**
```typescript
{
  mealSelections: Array<{
    restaurantId: string,
    mealId: string,
    quantity: number,
    specialInstructions?: string
  }>,
  deliverySchedule: {
    mealType: string,
    dayOfWeek: number,
    deliveryTime: string
  },
  deliveryAddress: string (address ID or serialized)
}
```
**Outputs:**
```json
{
  "orderId": "string",
  "total": number,
  "estimatedDeliveryTime": "timestamp"
}
```
**Process:**
1. Validates user authentication
2. Retrieves meal data from Firestore
3. Validates delivery address
4. Creates order document in `orders` collection
5. Triggers dispatch flow

#### `confirmNextOrder` (Callable)
**Purpose:** Confirm the next order in queue  
**Auth:** Requires authentication  
**Inputs:** `{orderId: string}`  
**Outputs:** `{success: boolean, orderId: string}`  
**Side Effects:** Sets `userConfirmed: true`, `userConfirmedAt: timestamp`

#### `editOrder` (HTTP)
**Purpose:** Modify order details before dispatch  
**HTTP Endpoint:** POST `/editOrder`  
**Auth:** User token validation  
**Inputs:**
```json
{
  "orderId": "string",
  "updates": {
    "meals": "array",
    "specialInstructions": "string",
    "deliveryAddress": "object"
  }
}
```
**Outputs:** `{success: boolean, updatedOrder: object}`

#### `manuallyForwardOrder` (HTTP)
**Purpose:** Manually send order to Square (bypass automation)  
**HTTP Endpoint:** POST `/manuallyForwardOrder`  
**Auth:** Admin/kitchen staff  
**Inputs:** `{orderId: string}`  
**Outputs:** `{squareOrderId: string, status: string}`

#### `checkOrderStatus` (HTTP)
**Purpose:** Check order status in Firestore  
**HTTP Endpoint:** GET `/checkOrderStatus?orderId=...`  
**Outputs:**
```json
{
  "orderId": "string",
  "status": "string",
  "restaurantId": "string",
  "customerName": "string",
  "squareOrders": "object",
  "createdAt": "timestamp"
}
```

#### `debugOrderData` (HTTP)
**Purpose:** Inspect detailed order data  
**HTTP Endpoint:** GET `/debugOrderData?orderId=...`  
**Outputs:** Full order document with all fields and types

#### `getRecentOrders` (HTTP)
**Purpose:** Retrieve recent orders  
**HTTP Endpoint:** GET `/getRecentOrders`  
**Outputs:** Array of orders with status summary

#### `getUpcomingOrders()` (Firestore Service - Dart)
**Purpose:** Fetch user's upcoming orders  
**Query:** WHERE `status` IN ['pending', 'confirmed']  
**Outputs:** List of order maps

#### `getPastOrders()` (Firestore Service - Dart)
**Purpose:** Fetch user's order history  
**Query:** WHERE `status` IN ['delivered', 'cancelled']  
**Outputs:** List of order maps, sorted by date DESC, limit 20

#### `replaceNextUpcomingOrderMealOfType()` (Firestore Service - Dart)
**Purpose:** Change meal selection in upcoming order  
**Inputs:** userId, mealType, newMealId  
**Outputs:** Boolean success

---

### Subscription & Billing Functions

#### `createSubscription` (Callable)
**Purpose:** Create Stripe subscription for user  
**Auth:** Requires authentication  
**Inputs:**
```json
{
  "customerId": "string",
  "priceId": "string",
  "billingCycle": "weekly|monthly",
  "mealPlan": "1meal|2meal|3meal"
}
```
**Outputs:** `{subscriptionId: string, status: string}`  
**Stripe Integration:** Creates subscription via Stripe API

#### `createSubscriptionInvoice` (Callable)
**Purpose:** Create and finalize Stripe invoice  
**Auth:** Requires authentication  
**Inputs:**
```json
{
  "customerId": "string",
  "subscriptionPricing": {
    "mealCost": number,
    "deliveryFee": number,
    "discount": number
  },
  "mealSelections": "array"
}
```
**Outputs:** `{invoiceId: string, amount: number, pdfUrl: string}`  
**Process:**
1. Validates customer
2. Calculates upfront charges
3. Creates draft invoice
4. Finalizes invoice
5. Returns PDF link

#### `getInvoiceDetails` (Callable)
**Purpose:** Retrieve invoice information  
**Inputs:** `{invoiceId: string}`  
**Outputs:** Invoice data object with line items

#### `cancelSubscription` (Callable)
**Purpose:** Cancel user's subscription  
**Inputs:** `{subscriptionId: string}`  
**Outputs:** `{success: boolean}`  
**Side Effect:** Sets `cancelAtPeriodEnd: true` in Stripe

#### `pauseSubscription` (Callable)
**Purpose:** Temporarily pause subscription  
**Inputs:** `{subscriptionId: string, resumeDate: timestamp}`  
**Outputs:** `{paused: boolean, resumeDate: timestamp}`

#### `resumeSubscription` (Callable)
**Purpose:** Resume paused subscription  
**Inputs:** `{subscriptionId: string}`  
**Outputs:** `{resumed: boolean}`

#### `updateSubscription` (Callable)
**Purpose:** Change subscription plan  
**Inputs:**
```json
{
  "subscriptionId": "string",
  "newPriceId": "string",
  "mealSelections": "array"
}
```
**Outputs:** `{success: boolean, newAmount: number}`

#### `backfillStripeSubscriptions` (Callable)
**Purpose:** Admin tool to sync Stripe subscription data  
**Auth:** Admin required  
**Process:**
1. Finds users missing `stripeSubscriptionId`
2. Queries Stripe for subscriptions by customer ID
3. Selects subscription with highest priority status
4. Writes back normalized fields

#### `getBillingOptions` (Callable)
**Purpose:** Return available subscription plans  
**Auth:** Public  
**Outputs:**
```json
{
  "plans": [
    {
      "id": "string",
      "name": "string",
      "mealsPerDay": number,
      "pricePerWeek": number,
      "stripePriceId": "string"
    }
  ]
}
```

---

### Payment Functions

#### `createPaymentIntent` (Callable)
**Purpose:** Create Stripe PaymentIntent for checkout  
**Auth:** Requires authentication  
**Inputs:**
```json
{
  "orderId": "string",
  "amount": number
}
```
**Outputs:** `{clientSecret: string, publishableKey: string}`

#### `createCustomer` (Callable)
**Purpose:** Create Stripe customer account  
**Auth:** Requires authentication  
**Inputs:** `{email: string, name: string}`  
**Outputs:** `{customerId: string}`

#### `createSetupIntent` (Callable)
**Purpose:** Create SetupIntent for saving payment method  
**Auth:** Requires authentication  
**Outputs:** `{clientSecret: string}`

#### `retrieveSetupIntent` (Callable)
**Purpose:** Retrieve SetupIntent details  
**Inputs:** `{setupIntentId: string}`  
**Outputs:** SetupIntent object with payment method

#### `createTestPaymentMethod` (Callable)
**Purpose:** Create test payment method for testing  
**Auth:** Testing only  
**Inputs:** `{type: "visa"|"mastercard"|"declined"}`  
**Outputs:** `{paymentMethodId: string, token: string}`

#### `listPaymentMethods` (Callable)
**Purpose:** List user's saved payment methods  
**Auth:** Requires authentication  
**Outputs:** Array of payment method objects with last 4 digits

#### `detachPaymentMethod` (Callable)
**Purpose:** Remove saved payment method  
**Auth:** Requires authentication  
**Inputs:** `{paymentMethodId: string}`  
**Outputs:** `{success: boolean}`

#### `setDefaultPaymentMethod` (Callable)
**Purpose:** Set primary payment method  
**Auth:** Requires authentication  
**Inputs:** `{paymentMethodId: string}`  
**Outputs:** `{success: boolean}`

#### `processSquarePayment` (Callable, from `square-payments.ts`)
**Purpose:** Process payment through Square API  
**Auth:** Requires authentication  
**Inputs:**
```json
{
  "orderId": "string",
  "restaurantId": "string",
  "amount": number,
  "paymentMethod": "square_payment_id"
}
```
**Outputs:** `{success: boolean, squarePaymentId: string}`  
**Side Effects:**
1. Records payment in `payments` collection
2. Updates order with `paymentStatus: "paid"`
3. Tracks restaurant earnings in `restaurant_earnings`
4. Logs audit event

#### `getRestaurantEarnings` (Callable, from `square-payments.ts`)
**Purpose:** Get restaurant revenue total  
**Auth:** Restaurant staff  
**Inputs:** `{restaurantId: string}`  
**Outputs:**
```json
{
  "totalEarnings": number,
  "monthlyBreakdown": {
    "2026-01": number,
    "2026-02": number
  }
}
```

#### `createRestaurantPayout` (Callable, from `square-payments.ts`)
**Purpose:** Generate payout to restaurant bank account  
**Auth:** Admin/Accounting  
**Inputs:**
```json
{
  "restaurantId": "string",
  "amount": number,
  "bankAccountId": "string"
}
```
**Outputs:** `{payoutId: string, status: string, estimatedArrivalTime: timestamp}`  
**Integration:** Uses Square Payouts API

---

### Square Integration Functions (from `square-integration.ts`)

#### `initiateSquareOAuthHttp` (HTTP)
**Purpose:** Start Square OAuth flow  
**HTTP Endpoint:** GET `/initiateSquareOAuthHttp?restaurantId=...`  
**Region:** us-east4  
**Auth:** Public (OAuth redirect)  
**Inputs:** Query param: `restaurantId`  
**Outputs:** Redirects to Square consent URL

#### `completeSquareOAuthHttp` (HTTP)
**Purpose:** Handle Square OAuth callback  
**HTTP Endpoint:** GET `/completeSquareOAuthHttp?code=...&state=...`  
**Region:** us-east4  
**Process:**
1. Extracts authorization code
2. Exchanges for access token via Square API
3. Stores encrypted tokens in `restaurant_partners`
4. Sets token expiration
5. Triggers menu sync
6. Redirects to success page

#### `squareOAuthTestPage` (HTTP)
**Purpose:** Simple OAuth testing interface  
**HTTP Endpoint:** GET `/squareOAuthTestPage`  
**Outputs:** HTML form for OAuth testing

#### `diagnoseSquareOAuth` (HTTP)
**Purpose:** Debug OAuth credential issues  
**HTTP Endpoint:** GET `/diagnoseSquareOAuth?restaurantId=...`  
**Outputs:** Credential status, token expiration, last sync info

#### `syncSquareMenu` (Callable, from `square-integration.ts`)
**Purpose:** Sync menu from Square to Firestore  
**Auth:** Restaurant staff  
**Inputs:** `{restaurantId: string}`  
**Process:**
1. Retrieves restaurant OAuth credentials
2. Calls Square Catalog API
3. Parses items and variations
4. Creates/updates meal documents in Firestore
5. Logs sync results
**Outputs:** `{synced: number, created: number, updated: number, errors: array}`

#### `forwardOrderToSquare` (HTTP, also Callable)
**Purpose:** Send confirmed order to restaurant's Square account  
**HTTP Endpoint:** POST `/forwardOrderToSquare`  
**Region:** us-east4  
**Auth:** Cloud Function (triggered by order status)  
**Inputs:** `{orderId: string, restaurantId: string}`  
**Process:**
1. Retrieves order from Firestore
2. Retrieves restaurant Square credentials
3. Groups meals by restaurant
4. Creates Square order with:
   - Line items with catalog object IDs
   - Customer info (name, email, phone)
   - Delivery address
   - Fulfillment details:
     - Type: DELIVERY
     - State: PROPOSED (initial state for Orders page visibility)
     - Schedule: SCHEDULED with delivery time
     - Recipient: Customer name, phone, email
     - Delivery address (formatted per Square requirements)
     - Note: Special instructions and expected delivery time
5. Records Square Order ID in Firestore
6. Returns Square Order ID
**Outputs:** `{squareOrderId: string, success: boolean, error?: string}`  
**Data Structure Sent to Square:**
```json
{
  "order": {
    "location_id": "string",
    "source": {
      "name": "FreshPunk"
    },
    "customer_id": "string",
    "line_items": [
      {
        "catalog_object_id": "string",
        "quantity": "1"
      }
    ],
    "fulfillments": [
      {
        "type": "DELIVERY",
        "state": "PROPOSED",
        "delivery_details": {
          "schedule_type": "SCHEDULED",
          "deliver_at": "ISO8601",
          "prep_time_duration": "PT45M",
          "recipient": {
            "display_name": "string",
            "phone_number": "string",
            "email_address": "string"
          },
          "delivery_address": {
            "address_line_1": "string",
            "address_line_2": "string",
            "locality": "string",
            "administrative_district_level_1": "string",
            "postal_code": "string",
            "country": "US"
          },
          "note": "string",
          "is_no_contact": false
        }
      }
    ],
    "reference_id": "string"
  }
}
```

#### `forwardOrderOnStatusUpdate` (Callable, Firestore trigger)
**Purpose:** Auto-forward order when status changes to "confirmed"  
**Trigger:** onDocumentUpdated on `orders/{orderId}`  
**Region:** us-east4  
**Condition:** `status: "confirmed"`  
**Process:** Calls `forwardOrderToSquare` internally

#### `updateFulfillmentState` (Callable, from `fulfillment-state-management.ts`)
**Purpose:** Update Square order fulfillment state  
**Valid States:** PROPOSED → ACCEPTED → PREPARED → COMPLETED  
**Auth:** Restaurant staff  
**Inputs:**
```json
{
  "orderId": "string",
  "squareOrderId": "string",
  "newState": "PROPOSED|ACCEPTED|PREPARED|COMPLETED"
}
```
**Outputs:** `{success: boolean, previousState: string, newState: string}`  
**Audit:** Logs state transition

#### `updateFulfillmentStateHttp` (HTTP, from `fulfillment-state-management.ts`)
**Purpose:** HTTP endpoint for state updates  
**HTTP Endpoint:** POST `/updateFulfillmentStateHttp`  
**Same inputs/outputs as callable**

#### `syncOrderStatusToSquare` (Callable)
**Purpose:** Two-way sync between Firestore and Square  
**Inputs:** `{orderId: string}`  
**Process:**
1. Fetches Square order details
2. Updates Firestore order with latest status
3. Writes audit log

#### `devListRecentSquareOrders` (HTTP)
**Purpose:** List recent orders from Square  
**HTTP Endpoint:** GET `/devListRecentSquareOrders?restaurantId=...&limit=10`  
**Region:** us-east4  
**Outputs:** Array of recent Square orders

#### `devFindSquareOrderByReference` (HTTP)
**Purpose:** Find Square order by FreshPunk reference ID  
**HTTP Endpoint:** GET `/devFindSquareOrderByReference?restaurantId=...&referenceId=...`  
**Outputs:** Square order details

#### `devGetSquareOrderDetails` (HTTP)
**Purpose:** Get full details of a Square order  
**HTTP Endpoint:** GET `/devGetSquareOrderDetails?restaurantId=...&squareOrderId=...`  
**Outputs:** Complete Square order object

#### `squareWhoAmI` (HTTP)
**Purpose:** Verify Square API access and get merchant info  
**HTTP Endpoint:** GET `/squareWhoAmI?restaurantId=...`  
**Outputs:** Merchant account details, permissions, location info

#### `devForceSyncSquareMenu` (HTTP)
**Purpose:** Force immediate menu sync  
**HTTP Endpoint:** POST `/devForceSyncSquareMenu`  
**Auth:** Admin  
**Outputs:** Sync results

#### `checkMenuSyncStatus` (HTTP, from `menu-diagnostics.ts`)
**Purpose:** Check menu synchronization status  
**HTTP Endpoint:** GET `/checkMenuSyncStatus`  
**Outputs:**
```json
{
  "partners": [
    {
      "id": "string",
      "restaurantName": "string",
      "status": "string",
      "menuItemCount": number,
      "lastMenuSync": "timestamp"
    }
  ],
  "syncLogs": [
    {
      "restaurantId": "string",
      "action": "string",
      "status": "success|failed",
      "timestamp": "timestamp"
    }
  ]
}
```

#### `checkSquareCatalog` (HTTP, from `check-square-catalog.ts`)
**Purpose:** Inspect Square catalog items  
**HTTP Endpoint:** GET `/checkSquareCatalog?restaurantId=...`  
**Outputs:** List of catalog items with IDs and variations

#### `testSquareDeliveryConfig` (HTTP, from `test-square-delivery.ts`)
**Purpose:** Test delivery configuration  
**HTTP Endpoint:** POST `/testSquareDeliveryConfig`  
**Inputs:** Test delivery details  
**Outputs:** Validation results

#### `verifySquareAddresses` (HTTP, from `verify-square-address.ts`)
**Purpose:** Validate addresses with Square API  
**HTTP Endpoint:** POST `/verifySquareAddresses`  
**Inputs:** Array of addresses  
**Outputs:** Verified addresses with corrections

---

### Restaurant Management Functions

#### `registerRestaurantPartner` (Callable, from `restaurant-notifications.ts`)
**Purpose:** Create new restaurant partner record  
**Auth:** Admin  
**Inputs:**
```json
{
  "restaurantName": "string",
  "email": "string",
  "phoneNumber": "string",
  "address": "object",
  "squareMerchantId": "string"
}
```
**Outputs:** `{restaurantId: string, success: boolean}`

#### `manualCreateRestaurant` (HTTP, from `manual-create-restaurant.ts`)
**Purpose:** Manually create restaurant without OAuth  
**HTTP Endpoint:** POST `/manualCreateRestaurant`  
**Auth:** Admin  
**Inputs:** Restaurant data  
**Outputs:** Restaurant ID

#### `checkRestaurantSquareSetup` (HTTP)
**Purpose:** Verify restaurant Square configuration  
**HTTP Endpoint:** GET `/checkRestaurantSquareSetup?restaurantId=...`  
**Outputs:**
```json
{
  "restaurantId": "string",
  "setupComplete": boolean,
  "status": "string",
  "missingFields": "array"
}
```

#### `searchRestaurants` (HTTP)
**Purpose:** Search restaurants by name or location  
**HTTP Endpoint:** GET `/searchRestaurants?q=...`  
**Outputs:** Array of matching restaurants

#### `listAllRestaurants` (HTTP)
**Purpose:** List all active restaurants  
**HTTP Endpoint:** GET `/listAllRestaurants`  
**Outputs:** Array of restaurants with basic info

#### `dumpAllRestaurants` (HTTP)
**Purpose:** Export all restaurant data (admin debugging)  
**HTTP Endpoint:** GET `/dumpAllRestaurants`  
**Auth:** Admin  
**Outputs:** Full restaurant inventory

#### `debugRestaurantPartners` (HTTP, from `debug-restaurant-partners.ts`)
**Purpose:** Debug restaurant configuration  
**HTTP Endpoint:** GET `/debugRestaurantPartners?restaurantId=...`  
**Outputs:** Detailed partner data and OAuth status

#### `getRestaurantOAuthCredentials` (HTTP, from `get-oauth-credentials.ts`)
**Purpose:** Retrieve OAuth credentials (for password recovery flow)  
**Auth:** Admin/Restaurant  
**Inputs:** `restaurantId`  
**Outputs:** Masked credentials for verification

#### `copyOAuthCredentials` (HTTP, from `copy-oauth-credentials.ts`)
**Purpose:** Copy credentials between restaurant accounts  
**Auth:** Admin  
**Inputs:** Source and destination restaurant IDs  
**Outputs:** `{success: boolean}`

#### `refreshOAuthToken` (HTTP, from `refresh-oauth-token.ts`)
**Purpose:** Refresh expired Square OAuth token  
**Auth:** Automatic or manual trigger  
**Process:**
1. Checks token expiration
2. Uses refresh token to get new access token
3. Updates Firestore with new tokens
4. Logs refresh event
**Outputs:** `{success: boolean, expiresAt: timestamp}`

#### `manualOAuthEntry` (HTTP, from `manual-oauth-helper.ts`)
**Purpose:** Provide manual OAuth token entry (if consent UI fails)  
**HTTP Endpoint:** GET `/manualOAuthEntry`  
**Outputs:** HTML form for manual token input

#### `manualOAuthSave` (HTTP, from `manual-oauth-save.ts`)
**Purpose:** Save manually entered OAuth credentials  
**HTTP Endpoint:** POST `/manualOAuthSave`  
**Inputs:**
```json
{
  "restaurantId": "string",
  "accessToken": "string",
  "refreshToken": "string",
  "expiresAt": "timestamp"
}
```
**Outputs:** `{success: boolean}`

---

### Notification Functions (from `restaurant-notifications.ts`)

#### `notifyRestaurantsOnOrder` (Firestore trigger)
**Purpose:** Notify restaurant when order is confirmed  
**Trigger:** onDocumentCreated on `orders/{orderId}`  
**Condition:** `status: "confirmed"`  
**Recipient:** Restaurant's `notificationEmail`  
**Email Content:**
- Order ID and details
- Customer info and delivery address
- Meal list with quantities
- Special instructions
- Estimated delivery time
**Process:**
1. Reads order and restaurant data
2. Sends email via Gmail (using nodemailer)
3. Logs notification in `restaurant_notifications` subcollection
4. Tracks delivery status

#### `notifyRestaurantsOnSubscription` (Firestore trigger)
**Purpose:** Notify restaurant of new subscription  
**Trigger:** onDocumentCreated on `subscriptions/{subscriptionId}`  
**Email Content:**
- Meal plan details
- Delivery schedule
- Weekly meal selections
- Duration and pricing

#### `sendRestaurantOrderNotification` (Callable)
**Purpose:** Manually send order notification  
**Auth:** Admin  
**Inputs:** `{orderId: string}`  
**Outputs:** `{sent: boolean, timestamp: timestamp}`

#### `getRestaurantOrders` (HTTP)
**Purpose:** Get restaurant's recent orders  
**HTTP Endpoint:** GET `/getRestaurantOrders?restaurantId=...`  
**Outputs:** Array of orders with status

#### `weeklyRestaurantScheduleReminder` (Scheduled, Pub/Sub)
**Purpose:** Send weekly prep schedule email  
**Schedule:** Every Monday at 6 AM EST  
**Region:** us-east4  
**Process:**
1. Queries upcoming orders for the week
2. Groups by restaurant
3. Sends email with full prep schedule
4. Includes: meals, quantities, delivery times, addresses
5. Logs reminders sent

#### `sendWeeklyPrepSchedules` (Scheduled)
**Purpose:** Alternative weekly schedule distribution  
**Schedule:** Same as above

---

### Address Functions (from `firestore_service_v3.dart`)

#### `getUserAddresses()` (Firestore Service - Dart)
**Purpose:** Fetch user's saved addresses  
**Inputs:** userId (string)  
**Outputs:** List of AddressModelV3 objects

#### `addUserAddress()` (Firestore Service - Dart)
**Purpose:** Save new delivery address  
**Inputs:** userId, address object  
**Outputs:** Address ID

#### `updateUserAddress()` (Firestore Service - Dart)
**Purpose:** Modify existing address  
**Inputs:** userId, addressId, updates  
**Outputs:** Success boolean

#### `deleteUserAddress()` (Firestore Service - Dart)
**Purpose:** Remove address  
**Inputs:** userId, addressId  
**Outputs:** Success boolean

#### `geocodeAddress` (Callable)
**Purpose:** Convert address to coordinates  
**Auth:** Requires authentication  
**Inputs:** `{address: string}`  
**Outputs:**
```json
{
  "latitude": number,
  "longitude": number,
  "formattedAddress": "string",
  "verified": boolean
}
```
**Integration:** Google Geocoding API (server-side key)

---

### Diagnostic & Testing Functions

#### `ping` (Callable)
**Purpose:** Health check / connectivity test  
**Inputs:** None  
**Outputs:** `{ok: true, time: timestamp, version: "2.0.0"}`  
**Rate Limit:** 60 per minute per IP

#### `testFirestoreWrite` (HTTP, from `test-firestore-write.ts`)
**Purpose:** Test Firestore write capability  
**HTTP Endpoint:** POST `/testFirestoreWrite`  
**Process:** Creates test document and reads it back  
**Outputs:** `{success: boolean, documentId: string}`

#### `diagnoseDatabase` (HTTP, from `diagnose-database.ts`)
**Purpose:** Check database structure and credentials  
**HTTP Endpoint:** GET `/diagnoseDatabase`  
**Outputs:** Restaurant and OAuth credential status

#### `checkSquareEnvironment` (HTTP)
**Purpose:** Verify Square API connectivity  
**HTTP Endpoint:** GET `/checkSquareEnvironment`  
**Outputs:** Square API status and available endpoints

#### `testSquareOrderCreation` (HTTP)
**Purpose:** Create test order in Square directly  
**HTTP Endpoint:** POST `/testSquareOrderCreation?restaurantId=...`  
**Outputs:** Square Order ID and status

#### `createTestOrder` (Callable)
**Purpose:** Server-side test order creation  
**Auth:** Public (for testing)  
**Outputs:** Order ID in Firestore

---

### FCM & Push Notifications

#### `registerFcmToken` (Callable)
**Purpose:** Register device for push notifications  
**Auth:** Requires authentication  
**Inputs:**
```json
{
  "token": "string",
  "platform": "ios|android|web"
}
```
**Outputs:** `{success: true}`  
**Storage:** Saves to `users/{userId}/fcmTokens/{token}`

#### Notification Triggers (Firestore)
**Purpose:** Send push notifications on order status changes  
**Trigger:** onDocumentUpdated on `orders/{orderId}`  
**Conditions:**
- Status changed to "outForDelivery" → "Order is out for delivery"
- Status changed to "delivered" → "Order delivered!"
- Status changed to "cancelled" → "Order cancelled"

---

### Stripe Webhook Handler

#### `stripeWebhook` (HTTP)
**Purpose:** Process Stripe events  
**HTTP Endpoint:** POST `/stripeWebhook`  
**Region:** us-east4  
**Auth:** STRIPE_WEBHOOK_SECRET signature verification  
**Handled Events:**
- `customer.created` → Create user in Firestore
- `customer.subscription.created` → Create subscription record
- `customer.subscription.updated` → Update subscription status
- `charge.completed` → Record payment
- `charge.refunded` → Process refund
- `invoice.payment_succeeded` → Log successful invoice payment
- `invoice.payment_failed` → Log payment failure
**Process:**
1. Verifies webhook signature
2. Parses event
3. Executes corresponding handler
4. Writes to `audit_logs` and `stripe_webhooks` collections
5. Returns 200 OK to Stripe

---

## 🔐 AUTHENTICATION & AUTHORIZATION

### Authentication Methods

1. **Email/Password** (Firebase)
   - Sign up: Email + password validation
   - Sign in: Email + password
   - Password reset: Email verification link
   - Storage: Firebase Auth (NOT Firestore)

2. **Google Sign-In**
   - OAuth 2.0 via Firebase
   - Web config: `AIzaSyCo8B9rp5xliWRtybccAt-_8YcCuswBMrs`
   - iOS config: `AIzaSyCo8B9rp5xliWRtybccAt-_8YcCuswBMrs`
   - iOS Bundle: `com.Victus.flutterApplication1`
   - Android: `com.example.flutter_application_1`

3. **Apple Sign-In**
   - OAuth via Firebase
   - Platform-specific: iOS only

4. **Phone Authentication (SMS)**
   - Firebase Phone Auth
   - SMS OTP verification
   - International number support

5. **Custom JWT** (Kitchen Partner)
   - For restaurant staff dashboard
   - Generated by `grantKitchenAccess`
   - Uses JWT_SECRET

### Authorization Levels

- **Public:** No auth required
- **User:** Authentication required
- **Admin:** Custom claim `admin: true`
- **Restaurant:** Custom claim `restaurant_partner: true`
- **Kitchen:** JWT token from kitchen partner auth

---

## 🔗 EXTERNAL INTEGRATIONS

### 1. Stripe Payment Processing

**API Version:** Latest (v3 implied from SDK)  
**Environment:** Production  
**Credentials:** STRIPE_SECRET_KEY (secret)  
**Webhook Secret:** STRIPE_WEBHOOK_SECRET  

**Operations:**
- Create customer
- Create/manage payment intents
- Create/manage setup intents
- Create subscriptions
- Create invoices
- Process refunds
- List payment methods
- Attach/detach payment methods

**Data Flow:**
```
Flutter App → Stripe.js → Client secret → Payment Intent
                                            ↓
                                      Server validates
                                            ↓
                                      Update Firestore
```

---

### 2. Square Point of Sale Integration

**API Version:** Square REST API v2  
**Environment:** Production  
**Merchant:** Victus Restaurant (test account)  
**Location ID:** Configured per restaurant  
**OAuth Scopes:**
- `orders:write` - Create/update orders
- `orders:read` - Read orders
- `catalog:read` - Access menu items
- `payments:read` - Read payment info
- `merchants:read` - Get merchant info

**OAuth Credentials Storage:**
- Access token: Encrypted in `restaurant_partners.squareAccessToken`
- Refresh token: Encrypted in `restaurant_partners.squareRefreshToken`
- Expires: Stored in `restaurant_partners.tokenExpiresAt`
- Auto-refresh: Handled by `refreshOAuthToken` function

**Data Sync:**
- Menu → Square Catalog API
- Orders → Square Orders API
- Fulfillment state → Square Fulfillment API
- Payments → Square Payments API
- Payouts → Square Payouts API

**Key Endpoints:**
- `POST /v2/orders` - Create delivery order
- `PUT /v2/orders/{order_id}` - Update fulfillment
- `GET /v2/catalog/list` - Get menu items
- `POST /v2/payments` - Process payment
- `GET /v2/locations` - Get merchant locations
- `POST /v2/bank-accounts` - Payout configuration

**Order Format to Square:**
```typescript
{
  location_id: string,
  source: { name: "FreshPunk" },
  customer_id: string,
  line_items: [{
    catalog_object_id: string,
    quantity: number
  }],
  fulfillments: [{
    type: "DELIVERY",
    state: "PROPOSED",
    delivery_details: {
      schedule_type: "SCHEDULED",
      deliver_at: ISO8601String,
      prep_time_duration: "PT45M",
      recipient: { display_name, phone_number, email },
      delivery_address: { /* full address */ },
      is_no_contact: false
    }
  }],
  reference_id: "freshpunk_order_id"
}
```

---

### 3. Firebase Services

#### Cloud Firestore
- Primary database
- All collections listed above
- Indexes configured for complex queries
- Real-time listeners for orders and subscriptions

#### Firebase Authentication
- Email/password
- Google Sign-In
- Apple Sign-In
- Phone authentication

#### Firebase Cloud Functions
- 50+ serverless functions
- Regions: us-central1, us-east4
- Secrets: Stripe keys, Google Geocoding, Admin allowlist, JWT
- Memory: 256MB-512MB per function
- Timeout: 60-300 seconds depending on function

#### Firebase Cloud Storage
- Meal images
- CORS configured for web access
- Firebase Hosting CDN

#### Firebase Cloud Messaging (FCM)
- Push notifications
- Device token registration
- Order status notifications

#### Firebase Hosting
- Web application hosting
- Custom domain: https://freshpunk-48db1.web.app
- Redirect rules in firebase.json
- Preview channels for testing

#### Firebase Realtime Database
- Used sparingly (mostly Firestore)
- Config data storage if needed

---

### 4. Google Services

#### Google Maps API
- Server-side geocoding via GOOGLE_GEOCODE_KEY
- Address validation and coordinates
- Distance calculations for delivery

#### Google Sign-In OAuth
- Web: Google API credentials
- iOS: `AIzaSyCo8B9rp5xliWRtybccAt-_8YcCuswBMrs`
- Android: Same API key

---

### 5. Email Service

**Provider:** Gmail (via nodemailer in Node.js)  
**Credentials:** GMAIL_USER, GMAIL_PASSWORD (secrets)  
**Use Cases:**
- Order confirmations to restaurants
- Subscription notifications
- Weekly prep schedules
- Invoice delivery

**Email Templates:**
- Order confirmation with full details
- Weekly schedule with prep times
- Invoice with line items and total
- Subscription confirmation

---

## 📊 DATA FLOWS & OPERATIONS

### Order Creation Flow

```
User selects meals (Flutter app)
         ↓
POST generateOrderFromMealSelection
         ↓
Validate meals & address in Firestore
         ↓
Create order document (status: "pending")
         ↓
User confirms order (status → "confirmed")
         ↓
Firestore trigger fires
         ↓
forwardOrderOnStatusUpdate executes
         ↓
forwardOrderToSquare function called
         ↓
Retrieve restaurant Square credentials
         ↓
Call Square Orders API → Create order (state: PROPOSED)
         ↓
Write squareOrderId to Firestore
         ↓
Send email to restaurant
         ↓
Send FCM notification to user
```

---

### Subscription Creation Flow

```
User selects meal plan & schedule (Flutter)
         ↓
POST createSubscription with details
         ↓
Create Stripe customer (if new)
         ↓
Create Stripe subscription with price
         ↓
Stripe webhook: subscription.created
         ↓
Create subscription document in Firestore
         ↓
Send email notification to restaurant
         ↓
Generate weekly orders based on schedule
         ↓
Recurring: Weekly orders auto-created at scheduled time
```

---

### Payment Processing Flow

```
Order total calculated
         ↓
POST createPaymentIntent
         ↓
Stripe creates PaymentIntent
         ↓
Flutter app displays Stripe UI
         ↓
User enters payment details
         ↓
Stripe processes payment
         ↓
Stripe webhook: charge.completed
         ↓
Write payment to payments collection
         ↓
Update order: paymentStatus = "paid"
         ↓
Calculate platform fee (FreshPunk share)
         ↓
Calculate restaurant earnings
         ↓
Update restaurant_earnings collection
         ↓
Can now proceed with order fulfillment
```

---

### Menu Synchronization Flow

```
Restaurant OAuth with Square
         ↓
completeSquareOAuthHttp stores tokens
         ↓
Auto-trigger syncSquareMenu
         ↓
Retrieve access token from Firestore
         ↓
Call Square Catalog API → List items
         ↓
Parse items and variations
         ↓
Create/update meal documents in Firestore
         ↓
Log sync in sync_logs subcollection
         ↓
Update lastMenuSync timestamp
```

---

## 📈 REPORTING & ANALYTICS

### Collections used for reporting:
- `orders` - Order volume, status distribution
- `payments` - Revenue, transaction amounts, failures
- `restaurant_earnings` - Restaurant revenue tracking
- `subscriptions` - Active subscriptions, churn
- `audit_logs` - System activity, security events
- `sync_logs` - Menu sync success rate

### Key Metrics:
- Daily orders created
- Conversion rate (pending → confirmed)
- Average order value
- Restaurant earnings by month
- Subscription active/cancelled
- Menu sync success rate
- Payment failure rate

---

## 🔒 SECURITY IMPLEMENTATION

### Secrets Management
- Stored in Firebase Secrets Manager
- Injected via `defineSecret()` at runtime
- Never logged or exposed in errors
- Auto-rotated by Firebase

**Secrets:**
1. `STRIPE_SECRET_KEY` - Stripe payments
2. `STRIPE_WEBHOOK_SECRET` - Webhook validation
3. `GOOGLE_GEOCODE_KEY` - Address geocoding
4. `GMAIL_USER` / `GMAIL_PASSWORD` - Email service
5. `JWT_SECRET` - Kitchen partner auth
6. `ADMIN_EMAIL_ALLOWLIST` - Admin grant allowlist

### Input Validation
- All user inputs sanitized with `sanitizeInput()`
- String length limits (1000 chars)
- Number range limits
- Array size limits (100 items max)
- Email format validation

### Rate Limiting
- In-memory rate limit store
- Configurable per endpoint
- Default: 100 requests per 60 seconds
- Admin grant: 5 requests per 5 minutes

### Audit Logging
- All sensitive actions logged to `audit_logs`
- User ID, action, timestamp recorded
- Success/failure status
- Error messages (non-sensitive)
- Sanitized details object

### Authentication Checks
- All callables verify `request.auth`
- Custom claims for roles (admin, restaurant)
- UID format validation
- Email format validation

### CORS Configuration
```json
{
  "origins": [
    "https://freshpunk-48db1.web.app",
    "https://freshpunk-48db1.firebaseapp.com",
    "http://localhost:5000",
    "http://localhost:3000",
    "http://localhost:5173"
  ]
}
```

---

## 📦 EXTERNAL DEPENDENCIES

### Node.js (Cloud Functions)
- `firebase-admin` v12+ - Firebase SDK
- `firebase-functions` v4+ - Cloud Functions
- `stripe` v14+ - Stripe SDK
- `nodemailer` v6+ - Email sending
- `typescript` v5.8+ - TypeScript compiler
- `eslint` - Code linting

### Flutter (Mobile/Web)
- `firebase_auth` - Authentication
- `cloud_firestore` - Database
- `firebase_messaging` - Push notifications
- `firebase_storage` - Cloud storage
- `stripe_flutter` - Stripe payment UI
- `google_maps_flutter` - Maps integration
- `google_sign_in` - Google OAuth
- `sign_in_with_apple` - Apple Sign-In
- `intl` - Internationalization

---

## 🌐 HOSTING & DEPLOYMENT

### Firebase Hosting
- Primary domain: https://freshpunk-48db1.web.app
- Fallback: https://freshpunk-48db1.firebaseapp.com
- Redirects configured in firebase.json
- Preview channels available

### Cloud Functions Deployment
```bash
firebase deploy --only functions --project freshpunk-48db1
```

### Regions
- Primary: us-central1 (120 second timeout)
- Secondary: us-east4 (for Square integration)

---

## 📋 SUMMARY STATISTICS

**Total Cloud Functions:** 50+  
**Firestore Collections:** 15+  
**External APIs:** 3 (Stripe, Square, Google)  
**Authentication Methods:** 5 (Email, Google, Apple, Phone, JWT)  
**Total Fields Across Models:** 200+  
**Scheduled Functions:** 2 (Weekly reminders)  
**Firestore Triggers:** 4 (onDocumentCreated/Updated)  
**Payment Systems:** 2 (Stripe + Square)  
**Notification Channels:** 3 (Email, FCM, SMS)

---

## 🚀 CRITICAL ENDPOINTS (FOR INTEGRATION TESTING)

### Production Base URLs
- **Cloud Functions:** https://us-central1-freshpunk-48db1.cloudfunctions.net/
- **Alternative Region:** https://us-east4-freshpunk-48db1.cloudfunctions.net/
- **Firebase Hosting:** https://freshpunk-48db1.web.app

### Must-Test Endpoints
1. `/ping` - Health check
2. `/listAllRestaurants` - Restaurant list
3. `/listRestaurantMeals?restaurantId=fd1JQwNpIesg7HOEMeCv` - Menu
4. `/forwardOrderToSquare` - Order forwarding
5. `/checkOrderStatus?orderId=...` - Order tracking
6. `/stripeWebhook` - Payment webhooks
7. `/completeSquareOAuthHttp` - OAuth callback

---

**END OF TECHNICAL INVENTORY**

This document contains the complete technical specification for FreshPunk as of January 27, 2026. For updates, refer to git history and codebase comments.
