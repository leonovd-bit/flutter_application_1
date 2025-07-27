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

// Initialize Stripe with your secret key
const stripe = new Stripe(process.env.STRIPE_SECRET_KEY || "sk_test_...", {
  apiVersion: "2025-06-30.basil",
});

// For cost control, set maximum number of containers
setGlobalOptions({maxInstances: 10});

// Create Payment Intent
export const createPaymentIntent = onCall(async (request) => {
  try {
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
export const createCustomer = onCall(async (request) => {
  try {
    const {email, name} = request.data;

    const customer = await stripe.customers.create({
      email,
      name,
    });

    return {customer};
  } catch (error) {
    logger.error("Error creating customer:", error);
    throw new Error("Failed to create customer");
  }
});

// Create Subscription
export const createSubscription = onCall(async (request) => {
  try {
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
export const createSetupIntent = onCall(async (request) => {
  try {
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
export const cancelSubscription = onCall(async (request) => {
  try {
    const {subscriptionId} = request.data;

    const subscription = await stripe.subscriptions.cancel(subscriptionId);

    return {subscription};
  } catch (error) {
    logger.error("Error canceling subscription:", error);
    throw new Error("Failed to cancel subscription");
  }
});

// Update Subscription
export const updateSubscription = onCall(async (request) => {
  try {
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
