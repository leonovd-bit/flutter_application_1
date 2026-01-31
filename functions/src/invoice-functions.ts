import {onCall} from "firebase-functions/v2/https";
import Stripe from "stripe";
import {getFirestore, FieldValue} from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import {defineSecret} from "firebase-functions/params";

// Initialize Firestore
const db = getFirestore();

// Define secret
const STRIPE_SECRET_KEY = defineSecret("STRIPE_SECRET_KEY");

/**
 * Create and finalize a Stripe invoice for subscription payment
 * Calculates upfront charges based on meal selections, delivery fees, and FreshPunk share
 */
export const createSubscriptionInvoice = onCall(
  {secrets: [STRIPE_SECRET_KEY]},
  async (request) => {
    // Verify user is authenticated
    if (!request.auth) {
      throw new Error("User must be logged in");
    }

    const data = request.data;
    const userId = request.auth.uid;
    const customerId = data.customerId as string;
    const subscriptionPricing = data.subscriptionPricing as any;
    const mealSelections = data.mealSelections as any[];

    // Validate inputs
    if (!customerId || !subscriptionPricing) {
      throw new Error("customerId and subscriptionPricing are required");
    }

    try {
      const stripeKey = STRIPE_SECRET_KEY.value();
      if (!stripeKey) {
        throw new Error("STRIPE_SECRET_KEY not configured");
      }

      const stripe = new Stripe(stripeKey, {apiVersion: "2025-06-30.basil" as any});

      // Create invoice for this subscription billing cycle
      const invoice = await stripe.invoices.create({
        customer: customerId,
        collection_method: "charge_automatically",
        auto_advance: false, // Don't auto-finalize yet
        metadata: {
          userId,
          subscriptionType: "meal_subscription",
          billingCycle: new Date().toISOString().split("T")[0],
        },
      });

      if (!invoice.id) {
        throw new Error("Failed to create invoice");
      }

      if (subscriptionPricing.stripeOnly === true) {
        const baseTotal = (subscriptionPricing.totalAmount || 0) - (subscriptionPricing.stripeFee || 0);
        await stripe.invoiceItems.create({
          customer: customerId,
          invoice: invoice.id,
          amount: Math.round(baseTotal * 100),
          currency: "usd",
          description: "Meals + Delivery",
          metadata: {
            type: "meal_total",
          },
        });

        if (subscriptionPricing.stripeFee > 0) {
          await stripe.invoiceItems.create({
            customer: customerId,
            invoice: invoice.id,
            amount: Math.round(subscriptionPricing.stripeFee * 100),
            currency: "usd",
            description: "Payment Processing Fee",
            metadata: {
              type: "stripe_fee",
              percent: 2.9,
              fixed: 0.30,
            },
          });
        }
      } else {
        // Add line item: FreshPunk Service Fee (10% of meal subtotal)
        await stripe.invoiceItems.create({
          customer: customerId,
          invoice: invoice.id,
          amount: Math.round(subscriptionPricing.freshpunkFee * 100),
          currency: "usd",
          description: "FreshPunk Service Fee (10% of meals)",
          metadata: {
            type: "freshpunk_fee",
            percent: 10,
          },
        });

        // Add line item: Stripe Processing Fee
        if (subscriptionPricing.stripeFee > 0) {
          await stripe.invoiceItems.create({
            customer: customerId,
            invoice: invoice.id,
            amount: Math.round(subscriptionPricing.stripeFee * 100),
            currency: "usd",
            description: "Payment Processing Fee",
            metadata: {
              type: "stripe_fee",
              percent: 2.9,
              fixed: 0.30,
            },
          });
        }

        // Add line item: Stripe Transaction Fee (for transparency)
        if (subscriptionPricing.stripeFee > 0) {
          await stripe.invoiceItems.create({
            customer: customerId,
            invoice: invoice.id,
            amount: Math.round(subscriptionPricing.stripeFee * 100),
            currency: "usd",
            description: "Payment Processing Fee (2.9% + $0.30)",
            metadata: {
              type: "stripe_fee",
              percent: 2.9,
              fixed: 0.30,
            },
          });
        }
      }

      // Finalize the invoice (triggers payment)
      const finalizedInvoice = await stripe.invoices.finalizeInvoice(invoice.id);

      if (!finalizedInvoice.id) {
        throw new Error("Failed to finalize invoice - no ID returned");
      }

      // Store invoice details in Firestore
      await db.collection("users").doc(userId).collection("invoices").doc(
        finalizedInvoice.id
      ).set({
        stripeInvoiceId: finalizedInvoice.id,
        customerId,
        status: "finalized",
        amountCents: Math.round((subscriptionPricing.stripeChargeTotal ?? subscriptionPricing.totalAmount) * 100),
        amountDollars: subscriptionPricing.stripeChargeTotal ?? subscriptionPricing.totalAmount,
        breakdown: {
          mealSubtotal: subscriptionPricing.mealSubtotal,
          deliveryFees: subscriptionPricing.deliveryFees,
          freshpunkFee: subscriptionPricing.freshpunkFee,
          stripeFee: subscriptionPricing.stripeFee,
          stripeChargeTotal: subscriptionPricing.stripeChargeTotal,
          squareChargeTotal: subscriptionPricing.squareChargeTotal,
        },
        mealCount: subscriptionPricing.mealCount,
        billingCycle: new Date().toISOString().split("T")[0],
        createdAt: FieldValue.serverTimestamp(),
        mealSelections: mealSelections.slice(0, 100), // Store meal details for reference
      });

      // Also update the active subscription with invoice info
      const subscriptionsSnapshot = await db.collection("users").doc(userId)
        .collection("subscriptions")
        .where("status", "==", "active")
        .limit(1)
        .get();

      if (!subscriptionsSnapshot.empty) {
        const subscriptionDoc = subscriptionsSnapshot.docs[0];
        await subscriptionDoc.ref.update({
          latestInvoiceId: finalizedInvoice.id,
          latestBillingAmount: subscriptionPricing.totalAmount,
          latestBillingAmountCents: subscriptionPricing.totalAmountCents,
          latestBillingCycle: new Date().toISOString().split("T")[0],
          updatedAt: FieldValue.serverTimestamp(),
        });
      }

      logger.info(
        `Invoice ${finalizedInvoice.id} created and finalized for user ${userId}. Amount: $${subscriptionPricing.totalAmount.toFixed(2)}`
      );

      return {
        success: true,
        invoiceId: finalizedInvoice.id,
        amount: subscriptionPricing.totalAmount,
        amountCents: subscriptionPricing.totalAmountCents,
        status: finalizedInvoice.status,
      };
    } catch (error) {
      logger.error(
        `Failed to create subscription invoice for user ${userId}:`,
        error
      );
      throw new Error(
        `Invoice creation failed: ${error instanceof Error ? error.message : String(error)}`
      );
    }
  }
);

/**
 * Get invoice details for a user
 */
export const getInvoiceDetails = onCall(
  {secrets: [STRIPE_SECRET_KEY]},
  async (request) => {
    if (!request.auth) {
      throw new Error("User must be logged in");
    }

    const userId = request.auth.uid;
    const data = request.data;
    const invoiceId = data.invoiceId as string;

    if (!invoiceId) {
      throw new Error("invoiceId is required");
    }

    try {
      const invoiceDoc = await db.collection("users").doc(userId)
        .collection("invoices").doc(invoiceId).get();

      if (!invoiceDoc.exists) {
        throw new Error("Invoice not found");
      }

      return {
        success: true,
        invoice: invoiceDoc.data(),
      };
    } catch (error) {
      logger.error(`Failed to retrieve invoice ${invoiceId}:`, error);
      throw new Error(
        `Failed to retrieve invoice: ${error instanceof Error ? error.message : String(error)}`
      );
    }
  }
);
