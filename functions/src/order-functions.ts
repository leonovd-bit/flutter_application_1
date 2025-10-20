/**
 * Order Generation and Confirmation Functions
 * These functions handle meal selection to order conversion and notifications
 */

import {onCall, HttpsError} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import {getFirestore, FieldValue, Timestamp} from "firebase-admin/firestore";

// ============================================================================
// MEAL SELECTION & ORDER GENERATION FUNCTIONS
// ============================================================================

/**
 * Generates actual orders from user meal selections and delivery schedule
 * This replaces the client-side order creation with server-side validation
 */
export const generateOrderFromMealSelection = onCall(async (request: any) => {
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

    // Process delivery schedule to create orders for the next 7 days
    const daysOfWeek = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"];

    for (let dayOffset = 0; dayOffset < 7; dayOffset++) {
      const deliveryDate = new Date(now);
      deliveryDate.setDate(now.getDate() + dayOffset);
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

        const deliveryDateTime = new Date(deliveryDate);
        deliveryDateTime.setHours(hours, minutes, 0, 0);

        // Skip past delivery times for today
        if (dayOffset === 0 && deliveryDateTime <= now) continue;

        // Find a meal for this slot (cycle through available meals)
        const mealIndex = (dayOffset * 3 + mealTypes.indexOf(mealType)) % mealSelections.length;
        const selectedMeal = mealSelections[mealIndex];

        if (!selectedMeal || !selectedMeal.id) continue;

        // Verify meal exists in database
        const mealDoc = await db.collection("meals").doc(selectedMeal.id).get();
        if (!mealDoc.exists) {
          logger.warn(`Meal ${selectedMeal.id} not found in database`);
          continue;
        }

        const mealData = mealDoc.data()!;
        const orderPrice = mealData.price || 12.99;

        // Generate order
        const orderId = `order_${userId}_${dayOffset}_${mealType}_${Date.now()}`;
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
          }],
          deliveryAddress: mealConfig.address || deliveryAddress,
          orderDate: FieldValue.serverTimestamp(),
          deliveryDate: Timestamp.fromDate(deliveryDateTime),
          estimatedDeliveryTime: Timestamp.fromDate(deliveryDateTime),
          status: "confirmed",
          totalAmount: orderPrice,
          mealPlanType: userData.currentMealPlan || "nutritious",
          dayName: dayName,
          mealType: mealType,
          source: "meal_selection",
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        };

        // Add to batch
        const orderRef = db.collection("orders").doc(orderId);
        batch.set(orderRef, orderData);
        generatedOrders.push({...orderData, id: orderId});
      }
    }

    // Commit batch
    await batch.commit();

    logger.info(`Generated ${generatedOrders.length} orders for user ${userId}`);

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
 * Sends order confirmation via email and optionally SMS
 * Supports both single orders and batch confirmations
 */
export const sendOrderConfirmation = onCall(async (request: any) => {
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
