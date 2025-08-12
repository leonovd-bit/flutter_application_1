/**
 * Import function triggers from their respective submodules:
 *
 * import {onCall} from "firebase-functions/v2/https";
 * import {onDocumentWritten} from "firebase-functions/v2/firestore";
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

import {setGlobalOptions} from "firebase-functions";
import {onCall} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import Stripe from "stripe";
import {defineSecret} from "firebase-functions/params";

// Define Stripe secret via Firebase Functions Secret Manager
const STRIPE_SECRET_KEY = defineSecret("STRIPE_SECRET_KEY");

// For cost control, set maximum number of containers
setGlobalOptions({maxInstances: 10});

// Small helper to construct Stripe with validation
function getStripe(): Stripe {
  const key = STRIPE_SECRET_KEY.value();
  if (!key || !key.startsWith("sk_")) {
    logger.error(
      "STRIPE_SECRET_KEY is not a valid Stripe secret key. It should start with 'sk_'."
    );
    throw new Error(
      "Server misconfigured: STRIPE_SECRET_KEY must be a Stripe secret key (starts with sk_)"
    );
  }
  return new Stripe(key);
}

// Create Payment Intent
export const createPaymentIntent = onCall({secrets: [STRIPE_SECRET_KEY]}, async (request) => {
  try {
    const stripe = getStripe();
    const {amount, currency = "usd", customer} = request.data;

    const paymentIntent = await stripe.paymentIntents.create({
      amount,
      currency,
      customer,
      automatic_payment_methods: {enabled: true},
    });

    return {client_secret: paymentIntent.client_secret};
  } catch (error) {
    logger.error("Error creating payment intent:", error);
    throw new Error("Failed to create payment intent");
  }
});

// Create Customer
export const createCustomer = onCall({secrets: [STRIPE_SECRET_KEY]}, async (request) => {
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
export const createSubscription = onCall({secrets: [STRIPE_SECRET_KEY]}, async (request) => {
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
export const createSetupIntent = onCall({secrets: [STRIPE_SECRET_KEY]}, async (request) => {
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
export const cancelSubscription = onCall({secrets: [STRIPE_SECRET_KEY]}, async (request) => {
  try {
  const stripe = getStripe();
    const {subscriptionId} = request.data;

    const subscription = await stripe.subscriptions.cancel(subscriptionId);

    return {subscription};
  } catch (error) {
    logger.error("Error canceling subscription:", error);
    throw new Error("Failed to cancel subscription");
  }
});

// Update Subscription
export const updateSubscription = onCall({secrets: [STRIPE_SECRET_KEY]}, async (request) => {
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
      });

  return {subscription: updatedSubscription};
  } catch (error) {
    logger.error("Error updating subscription:", error);
    throw new Error("Failed to update subscription");
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
export const listPaymentMethods = onCall({secrets: [STRIPE_SECRET_KEY]}, async (request) => {
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

    const data = pms.data.map((pm) => ({
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
export const detachPaymentMethod = onCall({secrets: [STRIPE_SECRET_KEY]}, async (request) => {
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
export const setDefaultPaymentMethod = onCall({secrets: [STRIPE_SECRET_KEY]}, async (request) => {
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
