/**
 * FreshPunk Backend Functions - Enhanced Security & Audit
 *
 * Security Features:
 * - Input validation and sanitization
 * - Rate limiting protection
 * - Comprehensive audit logging
 * - Role-based access control
 * - Error handling without data leakage
 */

import {setGlobalOptions} from "firebase-functions";
import {onCall, onRequest, HttpsError} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import Stripe from "stripe";
import {defineSecret} from "firebase-functions/params";
import {initializeApp} from "firebase-admin/app";
import {getFirestore, FieldValue, Timestamp} from "firebase-admin/firestore";
import {getMessaging} from "firebase-admin/messaging";
import {getAuth} from "firebase-admin/auth";

// Initialize Firebase Admin
initializeApp();

// Export order generation and confirmation functions
export {generateOrderFromMealSelection, sendOrderConfirmation, confirmNextOrder} from "./order-functions";

// (Removed) meal population function import
// import {runPopulateMeals} from "./populate-meals";

// Export Square integration functions
export {
  initiateSquareOAuthHttp,
  completeSquareOAuthHttp,
  squareOAuthTestPage,
  diagnoseSquareOAuth,
  devListRecentSquareOrders,
  devFindSquareOrderByReference,
  devGetSquareOrderDetails,
  squareWhoAmI,
  syncSquareMenu,
  forwardOrderToSquare,
  forwardOrderOnStatusUpdate,
  dispatchConfirmedOrders,
  devForceSyncSquareMenu,
  sendWeeklyPrepSchedules,
  getRestaurantNotifications,
  doorDashWebhookHandler, // DoorDash webhook for delivery status updates
  // squareWebhookHandler, // REMOVED: Only needed if restaurants create orders independently
} from "./square-integration";

// Export manual OAuth helper (backup for when Square consent UI won't load)
export {
  manualOAuthEntry,
} from "./manual-oauth-helper";

// Export menu diagnostics
export {
  checkMenuSyncStatus,
} from "./menu-diagnostics";

// Export diagnostic tools
export {
  diagnosticMeals,
} from "./diagnostic-meals";

// Export Square catalog checker
export {
  checkSquareCatalog,
} from "./check-square-catalog";

// Export restaurant notification functions
export {
  notifyRestaurantsOnOrder,
  sendRestaurantOrderNotification,
  registerRestaurantPartner,
  getRestaurantOrders,
} from "./restaurant-notifications";

// Export invoice creation functions
export {
  createSubscriptionInvoice,
  getInvoiceDetails,
} from "./invoice-functions";

// Define secrets via Firebase Functions Secret Manager
const STRIPE_SECRET_KEY = defineSecret("STRIPE_SECRET_KEY");
const STRIPE_WEBHOOK_SECRET = defineSecret("STRIPE_WEBHOOK_SECRET");
const ADMIN_EMAIL_ALLOWLIST = defineSecret("ADMIN_EMAIL_ALLOWLIST");
const JWT_SECRET = defineSecret("JWT_SECRET"); // For kitchen partner auth
// Server-side Google Geocoding key (NEVER expose in client)
const GOOGLE_GEOCODE_KEY = defineSecret("GOOGLE_GEOCODE_KEY");

const callableCorsOrigins = [
  "https://freshpunk-48db1.web.app",
  "https://freshpunk-48db1.firebaseapp.com",
  "http://localhost:5000",
  "http://localhost:3000",
  "http://localhost:5173",
];

const baseCallableOptions = {
  region: "us-central1",
  cors: callableCorsOrigins,
};

// For cost control + latency, set region and max instances
setGlobalOptions({region: "us-east4", maxInstances: 10});

// Rate limiting store (in-memory for simplicity, use Redis for production)
const rateLimitStore = new Map<string, {count: number; resetTime: number}>();

// Helper Functions
function getStripe(): Stripe {
  const key = STRIPE_SECRET_KEY.value();
  if (!key || !key.startsWith("sk_")) {
    logger.error("STRIPE_SECRET_KEY is not a valid Stripe secret key");
    throw new Error("Server misconfigured: STRIPE_SECRET_KEY must be a Stripe secret key");
  }
  return new Stripe(key);
}

function sanitizeInput(input: any): any {
  if (typeof input === "string") {
    return input.trim().substring(0, 1000); // Limit string length
  }
  if (typeof input === "number") {
    return isNaN(input) ? 0 : Math.min(Math.max(input, -1000000), 1000000);
  }
  if (Array.isArray(input)) {
    return input.slice(0, 100).map(sanitizeInput); // Limit array size
  }
  if (typeof input === "object" && input !== null) {
    const sanitized: any = {};
    Object.keys(input).slice(0, 50).forEach((key) => { // Limit object keys
      if (key.length <= 100) { // Limit key length
        sanitized[key] = sanitizeInput(input[key]);
      }
    });
    return sanitized;
  }
  return input;
}

function isValidEmail(email: string): boolean {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return emailRegex.test(email) && email.length <= 254;
}

function isValidUid(uid: string): boolean {
  return typeof uid === "string" && uid.length > 0 && uid.length <= 128;
}

async function rateLimitCheck(identifier: string, limit = 100, windowMs = 60000): Promise<boolean> {
  const now = Date.now();
  const key = identifier;
  const entry = rateLimitStore.get(key);

  if (!entry || now > entry.resetTime) {
    rateLimitStore.set(key, {count: 1, resetTime: now + windowMs});
    return true;
  }

  if (entry.count >= limit) {
    return false;
  }

  entry.count++;
  return true;
}

async function logAuditEvent(
  action: string,
  userId: string | null,
  details: any,
  isSuccess = true,
  errorMessage?: string
) {
  try {
    await db.collection("audit_logs").add({
      action,
      userId,
      details: sanitizeInput(details),
      isSuccess,
      errorMessage: errorMessage || null,
      timestamp: FieldValue.serverTimestamp(),
      ip: null, // Could be extracted from request context if needed
    });
  } catch (error) {
    logger.error("Failed to log audit event", {action, error});
  }
}

const db = getFirestore();

// Enhanced connectivity check with rate limiting
export const ping = onCall(baseCallableOptions, async (request: any) => {
  const identifier = request.rawRequest?.ip || "unknown";

  if (!await rateLimitCheck(identifier, 60, 60000)) {
    throw new HttpsError("resource-exhausted", "Rate limit exceeded");
  }

  return {ok: true, time: Date.now(), version: "2.0.0"};
});

// Enhanced admin granting with comprehensive validation and audit
export const grantAdminAllowlist = onCall({
  ...baseCallableOptions,
  secrets: [ADMIN_EMAIL_ALLOWLIST],
}, async (request: any) => {
  const callerUid = request.auth?.uid;
  const callerEmail = request.auth?.token?.email?.toLowerCase();

  // Rate limiting
  if (!await rateLimitCheck(callerUid || "anonymous", 5, 300000)) { // 5 attempts per 5 minutes
    throw new HttpsError("resource-exhausted", "Too many admin requests. Please wait.");
  }

  if (!callerUid || !callerEmail) {
    await logAuditEvent("admin_grant_attempt", null, {reason: "unauthenticated"}, false);
    throw new HttpsError("unauthenticated", "You must be signed in to request admin access.");
  }

  if (!isValidEmail(callerEmail) || !isValidUid(callerUid)) {
    await logAuditEvent("admin_grant_attempt", callerUid, {email: callerEmail, reason: "invalid_credentials"}, false);
    throw new HttpsError("invalid-argument", "Invalid user credentials.");
  }

  const allowCsv = ADMIN_EMAIL_ALLOWLIST.value() || "";
  const allowedEmails = allowCsv
    .split(",")
    .map((s) => s.trim().toLowerCase())
    .filter((s) => !!s);

  if (allowedEmails.length === 0) {
    await logAuditEvent("admin_grant_attempt", callerUid, {reason: "no_allowlist"}, false);
    throw new HttpsError("failed-precondition", "Admin allowlist is not configured.");
  }

  if (!allowedEmails.includes(callerEmail)) {
    await logAuditEvent("admin_grant_attempt", callerUid, {email: callerEmail, reason: "not_allowlisted"}, false);
    throw new HttpsError("permission-denied", "Your email is not allowlisted for admin access.");
  }

  try {
    await getAuth().setCustomUserClaims(callerUid, {admin: true, adminGrantedAt: Date.now()});
    await getAuth().revokeRefreshTokens(callerUid);

    await logAuditEvent("admin_granted", callerUid, {email: callerEmail, method: "allowlist"}, true);

    return {ok: true, uid: callerUid, admin: true};
  } catch (e: any) {
    logger.error("grantAdminAllowlist error", e);
    await logAuditEvent("admin_grant_failed", callerUid, {email: callerEmail, error: e.message}, false);
    throw new HttpsError("internal", "Failed to grant admin privileges.");
  }
});

// Kitchen partner authentication system
export const grantKitchenAccess = onCall({
  ...baseCallableOptions,
  secrets: [JWT_SECRET],
}, async (request: any) => {
  const {accessCode, partnerName, partnerEmail} = sanitizeInput(request.data || {});
  const callerUid = request.auth?.uid;

  if (!await rateLimitCheck(callerUid || "anonymous", 10, 300000)) {
    throw new HttpsError("resource-exhausted", "Too many kitchen access requests.");
  }

  if (!callerUid) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  // Validate kitchen access code (in production, these should be stored securely in Firestore)
  const validKitchenCodes = [
    {code: "KITCHEN001", id: "freshpunk_main", name: "FreshPunk Main Kitchen"},
    {code: "KITCHEN002", id: "freshpunk_east", name: "FreshPunk East Kitchen"},
    {code: "KITCHEN003", id: "freshpunk_west", name: "FreshPunk West Kitchen"},
  ];

  const kitchen = validKitchenCodes.find((k) => k.code === accessCode);
  if (!kitchen) {
    await logAuditEvent("kitchen_access_denied", callerUid, {code: accessCode, reason: "invalid_code"}, false);
    throw new HttpsError("permission-denied", "Invalid kitchen access code.");
  }

  if (!isValidEmail(partnerEmail) || !partnerName || partnerName.length < 2) {
    throw new HttpsError("invalid-argument", "Valid partner name and email required.");
  }

  try {
    // Grant kitchen partner role
    await getAuth().setCustomUserClaims(callerUid, {
      kitchen: true,
      kitchenId: kitchen.id,
      kitchenName: kitchen.name,
      partnerName: sanitizeInput(partnerName),
      partnerEmail: sanitizeInput(partnerEmail),
      kitchenGrantedAt: Date.now(),
    });

    await getAuth().revokeRefreshTokens(callerUid);

    // Store kitchen partner info
    await db.collection("kitchen_partners").doc(callerUid).set({
      uid: callerUid,
      kitchenId: kitchen.id,
      kitchenName: kitchen.name,
      partnerName: sanitizeInput(partnerName),
      partnerEmail: sanitizeInput(partnerEmail),
      accessCode: accessCode,
      isActive: true,
      createdAt: FieldValue.serverTimestamp(),
      lastLoginAt: FieldValue.serverTimestamp(),
    });

    await logAuditEvent("kitchen_access_granted", callerUid, {
      kitchenId: kitchen.id,
      partnerName: partnerName,
      partnerEmail: partnerEmail,
    }, true);

    return {
      ok: true,
      kitchen: {
        id: kitchen.id,
        name: kitchen.name,
        partnerName: partnerName,
      },
    };
  } catch (e: any) {
    logger.error("grantKitchenAccess error", e);
    await logAuditEvent("kitchen_access_failed", callerUid, {error: e.message}, false);
    throw new HttpsError("internal", "Failed to grant kitchen access.");
  }
});

// Enhanced Payment Intent creation with comprehensive validation
export const createPaymentIntent = onCall({
  ...baseCallableOptions,
  secrets: [STRIPE_SECRET_KEY],
}, async (request: any) => {
  const callerUid = request.auth?.uid;

  if (!callerUid) {
    throw new HttpsError("unauthenticated", "Authentication required for payment operations.");
  }

  if (!await rateLimitCheck(callerUid, 20, 300000)) { // 20 payment attempts per 5 minutes
    throw new HttpsError("resource-exhausted", "Payment rate limit exceeded. Please wait.");
  }

  try {
    const stripe = getStripe();
    const {amount, currency = "usd", customer, metadata} = sanitizeInput(request.data || {});

    // Client-side misconfig guard: provide structured hints back.
    const fieldErrors: Record<string, string> = {};

    // Comprehensive validation
    if (typeof amount !== "number") fieldErrors.amount = "Amount must be a number in cents.";
    if (typeof amount === "number" && !Number.isInteger(amount)) fieldErrors.amount = "Amount must be an integer (cents).";
    if (typeof amount === "number" && amount <= 0) fieldErrors.amount = "Amount must be > 0.";

    if (typeof amount === "number" && amount > 100000) fieldErrors.amount = "Amount exceeds $1000 limit.";

    if (currency !== "usd") fieldErrors.currency = "Only 'usd' currency supported.";

    if (Object.keys(fieldErrors).length > 0) {
      throw new HttpsError("invalid-argument", JSON.stringify({message: "Validation failed", fieldErrors}));
    }

    // Create payment intent with enhanced metadata
    const paymentIntent = await stripe.paymentIntents.create({
      amount,
      currency,
      customer: customer || undefined,
      metadata: {
        ...sanitizeInput(metadata),
        userId: callerUid,
        createdAt: new Date().toISOString(),
      },
      automatic_payment_methods: {
        enabled: true,
      },
    });

    await logAuditEvent("payment_intent_created", callerUid, {
      paymentIntentId: paymentIntent.id,
      amount,
      currency,
      customer,
    }, true);

    return {
      ok: true,
      clientSecret: paymentIntent.client_secret,
      paymentIntentId: paymentIntent.id,
    };
  } catch (e: any) {
    logger.error("createPaymentIntent error", e);
    await logAuditEvent("payment_intent_failed", callerUid, {error: e.message}, false);

    if (e instanceof HttpsError) {
      // Pass through structured validation / auth / rate limit errors.
      throw e;
    }

    // Map common Stripe error types to more specific HttpsError codes for actionable client handling.
    const type = e?.type || e?.code;
    let mapped: HttpsError;
    switch (type) {
      case "StripeAuthenticationError":
      case "authentication_error":
        mapped = new HttpsError("failed-precondition", "Stripe authentication failed: check STRIPE_SECRET_KEY.");
        break;
      case "StripePermissionError":
      case "permission_error":
        mapped = new HttpsError("permission-denied", "Stripe permission error: verify account capabilities.");
        break;
      case "StripeRateLimitError":
      case "rate_limit_error":
        mapped = new HttpsError("resource-exhausted", "Stripe rate limit exceeded. Please retry later.");
        break;
      case "StripeInvalidRequestError":
      case "invalid_request_error":
        mapped = new HttpsError("invalid-argument", `Invalid Stripe request: ${e.message}`);
        break;
      case "StripeAPIError":
      case "api_error":
        mapped = new HttpsError("unavailable", "Stripe API temporary error. Retry shortly.");
        break;
      case "StripeConnectionError":
      case "connection_error":
        mapped = new HttpsError("unavailable", "Network error contacting Stripe. Check connectivity.");
        break;
      case "StripeCardError":
      case "card_error":
        mapped = new HttpsError("failed-precondition", `Card error: ${e.message}`);
        break;
      default:
        mapped = new HttpsError("internal", "Payment processing failed. Please try again.");
    }
    throw mapped;
  }
});

// Enhanced order management for kitchen partners

// Enhanced notification system
async function sendOrderStatusNotification(userId: string, orderId: string, status: string) {
  try {
    // Get user's FCM token from user document
    const userDoc = await db.collection("users").doc(userId).get();
    const userData = userDoc.data();

    if (!userData?.fcmToken) {
      logger.warn(`No FCM token for user ${userId}`);
      return;
    }

    const statusMessages: {[key: string]: string} = {
      "confirmed": "Your order has been confirmed!",
      "preparing": "Your meal is being prepared.",
      "ready": "Your order is ready for pickup/delivery!",
      "out_for_delivery": "Your order is on the way!",
      "delivered": "Your order has been delivered. Enjoy!",
      "cancelled": "Your order has been cancelled.",
    };

    const message = {
      token: userData.fcmToken,
      notification: {
        title: "Order Update",
        body: statusMessages[status] || `Order status: ${status}`,
      },
      data: {
        orderId,
        status,
        type: "order_status_update",
      },
    };

    await getMessaging().send(message);

    // Also create an in-app notification
    await db.collection("notifications").add({
      userId,
      title: "Order Update",
      message: statusMessages[status] || `Order status: ${status}`,
      type: "order_status",
      orderId,
      isRead: false,
      createdAt: FieldValue.serverTimestamp(),
    });
  } catch (error) {
    logger.error("Failed to send notification", {userId, orderId, status, error});
  }
}

// ============ Maintenance: Sanitize Meals Metadata ============

// HTTP variant to trigger from a browser or CLI with explicit confirmation

// Create Customer
export const createCustomer = onCall({
  ...baseCallableOptions,
  secrets: [STRIPE_SECRET_KEY],
}, async (request: any) => {
  try {
    const stripe = getStripe();
    const {email, name} = request.data;
    const uid = request.auth?.uid as string | undefined;

    const customer = await stripe.customers.create({
      email,
      name,
      metadata: uid ? {firebase_uid: uid} : undefined,
    });

    return {customer};
  } catch (error) {
    logger.error("Error creating customer:", error);
    throw new Error("Failed to create customer");
  }
});

// Create Subscription
export const createSubscription = onCall({
  ...baseCallableOptions,
  secrets: [STRIPE_SECRET_KEY],
}, async (request: any) => {
  try {
  const stripe = getStripe();
    const {customer, paymentMethod, priceId} = request.data;

    // Attach payment method to customer
    await stripe.paymentMethods.attach(paymentMethod, {
      customer,
    });

    // Set as default payment method
    await stripe.customers.update(customer, {
      invoice_settings: {
        default_payment_method: paymentMethod,
      },
    });

    // Create subscription
    const subscription = await stripe.subscriptions.create({
      customer,
      items: [{price: priceId}],
      payment_settings: {
        payment_method_types: ["card"],
        save_default_payment_method: "on_subscription",
      },
      expand: ["latest_invoice.payment_intent"],
    });

  return {subscription};
  } catch (error) {
    logger.error("Error creating subscription:", error);
    throw new Error("Failed to create subscription");
  }
});

// Create Setup Intent
export const createSetupIntent = onCall({
  ...baseCallableOptions,
  secrets: [STRIPE_SECRET_KEY],
}, async (request: any) => {
  try {
  const stripe = getStripe();
    const {customer} = request.data;

    if (!customer) {
      throw new Error("customer is required");
    }

    const setupIntent = await stripe.setupIntents.create({
      customer,
      automatic_payment_methods: {enabled: true},
      usage: "off_session", // Allow charging when customer is not present
      payment_method_options: {
        card: {
          request_three_d_secure: "automatic",
        },
      },
    });

    logger.info(`Setup intent created for customer: ${customer}`);
    return {client_secret: setupIntent.client_secret};
  } catch (error) {
    logger.error("Error creating setup intent:", error);
    throw new Error("Failed to create setup intent");
  }
});

// Retrieve Setup Intent
export const retrieveSetupIntent = onCall({
  ...baseCallableOptions,
  secrets: [STRIPE_SECRET_KEY],
}, async (request: any) => {
  try {
    const stripe = getStripe();
    const {setup_intent} = request.data;

    if (!setup_intent) {
      throw new Error("setup_intent is required");
    }

    const setupIntent = await stripe.setupIntents.retrieve(setup_intent);

    return {
      id: setupIntent.id,
      status: setupIntent.status,
      payment_method: setupIntent.payment_method,
      customer: setupIntent.customer,
    };
  } catch (error) {
    logger.error("Error retrieving setup intent:", error);
    throw new Error("Failed to retrieve setup intent");
  }
});

// Create Test Payment Method for Web (Development)
export const createTestPaymentMethod = onCall({
  ...baseCallableOptions,
  secrets: [STRIPE_SECRET_KEY],
}, async (request: any) => {
  try {
    const stripe = getStripe();
    const {customer} = request.data;

    // Create a test payment method using Stripe's test card token
    const paymentMethod = await stripe.paymentMethods.create({
      type: "card",
      card: {
        token: "tok_visa", // Stripe test token
      },
    });

    // Attach to customer
    await stripe.paymentMethods.attach(paymentMethod.id, {
      customer,
    });

    // Set as default
    await stripe.customers.update(customer, {
      invoice_settings: {
        default_payment_method: paymentMethod.id,
      },
    });

    logger.info(`Test payment method created for customer: ${customer}`);
    return {success: true, paymentMethodId: paymentMethod.id};
  } catch (error) {
    logger.error("Error creating test payment method:", error);
    throw new Error("Failed to create test payment method");
  }
});

// Cancel Subscription
export const cancelSubscription = onCall({
  ...baseCallableOptions,
  secrets: [STRIPE_SECRET_KEY],
}, async (request: any) => {
  try {
  const stripe = getStripe();
    const {subscriptionId} = request.data;

    const subscription = await stripe.subscriptions.cancel(subscriptionId);
    // Mirror to Firestore if authenticated
    const uid = request.auth?.uid as string | undefined;
    try {
      if (uid && subscription?.id) {
        await db.collection("users").doc(uid)
          .collection("subscriptions").doc(subscription.id)
          .set({
            id: subscription.id,
            stripeSubscriptionId: subscription.id,
            status: subscription.status ?? "canceled",
            cancelAtPeriodEnd: true,
            canceledAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
          }, {merge: true});
      }
    } catch (e) {
 logger.warn("cancelSubscription Firestore mirror failed", e as any);
}
    return {subscription};
  } catch (error) {
    logger.error("Error canceling subscription:", error);
    throw new Error("Failed to cancel subscription");
  }
});

// Update Subscription
export const updateSubscription = onCall({
  ...baseCallableOptions,
  secrets: [STRIPE_SECRET_KEY],
}, async (request: any) => {
  try {
  const stripe = getStripe();
    const {subscriptionId, newPriceId} = request.data;

    const subscription = await stripe.subscriptions.retrieve(
      subscriptionId
    );

    const updatedSubscription = await stripe.subscriptions.update(
      subscriptionId, {
        items: [{
          id: subscription.items.data[0].id,
          price: newPriceId,
        }],
        // Apply change on next billing cycle (no proration now)
        proration_behavior: "none",
        billing_cycle_anchor: "unchanged",
      });
  // Mirror to Firestore if authenticated
  const uid = request.auth?.uid as string | undefined;
  try {
    if (uid && updatedSubscription?.id) {
      const nextTs = ((updatedSubscription as any).current_period_end as number | undefined);
      await db.collection("users").doc(uid)
        .collection("subscriptions").doc(updatedSubscription.id)
        .set({
          id: updatedSubscription.id,
          stripeSubscriptionId: updatedSubscription.id,
          status: updatedSubscription.status ?? "active",
          stripePriceId: newPriceId,
          nextBillingDate: nextTs ? new Date(nextTs * 1000) : null,
          cancelAtPeriodEnd: !!updatedSubscription.cancel_at_period_end,
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
    }
  } catch (e) {
 logger.warn("updateSubscription Firestore mirror failed", e as any);
}
  return {subscription: updatedSubscription};
  } catch (error) {
    logger.error("Error updating subscription:", error);
    throw new Error("Failed to update subscription");
  }
});

// Pause Subscription (stop invoicing until resumed)
export const pauseSubscription = onCall({
  ...baseCallableOptions,
  secrets: [STRIPE_SECRET_KEY],
}, async (request: any) => {
  try {
    const stripe = getStripe();
    const {subscriptionId} = request.data;
    const updated = await stripe.subscriptions.update(subscriptionId, {
      pause_collection: {behavior: "mark_uncollectible"},
    });
    // Mirror to Firestore if authenticated
    const uid = request.auth?.uid as string | undefined;
    try {
      if (uid && updated?.id) {
        const subPayload = {
          id: updated.id,
          stripeSubscriptionId: updated.id,
          status: "paused",
          pauseBehavior: "mark_uncollectible",
          updatedAt: FieldValue.serverTimestamp(),
        };
        // Legacy nested location
        await db.collection("users").doc(uid)
          .collection("subscriptions").doc(updated.id)
          .set(subPayload, {merge: true});
        // Top-level canonical subscription doc (doc id is userId)
        await db.collection("subscriptions").doc(uid).set(subPayload, {merge: true});
      }
    } catch (e) {
      logger.warn("pauseSubscription Firestore mirror failed", e as any);
    }
    return {subscription: updated};
  } catch (error) {
    logger.error("Error pausing subscription:", error);
    throw new Error("Failed to pause subscription");
  }
});

// Resume Subscription
export const resumeSubscription = onCall({
  ...baseCallableOptions,
  secrets: [STRIPE_SECRET_KEY],
}, async (request: any) => {
  try {
    const stripe = getStripe();
    const {subscriptionId} = request.data;
    const updated = await stripe.subscriptions.update(subscriptionId, {
      pause_collection: "",
    } as any);
    // Mirror to Firestore if authenticated
    const uid = request.auth?.uid as string | undefined;
    try {
      if (uid && updated?.id) {
        const nextTs = ((updated as any).current_period_end as number | undefined);
        const subPayload = {
          id: updated.id,
          stripeSubscriptionId: updated.id,
          status: updated.status ?? "active",
          nextBillingDate: nextTs ? new Date(nextTs * 1000) : null,
          updatedAt: FieldValue.serverTimestamp(),
        };
        await db.collection("users").doc(uid)
          .collection("subscriptions").doc(updated.id)
          .set(subPayload, {merge: true});
        await db.collection("subscriptions").doc(uid).set(subPayload, {merge: true});
      }
    } catch (e) {
      logger.warn("resumeSubscription Firestore mirror failed", e as any);
    }
    return {subscription: updated};
  } catch (error) {
    logger.error("Error resuming subscription:", error);
    throw new Error("Failed to resume subscription");
  }
});

// Probe available installments and payment method types for a given amount/currency
export const getBillingOptions = onCall({
  ...baseCallableOptions,
  secrets: [STRIPE_SECRET_KEY],
}, async (request: any) => {
  try {
    const stripe = getStripe();
    const {amount, currency = "usd", customer, paymentMethod} = request.data ?? {};

    if (typeof amount !== "number" || !Number.isInteger(amount) || amount <= 0) {
      throw new Error("amount (integer, cents) is required");
    }

    const params: Stripe.PaymentIntentCreateParams = {
      amount,
      currency,
      customer,
      automatic_payment_methods: {enabled: true},
      payment_method: paymentMethod,
      payment_method_options: {
        card: {
          installments: {enabled: true},
        },
      },
    } as any;

    // Create a short-lived PI to let Stripe compute available options
    const pi = await stripe.paymentIntents.create(params);

    // Extract results
    const pmTypes = (pi.payment_method_types ?? []) as string[];
    const installments = ((pi.payment_method_options as any)?.card?.installments?.available_plans ?? []) as Array<any>;

    // Optionally include default payment method basics
    let defaultPaymentMethod: any = null;
    if (customer) {
      try {
        const cust = await stripe.customers.retrieve(customer);
        if (cust && !(cust as Stripe.DeletedCustomer).deleted) {
          const defaultPm = (cust as Stripe.Customer).invoice_settings?.default_payment_method as string | Stripe.PaymentMethod | null;
          const defaultId = typeof defaultPm === "string" ? defaultPm : (defaultPm?.id ?? null);
          if (defaultId) {
            const pm = await stripe.paymentMethods.retrieve(defaultId);
            defaultPaymentMethod = {
              id: pm.id,
              type: pm.type,
              card: (pm as any).card ? {
                brand: (pm as any).card.brand,
                last4: (pm as any).card.last4,
                exp_month: (pm as any).card.exp_month,
                exp_year: (pm as any).card.exp_year,
              } : null,
            };
          }
        }
      } catch (e) {
        // ignore
      }
    }

    // Cleanup: cancel the PI to avoid clutter
    try {
 await stripe.paymentIntents.cancel(pi.id);
} catch (_) {/* best effort */}

    return {
      payment_method_types: pmTypes,
      card_installments: installments,
      default_payment_method: defaultPaymentMethod,
    };
  } catch (error) {
    logger.error("getBillingOptions error", error);
    throw new Error("Failed to get billing options");
  }
});

// Helper to get or create a Stripe customer by email (from auth or request)
async function getOrCreateCustomer(stripe: Stripe, email?: string, name?: string, uid?: string) {
  // 1) Prefer lookup by email if provided
  if (email && email.trim().length > 0) {
    const existing = await stripe.customers.list({email, limit: 1});
    if (existing.data.length > 0) {
      const cust = existing.data[0];
      // Backfill firebase_uid metadata if we have a uid and it's missing or different
      if (uid && uid.trim().length > 0) {
        const currentUid = (cust.metadata as any)?.firebase_uid as string | undefined;
        if (!currentUid || currentUid !== uid) {
          const newMeta: Record<string, string> = {...(cust.metadata as any)};
          newMeta.firebase_uid = uid;
          try {
            const updated = await stripe.customers.update(cust.id, {metadata: newMeta});
            return updated;
          } catch (e) {
            // If metadata update fails, fall back to returning the existing customer
            return cust;
          }
        }
      }
      return cust;
    }
  }
  // 2) Fallback: lookup by Firebase UID metadata if available
  if (uid && uid.trim().length > 0) {
    try {
      const search = await (stripe.customers as any).search({
        // @ts-ignore - search API supports this query syntax
        query: `metadata['firebase_uid']:'${uid}'`,
        limit: 1,
      });
      if (search && search.data && search.data.length > 0) {
        return search.data[0];
      }
    } catch (e) {
      // ignore search errors; will create below
    }
  }
  // 3) Create new customer with whatever identity we have
  const createParams: Stripe.CustomerCreateParams = {
    email: email && email.trim().length > 0 ? email : undefined,
    name,
  };
  if (uid && uid.trim().length > 0) {
    (createParams as any).metadata = {firebase_uid: uid};
  }
  return await stripe.customers.create(createParams);
}

// List Payment Methods (cards) for the authenticated user's customer
export const listPaymentMethods = onCall({
  ...baseCallableOptions,
  secrets: [STRIPE_SECRET_KEY],
}, async (request: any) => {
  try {
    const stripe = getStripe();
    const email: string | undefined = (request.data?.email as string) ||
      (request.auth?.token?.email as string | undefined);
    const uid: string | undefined = request.auth?.uid as string | undefined;
    const name: string | undefined = (request.data?.name as string) || undefined;
    const customerInput: string | undefined = request.data?.customer;

    let customer: Stripe.Customer | Stripe.DeletedCustomer | null = null;
    if (customerInput) {
      customer = await stripe.customers.retrieve(customerInput);
    } else {
      customer = await getOrCreateCustomer(stripe, email, name, uid);
    }

    if (!customer || (customer as Stripe.DeletedCustomer).deleted) {
      throw new Error("Customer not found");
    }

  const cust = customer as Stripe.Customer;
    const defaultPmId = (cust.invoice_settings?.default_payment_method as string | Stripe.PaymentMethod | null) || null;
    const defaultId = typeof defaultPmId === "string" ? defaultPmId : (defaultPmId?.id ?? null);

    const pms = await stripe.paymentMethods.list({
      customer: cust.id,
      type: "card",
    });

  const data = pms.data.map((pm: any) => ({
      id: pm.id,
      card: pm.card,
      default: pm.id === defaultId,
    }));

  return {data};
  } catch (error) {
    logger.error("Error listing payment methods:", error);
    throw new Error("Failed to list payment methods");
  }
});

// Detach a payment method from the authenticated user's customer
export const detachPaymentMethod = onCall({
  ...baseCallableOptions,
  secrets: [STRIPE_SECRET_KEY],
}, async (request: any) => {
  try {
    const stripe = getStripe();
    const {payment_method} = request.data ?? {};
    if (!payment_method) throw new Error("payment_method is required");
    await stripe.paymentMethods.detach(payment_method);
    return {success: true};
  } catch (error) {
    logger.error("Error detaching payment method:", error);
    return {success: false};
  }
});

// Set default payment method for the authenticated user's customer
export const setDefaultPaymentMethod = onCall({
  ...baseCallableOptions,
  secrets: [STRIPE_SECRET_KEY],
}, async (request: any) => {
  try {
    const stripe = getStripe();
    const email: string | undefined = (request.data?.email as string) ||
      (request.auth?.token?.email as string | undefined);
    const uid: string | undefined = request.auth?.uid as string | undefined;
    const name: string | undefined = (request.data?.name as string) || undefined;
    const customerInput: string | undefined = request.data?.customer;
    const {payment_method} = request.data ?? {};
    if (!payment_method) throw new Error("payment_method is required");

    let customer: Stripe.Customer | Stripe.DeletedCustomer | null = null;
    if (customerInput) {
      customer = await stripe.customers.retrieve(customerInput);
    } else {
      customer = await getOrCreateCustomer(stripe, email, name, uid);
    }

    if (!customer || (customer as Stripe.DeletedCustomer).deleted) {
      throw new Error("Customer not found");
    }

  const updated = await stripe.customers.update((customer as Stripe.Customer).id, {
      invoice_settings: {default_payment_method: payment_method},
    });

  return {success: true, customer: updated};
  } catch (error) {
    logger.error("Error setting default payment method:", error);
    return {success: false};
  }
});

// ============ Minimal Order APIs ============

// Place an order (server-authored write to Firestore)
export const placeOrder = onCall(baseCallableOptions, async (request: any) => {
  try {
    const uid = request.auth?.uid as string | undefined;
    if (!uid) throw new Error("Unauthenticated");

    const {items, scheduleName, addressId, deliveryDate} = request.data ?? {};
    if (!Array.isArray(items) || items.length === 0) {
      throw new Error("items is required and must be a non-empty array");
    }
    if (!addressId) throw new Error("addressId is required");

    let deliveryTs: Timestamp | null = null;
    if (deliveryDate) {
      try {
        deliveryTs = Timestamp.fromDate(new Date(deliveryDate));
      } catch {
        deliveryTs = null;
      }
    }

    const order = {
      userId: uid,
      items,
      scheduleName: scheduleName ?? null,
      addressId,
      deliveryDate: deliveryTs,
      status: "pending" as const,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    };

    const ref = await db.collection("orders").add(order as any);
    return {id: ref.id, status: order.status};
  } catch (error) {
    logger.error("placeOrder error", error);
    throw new Error((error as Error).message || "Failed to place order");
  }
});

// Cancel an order (owner-only; rules enforce constraints; we set server timestamps)
export const cancelOrder = onCall(baseCallableOptions, async (request: any) => {
  try {
    const uid = request.auth?.uid as string | undefined;
    if (!uid) throw new Error("Unauthenticated");
    const {orderId} = request.data ?? {};
    if (!orderId) throw new Error("orderId is required");

    const snap = await db.collection("orders").doc(orderId).get();
    if (!snap.exists) throw new Error("Order not found");
    const data = snap.data() as any;
    if (data.userId !== uid) throw new Error("Forbidden");

    await snap.ref.update({
      status: "cancelled",
      cancelledAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    return {success: true};
  } catch (error) {
    logger.error("cancelOrder error", error);
    return {success: false, error: (error as Error).message};
  }
});

// ============ FCM Registration ============
export const registerFcmToken = onCall(baseCallableOptions, async (request: any) => {
  const uid = request.auth?.uid as string | undefined;
  if (!uid) throw new Error("Unauthenticated");
  const token = (request.data?.token as string | undefined)?.trim();
  const platform = (request.data?.platform as string | undefined) ?? "unknown";
  if (!token) throw new Error("token is required");
  await db.collection("users").doc(uid)
    .collection("fcmTokens").doc(token)
    .set({
      platform,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
  return {success: true};
});

// Notify user on order status changes

// ============ Admin Claims ============

// Clear existing meals to trigger reseed with local images

// Enhanced Stripe webhook handler with security and audit
export const stripeWebhook = onRequest({secrets: [STRIPE_WEBHOOK_SECRET]}, async (req: any, res: any) => {
  const startTime = Date.now();
  let eventId = "unknown";

  try {
    const signature = req.headers["stripe-signature"] as string | undefined;
    if (!signature) {
      logger.warn("Webhook received without signature");
      res.status(400).send("Missing Stripe signature");
      return;
    }

    const stripe = getStripe();
    const secret = STRIPE_WEBHOOK_SECRET.value();
    if (!secret) {
      logger.error("Webhook secret not configured");
      res.status(500).send("Webhook secret not configured");
      return;
    }

    // Verify webhook signature
    const event = stripe.webhooks.constructEvent(req.rawBody, signature, secret);
    eventId = event.id;

    // Rate limiting for webhooks (basic protection)
    if (!await rateLimitCheck(`webhook_${event.type}`, 1000, 60000)) {
      logger.warn(`Webhook rate limit exceeded for event type: ${event.type}`);
      res.status(429).send("Rate limit exceeded");
      return;
    }

    // Idempotency check
    const eventRef = db.collection("webhook_events").doc(event.id);
    const existing = await eventRef.get();
    if (existing.exists) {
      logger.info(`Webhook event ${event.id} already processed (deduplicated)`);
      res.json({received: true, deduped: true});
      return;
    }

    // Store event for idempotency and audit
    await eventRef.set({
      id: event.id,
      type: event.type,
      created: new Date(event.created * 1000),
      processed: false,
      processedAt: null,
      livemode: event.livemode,
      apiVersion: event.api_version,
      createdAt: FieldValue.serverTimestamp(),
    });

    logger.info(`Processing webhook event: ${event.type} (${event.id})`);

    // Process different event types
    let processingResult = null;
    switch (event.type) {
      case "payment_intent.succeeded":
        processingResult = await handlePaymentIntentSucceeded(event);
        break;

      case "payment_intent.payment_failed":
        processingResult = await handlePaymentIntentFailed(event);
        break;

      case "customer.subscription.created":
        processingResult = await handleSubscriptionCreated(event);
        break;

      case "customer.subscription.updated":
        processingResult = await handleSubscriptionUpdated(event);
        break;

      case "customer.subscription.deleted":
        processingResult = await handleSubscriptionDeleted(event);
        break;

      case "invoice.payment_succeeded":
        processingResult = await handleInvoicePaymentSucceeded(event);
        break;

      case "invoice.payment_failed":
        processingResult = await handleInvoicePaymentFailed(event);
        break;

      default:
        logger.info(`Unhandled webhook event type: ${event.type}`);
        processingResult = {handled: false, reason: "Unhandled event type"};
    }

    // Mark event as processed
    await eventRef.update({
      processed: true,
      processedAt: FieldValue.serverTimestamp(),
      processingResult,
      processingTimeMs: Date.now() - startTime,
    });

    await logAuditEvent("webhook_processed", null, {
      eventId: event.id,
      eventType: event.type,
      processingTimeMs: Date.now() - startTime,
      result: processingResult,
    }, true);

    res.json({received: true, eventId: event.id, processingResult});
  } catch (err: any) {
    logger.error("Webhook processing error", {eventId, error: err.message, stack: err.stack});

    await logAuditEvent("webhook_failed", null, {
      eventId,
      error: err.message,
      processingTimeMs: Date.now() - startTime,
    }, false);

    res.status(400).send(`Webhook Error: ${err.message}`);
  }
});

// Webhook event handlers
async function handlePaymentIntentSucceeded(event: any) {
  const paymentIntent = event.data.object;
  const userId = paymentIntent.metadata?.userId;

  if (!userId) {
    return {handled: false, reason: "No userId in metadata"};
  }

  try {
    // Update order status to confirmed
    const ordersSnapshot = await db.collection("orders")
      .where("paymentIntentId", "==", paymentIntent.id)
      .limit(1)
      .get();

    if (!ordersSnapshot.empty) {
      const orderDoc = ordersSnapshot.docs[0];
      await orderDoc.ref.update({
        status: "confirmed",
        paymentConfirmedAt: FieldValue.serverTimestamp(),
        stripePaymentIntentId: paymentIntent.id,
      });

      await sendOrderStatusNotification(userId, orderDoc.id, "confirmed");
    }

    return {handled: true, ordersUpdated: ordersSnapshot.size};
  } catch (error: any) {
    logger.error("Error handling payment_intent.succeeded", error);
    return {handled: false, error: error.message};
  }
}

async function handlePaymentIntentFailed(event: any) {
  const paymentIntent = event.data.object;
  const userId = paymentIntent.metadata?.userId;

  if (!userId) {
    return {handled: false, reason: "No userId in metadata"};
  }

  try {
    // Update order status to payment_failed
    const ordersSnapshot = await db.collection("orders")
      .where("paymentIntentId", "==", paymentIntent.id)
      .limit(1)
      .get();

    if (!ordersSnapshot.empty) {
      const orderDoc = ordersSnapshot.docs[0];
      await orderDoc.ref.update({
        status: "payment_failed",
        paymentFailedAt: FieldValue.serverTimestamp(),
        paymentFailureReason: paymentIntent.last_payment_error?.message || "Unknown error",
      });

      // Send failure notification
      await sendOrderStatusNotification(userId, orderDoc.id, "payment_failed");
    }

    return {handled: true, ordersUpdated: ordersSnapshot.size};
  } catch (error: any) {
    logger.error("Error handling payment_intent.payment_failed", error);
    return {handled: false, error: error.message};
  }
}

async function handleSubscriptionCreated(event: any) {
  const subscription = event.data.object;
  const customerId = subscription.customer;

  try {
    // Find user by Stripe customer ID
    const usersSnapshot = await db.collection("users")
      .where("stripeCustomerId", "==", customerId)
      .limit(1)
      .get();

    if (!usersSnapshot.empty) {
      const userId = usersSnapshot.docs[0].id;

      // Create subscription record in top-level /subscriptions collection
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

      return {handled: true, userId, subscriptionId: subscription.id};
    }

    return {handled: false, reason: "User not found for customer"};
  } catch (error: any) {
    logger.error("Error handling subscription created", error);
    return {handled: false, error: error.message};
  }
}

async function handleSubscriptionUpdated(event: any) {
  // Similar to created but update existing record
  const subscription = event.data.object;
  const customerId = subscription.customer;

  try {
    const usersSnapshot = await db.collection("users")
      .where("stripeCustomerId", "==", customerId)
      .limit(1)
      .get();

    if (!usersSnapshot.empty) {
      const userId = usersSnapshot.docs[0].id;

      await db.collection("subscriptions").doc(userId).update({
        status: subscription.status,
        currentPeriodEnd: new Date(subscription.current_period_end * 1000),
        cancelAtPeriodEnd: subscription.cancel_at_period_end,
        updatedAt: FieldValue.serverTimestamp(),
      });

      return {handled: true, userId, subscriptionId: subscription.id};
    }

    return {handled: false, reason: "User not found for customer"};
  } catch (error: any) {
    logger.error("Error handling subscription updated", error);
    return {handled: false, error: error.message};
  }
}

async function handleSubscriptionDeleted(event: any) {
  const subscription = event.data.object;
  const customerId = subscription.customer;

  try {
    const usersSnapshot = await db.collection("users")
      .where("stripeCustomerId", "==", customerId)
      .limit(1)
      .get();

    if (!usersSnapshot.empty) {
      const userId = usersSnapshot.docs[0].id;

      await db.collection("subscriptions").doc(userId).update({
        status: "cancelled",
        cancelledAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });

      return {handled: true, userId, subscriptionId: subscription.id};
    }

    return {handled: false, reason: "User not found for customer"};
  } catch (error: any) {
    logger.error("Error handling subscription deleted", error);
    return {handled: false, error: error.message};
  }
}

async function handleInvoicePaymentSucceeded(event: any) {
  return {handled: true, note: "Invoice payment succeeded - no action needed"};
}

async function handleInvoicePaymentFailed(event: any) {
  const invoice = event.data.object;
  const customerId = invoice.customer;

  try {
    const usersSnapshot = await db.collection("users")
      .where("stripeCustomerId", "==", customerId)
      .limit(1)
      .get();

    if (!usersSnapshot.empty) {
      const userId = usersSnapshot.docs[0].id;

      // Create failed payment notification
      await db.collection("notifications").add({
        userId,
        title: "Payment Failed",
        message: "Your subscription payment failed. Please update your payment method.",
        type: "payment_failed",
        invoiceId: invoice.id,
        isRead: false,
        createdAt: FieldValue.serverTimestamp(),
      });

      return {handled: true, userId, invoiceId: invoice.id};
    }

    return {handled: false, reason: "User not found for customer"};
  } catch (error: any) {
    logger.error("Error handling invoice payment failed", error);
    return {handled: false, error: error.message};
  }
}

// Security monitoring functions

// Kitchen operations Cloud Functions

// Bulk order status update for kitchen efficiency

// Get kitchen performance metrics

// Temporary function to grant kitchen access (remove after setup)

// ============ SMS Notification Functions ============

// Send SMS notification via Twilio

// Send order confirmation SMS

// Send order status update SMS

/**
 * List all meal IDs for image naming reference
 */

/**
 * Update meal image URLs in Firestore
 */

// (Removed) HTTP endpoint to populate Firestore with real meal data
// export const populateMealsHttp = onRequest(async (req, res) => {
//   try {
//     await runPopulateMeals();
//     res.status(200).send("✅ Successfully populated meals!");
//   } catch (error) {
//     logger.error("Error updating meal images:", error);
//     res.status(500).send("Error updating meal images");
//   }
// });

/**
 * List all files in Firebase Storage meals folder for debugging
 */

/**
 * Update meal image URLs with persistent download tokens so they work publicly
 */

/**
 * Update meal image URLs using .firebasestorage.app domain (simple version - no file checks)
 */

/**
 * Update meal image URLs by listing Storage first (robust against false negatives)
 * - Lists all files under meals/Meal Images/
 * - Ensures each file has a firebaseStorageDownloadTokens metadata
 * - Builds public download URLs and updates Firestore collectionGroup('items')
 */

/**
 * Configure Cloud Storage CORS to allow images to load on Flutter Web (CanvasKit/HTML).
 * Allows GET/HEAD from hosting origins so Image.network works without XHR/CORS failures.
 */

/**
 * Count meals across collection group 'items' for diagnostics
 */

/**
 * Admin-only callable to backfill missing stripeSubscriptionId fields in top-level /subscriptions docs.
 * Iterates documents missing stripeSubscriptionId, looks up the user's stripeCustomerId, queries Stripe
 * for subscriptions, picks the highest-priority status (active > incomplete > trialing > past_due > unpaid > canceled),
 * and writes back normalized fields.
 */
export const backfillStripeSubscriptions = onCall({
  ...baseCallableOptions,
  secrets: [STRIPE_SECRET_KEY],
}, async (request: any) => {
  const callerUid = request.auth?.uid as string | undefined;
  const isAdmin = !!request.auth?.token?.admin;
  if (!callerUid || !isAdmin) {
    throw new HttpsError("permission-denied", "Admin privileges required");
  }

  const stripe = getStripe();
  const started = Date.now();
  const updated: Array<{docId: string; subId: string; status: string}> = [];
  const skipped: Array<{docId: string; reason: string}> = [];
  const missing: Array<{docId: string; reason: string}> = [];

  try {
    const snap = await db.collection("subscriptions").get();
    for (const doc of snap.docs) {
      const data = doc.data() as any;
      if (data.stripeSubscriptionId) {
        skipped.push({docId: doc.id, reason: "has_id"});
        continue;
      }

      // Fetch user for stripeCustomerId
      const userDoc = await db.collection("users").doc(doc.id).get();
      const userData = userDoc.data() as any;
      const stripeCustomerId = userData?.stripeCustomerId;
      if (!stripeCustomerId) {
        missing.push({docId: doc.id, reason: "no_stripeCustomerId"});
        continue;
      }

      try {
        const subs = await stripe.subscriptions.list({customer: stripeCustomerId, status: "all", limit: 20});
        if (!subs.data.length) {
          missing.push({docId: doc.id, reason: "no_subs"});
          continue;
        }
        const priority = ["active", "incomplete", "trialing", "past_due", "unpaid", "canceled"];
        const chosen = subs.data.slice().sort((a, b) => {
          const ai = priority.indexOf(a.status);
          const bi = priority.indexOf(b.status);
          return (ai === -1 ? 999 : ai) - (bi === -1 ? 999 : bi);
        })[0];
        if (!chosen) {
          missing.push({docId: doc.id, reason: "sort_empty"});
          continue;
        }

        // Use any type casting to access epoch seconds safely without TS complaints
        const rawChosen: any = chosen as any;
        await doc.ref.set({
          stripeSubscriptionId: chosen.id,
          status: chosen.status,
          stripePriceId: chosen.items.data[0]?.price?.id || data.stripePriceId || null,
          currentPeriodStart: rawChosen.current_period_start ? new Date(rawChosen.current_period_start * 1000) : null,
          currentPeriodEnd: rawChosen.current_period_end ? new Date(rawChosen.current_period_end * 1000) : null,
          cancelAtPeriodEnd: !!rawChosen.cancel_at_period_end,
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
        updated.push({docId: doc.id, subId: chosen.id, status: chosen.status});
      } catch (e: any) {
        missing.push({docId: doc.id, reason: `stripe_error:${e.message || e.code || "unknown"}`});
      }
    }
  } catch (e: any) {
    logger.error("backfillStripeSubscriptions error", e);
    throw new HttpsError("internal", "Backfill failed: " + (e.message || "unknown"));
  }

  const result = {
    ok: true,
    processed: updated.length + skipped.length + missing.length,
    updated,
    skipped,
    missing,
    ms: Date.now() - started,
  };
  await logAuditEvent("backfill_subscriptions", callerUid, result, true);
  return result;
});

/**
 * Secure server-side geocode callable. Use this instead of calling Google Geocoding
 * directly from the client when the key is IP restricted or not allowed for browser use.
 * Returns structured address data similar to client AddressResult.
 */
export const geocodeAddress = onCall({
  ...baseCallableOptions,
  secrets: [GOOGLE_GEOCODE_KEY],
}, async (request: any) => {
  const raw = (request.data?.address as string | undefined)?.trim();
  if (!raw) {
    throw new HttpsError("invalid-argument", "address is required");
  }

  // Basic rate limiting per caller
  const caller = request.auth?.uid || request.rawRequest?.ip || "anon";
  if (!await rateLimitCheck(`geocode_${caller}`, 30, 60000)) {
    throw new HttpsError("resource-exhausted", "Too many geocode requests. Slow down.");
  }

  const key = GOOGLE_GEOCODE_KEY.value();
  if (!key) {
    throw new HttpsError("failed-precondition", "Server geocode key not configured");
  }

  const address = raw.substring(0, 256); // guard length
  const url = new URL("https://maps.googleapis.com/maps/api/geocode/json");
  url.searchParams.set("address", address);
  url.searchParams.set("key", key);
  url.searchParams.set("components", "country:US");

  try {
    const fetchRes = await fetch(url.toString(), {method: "GET"});
    const statusCode = fetchRes.status;
    const body = await fetchRes.json();
    const status = body?.status || "UNKNOWN";

    if (statusCode !== 200) {
      throw new HttpsError("unavailable", `HTTP ${statusCode}`);
    }

    if (status === "REQUEST_DENIED") {
      throw new HttpsError("permission-denied", body?.error_message || "Geocoding denied");
    }
    if (status === "OVER_QUERY_LIMIT") {
      throw new HttpsError("resource-exhausted", "Geocoding quota exceeded");
    }
    if (status !== "OK") {
      return {found: false, status, reason: body?.error_message || "No match"};
    }

    const first = (body?.results || [])[0];
    if (!first) {
      return {found: false, status: "ZERO_RESULTS"};
    }
    const components: Record<string, string> = {};
    for (const comp of first.address_components || []) {
      const types: string[] = comp.types || [];
      for (const t of types) {
        switch (t) {
          case "street_number":
            components.street_number = comp.long_name; break;
          case "route":
            components.route = comp.long_name; break;
          case "locality":
            components.city = comp.long_name; break;
          case "administrative_area_level_1":
            components.state = comp.short_name; break;
          case "postal_code":
            components.zipCode = comp.long_name; break;
        }
      }
    }
    const loc = first.geometry?.location || {lat: 0, lng: 0};
    const streetNumber = components.street_number || "";
    const route = components.route || "";
    const street = `${streetNumber} ${route}`.trim();

    const result = {
      found: true,
      status: "OK",
      formattedAddress: first.formatted_address,
      latitude: loc.lat,
      longitude: loc.lng,
      street,
      city: components.city || "",
      state: components.state || "",
      zipCode: components.zipCode || "",
      isValid: true,
    };
    await logAuditEvent("geocode_address", request.auth?.uid || null, {address, status: "OK"}, true);
    return result;
  } catch (e: any) {
    await logAuditEvent("geocode_address_failed", request.auth?.uid || null, {address, error: e.message}, false);
    if (e instanceof HttpsError) throw e;
    throw new HttpsError("internal", "Geocode failed: " + (e.message || "unknown"));
  }
});
