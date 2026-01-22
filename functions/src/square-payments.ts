import {onRequest} from "firebase-functions/v2/https";
import {getFirestore, FieldValue} from "firebase-admin/firestore";
import {logger} from "firebase-functions";
import {getSquareConfig} from "./square-integration";

/**
 * Square Payments Integration
 * Processes customer payments through restaurant's Square account
 *
 * Payment Model:
 * - Customer pays: Meals + Delivery Fee + 10% platform fee
 * - Restaurant receives: Full meal price (no deductions)
 * - FreshPunk fee: 10% of (Meals + Delivery)
 * - Sause: Paid from FreshPunk's 10% fee by kitchen
 */

const db = getFirestore();

/**
 * Process payment through Square using restaurant's OAuth token
 * Customer pays total amount, FreshPunk deducts 10% fee, restaurant gets the rest
 * Note: Restaurant receives full meal price as promised to them
 */
export const processSquarePayment = onRequest(
  {region: "us-central1", timeoutSeconds: 30},
  async (request, response) => {
    response.set("Access-Control-Allow-Origin", "*");
    response.set("Access-Control-Allow-Methods", "POST, OPTIONS");
    response.set("Access-Control-Allow-Headers", "Content-Type, Authorization");

    if (request.method === "OPTIONS") {
      response.status(204).send("");
      return;
    }

    try {
      const {
        orderId,
        restaurantId,
        amountCents, // Total amount customer is paying (cents)
        sourceId, // Square payment token from client
        idempotencyKey,
        customerId,
        customerName,
        customerEmail,
      } = request.body;

      // Validate inputs
      if (!orderId || !restaurantId || !amountCents || !sourceId) {
        response.status(400).json({
          error: "Missing required fields: orderId, restaurantId, amountCents, sourceId",
        });
        return;
      }

      logger.info("Processing Square payment", {
        orderId,
        restaurantId,
        amountCents,
      });

      // Get restaurant OAuth credentials
      const restaurantDoc = await db.collection("restaurant_partners").doc(restaurantId).get();
      if (!restaurantDoc.exists) {
        response.status(404).json({error: "Restaurant not found"});
        return;
      }

      const restaurant = restaurantDoc.data()!;
      const accessToken = restaurant.squareAccessToken;
      const locationId = restaurant.squareLocationId || restaurant.squareMerchantId;

      if (!accessToken || !locationId) {
        response.status(400).json({
          error: "Restaurant Square credentials incomplete",
        });
        return;
      }

      // Calculate platform fee (10% default, can be configurable per restaurant)
      const platformFeePercent = restaurant.platformFeePercent || 10;
      const platformFeeCents = Math.round((amountCents * platformFeePercent) / 100);
      const restaurantReceivesCents = amountCents - platformFeeCents;

      logger.info("Payment breakdown", {
        orderId,
        totalCents: amountCents,
        platformFeeCents,
        restaurantReceivesCents,
        feePercent: platformFeePercent,
      });

      // Prepare Square Payment request
      // Note: Payment goes to restaurant's account via their OAuth
      const paymentPayload = {
        idempotency_key: idempotencyKey || `fp_${orderId}_${Date.now()}`,
        amount_money: {
          amount: amountCents,
          currency: "USD",
        },
        source_id: sourceId, // Square payment token from Web Payments
        location_id: locationId,
        customer_id: customerId,
        order_id: orderId,
        receipt_number_option: "ORDER_AND_PAYMENT_RECEIPTS",
        note: `FreshPunk Order #${orderId.substring(0, 8)}`,
        app_fee_money: {
          // Platform fee goes to FreshPunk's Square account
          amount: platformFeeCents,
          currency: "USD",
        },
      };

      const {baseUrl} = getSquareConfig();

      // Call Square Payments API
      const paymentResponse = await fetch(`${baseUrl}/v2/payments`, {
        method: "POST",
        headers: {
          "Square-Version": "2023-10-18",
          "Authorization": `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(paymentPayload),
      });

      const paymentData = await paymentResponse.json();

      if (!paymentResponse.ok) {
        logger.error("Square payment failed", {
          orderId,
          restaurantId,
          status: paymentResponse.status,
          error: paymentData.errors,
        });

        response.status(paymentResponse.status).json({
          error: "Payment processing failed",
          details: paymentData.errors,
        });
        return;
      }

      const squarePaymentId = paymentData.payment?.id;
      const paymentStatus = paymentData.payment?.status;

      logger.info("Square payment successful", {
        orderId,
        restaurantId,
        squarePaymentId,
        paymentStatus,
      });

      // Record payment in Firestore
      const paymentRecord = {
        orderId,
        restaurantId,
        customerId,
        customerName,
        customerEmail,
        amountCents,
        platformFeeCents,
        restaurantReceivesCents,
        squarePaymentId,
        paymentStatus,
        paymentMethod: "square",
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      };

      // Save payment record
      const paymentsCollectionRef = db.collection("payments");
      const paymentDocRef = await paymentsCollectionRef.add(paymentRecord);

      logger.info("Payment recorded in Firestore", {
        orderId,
        paymentDocId: paymentDocRef.id,
      });

      // Update order as paid
      await db.collection("orders").doc(orderId).update({
        paymentStatus: "paid",
        squarePaymentId,
        paymentAmount: amountCents,
        platformFee: platformFeeCents,
        restaurantEarnings: restaurantReceivesCents,
        updatedAt: FieldValue.serverTimestamp(),
      });

      // Track restaurant earnings
      const restaurantEarningsRef = db.collection("restaurant_earnings").doc(restaurantId);
      const earningsDoc = await restaurantEarningsRef.get();
      const currentEarnings = earningsDoc.exists ? earningsDoc.data()!.totalCents || 0 : 0;

      await restaurantEarningsRef.set({
        restaurantId,
        totalCents: currentEarnings + restaurantReceivesCents,
        totalOrders: (earningsDoc.exists ? earningsDoc.data()!.totalOrders || 0 : 0) + 1,
        platformFeesCents: (earningsDoc.exists ? earningsDoc.data()!.platformFeesCents || 0 : 0) + platformFeeCents,
        lastPaymentAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});

      // Success response
      response.status(200).json({
        success: true,
        orderId,
        squarePaymentId,
        amountCents,
        restaurantReceivesCents,
        platformFeeCents,
        paymentStatus,
        message: "Payment processed successfully",
      });
    } catch (error: any) {
      logger.error("Payment processing error", {
        error: error.message,
        stack: error.stack,
      });

      response.status(500).json({
        error: "Payment processing failed",
        details: error.message,
      });
    }
  }
);

/**
 * Get restaurant earnings summary
 * Returns total earned, number of orders, platform fees
 */
export const getRestaurantEarnings = onRequest(
  {region: "us-central1"},
  async (request, response) => {
    response.set("Access-Control-Allow-Origin", "*");

    try {
      const restaurantId = request.query.restaurantId as string;

      if (!restaurantId) {
        response.status(400).json({error: "restaurantId required"});
        return;
      }

      const earningsDoc = await db.collection("restaurant_earnings").doc(restaurantId).get();

      if (!earningsDoc.exists) {
        response.status(200).json({
          restaurantId,
          totalCents: 0,
          totalOrders: 0,
          platformFeesCents: 0,
          message: "No earnings yet",
        });
        return;
      }

      const earnings = earningsDoc.data()!;

      response.status(200).json({
        restaurantId,
        totalCents: earnings.totalCents || 0,
        totalDollars: ((earnings.totalCents || 0) / 100).toFixed(2),
        totalOrders: earnings.totalOrders || 0,
        platformFeesCents: earnings.platformFeesCents || 0,
        platformFeesDollars: ((earnings.platformFeesCents || 0) / 100).toFixed(2),
        lastPaymentAt: earnings.lastPaymentAt,
      });
    } catch (error: any) {
      logger.error("Get earnings error", {error: error.message});

      response.status(500).json({
        error: "Failed to get earnings",
        details: error.message,
      });
    }
  }
);

/**
 * Create payout for restaurant
 * Transfers earned amount to restaurant's bank account
 * Can be called manually or on schedule (weekly/monthly)
 */
export const createRestaurantPayout = onRequest(
  {region: "us-central1", timeoutSeconds: 60},
  async (request, response) => {
    response.set("Access-Control-Allow-Origin", "*");

    try {
      const {restaurantId, payoutMethod = "stripe"} = request.body;

      if (!restaurantId) {
        response.status(400).json({error: "restaurantId required"});
        return;
      }

      // Get restaurant earnings
      const earningsDoc = await db.collection("restaurant_earnings").doc(restaurantId).get();
      if (!earningsDoc.exists || !earningsDoc.data()!.totalCents) {
        response.status(400).json({
          error: "No earnings to pay out",
        });
        return;
      }

      const earnings = earningsDoc.data()!;
      const payoutAmountCents = earnings.totalCents;

      logger.info("Creating payout", {
        restaurantId,
        payoutAmountCents,
        payoutMethod,
      });

      // Get restaurant bank info
      const restaurantDoc = await db.collection("restaurant_partners").doc(restaurantId).get();
      if (!restaurantDoc.exists) {
        response.status(404).json({error: "Restaurant not found"});
        return;
      }

      // TODO: Implement actual payout based on payoutMethod
      // For now, just track the payout request
      const payoutRecord = {
        restaurantId,
        amountCents: payoutAmountCents,
        payoutMethod,
        status: "pending",
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      };

      const payoutDocRef = await db.collection("payouts").add(payoutRecord);

      // Reset earnings after payout
      await db.collection("restaurant_earnings").doc(restaurantId).update({
        totalCents: 0,
        payoutsPending: (earnings.payoutsPending || 0) + payoutAmountCents,
        lastPayoutAt: FieldValue.serverTimestamp(),
      });

      response.status(200).json({
        success: true,
        payoutId: payoutDocRef.id,
        restaurantId,
        payoutAmountCents,
        payoutAmountDollars: (payoutAmountCents / 100).toFixed(2),
        payoutMethod,
        message: "Payout created successfully",
      });
    } catch (error: any) {
      logger.error("Payout creation error", {error: error.message});

      response.status(500).json({
        error: "Payout creation failed",
        details: error.message,
      });
    }
  }
);
