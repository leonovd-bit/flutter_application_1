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
import {onDocumentUpdated} from "firebase-functions/v2/firestore";
import * as logger from "firebase-functions/logger";
import Stripe from "stripe";
import {defineSecret} from "firebase-functions/params";
import {initializeApp} from "firebase-admin/app";
import {getFirestore, FieldValue, Timestamp} from "firebase-admin/firestore";
import {getMessaging} from "firebase-admin/messaging";
import {getAuth} from "firebase-admin/auth";

// Define secrets via Firebase Functions Secret Manager
const STRIPE_SECRET_KEY = defineSecret("STRIPE_SECRET_KEY");
const STRIPE_WEBHOOK_SECRET = defineSecret("STRIPE_WEBHOOK_SECRET");
const TWILIO_ACCOUNT_SID = defineSecret("TWILIO_ACCOUNT_SID");
const TWILIO_AUTH_TOKEN = defineSecret("TWILIO_AUTH_TOKEN");
const ADMIN_EMAIL_ALLOWLIST = defineSecret("ADMIN_EMAIL_ALLOWLIST");
const JWT_SECRET = defineSecret("JWT_SECRET"); // For kitchen partner auth

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

// Initialize Admin SDK
initializeApp();
const db = getFirestore();

// Enhanced connectivity check with rate limiting
export const ping = onCall(async (request: any) => {
  const identifier = request.rawRequest?.ip || "unknown";

  if (!await rateLimitCheck(identifier, 60, 60000)) {
    throw new HttpsError("resource-exhausted", "Rate limit exceeded");
  }

  return {ok: true, time: Date.now(), version: "2.0.0"};
});

// Enhanced admin granting with comprehensive validation and audit
export const grantAdminAllowlist = onCall({secrets: [ADMIN_EMAIL_ALLOWLIST]}, async (request: any) => {
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
export const grantKitchenAccess = onCall({secrets: [JWT_SECRET]}, async (request: any) => {
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
export const createPaymentIntent = onCall({secrets: [STRIPE_SECRET_KEY]}, async (request: any) => {
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

    // Comprehensive validation
    if (typeof amount !== "number" || !Number.isInteger(amount) || amount <= 0) {
      throw new HttpsError("invalid-argument", "Valid amount (integer, cents) is required");
    }

    if (amount > 100000) { // $1000 max per transaction
      throw new HttpsError("invalid-argument", "Amount exceeds maximum limit");
    }

    if (currency !== "usd") {
      throw new HttpsError("invalid-argument", "Only USD currency is supported");
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
      throw e;
    }
    throw new HttpsError("internal", "Payment processing failed. Please try again.");
  }
});

// Enhanced order management for kitchen partners
export const updateOrderStatus = onCall(async (request: any) => {
  const callerUid = request.auth?.uid;
  const isAdmin = request.auth?.token?.admin === true;
  const isKitchen = request.auth?.token?.kitchen === true;

  if (!callerUid) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  if (!isAdmin && !isKitchen) {
    throw new HttpsError("permission-denied", "Only kitchen partners and admins can update order status.");
  }

  if (!await rateLimitCheck(callerUid, 100, 60000)) { // 100 updates per minute
    throw new HttpsError("resource-exhausted", "Update rate limit exceeded.");
  }

  const {orderId, status, trackingNumber, estimatedDeliveryTime, notes} = sanitizeInput(request.data || {});

  if (!orderId || typeof orderId !== "string") {
    throw new HttpsError("invalid-argument", "Valid order ID is required.");
  }

  const validStatuses = ["pending", "confirmed", "preparing", "ready", "out_for_delivery", "delivered", "cancelled"];
  if (!status || !validStatuses.includes(status)) {
    throw new HttpsError("invalid-argument", "Valid status is required.");
  }

  try {
    const orderRef = db.collection("orders").doc(orderId);
    const orderDoc = await orderRef.get();

    if (!orderDoc.exists) {
      throw new HttpsError("not-found", "Order not found.");
    }

    const orderData = orderDoc.data()!;

    // Kitchen partners can only update orders for their kitchen
    if (isKitchen && !isAdmin) {
      const kitchenId = request.auth.token.kitchenId;
      if (orderData.kitchenId !== kitchenId) {
        throw new HttpsError("permission-denied", "You can only update orders for your kitchen.");
      }
    }

    const updateData: any = {
      status,
      updatedAt: FieldValue.serverTimestamp(),
      updatedBy: callerUid,
    };

    if (trackingNumber) updateData.trackingNumber = trackingNumber;
    if (estimatedDeliveryTime) updateData.estimatedDeliveryTime = new Date(estimatedDeliveryTime);
    if (notes) updateData.kitchenNotes = notes;

    await orderRef.update(updateData);

    await logAuditEvent("order_status_updated", callerUid, {
      orderId,
      oldStatus: orderData.status,
      newStatus: status,
      kitchenId: request.auth.token?.kitchenId || "admin",
    }, true);

    // Send notification to customer
    if (orderData.userId) {
      await sendOrderStatusNotification(orderData.userId, orderId, status);
    }

    return {ok: true, orderId, status};
  } catch (e: any) {
    logger.error("updateOrderStatus error", e);
    await logAuditEvent("order_update_failed", callerUid, {orderId, error: e.message}, false);

    if (e instanceof HttpsError) {
      throw e;
    }
    throw new HttpsError("internal", "Failed to update order status.");
  }
});

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

// Create Customer
export const createCustomer = onCall({secrets: [STRIPE_SECRET_KEY]}, async (request: any) => {
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
export const createSubscription = onCall({secrets: [STRIPE_SECRET_KEY]}, async (request: any) => {
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
export const createSetupIntent = onCall({secrets: [STRIPE_SECRET_KEY]}, async (request: any) => {
  try {
  const stripe = getStripe();
    const {customer} = request.data;

    const setupIntent = await stripe.setupIntents.create({
      customer,
      automatic_payment_methods: {enabled: true},
    });

    return {client_secret: setupIntent.client_secret};
  } catch (error) {
    logger.error("Error creating setup intent:", error);
    throw new Error("Failed to create setup intent");
  }
});

// Cancel Subscription
export const cancelSubscription = onCall({secrets: [STRIPE_SECRET_KEY]}, async (request: any) => {
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
export const updateSubscription = onCall({secrets: [STRIPE_SECRET_KEY]}, async (request: any) => {
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
export const pauseSubscription = onCall({secrets: [STRIPE_SECRET_KEY]}, async (request: any) => {
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
        await db.collection("users").doc(uid)
          .collection("subscriptions").doc(updated.id)
          .set({
            id: updated.id,
            stripeSubscriptionId: updated.id,
            status: "paused",
            pauseBehavior: "mark_uncollectible",
            updatedAt: FieldValue.serverTimestamp(),
          }, {merge: true});
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
export const resumeSubscription = onCall({secrets: [STRIPE_SECRET_KEY]}, async (request: any) => {
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
        await db.collection("users").doc(uid)
          .collection("subscriptions").doc(updated.id)
          .set({
            id: updated.id,
            stripeSubscriptionId: updated.id,
            status: updated.status ?? "active",
            nextBillingDate: nextTs ? new Date(nextTs * 1000) : null,
            updatedAt: FieldValue.serverTimestamp(),
          }, {merge: true});
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
export const getBillingOptions = onCall({secrets: [STRIPE_SECRET_KEY]}, async (request: any) => {
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
export const listPaymentMethods = onCall({secrets: [STRIPE_SECRET_KEY]}, async (request: any) => {
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
export const detachPaymentMethod = onCall({secrets: [STRIPE_SECRET_KEY]}, async (request: any) => {
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
export const setDefaultPaymentMethod = onCall({secrets: [STRIPE_SECRET_KEY]}, async (request: any) => {
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
export const placeOrder = onCall(async (request: any) => {
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
export const cancelOrder = onCall(async (request: any) => {
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
      status: "canceled",
      canceledAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    return {success: true};
  } catch (error) {
    logger.error("cancelOrder error", error);
    return {success: false, error: (error as Error).message};
  }
});

// ============ FCM Registration ============
export const registerFcmToken = onCall(async (request: any) => {
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
export const onOrderUpdated = onDocumentUpdated("orders/{orderId}", async (event: any) => {
  try {
    const before = event.data?.before.data() as any;
    const after = event.data?.after.data() as any;
    if (!before || !after) return;
    if (before.status === after.status) return;

    const userId = after.userId as string | undefined;
    if (!userId) return;

    const tokensSnap = await db.collection("users").doc(userId).collection("fcmTokens").get();
    if (tokensSnap.empty) return;
  const tokens = tokensSnap.docs.map((d: any) => d.id).filter(Boolean);
    if (tokens.length === 0) return;

    const messaging = getMessaging();
    const title = "Order update";
    const body = `Your order is now ${after.status}`;
    await messaging.sendEachForMulticast({
      tokens,
      notification: {title, body},
      data: {
        orderId: event.params.orderId as string,
        status: String(after.status ?? "unknown"),
      },
    });
  } catch (e) {
    logger.error("onOrderUpdated error", e);
  }
});

// ============ Admin Claims ============
export const grantAdmin = onCall(async (request: any) => {
  const callerAdmin = (request.auth?.token as any)?.admin === true;
  // TEMP bootstrap: allow grant when 'bootstrap' is true. Remove after owner is admin.
  const {uid, email, bootstrap} = request.data ?? {} as {uid?: string; email?: string; bootstrap?: boolean};
  const auth = getAuth();

  // Permission check: allow if caller is admin, or if bootstrap flag is set (temporary).
  const bootstrapAllowed = bootstrap === true;
  if (!(callerAdmin || bootstrapAllowed)) {
    throw new HttpsError("permission-denied", "Only admins can grant admin (or pass bootstrap for the owner email).");
  }

  let targetUid: string | undefined = uid;
  if (!targetUid && email) {
    try {
      const user = await auth.getUserByEmail(email);
      targetUid = user.uid;
    } catch (err) {
      throw new HttpsError("not-found", "No Firebase user found for the provided email. Please sign up/sign in first and try again.");
    }
  }
  if (!targetUid) {
    throw new HttpsError("invalid-argument", "uid or email is required");
  }
  await auth.setCustomUserClaims(targetUid, {admin: true});
  return {success: true, uid: targetUid};
});

// Clear existing meals to trigger reseed with local images
export const clearMealsAndReseed = onCall(async (request) => {
  try {
    logger.info("Clearing existing meals...");

    // Get all meals
    const mealsSnapshot = await db.collection("meals").get();

    // Delete all existing meals in batches
    const batch = db.batch();
    mealsSnapshot.docs.forEach((doc) => {
      batch.delete(doc.ref);
    });

    await batch.commit();
    logger.info(`Deleted ${mealsSnapshot.docs.length} existing meals`);

    return {
      success: true,
      message: `Cleared ${mealsSnapshot.docs.length} meals. App will reseed with local images on next meal load.`,
      clearedCount: mealsSnapshot.docs.length,
    };
  } catch (error) {
    logger.error("Error clearing meals:", error);
    throw new HttpsError("internal", "Failed to clear meals");
  }
});

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

      // Create subscription record
      await db.collection("users").doc(userId)
        .collection("subscriptions").doc(subscription.id).set({
          id: subscription.id,
          stripeSubscriptionId: subscription.id,
          status: subscription.status,
          stripePriceId: subscription.items.data[0]?.price?.id,
          currentPeriodStart: new Date(subscription.current_period_start * 1000),
          currentPeriodEnd: new Date(subscription.current_period_end * 1000),
          cancelAtPeriodEnd: subscription.cancel_at_period_end,
          createdAt: FieldValue.serverTimestamp(),
        });

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

      await db.collection("users").doc(userId)
        .collection("subscriptions").doc(subscription.id).update({
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

      await db.collection("users").doc(userId)
        .collection("subscriptions").doc(subscription.id).update({
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
export const getSecurityMetrics = onCall(async (request: any) => {
  const isAdmin = request.auth?.token?.admin === true;

  if (!isAdmin) {
    throw new HttpsError("permission-denied", "Admin access required.");
  }

  try {
    const now = new Date();
    const dayAgo = new Date(now.getTime() - 24 * 60 * 60 * 1000);

    // Get recent audit logs
    const auditSnapshot = await db.collection("audit_logs")
      .where("timestamp", ">=", dayAgo)
      .orderBy("timestamp", "desc")
      .limit(100)
      .get();

    const auditLogs = auditSnapshot.docs.map((doc) => doc.data());

    // Calculate metrics
    const totalEvents = auditLogs.length;
    const failedEvents = auditLogs.filter((log) => !log.isSuccess).length;
    const successRate = totalEvents > 0 ? ((totalEvents - failedEvents) / totalEvents * 100).toFixed(1) : "100";

    const eventTypes = auditLogs.reduce((acc: any, log) => {
      acc[log.action] = (acc[log.action] || 0) + 1;
      return acc;
    }, {});

    return {
      period: "24h",
      totalEvents,
      failedEvents,
      successRate: `${successRate}%`,
      eventTypes,
      recentLogs: auditLogs.slice(0, 20), // Last 20 events
    };
  } catch (error: any) {
    logger.error("Error getting security metrics", error);
    throw new HttpsError("internal", "Failed to retrieve security metrics");
  }
});

// Kitchen operations Cloud Functions
export const getKitchenOrders = onCall(async (request: any) => {
  const callerUid = request.auth?.uid;
  const isKitchen = request.auth?.token?.kitchen === true;
  const isAdmin = request.auth?.token?.admin === true;
  const kitchenId = request.auth?.token?.kitchenId;

  if (!callerUid) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  if (!isKitchen && !isAdmin) {
    throw new HttpsError("permission-denied", "Kitchen partner access required.");
  }

  if (!await rateLimitCheck(callerUid, 60, 60000)) { // 60 requests per minute
    throw new HttpsError("resource-exhausted", "Request rate limit exceeded.");
  }

  try {
    const {status = "all", limit = 50} = sanitizeInput(request.data || {});

    let ordersQuery = db.collection("orders")
      .orderBy("createdAt", "desc")
      .limit(Math.min(limit, 100)); // Max 100 orders

    // Filter by status if specified
    if (status !== "all") {
      const validStatuses = ["pending", "confirmed", "preparing", "ready", "out_for_delivery", "delivered", "cancelled"];
      if (validStatuses.includes(status)) {
        ordersQuery = ordersQuery.where("status", "==", status);
      }
    }

    // Kitchen partners see only their kitchen's orders (if kitchenId is set)
    if (isKitchen && !isAdmin && kitchenId) {
      ordersQuery = ordersQuery.where("kitchenId", "==", kitchenId);
    }

    const ordersSnapshot = await ordersQuery.get();
    const orders = ordersSnapshot.docs.map((doc) => {
      const data = doc.data();
      return {
        id: doc.id,
        ...data,
        // Remove sensitive customer information for kitchen partners
        customerEmail: isAdmin ? data.customerEmail : undefined,
        customerPhone: isAdmin ? data.customerPhone : undefined,
      };
    });

    await logAuditEvent("kitchen_orders_retrieved", callerUid, {
      kitchenId,
      ordersCount: orders.length,
      status,
    }, true);

    return {
      orders,
      count: orders.length,
      kitchenId,
    };
  } catch (error: any) {
    logger.error("Error getting kitchen orders", error);
    await logAuditEvent("kitchen_orders_failed", callerUid, {error: error.message}, false);
    throw new HttpsError("internal", "Failed to retrieve kitchen orders");
  }
});

// Bulk order status update for kitchen efficiency
export const bulkUpdateOrderStatus = onCall(async (request: any) => {
  const callerUid = request.auth?.uid;
  const isKitchen = request.auth?.token?.kitchen === true;
  const isAdmin = request.auth?.token?.admin === true;
  const kitchenId = request.auth?.token?.kitchenId;

  if (!callerUid) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  if (!isKitchen && !isAdmin) {
    throw new HttpsError("permission-denied", "Kitchen partner access required.");
  }

  if (!await rateLimitCheck(callerUid, 10, 60000)) { // 10 bulk updates per minute
    throw new HttpsError("resource-exhausted", "Bulk update rate limit exceeded.");
  }

  const {orderIds, status} = sanitizeInput(request.data || {});

  if (!Array.isArray(orderIds) || orderIds.length === 0 || orderIds.length > 20) {
    throw new HttpsError("invalid-argument", "Must provide 1-20 order IDs");
  }

  const validStatuses = ["preparing", "ready", "out_for_delivery", "delivered"];
  if (!validStatuses.includes(status)) {
    throw new HttpsError("invalid-argument", "Invalid status for bulk update");
  }

  try {
    const batch = db.batch();
    const updatedOrders = [];

    for (const orderId of orderIds) {
      const orderRef = db.collection("orders").doc(orderId);
      const orderDoc = await orderRef.get();

      if (!orderDoc.exists) {
        continue; // Skip non-existent orders
      }

      const orderData = orderDoc.data()!;

      // Verify kitchen access for this order
      if (isKitchen && !isAdmin && orderData.kitchenId !== kitchenId) {
        continue; // Skip orders not belonging to this kitchen
      }

      batch.update(orderRef, {
        status,
        updatedAt: FieldValue.serverTimestamp(),
        updatedBy: callerUid,
        kitchenUpdatedAt: FieldValue.serverTimestamp(),
      });

      updatedOrders.push(orderId);
    }

    await batch.commit();

    // Send notifications for updated orders
    for (const orderId of updatedOrders) {
      try {
        const orderDoc = await db.collection("orders").doc(orderId).get();
        const orderData = orderDoc.data();
        if (orderData?.userId) {
          await sendOrderStatusNotification(orderData.userId, orderId, status);
        }
      } catch (notificationError) {
        logger.warn(`Failed to send notification for order ${orderId}`, notificationError);
      }
    }

    await logAuditEvent("bulk_order_update", callerUid, {
      orderIds: updatedOrders,
      status,
      kitchenId,
      count: updatedOrders.length,
    }, true);

    return {
      updatedOrders,
      count: updatedOrders.length,
      status,
    };
  } catch (error: any) {
    logger.error("Error in bulk order update", error);
    await logAuditEvent("bulk_order_update_failed", callerUid, {error: error.message}, false);
    throw new HttpsError("internal", "Failed to update orders");
  }
});

// Get kitchen performance metrics
export const getKitchenMetrics = onCall(async (request: any) => {
  const callerUid = request.auth?.uid;
  const isKitchen = request.auth?.token?.kitchen === true;
  const isAdmin = request.auth?.token?.admin === true;
  const kitchenId = request.auth?.token?.kitchenId;

  if (!callerUid) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  if (!isKitchen && !isAdmin) {
    throw new HttpsError("permission-denied", "Kitchen partner access required.");
  }

  try {
    const now = new Date();
    const dayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const weekStart = new Date(dayStart.getTime() - 7 * 24 * 60 * 60 * 1000);

    let ordersQuery: any = db.collection("orders");

    // Filter by kitchen if not admin
    if (isKitchen && !isAdmin && kitchenId) {
      ordersQuery = ordersQuery.where("kitchenId", "==", kitchenId);
    }

    // Get today's orders
    const todayOrdersSnapshot = await ordersQuery
      .where("createdAt", ">=", dayStart)
      .get();

    // Get this week's orders
    const weekOrdersSnapshot = await ordersQuery
      .where("createdAt", ">=", weekStart)
      .get();

    const todayOrders = todayOrdersSnapshot.docs.map((doc: any) => doc.data());
    const weekOrders = weekOrdersSnapshot.docs.map((doc: any) => doc.data());

    // Calculate metrics
    const todayStats = calculateOrderStats(todayOrders);
    const weekStats = calculateOrderStats(weekOrders);

    return {
      today: {
        date: dayStart.toISOString().split("T")[0],
        ...todayStats,
      },
      week: {
        startDate: weekStart.toISOString().split("T")[0],
        endDate: now.toISOString().split("T")[0],
        ...weekStats,
      },
      kitchenId: isAdmin ? null : kitchenId,
    };
  } catch (error: any) {
    logger.error("Error getting kitchen metrics", error);
    throw new HttpsError("internal", "Failed to retrieve kitchen metrics");
  }
});

function calculateOrderStats(orders: any[]) {
  const total = orders.length;
  const byStatus = orders.reduce((acc: any, order) => {
    acc[order.status] = (acc[order.status] || 0) + 1;
    return acc;
  }, {});

  const completed = (byStatus.delivered || 0);
  const pending = (byStatus.pending || 0) + (byStatus.confirmed || 0);
  const inProgress = (byStatus.preparing || 0) + (byStatus.ready || 0) + (byStatus.out_for_delivery || 0);
  const cancelled = (byStatus.cancelled || 0);

  const totalRevenue = orders
    .filter((order) => order.status === "delivered")
    .reduce((sum, order) => sum + (order.totalAmount || 0), 0);

  return {
    total,
    completed,
    pending,
    inProgress,
    cancelled,
    revenue: totalRevenue,
    statusBreakdown: byStatus,
  };
}

// Temporary function to grant kitchen access (remove after setup)
export const tempGrantKitchenAccess = onRequest(async (req: any, res: any) => {
  const email = req.query.email || "davvitala@gmail.com";

  try {
    // Get user by email
    const userRecord = await getAuth().getUserByEmail(email);

    // Set custom claims
    await getAuth().setCustomUserClaims(userRecord.uid, {
      kitchen: true,
      kitchenId: "freshpunk_main",
      kitchenName: "FreshPunk Main Kitchen",
      partnerName: "Test Kitchen Partner",
      partnerEmail: email,
      kitchenGrantedAt: Date.now(),
    });

    res.json({
      success: true,
      message: `Kitchen access granted to ${email}`,
      uid: userRecord.uid,
      claims: {
        kitchen: true,
        kitchenId: "freshpunk_main",
        kitchenName: "FreshPunk Main Kitchen",
      },
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: (error as Error).message,
    });
  }
});

// ============ SMS Notification Functions ============

// Send SMS notification via Twilio
export const sendSMS = onCall({secrets: [TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN]}, async (request: any) => {
  try {
    const {toNumber, message, orderNumber} = request.data ?? {};

    if (!toNumber || !message) {
      throw new Error("toNumber and message are required");
    }

    const accountSid = TWILIO_ACCOUNT_SID.value();
    const authToken = TWILIO_AUTH_TOKEN.value();

    if (!accountSid || !authToken) {
      logger.error("Twilio credentials not configured");
      return {success: false, error: "SMS service not configured"};
    }

    // Clean phone number
    const cleanNumber = cleanPhoneNumber(toNumber);
    if (!cleanNumber) {
      throw new Error("Invalid phone number format");
    }

    // Send SMS via Twilio API
    const twilioUrl = `https://api.twilio.com/2010-04-01/Accounts/${accountSid}/Messages.json`;
    const credentials = Buffer.from(`${accountSid}:${authToken}`).toString("base64");

    const response = await fetch(twilioUrl, {
      method: "POST",
      headers: {
        "Authorization": `Basic ${credentials}`,
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: new URLSearchParams({
        "From": "+18336470630", // Replace with your Twilio number
        "To": cleanNumber,
        "Body": message,
      }),
    });

    if (response.ok) {
      const data = await response.json();
      logger.info(`SMS sent successfully. SID: ${data.sid}`);

      // Log notification
      await db.collection("notifications").add({
        type: "sms",
        toNumber: cleanNumber,
        message: message.substring(0, 100) + "...", // Truncate for storage
        orderNumber: orderNumber || null,
        status: "sent",
        twilioSid: data.sid,
        timestamp: FieldValue.serverTimestamp(),
      });

      return {success: true, sid: data.sid};
    } else {
      const errorData = await response.text();
      logger.error(`Twilio API error: ${response.status} - ${errorData}`);
      return {success: false, error: `SMS sending failed: ${response.status}`};
    }
  } catch (error) {
    logger.error("SMS sending error:", error);
    return {success: false, error: (error as Error).message};
  }
});

// Send order confirmation SMS
export const sendOrderConfirmationSMS = onCall({secrets: [TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN]}, async (request: any) => {
  try {
    const {orderNumber, customerName, customerPhone, items, estimatedDelivery} = request.data ?? {};

    if (!orderNumber || !customerPhone) {
      throw new Error("orderNumber and customerPhone are required");
    }

    // Format items list
    const itemsList = Array.isArray(items) ? items.slice(0, 3).join(", ") : "Your meals";
    const moreItems = Array.isArray(items) && items.length > 3 ? ` +${items.length - 3} more` : "";

    const message = `🍽️ Order Confirmed! #${orderNumber}

Hi ${customerName || "there"}! Your FreshPunk order is being prepared:
${itemsList}${moreItems}

📦 Estimated delivery: ${estimatedDelivery || "30-45 minutes"}
📱 Track your order in the app!

Thanks for choosing FreshPunk! 🌟`;

    // Send SMS using internal function
    const result = await sendSMSInternal(customerPhone, message, orderNumber);

    return result;
  } catch (error) {
    logger.error("Order confirmation SMS error:", error);
    return {success: false, error: (error as Error).message};
  }
});

// Send order status update SMS
export const sendOrderStatusSMS = onCall({secrets: [TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN]}, async (request: any) => {
  try {
    const {orderNumber, customerPhone, status, eta, driverName} = request.data ?? {};

    if (!orderNumber || !customerPhone || !status) {
      throw new Error("orderNumber, customerPhone, and status are required");
    }

    let message = `📦 Order Update #${orderNumber}\n\n`;

    switch (status.toLowerCase()) {
      case "preparing":
        message += `👨‍🍳 Your meal is being prepared!\nETA: ${eta || "30-45 minutes"}`;
        break;
      case "ready":
        message += "✅ Your order is ready for pickup!";
        break;
      case "out_for_delivery":
        message += "🚗 Out for delivery!";
        if (driverName) {
          message += `\nDriver: ${driverName}`;
        }
        if (eta) {
          message += `\nETA: ${eta}`;
        }
        break;
      case "nearby":
        message += "📍 Driver is nearby!\nETA: 2-5 minutes";
        break;
      case "delivered":
        message += "🎉 Order delivered!\nEnjoy your FreshPunk meal!";
        break;
      default:
        message += `Status: ${status}`;
        if (eta) {
          message += `\nETA: ${eta}`;
        }
    }

    message += "\n\n📱 Open the app for real-time tracking";

    // Send SMS using internal function
    const result = await sendSMSInternal(customerPhone, message, orderNumber);

    return result;
  } catch (error) {
    logger.error("Order status SMS error:", error);
    return {success: false, error: (error as Error).message};
  }
});

// Helper function to clean phone numbers
function cleanPhoneNumber(phoneNumber: string): string | null {
  // Remove all non-digit characters
  const digits = phoneNumber.replace(/[^\d]/g, "");

  // US phone number validation
  if (digits.length === 10) {
    return `+1${digits}`; // Add US country code
  } else if (digits.length === 11 && digits.startsWith("1")) {
    return `+${digits}`; // Already has country code
  }

  return null; // Invalid
}

// Internal SMS sending function
async function sendSMSInternal(toNumber: string, message: string, orderNumber?: string): Promise<{success: boolean; error?: string; sid?: string}> {
  try {
    const accountSid = TWILIO_ACCOUNT_SID.value();
    const authToken = TWILIO_AUTH_TOKEN.value();

    if (!accountSid || !authToken) {
      logger.error("Twilio credentials not configured");
      return {success: false, error: "SMS service not configured"};
    }

    // Clean phone number
    const cleanNumber = cleanPhoneNumber(toNumber);
    if (!cleanNumber) {
      return {success: false, error: "Invalid phone number format"};
    }

    // Send SMS via Twilio API
    const twilioUrl = `https://api.twilio.com/2010-04-01/Accounts/${accountSid}/Messages.json`;
    const credentials = Buffer.from(`${accountSid}:${authToken}`).toString("base64");

    const response = await fetch(twilioUrl, {
      method: "POST",
      headers: {
        "Authorization": `Basic ${credentials}`,
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: new URLSearchParams({
        "From": "+18336470630", // Replace with your Twilio number
        "To": cleanNumber,
        "Body": message,
      }),
    });

    if (response.ok) {
      const data = await response.json();
      logger.info(`SMS sent successfully. SID: ${data.sid}`);

      // Log notification
      await db.collection("notifications").add({
        type: "sms",
        toNumber: cleanNumber,
        message: message.substring(0, 100) + "...", // Truncate for storage
        orderNumber: orderNumber || null,
        status: "sent",
        twilioSid: data.sid,
        timestamp: FieldValue.serverTimestamp(),
      });

      return {success: true, sid: data.sid};
    } else {
      const errorData = await response.text();
      logger.error(`Twilio API error: ${response.status} - ${errorData}`);
      return {success: false, error: `SMS sending failed: ${response.status}`};
    }
  } catch (error) {
    logger.error("SMS sending error:", error);
    return {success: false, error: (error as Error).message};
  }
}
