# Stripe Backend API Documentation

This document outlines the backend API endpoints required for Stripe integration with your Flutter app.

## Required Backend Endpoints

You'll need to create these endpoints on your backend server (Node.js, Python, etc.) to handle Stripe operations securely.

### 1. Create Customer
**POST** `/create-customer`

Creates a new Stripe customer.

**Request Body:**
```json
{
  "email": "user@example.com",
  "name": "John Doe"
}
```

**Response:**
```json
{
  "id": "cus_xxxxxxxxxx",
  "email": "user@example.com",
  "name": "John Doe"
}
```

### 2. Create Setup Intent
**POST** `/create-setup-intent`

Creates a setup intent for saving payment methods.

**Request Body:**
```json
{
  "customer": "cus_xxxxxxxxxx",
  "automatic_payment_methods": {
    "enabled": true
  }
}
```

**Response:**
```json
{
  "id": "seti_xxxxxxxxxx",
  "client_secret": "seti_xxxxxxxxxx_secret_xxxxxxxxxx"
}
```

### 3. Create Subscription
**POST** `/create-subscription`

Creates a new Stripe subscription.

**Request Body:**
```json
{
  "customer": "cus_xxxxxxxxxx",
  "payment_method": "pm_xxxxxxxxxx",
  "price_id": "price_1MpSYpHB8mNBBYgB7QqDlFEn"
}
```

**Response:**
```json
{
  "id": "sub_xxxxxxxxxx",
  "status": "active",
  "current_period_start": 1704067200,
  "current_period_end": 1706745600
}
```

### 4. Create Payment Intent
**POST** `/create-payment-intent`

Creates a payment intent for one-time payments.

**Request Body:**
```json
{
  "amount": 8999,
  "currency": "usd",
  "customer": "cus_xxxxxxxxxx",
  "automatic_payment_methods": {
    "enabled": true
  }
}
```

**Response:**
```json
{
  "id": "pi_xxxxxxxxxx",
  "client_secret": "pi_xxxxxxxxxx_secret_xxxxxxxxxx"
}
```

### 5. Cancel Subscription
**POST** `/cancel-subscription`

Cancels an existing subscription.

**Request Body:**
```json
{
  "subscription_id": "sub_xxxxxxxxxx"
}
```

**Response:**
```json
{
  "id": "sub_xxxxxxxxxx",
  "status": "canceled",
  "canceled_at": 1704067200
}
```

### 6. Update Subscription
**POST** `/update-subscription`

Updates subscription to a different plan.

**Request Body:**
```json
{
  "subscription_id": "sub_xxxxxxxxxx",
  "new_price_id": "price_1MpSYpHB8mNBBYgB7QqDlFEo"
}
```

**Response:**
```json
{
  "id": "sub_xxxxxxxxxx",
  "status": "active",
  "items": {
    "data": [
      {
        "price": {
          "id": "price_1MpSYpHB8mNBBYgB7QqDlFEo"
        }
      }
    ]
  }
}
```

## Stripe Products and Prices Setup

You need to create these in your Stripe Dashboard:

### Products:
1. **1 Meal Plan**
   - Name: "1 Meal Plan"
   - Description: "One fresh meal delivered daily"

2. **2 Meal Plan**
   - Name: "2 Meal Plan" 
   - Description: "Two fresh meals delivered daily"

### Prices:
1. **1 Meal Plan Price**
   - Product: 1 Meal Plan
   - Amount: $89.99
   - Billing: Monthly recurring
   - Price ID: `price_1MpSYpHB8mNBBYgB7QqDlFEn` (example)

2. **2 Meal Plan Price**
   - Product: 2 Meal Plan
   - Amount: $159.99
   - Billing: Monthly recurring
   - Price ID: `price_1MpSYpHB8mNBBYgB7QqDlFEo` (example)

## Environment Variables

Update your backend with these environment variables:

```bash
STRIPE_SECRET_KEY=sk_test_...
STRIPE_PUBLISHABLE_KEY=pk_test_...
STRIPE_WEBHOOK_SECRET=whsec_...
```

## Webhook Endpoints

Set up webhooks in Stripe Dashboard to handle subscription events:

**Webhook URL:** `https://your-backend.com/stripe-webhook`

**Events to listen for:**
- `customer.subscription.created`
- `customer.subscription.updated`
- `customer.subscription.deleted`
- `invoice.payment_succeeded`
- `invoice.payment_failed`

## Security Notes

1. **Never** put your Stripe secret key in the Flutter app
2. Always validate webhooks using the webhook secret
3. Use HTTPS for all API endpoints
4. Implement proper authentication for your API endpoints
5. Validate all incoming requests on the backend

## Flutter App Configuration

Update these values in `lib/services/stripe_service.dart`:

```dart
static const String _publishableKey = 'pk_test_YOUR_ACTUAL_KEY';
static const String _backendUrl = 'https://your-backend-url.com';
```

Replace the price IDs in `lib/models/subscription.dart`:

```dart
String get priceId {
  switch (this) {
    case SubscriptionPlan.oneMeal:
      return 'price_YOUR_ACTUAL_1_MEAL_PRICE_ID';
    case SubscriptionPlan.twoMeal:
      return 'price_YOUR_ACTUAL_2_MEAL_PRICE_ID';
  }
}
```
