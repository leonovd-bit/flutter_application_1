/**
 * Restaurant Notification System
 * Sends order notifications directly to restaurant partners
 */

import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {onSchedule} from "firebase-functions/v2/scheduler";
import * as logger from "firebase-functions/logger";
import {getFirestore} from "firebase-admin/firestore";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {defineSecret} from "firebase-functions/params";
import nodemailer from "nodemailer";

// Define Gmail credentials as secrets
const GMAIL_USER = defineSecret("GMAIL_USER");
const GMAIL_PASSWORD = defineSecret("GMAIL_PASSWORD");

// Firebase is initialized in index.ts - no need to initialize here

// Firebase services will be accessed inside functions

// ============================================================================
// SUBSCRIPTION NOTIFICATION SYSTEM (Schedule emails to restaurants)
// ============================================================================

/**
 * Automatically notify restaurants when a customer subscribes (send schedule)
 */
export const notifyRestaurantsOnSubscription = onDocumentCreated(
  {
    document: "subscriptions/{subscriptionId}",
    memory: "512MiB",
    timeoutSeconds: 300,
    region: "us-east4",
    secrets: [GMAIL_USER, GMAIL_PASSWORD],
  },
  async (event) => {
    try {
      const subscriptionId = event.params.subscriptionId;
      const subscriptionData = event.data?.data();

      if (!subscriptionData) {
        logger.error("No subscription data found", {subscriptionId});
        return;
      }

      const db = getFirestore();
      const userId = subscriptionData.userId;

      // Get user data to find their active meal selections
      const userDoc = await db.collection("users").doc(userId).get();
      if (!userDoc.exists) {
        logger.warn("User not found for subscription", {userId, subscriptionId});
        return;
      }

      const userData = userDoc.data()!;
      const userEmail = userData.email || "";

      logger.info("Processing subscription for restaurant notifications", {
        subscriptionId,
        userId,
        userEmail,
      });

      // Get the user's meal selections (from their meal plan)
      const mealSelections = userData.mealSelections || [];
      if (mealSelections.length === 0) {
        logger.info("No meal selections found for subscription", {subscriptionId});
        return;
      }

      // Group meals by restaurant
      const restaurantMeals = await groupMealsByRestaurant(mealSelections);

      // Get user delivery schedule
      const deliverySchedule = userData.deliverySchedule || {};

      // Send welcome/schedule email to each restaurant
      for (const [restaurantId, meals] of Object.entries(restaurantMeals)) {
        await sendRestaurantScheduleEmail({
          restaurantId,
          meals: meals as any[],
          customerName: userData.name || userData.email || "Customer",
          customerEmail: userEmail,
          customerPhone: userData.phone,
          subscriptionId,
          deliverySchedule,
        });
      }

      logger.info("Restaurant schedule notifications sent successfully", {subscriptionId});
    } catch (error: any) {
      logger.error("Failed to notify restaurants on subscription", {
        subscriptionId: event.params.subscriptionId,
        error: error.message,
      });
    }
  }
);

/**
 * Weekly reminder: Send upcoming week's schedule to restaurants (every Monday morning)
 */
export const weeklyRestaurantScheduleReminder = onSchedule(
  {
    schedule: "every monday 06:00",
    timeZone: "America/New_York",
    memory: "1GiB",
    timeoutSeconds: 300,
    region: "us-east4",
    secrets: [GMAIL_USER, GMAIL_PASSWORD],
  },
  async (context) => {
    try {
      const db = getFirestore();

      // Get all active subscriptions
      const subscriptionsSnap = await db.collection("subscriptions")
        .where("status", "==", "active")
        .get();

      logger.info("Weekly schedule reminder started", {
        activeSubscriptions: subscriptionsSnap.size,
      });

      // Process each subscription
      for (const subDoc of subscriptionsSnap.docs) {
        const subscriptionData = subDoc.data();
        const userId = subscriptionData.userId;

        // Get user and their meals
        const userDoc = await db.collection("users").doc(userId).get();
        if (!userDoc.exists) continue;

        const userData = userDoc.data()!;
        const mealSelections = userData.mealSelections || [];

        if (mealSelections.length === 0) continue;

        // Group meals by restaurant
        const restaurantMeals = await groupMealsByRestaurant(mealSelections);
        const deliverySchedule = userData.deliverySchedule || {};
        const userEmail = userData.email || "";

        // Send weekly reminder to each restaurant
        for (const [restaurantId, meals] of Object.entries(restaurantMeals)) {
          await sendRestaurantWeeklyReminder({
            restaurantId,
            meals: meals as any[],
            customerName: userData.name || userEmail || "Customer",
            customerEmail: userEmail,
            customerPhone: userData.phone,
            deliverySchedule,
          });
        }
      }

      logger.info("Weekly schedule reminders completed successfully", {
        subscriptionsProcessed: subscriptionsSnap.size,
      });
    } catch (error: any) {
      logger.error("Weekly schedule reminder failed", {error: error.message});
    }
  }
);

// ============================================================================
// ORDER NOTIFICATION SYSTEM
// ============================================================================

/**
 * Automatically notify restaurants when a scheduled order is created
 */
export const notifyRestaurantsOnOrder = onDocumentCreated(
  {
    document: "orders/{orderId}",
    memory: "512MiB",
    timeoutSeconds: 300,
    region: "us-east4",
    secrets: [GMAIL_USER, GMAIL_PASSWORD],
  },
  async (event) => {
    try {
      const orderId = event.params.orderId;
      const orderData = event.data?.data();

      if (!orderData) {
        logger.error("No order data found", {orderId});
        return;
      }

      logger.info("Processing order for restaurant notifications", {
        orderId,
        customerName: orderData.customerName,
        deliveryDate: orderData.deliveryDate,
      });

      // Group meals by restaurant
      const restaurantOrders = await groupMealsByRestaurant(orderData.meals);

      // Send notification to each restaurant
      for (const [restaurantId, restaurantMeals] of Object.entries(restaurantOrders)) {
        await sendRestaurantNotification({
          orderId,
          restaurantId,
          customerName: orderData.customerName || "Customer",
          customerPhone: orderData.customerPhone,
          customerEmail: orderData.customerEmail,
          deliveryDate: orderData.deliveryDate,
          deliveryTime: orderData.deliveryTime || "TBD",
          deliveryAddress: orderData.deliveryAddress,
          meals: restaurantMeals as any[],
          specialInstructions: orderData.specialInstructions,
          totalAmount: calculateRestaurantTotal(restaurantMeals as any[]),
        });
      }

      logger.info("Restaurant notifications sent successfully", {orderId});
    } catch (error: any) {
      logger.error("Failed to notify restaurants", {
        orderId: event.params.orderId,
        error: error.message,
      });
    }
  }
);

/**
 * Manual function to send restaurant notifications (for testing or resending)
 */
export const sendRestaurantOrderNotification = onCall(
  {
    memory: "512MiB",
    timeoutSeconds: 300,
    region: "us-east4",
    secrets: [GMAIL_USER, GMAIL_PASSWORD],
  },
  async (request) => {
  const db = getFirestore();
  try {
    const {orderId, restaurantId} = request.data;

    if (!orderId) {
      throw new HttpsError("invalid-argument", "Order ID is required");
    }

    // Get order data
    const orderDoc = await db.collection("orders").doc(orderId).get();
    if (!orderDoc.exists) {
      throw new HttpsError("not-found", "Order not found");
    }

    const orderData = orderDoc.data()!;

    if (restaurantId) {
      // Send to specific restaurant
      const restaurantMeals = orderData.meals.filter((meal: any) =>
        meal.restaurantId === restaurantId
      );

      if (restaurantMeals.length === 0) {
        throw new HttpsError("not-found", "No meals found for this restaurant");
      }

      await sendRestaurantNotification({
        orderId,
        restaurantId,
        customerName: orderData.customerName || "Customer",
        customerPhone: orderData.customerPhone,
        customerEmail: orderData.customerEmail,
        deliveryDate: orderData.deliveryDate,
        deliveryTime: orderData.deliveryTime || "TBD",
        deliveryAddress: orderData.deliveryAddress,
        meals: restaurantMeals,
        specialInstructions: orderData.specialInstructions,
        totalAmount: calculateRestaurantTotal(restaurantMeals),
      });
    } else {
      // Send to all restaurants in the order
      const restaurantOrders = await groupMealsByRestaurant(orderData.meals);

      for (const [restId, restaurantMeals] of Object.entries(restaurantOrders)) {
        await sendRestaurantNotification({
          orderId,
          restaurantId: restId,
          customerName: orderData.customerName || "Customer",
          customerPhone: orderData.customerPhone,
          customerEmail: orderData.customerEmail,
          deliveryDate: orderData.deliveryDate,
          deliveryTime: orderData.deliveryTime || "TBD",
          deliveryAddress: orderData.deliveryAddress,
          meals: restaurantMeals as any[],
          specialInstructions: orderData.specialInstructions,
          totalAmount: calculateRestaurantTotal(restaurantMeals as any[]),
        });
      }
    }

    return {success: true, message: "Notifications sent successfully"};
  } catch (error: any) {
    logger.error("Manual restaurant notification failed", {error: error.message});
    throw new HttpsError("internal", error.message);
  }
});

// ============================================================================
// RESTAURANT MANAGEMENT
// ============================================================================

/**
 * Register a new restaurant partner
 */
export const registerRestaurantPartner = onCall(async (request) => {
  const db = getFirestore();
  try {
    const {
      restaurantName,
      contactEmail,
      contactPhone,
      address,
      businessType,
      description,
      notificationPreferences = {},
    } = request.data;

    if (!restaurantName || !contactEmail) {
      throw new HttpsError("invalid-argument", "Restaurant name and contact email are required");
    }

    const restaurantId = `restaurant_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;

    const restaurantData = {
      id: restaurantId,
      name: restaurantName,
      contactEmail,
      contactPhone: contactPhone || null,
      address: address || null,
      businessType: businessType || "restaurant",
      description: description || null,
      status: "active",
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),

      // Notification preferences
      notificationMethods: {
        email: true,
        sms: !!contactPhone,
        dashboard: true,
        ...notificationPreferences,
      },

      // Statistics
      stats: {
        totalOrders: 0,
        completedOrders: 0,
        totalRevenue: 0,
        averageOrderValue: 0,
        lastOrderDate: null,
      },
    };

    await db.collection("restaurant_partners").doc(restaurantId).set(restaurantData);

    logger.info("Restaurant partner registered", {restaurantId, restaurantName});

    return {
      success: true,
      restaurantId,
      message: `${restaurantName} has been registered successfully!`,
    };
  } catch (error: any) {
    logger.error("Restaurant registration failed", {error: error.message});
    throw new HttpsError("internal", error.message);
  }
});

/**
 * Get restaurant orders and notifications
 */
export const getRestaurantOrders = onCall(
  {
    memory: "512MiB",
    timeoutSeconds: 300,
    region: "us-east4",
  },
  async (request) => {
  const db = getFirestore();
  try {
    const {restaurantId, limit = 50} = request.data;

    if (!restaurantId) {
      throw new HttpsError("invalid-argument", "Restaurant ID is required");
    }

    // Get restaurant notifications
    const notificationsQuery = db.collection("restaurant_notifications")
      .where("restaurantId", "==", restaurantId)
      .orderBy("createdAt", "desc")
      .limit(limit);

    const notificationsSnapshot = await notificationsQuery.get();
    const notifications = notificationsSnapshot.docs.map((doc) => ({
      id: doc.id,
      ...doc.data(),
    }));

    // Get restaurant statistics
    const restaurantDoc = await db.collection("restaurant_partners").doc(restaurantId).get();
    const restaurantData = restaurantDoc.exists ? restaurantDoc.data() : null;

    return {
      success: true,
      notifications,
      restaurant: restaurantData,
      total: notifications.length,
    };
  } catch (error: any) {
    logger.error("Failed to get restaurant orders", {error: error.message});
    throw new HttpsError("internal", error.message);
  }
});

// ============================================================================
// UTILITY FUNCTIONS
// ============================================================================

async function groupMealsByRestaurant(meals: any[]): Promise<Record<string, any[]>> {
  const db = getFirestore();
  const restaurantGroups: Record<string, any[]> = {};

  for (const meal of meals) {
    // Try to determine restaurant from meal data
    let restaurantId = meal.restaurantId || meal.restaurant_id;

    // If no restaurant ID, try to find it from the meal ID in the database
    if (!restaurantId && meal.id) {
      try {
        const mealDoc = await db.collection("meals").doc(meal.id).get();
        if (mealDoc.exists) {
          const mealData = mealDoc.data();
          restaurantId = mealData?.restaurantId || mealData?.restaurant_id || "default_kitchen";
        }
      } catch (error) {
        logger.warn("Could not fetch meal data", {mealId: meal.id});
      }
    }

    // Default to main kitchen if no restaurant found
    if (!restaurantId) {
      restaurantId = "freshpunk_kitchen";
    }

    if (!restaurantGroups[restaurantId]) {
      restaurantGroups[restaurantId] = [];
    }

    restaurantGroups[restaurantId].push(meal);
  }

  return restaurantGroups;
}

async function sendRestaurantNotification(notificationData: {
  orderId: string;
  restaurantId: string;
  customerName: string;
  customerPhone?: string;
  customerEmail?: string;
  deliveryDate: string;
  deliveryTime: string;
  deliveryAddress?: string;
  meals: any[];
  specialInstructions?: string;
  totalAmount: number;
}) {
  const db = getFirestore();
  try {
    // Store notification in database
    const notificationId = `${notificationData.orderId}_${notificationData.restaurantId}`;

    const notification = {
      id: notificationId,
      orderId: notificationData.orderId,
      restaurantId: notificationData.restaurantId,
      customerName: notificationData.customerName,
      customerPhone: notificationData.customerPhone || null,
      customerEmail: notificationData.customerEmail || null,
      deliveryDate: notificationData.deliveryDate,
      deliveryTime: notificationData.deliveryTime,
      deliveryAddress: notificationData.deliveryAddress || null,
      meals: notificationData.meals,
      specialInstructions: notificationData.specialInstructions || null,
      totalAmount: notificationData.totalAmount,
      status: "pending",
      createdAt: new Date().toISOString(),
      readAt: null,
      acknowledgedAt: null,
    };

    await db.collection("restaurant_notifications").doc(notificationId).set(notification);

    // Get restaurant contact info
    const restaurantDoc = await db.collection("restaurant_partners")
      .doc(notificationData.restaurantId)
      .get();

    if (!restaurantDoc.exists) {
      logger.warn("Restaurant not found, using default notification", {
        restaurantId: notificationData.restaurantId,
      });
      return;
    }

    const restaurant = restaurantDoc.data()!;

    // Send email notification if enabled
    if (restaurant.notificationMethods?.email && restaurant.contactEmail) {
      await sendEmailNotification(restaurant, notification);
    }

    // Send SMS notification if enabled
    if (restaurant.notificationMethods?.sms && restaurant.contactPhone) {
      await sendSMSNotification(restaurant, notification);
    }

    // Update restaurant statistics
    await updateRestaurantStats(notificationData.restaurantId, notificationData.totalAmount);

    logger.info("Restaurant notification sent", {
      notificationId,
      restaurantId: notificationData.restaurantId,
      restaurantName: restaurant.name,
    });
  } catch (error: any) {
    logger.error("Failed to send restaurant notification", {
      restaurantId: notificationData.restaurantId,
      orderId: notificationData.orderId,
      error: error.message,
    });
    throw error;
  }
}

async function sendEmailNotification(restaurant: any, notification: any) {
  try {
    const transporter = nodemailer.createTransport({
      service: "gmail",
      auth: {
        user: GMAIL_USER.value(),
        pass: GMAIL_PASSWORD.value(),
      },
    });

    const emailContent = generateEmailContent(restaurant, notification);
    const mailOptions = {
      from: `Victus Kitchen <${GMAIL_USER.value()}>`,
      to: restaurant.contactEmail,
      subject: `New Order from Victus: ${notification.customerName} - ${notification.deliveryDate}`,
      html: emailContent,
    };

    const info = await transporter.sendMail(mailOptions);
    logger.info("Order notification email sent successfully", {
      to: restaurant.contactEmail,
      messageId: info.messageId,
      orderId: notification.orderId,
      restaurantId: restaurant.id,
    });
  } catch (error: any) {
    logger.error("Failed to send order notification email", {
      to: restaurant.contactEmail,
      orderId: notification.orderId,
      error: error.message,
    });
    throw error;
  }
}

async function sendSMSNotification(restaurant: any, notification: any) {
  const smsContent = generateSMSContent(notification);

  logger.info("SMS notification (would send in production)", {
    to: restaurant.contactPhone,
    content: smsContent,
  });

  // TODO: Implement actual SMS sending
  // await sendSMS({
  //   to: restaurant.contactPhone,
  //   message: smsContent,
  // });
}

/**
 * Send schedule email when customer subscribes
 * @param {Object} data Email data object
 * @param {string} data.restaurantId Restaurant ID
 * @param {Array} data.meals List of meals
 * @param {string} data.customerName Customer name
 * @param {string} data.customerEmail Customer email
 * @param {string} data.customerPhone Customer phone
 * @param {string} data.subscriptionId Subscription ID
 * @param {Object} data.deliverySchedule Delivery schedule
 */
async function sendRestaurantScheduleEmail(data: {
  restaurantId: string;
  meals: any[];
  customerName: string;
  customerEmail: string;
  customerPhone?: string;
  subscriptionId: string;
  deliverySchedule: any;
}) {
  try {
    const db = getFirestore();
    const restaurantDoc = await db.collection("restaurant_partners")
      .doc(data.restaurantId)
      .get();

    if (!restaurantDoc.exists) {
      logger.warn("Restaurant not found for schedule email", {
        restaurantId: data.restaurantId,
      });
      return;
    }

    const restaurant = restaurantDoc.data()!;

    const transporter = nodemailer.createTransport({
      service: "gmail",
      auth: {
        user: GMAIL_USER.value(),
        pass: GMAIL_PASSWORD.value(),
      },
    });

    const emailContent = generateScheduleEmailContent(restaurant, data);
    const mailOptions = {
      from: `Victus Kitchen <${GMAIL_USER.value()}>`,
      to: restaurant.contactEmail,
      subject: `New Customer Schedule: ${data.customerName} - Victus`,
      html: emailContent,
    };

    const info = await transporter.sendMail(mailOptions);
    logger.info("Schedule notification email sent successfully", {
      to: restaurant.contactEmail,
      messageId: info.messageId,
      subscriptionId: data.subscriptionId,
      restaurantId: data.restaurantId,
    });
  } catch (error: any) {
    logger.error("Failed to send schedule email", {
      restaurantId: data.restaurantId,
      subscriptionId: data.subscriptionId,
      error: error.message,
    });
  }
}

/**
 * Send weekly reminder email to restaurants
 * @param {Object} data Email data object
 * @param {string} data.restaurantId Restaurant ID
 * @param {Array} data.meals List of meals
 * @param {string} data.customerName Customer name
 * @param {string} data.customerEmail Customer email
 * @param {string} data.customerPhone Customer phone
 * @param {Object} data.deliverySchedule Delivery schedule
 */
async function sendRestaurantWeeklyReminder(data: {
  restaurantId: string;
  meals: any[];
  customerName: string;
  customerEmail: string;
  customerPhone?: string;
  deliverySchedule: any;
}) {
  try {
    const db = getFirestore();
    const restaurantDoc = await db.collection("restaurant_partners")
      .doc(data.restaurantId)
      .get();

    if (!restaurantDoc.exists) {
      logger.warn("Restaurant not found for weekly reminder", {
        restaurantId: data.restaurantId,
      });
      return;
    }

    const restaurant = restaurantDoc.data()!;

    const transporter = nodemailer.createTransport({
      service: "gmail",
      auth: {
        user: GMAIL_USER.value(),
        pass: GMAIL_PASSWORD.value(),
      },
    });

    const emailContent = generateWeeklyReminderContent(restaurant, data);
    const mailOptions = {
      from: `Victus Kitchen <${GMAIL_USER.value()}>`,
      to: restaurant.contactEmail,
      subject: "Weekly Delivery Schedule Reminder - Victus",
      html: emailContent,
    };

    const info = await transporter.sendMail(mailOptions);
    logger.info("Weekly reminder email sent successfully", {
      to: restaurant.contactEmail,
      messageId: info.messageId,
      restaurantId: data.restaurantId,
    });
  } catch (error: any) {
    logger.error("Failed to send weekly reminder email", {
      restaurantId: data.restaurantId,
      error: error.message,
    });
  }
}

function generateEmailContent(restaurant: any, notification: any): string {
  const mealsHtml = notification.meals.map((meal: any) =>
    `<li>${meal.quantity || 1}x ${meal.name} - $${meal.price}</li>`
  ).join("");

  return `
    <h2>New Order for ${restaurant.name}</h2>
    
    <h3>Customer Information:</h3>
    <p><strong>Name:</strong> ${notification.customerName}</p>
    ${notification.customerPhone ? `<p><strong>Phone:</strong> ${notification.customerPhone}</p>` : ""}
    ${notification.customerEmail ? `<p><strong>Email:</strong> ${notification.customerEmail}</p>` : ""}
    
    <h3>Delivery Details:</h3>
    <p><strong>Date:</strong> ${notification.deliveryDate}</p>
    <p><strong>Time:</strong> ${notification.deliveryTime}</p>
    ${notification.deliveryAddress ? `<p><strong>Address:</strong> ${notification.deliveryAddress}</p>` : ""}
    
    <h3>Order Details:</h3>
    <ul>${mealsHtml}</ul>
    <p><strong>Total for your restaurant:</strong> $${notification.totalAmount.toFixed(2)}</p>
    
    ${notification.specialInstructions ? `<h3>Special Instructions:</h3><p>${notification.specialInstructions}</p>` : ""}
    
    <p><strong>Order ID:</strong> ${notification.orderId}</p>
    
    <p>Please prepare these items for delivery on the scheduled date and time.</p>
  `;
}

function generateSMSContent(notification: any): string {
  const mealsSummary = notification.meals.map((meal: any) =>
    `${meal.quantity || 1}x ${meal.name}`
  ).join(", ");

  return `FreshPunk Order Alert!
Customer: ${notification.customerName}
Delivery: ${notification.deliveryDate} at ${notification.deliveryTime}
Items: ${mealsSummary}
Total: $${notification.totalAmount.toFixed(2)}
Order ID: ${notification.orderId}`;
}

function calculateRestaurantTotal(meals: any[]): number {
  return meals.reduce((total, meal) => {
    const price = parseFloat(meal.price || 0);
    const quantity = parseInt(meal.quantity || 1);
    return total + (price * quantity);
  }, 0);
}

async function updateRestaurantStats(restaurantId: string, orderAmount: number) {
  const db = getFirestore();
  try {
    const restaurantRef = db.collection("restaurant_partners").doc(restaurantId);
    const restaurantDoc = await restaurantRef.get();

    if (restaurantDoc.exists) {
      const currentStats = restaurantDoc.data()?.stats || {};
      const totalOrders = (currentStats.totalOrders || 0) + 1;
      const totalRevenue = (currentStats.totalRevenue || 0) + orderAmount;

      await restaurantRef.update({
        "stats.totalOrders": totalOrders,
        "stats.totalRevenue": totalRevenue,
        "stats.averageOrderValue": totalRevenue / totalOrders,
        "stats.lastOrderDate": new Date().toISOString(),
        "updatedAt": new Date().toISOString(),
      });
    }
  } catch (error: any) {
    logger.error("Failed to update restaurant stats", {restaurantId, error: error.message});
  }
}
function generateScheduleEmailContent(restaurant: any, data: any): string {
  const mealsHtml = data.meals.map((meal: any) =>
    `<li>${meal.name || meal.id}${meal.quantity ? ` (${meal.quantity}x per delivery)` : ""}</li>`
  ).join("");

  const daysHtml = data.deliverySchedule ? Object.entries(data.deliverySchedule)
    .map(([day, times]: [string, any]) => {
      const timeStr = typeof times === "string" ? times : times?.time || "TBD";
      return `<li><strong>${day}:</strong> ${timeStr}</li>`;
    })
    .join("") : "<li>Custom schedule (see customer profile)</li>";

  return `
    <h2>Welcome! New Customer Schedule 🎉</h2>
    
    <p>A new customer has subscribed to Victus meal deliveries and will be receiving meals from your restaurant!</p>
    
    <h3>Customer Information:</h3>
    <p><strong>Name:</strong> ${data.customerName}</p>
    <p><strong>Email:</strong> ${data.customerEmail}</p>
    ${data.customerPhone ? `<p><strong>Phone:</strong> ${data.customerPhone}</p>` : ""}
    
    <h3>Meals You'll Be Preparing:</h3>
    <ul>${mealsHtml}</ul>
    
    <h3>Delivery Schedule:</h3>
    <ul>${daysHtml}</ul>
    
    <p><strong>Subscription ID:</strong> ${data.subscriptionId}</p>
    
    <hr style="margin: 20px 0;">
    
    <p>Please prepare for regular deliveries according to the schedule above. If you have any questions or concerns, please contact the customer directly or reply to this email.</p>
    
    <p>Best regards,<br/>
    <strong>Victus Kitchen Team</strong></p>
  `;
}

function generateWeeklyReminderContent(restaurant: any, data: any): string {
  const mealsHtml = data.meals.map((meal: any) =>
    `<li>${meal.name || meal.id}${meal.quantity ? ` (${meal.quantity}x per delivery)` : ""}</li>`
  ).join("");

  const daysHtml = data.deliverySchedule ? Object.entries(data.deliverySchedule)
    .map(([day, times]: [string, any]) => {
      const timeStr = typeof times === "string" ? times : times?.time || "TBD";
      return `<li><strong>${day}:</strong> ${timeStr}</li>`;
    })
    .join("") : "<li>See customer profile for schedule details</li>";

  return `
    <h2>Weekly Delivery Reminder 📦</h2>
    
    <h3>Customer: ${data.customerName}</h3>
    <p><strong>Email:</strong> ${data.customerEmail}</p>
    ${data.customerPhone ? `<p><strong>Phone:</strong> ${data.customerPhone}</p>` : ""}
    
    <h3>This Week's Items:</h3>
    <ul>${mealsHtml}</ul>
    
    <h3>Delivery Schedule:</h3>
    <ul>${daysHtml}</ul>
    
    <hr style="margin: 20px 0;">
    
    <p>Please ensure these items are prepared and ready for delivery according to the schedule. Thank you for being part of the Victus Kitchen network!</p>
    
    <p>Best regards,<br/>
    <strong>Victus Kitchen Team</strong></p>
  `;
}
