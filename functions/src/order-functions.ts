/**
 * Order Generation and Confirmation Functions
 * These functions handle meal selection to order conversion and notifications
 */

import {onCall, HttpsError} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import {getFirestore, FieldValue, Timestamp} from "firebase-admin/firestore";

// CORS configuration for web app access
const corsOptions = {
  cors: ["https://freshpunk-48db1.web.app", "https://freshpunk-48db1.firebaseapp.com"],
};

// ============================================================================
// MEAL SELECTION & ORDER GENERATION FUNCTIONS
// ============================================================================

/**
 * Generates actual orders from user meal selections and delivery schedule
 * This replaces the client-side order creation with server-side validation
 */
export const generateOrderFromMealSelection = onCall(corsOptions, async (request: any) => {
  try {
    const {auth, data} = request;

    // Authentication check
    if (!auth) {
      throw new HttpsError("unauthenticated", "User must be authenticated");
    }

    const userId = auth.uid;
    logger.info(`[generateOrderFromMealSelection] Starting for user: ${userId}`);

    // Input validation
    const {mealSelections, deliverySchedule, deliveryAddress} = data;

    logger.info("Received meal selections:", JSON.stringify(mealSelections));
    logger.info("Received delivery schedule:", JSON.stringify(deliverySchedule));
    logger.info("Received delivery address:", deliveryAddress);

    if (!Array.isArray(mealSelections) || mealSelections.length === 0) {
      throw new HttpsError("invalid-argument", "Meal selections are required");
    }

    if (!deliverySchedule || typeof deliverySchedule !== "object") {
      throw new HttpsError("invalid-argument", "Delivery schedule is required");
    }

    if (!deliveryAddress || typeof deliveryAddress !== "string") {
      throw new HttpsError("invalid-argument", "Delivery address is required");
    }

    const db = getFirestore();
    const batch = db.batch();
    const generatedOrders: any[] = [];

    // Get user data
    const userDoc = await db.collection("users").doc(userId).get();
    if (!userDoc.exists) {
      throw new HttpsError("not-found", "User profile not found");
    }

    const userData = userDoc.data()!;
    const now = new Date();

    // Calculate next Monday as the starting point (consistent with app's DateUtilsV3.getNextMonday())
    // This ensures new subscriptions start from Monday, not today
    const currentDayOfWeek = now.getDay(); // 0=Sunday, 1=Monday, ..., 6=Saturday
    const daysUntilMonday = currentDayOfWeek === 0 ? 1 : (8 - currentDayOfWeek); // Next Monday
    const nextMonday = new Date(now);
    nextMonday.setDate(now.getDate() + daysUntilMonday);
    nextMonday.setHours(0, 0, 0, 0);

    logger.info(`Order generation starting from next Monday: ${nextMonday.toISOString()} (${daysUntilMonday} days from now)`);

    // Process delivery schedule to create orders for 7 days starting from next Monday
    const daysOfWeek = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];

    for (let dayOffset = 0; dayOffset < 7; dayOffset++) {
      const deliveryDate = new Date(nextMonday);
      deliveryDate.setDate(nextMonday.getDate() + dayOffset);
      deliveryDate.setHours(0, 0, 0, 0);

      const dayName = daysOfWeek[deliveryDate.getDay()];
      const daySchedule = deliverySchedule[dayName];

      if (!daySchedule) continue;

      // Process each meal type for this day
      const mealTypes = ["breakfast", "lunch", "dinner"];
      for (const mealType of mealTypes) {
        const mealConfig = daySchedule[mealType];
        if (!mealConfig || !mealConfig.time) continue;

        // Parse delivery time
        const [hours, minutes] = mealConfig.time.split(":").map(Number);
        if (isNaN(hours) || isNaN(minutes)) continue;

        // Create date in user's timezone (assume EST/EDT, UTC-5/-4)
        // The schedule times are stored as "HH:mm" in user's local time
        // We need to convert to UTC for storage
        const deliveryDateTime = new Date(deliveryDate);

        // Get timezone offset from client (defaults to -5 for EST if not provided)
        const timezoneOffsetHours = data.timezoneOffsetHours ?? -5;

        // Set local time first
        deliveryDateTime.setUTCHours(hours - timezoneOffsetHours, minutes, 0, 0);

        // Find a meal for this slot (cycle through available meals)
        const mealIndex = (dayOffset * 3 + mealTypes.indexOf(mealType)) % mealSelections.length;
        const selectedMeal = mealSelections[mealIndex];

        logger.info(`Day ${dayOffset} (${dayName}), ${mealType}: Selected meal index ${mealIndex}, meal:`, JSON.stringify(selectedMeal));

        if (!selectedMeal || !selectedMeal.id) {
          logger.warn(`Skipping ${dayName} ${mealType}: No valid meal found (selectedMeal: ${JSON.stringify(selectedMeal)})`);
          continue;
        }

        // Verify meal exists in database - try flat structure first, then nested
        const mealDoc = await db.collection("meals").doc(selectedMeal.id).get();
        let mealData: any = null;

        if (mealDoc.exists) {
          // Found in flat structure
          mealData = mealDoc.data()!;
          logger.info(`Found meal ${selectedMeal.id} in flat structure`);
        } else {
          // Try nested structure: meals/{restaurantName}/items/{itemId}
          // Search known restaurant collections
          const restaurantNames = ["greenblend", "sen_saigon"];
          logger.info(`Searching nested structure across restaurants: ${restaurantNames.join(", ")}`);

          for (const restaurantName of restaurantNames) {
            const nestedMealDoc = await db.collection("meals").doc(restaurantName).collection("items").doc(selectedMeal.id).get();
            if (nestedMealDoc.exists) {
              mealData = nestedMealDoc.data()!;
              logger.info(`Found meal ${selectedMeal.id} in nested structure: meals/${restaurantName}/items`);
              break;
            }
          }

          if (!mealData) {
            logger.warn(`Meal ${selectedMeal.id} (${selectedMeal.name}) not found in flat structure or nested structure across restaurants`);
            continue;
          }
        }

        const orderPrice = mealData.price || 12.99;

        // Generate order
        const orderId = `order_${userId}_${dayOffset}_${mealType}_${Date.now()}`;
        const dispatchLeadMs = 60 * 60 * 1000; // 1 hour before delivery
        const dispatchReadyDate = new Date(
          Math.max(deliveryDateTime.getTime() - dispatchLeadMs, now.getTime())
        );

        const orderData = {
          id: orderId,
          userId: userId,
          userEmail: userData.email || auth.token?.email || "",
          meals: [{
            id: selectedMeal.id,
            name: selectedMeal.name || mealData.name,
            description: selectedMeal.description || mealData.description,
            calories: selectedMeal.calories || mealData.calories,
            protein: selectedMeal.protein || mealData.protein,
            imageUrl: selectedMeal.imageUrl || mealData.imageUrl,
            price: orderPrice,
            mealType: mealType,
            // Include restaurant + Square mapping so forwarding works
            restaurantId: mealData.restaurantId || null,
            squareItemId: mealData.squareItemId || null,
            squareVariationId: mealData.squareVariationId || mealData.id || null,
          }],
          deliveryAddress: mealConfig.address || deliveryAddress,
          orderDate: FieldValue.serverTimestamp(),
          deliveryDate: Timestamp.fromDate(deliveryDateTime),
          estimatedDeliveryTime: Timestamp.fromDate(deliveryDateTime),
          status: "pending",
          totalAmount: orderPrice,
          mealPlanType: userData.currentMealPlan || "nutritious",
          dayName: dayName,
          mealType: mealType,
          source: "meal_selection",
          userConfirmed: false,
          userConfirmedAt: null,
          dispatchReadyAt: Timestamp.fromDate(dispatchReadyDate),
          dispatchWindowMinutes: 60,
          dispatchTriggeredAt: null,
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        };

        // Add to batch
        const orderRef = db.collection("orders").doc(orderId);
        batch.set(orderRef, orderData);
        generatedOrders.push({...orderData, id: orderId});

        logger.info(`[BATCH] Adding order ${orderId}: userId=${userId}, status=${orderData.status}, deliveryDate=${deliveryDateTime.toISOString()}`);
      }
    }

    // Commit batch
    await batch.commit();

    logger.info(`Generated ${generatedOrders.length} orders for user ${userId}`);

    // Verify orders were written by querying them back
    const verifyQuery = await db.collection("orders")
      .where("userId", "==", userId)
      .where("status", "==", "pending")
      .get();
    logger.info(`[VERIFY] Query returned ${verifyQuery.docs.length} pending orders for user ${userId}`);

    // Send confirmation for first order
    if (generatedOrders.length > 0) {
      try {
        await sendOrderConfirmationEmail(generatedOrders[0], userData);
      } catch (emailError) {
        logger.warn("Failed to send order confirmation email:", emailError);
      }
    }

    return {
      success: true,
      ordersGenerated: generatedOrders.length,
      orders: generatedOrders.map((order) => ({
        id: order.id,
        deliveryDate: order.deliveryDate,
        mealName: order.meals[0]?.name,
        mealType: order.mealType,
        totalAmount: order.totalAmount,
      })),
    };
  } catch (error) {
    if (error instanceof HttpsError) {
      throw error;
    }

    logger.error("Order generation error:", error);
    throw new HttpsError("internal", "Failed to generate orders");
  }
});

/**
 * Allows a user to confirm their next upcoming order.
 * Ensures only the earliest pending order can be confirmed at a time.
 */
export const confirmNextOrder = onCall(corsOptions, async (request: any) => {
  try {
    const {auth, data} = request;
    if (!auth) {
      throw new HttpsError("unauthenticated", "User must be authenticated");
    }

    const userId = auth.uid;
    const orderId = (data?.orderId as string | undefined)?.trim();
    if (!orderId) {
      throw new HttpsError("invalid-argument", "orderId is required");
    }

    const db = getFirestore();
    const orderRef = db.collection("orders").doc(orderId);
    const orderSnap = await orderRef.get();
    if (!orderSnap.exists) {
      throw new HttpsError("not-found", "Order not found");
    }

    const order = orderSnap.data() as any;
    if (order.userId !== userId) {
      throw new HttpsError("permission-denied", "You can only confirm your own orders");
    }

    if (order.status !== "pending") {
      throw new HttpsError("failed-precondition", "Order is already confirmed or processed");
    }

    if (order.userConfirmed) {
      return {success: true, alreadyConfirmed: true};
    }

    const deliveryTs = order.deliveryDate;
    if (!deliveryTs) {
      throw new HttpsError("failed-precondition", "Order missing delivery date");
    }

    const deliveryDate: Date = deliveryTs.toDate ? deliveryTs.toDate() : new Date(deliveryTs._seconds * 1000);

    // Enforce sequential confirmation: this must be the earliest pending order
    const earliestPendingSnap = await db.collection("orders")
      .where("userId", "==", userId)
      .where("status", "==", "pending")
      .orderBy("estimatedDeliveryTime", "asc")
      .limit(1)
      .get();

    if (earliestPendingSnap.empty || earliestPendingSnap.docs[0].id !== orderId) {
      throw new HttpsError("failed-precondition", "Please confirm your next upcoming order first");
    }

    const dispatchLeadMs = Number(process.env.FP_DISPATCH_LEAD_MINUTES || 60) * 60 * 1000;
    const dispatchReadyDate = new Date(
      Math.max(deliveryDate.getTime() - dispatchLeadMs, Date.now())
    );

    await orderRef.update({
      userConfirmed: true,
      userConfirmedAt: FieldValue.serverTimestamp(),
      dispatchReadyAt: Timestamp.fromDate(dispatchReadyDate),
      updatedAt: FieldValue.serverTimestamp(),
    });

    return {
      success: true,
      orderId,
      dispatchReadyAt: dispatchReadyDate.toISOString(),
    };
  } catch (error: any) {
    if (error instanceof HttpsError) {
      throw error;
    }
    logger.error("confirmNextOrder error", {error: error?.message});
    throw new HttpsError("internal", "Failed to confirm order");
  }
});

/**
 * Sends order confirmation via email and optionally SMS
 * Supports both single orders and batch confirmations
 */
export const sendOrderConfirmation = onCall(corsOptions, async (request: any) => {
  try {
    const {auth, data} = request;

    // Authentication check
    if (!auth) {
      throw new HttpsError("unauthenticated", "User must be authenticated");
    }

    const userId = auth.uid;
    logger.info(`[sendOrderConfirmation] Starting for user: ${userId}, order: ${data.orderId}`);

    // Input validation
    const {orderId, notificationTypes = ["email"]} = data;

    if (!orderId || typeof orderId !== "string") {
      throw new HttpsError("invalid-argument", "Order ID is required");
    }

    const db = getFirestore();

    // Get order data
    const orderDoc = await db.collection("orders").doc(orderId).get();
    if (!orderDoc.exists) {
      throw new HttpsError("not-found", "Order not found");
    }

    const orderData = orderDoc.data()!;

    // Verify order belongs to user
    if (orderData.userId !== userId) {
      throw new HttpsError("permission-denied", "Access denied to this order");
    }

    // Get user data
    const userDoc = await db.collection("users").doc(userId).get();
    if (!userDoc.exists) {
      throw new HttpsError("not-found", "User profile not found");
    }

    const userData = userDoc.data()!;
    const results: any = {};

    // Send email confirmation
    if (notificationTypes.includes("email")) {
      try {
        results.email = await sendOrderConfirmationEmail(orderData, userData);
      } catch (emailError) {
        logger.error("Email confirmation failed:", emailError);
        results.email = {success: false, error: (emailError as Error).message};
      }
    }

    // Send SMS confirmation (if phone number exists)
    if (notificationTypes.includes("sms") && userData.phoneNumber) {
      try {
        const smsMessage = generateOrderConfirmationSMS(orderData);
        results.sms = {success: true, message: "SMS sending not implemented yet"};
        logger.info("SMS message generated:", smsMessage);
      } catch (smsError) {
        logger.error("SMS confirmation failed:", smsError);
        results.sms = {success: false, error: (smsError as Error).message};
      }
    }

    // Update order with confirmation status
    await orderDoc.ref.update({
      confirmationSent: true,
      confirmationSentAt: FieldValue.serverTimestamp(),
      confirmationMethods: notificationTypes,
      updatedAt: FieldValue.serverTimestamp(),
    });

    return {
      success: true,
      orderId: orderId,
      confirmations: results,
    };
  } catch (error) {
    if (error instanceof HttpsError) {
      throw error;
    }

    logger.error("Order confirmation error:", error);
    throw new HttpsError("internal", "Failed to send order confirmation");
  }
});

// Helper function to send order confirmation email
async function sendOrderConfirmationEmail(orderData: any, userData: any): Promise<any> {
  // For now, log the email content (implement with SendGrid/Mailgun later)
  const emailContent = {
    to: userData.email || orderData.userEmail,
    subject: `Order Confirmation - FreshPunk Order #${orderData.id.slice(-8)}`,
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h2 style="color: #2E7D32;">Order Confirmed! 🎉</h2>
        
        <p>Hi ${userData.displayName || "there"},</p>
        
        <p>Your FreshPunk order has been confirmed and is being prepared!</p>
        
        <div style="background: #f5f5f5; padding: 20px; border-radius: 8px; margin: 20px 0;">
          <h3>Order Details</h3>
          <p><strong>Order ID:</strong> #${orderData.id.slice(-8)}</p>
          <p><strong>Meal:</strong> ${orderData.meals[0]?.name || "Delicious Meal"}</p>
          <p><strong>Delivery Date:</strong> ${new Date(orderData.deliveryDate.toDate()).toLocaleDateString()}</p>
          <p><strong>Delivery Time:</strong> ${new Date(orderData.estimatedDeliveryTime.toDate()).toLocaleTimeString()}</p>
          <p><strong>Delivery Address:</strong> ${orderData.deliveryAddress}</p>
          <p><strong>Total:</strong> $${orderData.totalAmount.toFixed(2)}</p>
        </div>
        
        <p>We'll send you another notification when your meal is on its way!</p>
        
        <p>Best regards,<br>The FreshPunk Team</p>
      </div>
    `,
  };

  logger.info("Order confirmation email prepared:", {
    to: emailContent.to,
    orderId: orderData.id,
    subject: emailContent.subject,
  });

  // TODO: Implement actual email sending with SendGrid/Mailgun
  return {success: true, provider: "logged", messageId: `fake_${Date.now()}`};
}

// Helper function to generate SMS confirmation message
function generateOrderConfirmationSMS(orderData: any): string {
  const deliveryDate = new Date(orderData.deliveryDate.toDate());
  const deliveryTime = new Date(orderData.estimatedDeliveryTime.toDate());

  return `FreshPunk Order Confirmed! 🍽️
Order #${orderData.id.slice(-8)}
Meal: ${orderData.meals[0]?.name || "Delicious Meal"}
Delivery: ${deliveryDate.toLocaleDateString()} at ${deliveryTime.toLocaleTimeString()}
Address: ${orderData.deliveryAddress}
Total: $${orderData.totalAmount.toFixed(2)}

Track your order at freshpunk-48db1.web.app`;
}
