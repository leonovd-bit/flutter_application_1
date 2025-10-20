/**
 * Square Integration Functions
 * Handles restaurant partner onboarding, menu sync, and order forwarding
 */

import {onCall, onRequest, HttpsError} from "firebase-functions/v2/https";
import {onDocumentCreated} from "firebase-functions/v2/firestore";
import * as logger from "firebase-functions/logger";
import {getFirestore, FieldValue} from "firebase-admin/firestore";

// Firebase is initialized in index.ts - no need to initialize here

// Square API configuration - loaded from environment variables
const SQUARE_APPLICATION_ID = process.env.SQUARE_APPLICATION_ID || "";
const SQUARE_APPLICATION_SECRET = process.env.SQUARE_APPLICATION_SECRET || "";

// Firebase services will be accessed inside functions

// ============================================================================
// RESTAURANT ONBOARDING & OAUTH
// ============================================================================

/**
 * Initiate Square OAuth flow for restaurant partner onboarding (HTTP version)
 */
export const initiateSquareOAuthHttp = onRequest(async (req, res) => {
  try {
    const db = getFirestore();

    // Set CORS headers for restaurant portal
    res.set("Access-Control-Allow-Origin", "*");
    res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
    res.set("Access-Control-Allow-Headers", "Content-Type");

    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }

    if (req.method !== "POST") {
      res.status(405).json({success: false, message: "Method not allowed"});
      return;
    }

    // Generate a temporary user ID for restaurant onboarding
    const userId = `temp_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;

    const {restaurantName, contactEmail, contactPhone} = req.body;

    if (!restaurantName || !contactEmail) {
      res.status(400).json({success: false, message: "Restaurant name and contact email required"});
      return;
    }

    const applicationId = SQUARE_APPLICATION_ID;

    // Create pending restaurant application
    const applicationRef = await db.collection("restaurant_applications").add({
      userId,
      restaurantName,
      contactEmail,
      contactPhone: contactPhone || null,
      status: "pending_oauth",
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    // Generate Square OAuth URL
    const state = applicationRef.id; // Use application ID as state parameter
    const scopes = [
      "MERCHANT_PROFILE_READ",
      "ORDERS_READ",
      "ORDERS_WRITE",
      "ITEMS_READ",
      "INVENTORY_READ",
      "PAYMENTS_READ",
    ].join("+");

    const oauthUrl = "https://connect.squareup.com/oauth2/authorize?" +
      `client_id=${applicationId}&` +
      `scope=${scopes}&` +
      "session=false&" +
      `state=${state}&` +
      "redirect_uri=https://us-east4-freshpunk-48db1.cloudfunctions.net/completeSquareOAuthHttp";

    logger.info(`Square OAuth initiated for restaurant: ${restaurantName}`, {
      applicationId: applicationRef.id,
      userId,
    });

    res.status(200).json({
      success: true,
      oauthUrl,
      applicationId: applicationRef.id,
      message: "Complete OAuth flow to connect your Square account",
    });
  } catch (error: any) {
    logger.error("Square OAuth initiation failed", error);
    res.status(500).json({success: false, message: `OAuth setup failed: ${error.message}`});
  }
});

/**
 * Complete Square OAuth flow and setup restaurant integration (HTTP version)
 */
export const completeSquareOAuthHttp = onRequest(
  {
    memory: "1GiB",
    timeoutSeconds: 300,
    region: "us-east4",
  },
  async (req, res) => {
  try {
    const db = getFirestore();

    // Set CORS headers
    res.set("Access-Control-Allow-Origin", "*");
    res.set("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
    res.set("Access-Control-Allow-Headers", "Content-Type");

    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }

    // Get OAuth parameters from query string (Square sends them as GET parameters)
    const {code, state} = req.query;

    if (!code || !state) {
      res.status(400).json({success: false, message: "Authorization code and state required"});
      return;
    }

    // Get restaurant application
    const applicationDoc = await db.collection("restaurant_applications").doc(state as string).get();
    if (!applicationDoc.exists) {
      res.status(404).json({success: false, message: "Restaurant application not found"});
      return;
    }

    const applicationData = applicationDoc.data()!;
    const applicationId = SQUARE_APPLICATION_ID;
    const applicationSecret = SQUARE_APPLICATION_SECRET;

    // Exchange code for access token
    const tokenResponse = await fetch("https://connect.squareup.com/oauth2/token", {
      method: "POST",
      headers: {
        "Square-Version": "2023-10-18",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        client_id: applicationId,
        client_secret: applicationSecret,
        code,
        grant_type: "authorization_code",
      }),
    });

    if (!tokenResponse.ok) {
      const errorData = await tokenResponse.text();
      logger.error("Square token exchange failed", {error: errorData});
      res.status(500).json({success: false, message: "Failed to obtain Square access token"});
      return;
    }

    const tokenData = await tokenResponse.json();
    const {access_token, merchant_id, expires_at} = tokenData;

    // Get merchant information
    const merchantResponse = await fetch(`https://connect.squareup.com/v2/merchants/${merchant_id}`, {
      headers: {
        "Square-Version": "2023-10-18",
        "Authorization": `Bearer ${access_token}`,
      },
    });

    const merchantData = await merchantResponse.json();
    const merchant = merchantData.merchant;

    // Create restaurant partner record
    const restaurantRef = await db.collection("restaurant_partners").add({
      userId: applicationData.userId,
      applicationId: state,

      // Square integration
      squareMerchantId: merchant_id,
      squareAccessToken: access_token, // In production, encrypt this!
      squareTokenExpiresAt: expires_at ? new Date(expires_at) : null,

      // Restaurant info
      restaurantName: applicationData.restaurantName,
      squareBusinessName: merchant.business_name,
      contactEmail: applicationData.contactEmail,
      contactPhone: applicationData.contactPhone,

      // Address from Square
      address: merchant.main_location?.address ? {
        addressLine1: merchant.main_location.address.address_line_1,
        addressLine2: merchant.main_location.address.address_line_2,
        locality: merchant.main_location.address.locality,
        administrativeDistrictLevel1: merchant.main_location.address.administrative_district_level_1,
        postalCode: merchant.main_location.address.postal_code,
        country: merchant.main_location.address.country,
      } : null,

      // Status
      status: "active",
      onboardingCompleted: true,
      menuSyncEnabled: true,
      orderForwardingEnabled: true,

      // Timestamps
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
      lastMenuSync: null,
    });

    // Update application status
    await applicationDoc.ref.update({
      status: "completed",
      restaurantPartnerId: restaurantRef.id,
      completedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    // Trigger initial menu sync
    await triggerMenuSync(restaurantRef.id, access_token, merchant_id);

    logger.info("Square OAuth completed successfully", {
      restaurantId: restaurantRef.id,
      merchantId: merchant_id,
      businessName: merchant.business_name,
    });

    // Redirect to restaurant portal with success message
    res.redirect(`https://freshpunk-48db1.web.app/restaurant?success=true&restaurant=${encodeURIComponent(merchant.business_name)}`);
  } catch (error: any) {
    logger.error("Square OAuth completion failed", error);
    res.redirect(`https://freshpunk-48db1.web.app/restaurant?error=true&message=${encodeURIComponent(error.message)}`);
  }
});

// ============================================================================
// MENU SYNCHRONIZATION
// ============================================================================

/**
 * Sync restaurant menu from Square to FreshPunk
 */
export const syncSquareMenu = onCall(
  {
    memory: "1GiB",
    timeoutSeconds: 540,
    region: "us-east4",
  },
  async (request: any) => {
  try {
    const db = getFirestore();
    const {auth} = request;
    if (!auth) {
      throw new HttpsError("unauthenticated", "Authentication required");
    }

    const {restaurantId} = request.data;
    if (!restaurantId) {
      throw new HttpsError("invalid-argument", "Restaurant ID required");
    }

    // Get restaurant partner record
    const restaurantDoc = await db.collection("restaurant_partners").doc(restaurantId).get();
    if (!restaurantDoc.exists) {
      throw new HttpsError("not-found", "Restaurant partner not found");
    }

    const restaurant = restaurantDoc.data()!;

    // Verify ownership
    if (restaurant.userId !== auth.uid) {
      throw new HttpsError("permission-denied", "Access denied");
    }

    const syncResult = await triggerMenuSync(
      restaurantId,
      restaurant.squareAccessToken,
      restaurant.squareMerchantId
    );

    return {
      success: true,
      ...syncResult,
    };
  } catch (error: any) {
    logger.error("Manual menu sync failed", error);
    throw new HttpsError("internal", `Menu sync failed: ${error.message}`);
  }
});

/**
 * Internal function to sync menu from Square
 * @param {string} restaurantId - The restaurant ID
 * @param {string} accessToken - Square API access token
 * @param {string} merchantId - Square merchant ID
 * @return {Promise<void>}
 */
async function triggerMenuSync(restaurantId: string, accessToken: string, merchantId: string) {
  // merchantId is passed for future use with multi-location support
  const db = getFirestore();
  try {
    // Get catalog items from Square
    const catalogResponse = await fetch("https://connect.squareup.com/v2/catalog/list?types=ITEM", {
      headers: {
        "Square-Version": "2023-10-18",
        "Authorization": `Bearer ${accessToken}`,
      },
    });

    if (!catalogResponse.ok) {
      throw new Error(`Square API error: ${catalogResponse.status}`);
    }

    const catalogData = await catalogResponse.json();
    const items = catalogData.objects || [];

    // Get current inventory levels
    const inventoryResponse = await fetch("https://connect.squareup.com/v2/inventory/batch-retrieve-counts", {
      method: "POST",
      headers: {
        "Square-Version": "2023-10-18",
        "Authorization": `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        catalog_object_ids: items.map((item: any) => item.id),
      }),
    });

    const inventoryData = await inventoryResponse.json();
    const inventoryCounts = inventoryData.counts || [];

    // Create inventory lookup
    const inventoryLookup = inventoryCounts.reduce((acc: any, count: any) => {
      acc[count.catalog_object_id] = count.quantity || "0";
      return acc;
    }, {});

    // Convert Square items to FreshPunk meals
    const meals = [];
    const batch = db.batch();

    for (const item of items) {
      if (item.type === "ITEM" && item.item_data) {
        const itemData = item.item_data;
        const variations = itemData.variations || [];

        for (const variation of variations) {
          if (variation.type === "ITEM_VARIATION") {
            const variationData = variation.item_variation_data;
            const basePrice = variationData.price_money?.amount || 0;
            const price = basePrice / 100; // Convert cents to dollars

            const mealData = {
              // FreshPunk fields
              id: variation.id,
              name: itemData.name || "Unnamed Item",
              description: itemData.description || "",
              price: price,
              imageUrl: itemData.image_ids?.[0] ?
                "https://items-images-production.s3.us-west-2.amazonaws.com/files/" +
                `${itemData.image_ids[0]}/original.jpeg` :
                "https://via.placeholder.com/300x200/4CAF50/white?text=Fresh+Meal",

              // Categorization
              mealType: categorizeItem(itemData.name, itemData.description),
              cuisine: "restaurant", // Will be updated based on restaurant type
              tags: extractTags(itemData.name, itemData.description),

              // Nutritional info (placeholder - could be enhanced)
              calories: estimateCalories(itemData.name, itemData.description),
              protein: 0,
              carbs: 0,
              fat: 0,

              // Availability
              isAvailable: true,
              isVegetarian: isVegetarian(itemData.name, itemData.description),
              isVegan: isVegan(itemData.name, itemData.description),
              isGlutenFree: isGlutenFree(itemData.name, itemData.description),

              // Restaurant info
              restaurantId: restaurantId,
              squareItemId: item.id,
              squareVariationId: variation.id,
              squareCategoryId: itemData.category_id,

              // Inventory
              stockQuantity: parseInt(inventoryLookup[variation.id] || "0"),

              // Metadata
              createdAt: FieldValue.serverTimestamp(),
              updatedAt: FieldValue.serverTimestamp(),
              lastSquareSync: FieldValue.serverTimestamp(),
            };

            // Add to Firestore batch
            const mealRef = db.collection("meals").doc(variation.id);
            batch.set(mealRef, mealData, {merge: true});

            meals.push(mealData);
          }
        }
      }
    }

    // Commit batch
    await batch.commit();

    // Update restaurant sync status
    await db.collection("restaurant_partners").doc(restaurantId).update({
      lastMenuSync: FieldValue.serverTimestamp(),
      menuItemCount: meals.length,
      updatedAt: FieldValue.serverTimestamp(),
    });

    logger.info("Menu sync completed", {
      restaurantId,
      itemssynced: meals.length,
    });

    return {
      itemsSynced: meals.length,
      message: `Successfully synced ${meals.length} menu items`,
    };
  } catch (error: any) {
    logger.error("Menu sync failed", {restaurantId, error: error.message});
    throw error;
  }
}

// ============================================================================
// ORDER FORWARDING TO SQUARE
// ============================================================================

/**
 * Forward FreshPunk order to Square POS when order is confirmed
 * This handles individual confirmed orders (separate from weekly prep forecasts)
 */
export const forwardOrderToSquare = onDocumentCreated(
  {
    document: "orders/{orderId}",
    memory: "1GiB",
    timeoutSeconds: 300,
    region: "us-east4",
  },
  async (event: any) => {
  try {
    const orderData = event.data?.data();
    if (!orderData) return;

    // Only forward confirmed orders with Square restaurant items
    if (orderData.status !== "confirmed") return;

    const meals = orderData.meals || [];
    const squareMeals = meals.filter((meal: any) => meal.restaurantId && meal.squareItemId);

    if (squareMeals.length === 0) return;

    // Group by restaurant
    const ordersByRestaurant = squareMeals.reduce((acc: any, meal: any) => {
      const restaurantId = meal.restaurantId;
      if (!acc[restaurantId]) {
        acc[restaurantId] = [];
      }
      acc[restaurantId].push(meal);
      return acc;
    }, {});

    // Forward to each restaurant
    for (const [restaurantId, restaurantMeals] of Object.entries(ordersByRestaurant)) {
      await forwardToSquareRestaurant(
        event.params.orderId,
        restaurantId,
        restaurantMeals as any[],
        orderData,
        "confirmed_order" // This is a real confirmed order, not a forecast
      );
    }

    logger.info("Confirmed order forwarded to Square restaurants", {
      orderId: event.params.orderId,
      restaurantCount: Object.keys(ordersByRestaurant).length,
    });
  } catch (error: any) {
    logger.error("Order forwarding failed", {orderId: event.params.orderId, error: error.message});
  }
});

/**
 * Forward order to specific Square restaurant
 * @param {string} orderId - The order ID
 * @param {string} restaurantId - The restaurant ID
 * @param {any[]} meals - Array of meals in the order
 * @param {any} orderData - Complete order data
 * @param {string} orderType - Type: "confirmed_order" or "prep_forecast"
 * @return {Promise<void>}
 */
async function forwardToSquareRestaurant(
  orderId: string,
  restaurantId: string,
  meals: any[],
  orderData: any,
  orderType = "confirmed_order"
) {
  const db = getFirestore();
  try {
    // Get restaurant Square credentials
    const restaurantDoc = await db.collection("restaurant_partners").doc(restaurantId).get();
    if (!restaurantDoc.exists) return;

    const restaurant = restaurantDoc.data()!;
    if (!restaurant.orderForwardingEnabled) return;

    const accessToken = restaurant.squareAccessToken;
    const locationId = restaurant.squareLocationId || restaurant.squareMerchantId;

    // Create Square order with proper labeling
    const orderReference = orderType === "prep_forecast" ?
      `freshpunk_forecast_${orderId}` :
      `freshpunk_order_${orderId}`;

    const orderNote = orderType === "prep_forecast" ?
      `PREP FORECAST - Week of ${orderData.weekStart || "TBD"}` :
      `FreshPunk Order #${orderId}`;

    const squareOrder = {
      order: {
        location_id: locationId,
        reference_id: orderReference,
        source: {
          name: orderType === "prep_forecast" ? "FreshPunk Prep Forecast" : "FreshPunk Delivery",
        },
        line_items: meals.map((meal) => ({
          name: meal.name,
          quantity: meal.quantity?.toString() || "1",
          item_type: "ITEM_VARIATION",
          catalog_object_id: meal.squareVariationId,
          modifiers: [],
          note: orderNote,
        })),
        fulfillments: orderType === "prep_forecast" ? [] : [{
          type: "DELIVERY",
          state: "PROPOSED",
          delivery_details: {
            recipient: {
              display_name: orderData.customerName || "FreshPunk Customer",
              phone_number: orderData.customerPhone,
            },
            address: {
              address_line_1: orderData.deliveryAddress,
            },
            schedule_type: "ASAP",
            note: `Delivery for ${orderNote}`,
          },
        }],
        metadata: {
          freshpunk_order_id: orderId,
          freshpunk_customer_id: orderData.userId,
          freshpunk_order_type: orderType,
        },
      },
    };

    // Send to Square
    const response = await fetch("https://connect.squareup.com/v2/orders", {
      method: "POST",
      headers: {
        "Square-Version": "2023-10-18",
        "Authorization": `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(squareOrder),
    });

    if (response.ok) {
      const responseData = await response.json();
      const squareOrderId = responseData.order.id;

      // Update FreshPunk order with Square order ID
      await db.collection("orders").doc(orderId).update({
        [`squareOrders.${restaurantId}`]: {
          squareOrderId,
          restaurantId,
          forwardedAt: FieldValue.serverTimestamp(),
          status: "forwarded",
        },
        updatedAt: FieldValue.serverTimestamp(),
      });

      logger.info("Order forwarded to Square", {
        orderId,
        restaurantId,
        squareOrderId,
        orderType,
      });
    } else {
      const errorData = await response.text();
      logger.error("Square order creation failed", {
        orderId,
        restaurantId,
        orderType,
        error: errorData,
      });
    }
  } catch (error: any) {
    logger.error("Square order forwarding failed", {
      orderId,
      restaurantId,
      orderType,
      error: error.message,
    });
  }
}

// ============================================================================
// RESTAURANT SCHEDULE FILTERING & COMMUNICATION
// ============================================================================

/**
 * Send filtered weekly prep schedules to restaurants
 * Only sends schedule parts that use their specific meals
 */
export const sendWeeklyPrepSchedules = onCall(
  {
    memory: "1GiB",
    timeoutSeconds: 300,
    region: "us-east4",
  },
  async (request: any) => {
  try {
    const db = getFirestore();
    const {auth} = request;
    if (!auth) {
      throw new HttpsError("unauthenticated", "Authentication required");
    }

    const {weekStartDate} = request.data;
    if (!weekStartDate) {
      throw new HttpsError("invalid-argument", "Week start date required");
    }

    // Get all active restaurant partners
    const restaurantsSnapshot = await db.collection("restaurant_partners")
      .where("status", "==", "active")
      .get();

    const results = [];

    for (const restaurantDoc of restaurantsSnapshot.docs) {
      const restaurant = restaurantDoc.data();
      const restaurantId = restaurantDoc.id;

      // Get restaurant's menu items
      const mealsSnapshot = await db.collection("meals")
        .where("restaurantId", "==", restaurantId)
        .get();

      const restaurantMealIds = mealsSnapshot.docs.map((doc) => doc.id);

      if (restaurantMealIds.length === 0) continue;

      // Get scheduled orders for the week that include restaurant's meals
      const weekStart = new Date(weekStartDate);
      const weekEnd = new Date(weekStart);
      weekEnd.setDate(weekEnd.getDate() + 7);

      const scheduledOrdersSnapshot = await db.collection("scheduled_orders")
        .where("scheduledDate", ">=", weekStart)
        .where("scheduledDate", "<", weekEnd)
        .get();

      // Filter and organize relevant schedule items
      const relevantSchedule = {
        restaurantName: restaurant.restaurantName,
        weekStart: weekStartDate,
        prepItems: [] as any[],
        totalEstimatedOrders: 0,
      };

      const mealQuantities = new Map<string, number>();

      scheduledOrdersSnapshot.docs.forEach((doc) => {
        const order = doc.data();
        const meals = order.meals || [];

        meals.forEach((meal: any) => {
          if (restaurantMealIds.includes(meal.id)) {
            const key = `${meal.id}-${meal.name}`;
            mealQuantities.set(key, (mealQuantities.get(key) || 0) + 1);
          }
        });
      });

      // Convert to prep schedule format
      mealQuantities.forEach((quantity, key) => {
        const [mealId, mealName] = key.split("-", 2);
        relevantSchedule.prepItems.push({
          mealId,
          mealName,
          estimatedQuantity: quantity,
          mealType: categorizeMealTime(mealName),
        });
        relevantSchedule.totalEstimatedOrders += quantity;
      });

      // Only send if restaurant has relevant items
      if (relevantSchedule.prepItems.length > 0) {
        // Send notification to restaurant
        await sendRestaurantPrepNotification(restaurantId, restaurant, relevantSchedule);
        results.push({
          restaurantId,
          restaurantName: restaurant.restaurantName,
          itemsSent: relevantSchedule.prepItems.length,
          totalQuantity: relevantSchedule.totalEstimatedOrders,
        });
      }
    }

    logger.info("Weekly prep schedules sent", {
      weekStart: weekStartDate,
      restaurantsNotified: results.length,
    });

    return {
      success: true,
      weekStart: weekStartDate,
      restaurantsNotified: results.length,
      results,
      message: `Sent prep schedules to ${results.length} restaurants`,
    };
  } catch (error: any) {
    logger.error("Weekly prep schedule sending failed", error);
    throw new HttpsError("internal", `Failed to send prep schedules: ${error.message}`);
  }
});

/**
 * Send prep notification to specific restaurant
 * @param {string} restaurantId - The restaurant partner ID
 * @param {any} restaurant - The restaurant data object
 * @param {any} schedule - The filtered prep schedule data
 * @return {Promise<void>}
 */
async function sendRestaurantPrepNotification(restaurantId: string, restaurant: any, schedule: any) {
  const db = getFirestore();

  try {
    // Store prep schedule in restaurant's notifications
    await db.collection("restaurant_notifications").add({
      restaurantId,
      type: "weekly_prep_schedule",
      title: `Prep Schedule for Week of ${schedule.weekStart}`,
      message: `${schedule.totalEstimatedOrders} estimated orders requiring your meals`,
      data: {
        weekStart: schedule.weekStart,
        prepItems: schedule.prepItems,
        totalEstimatedOrders: schedule.totalEstimatedOrders,
      },
      priority: "medium",
      isRead: false,
      createdAt: FieldValue.serverTimestamp(),
    });

    // Send email notification (simplified)
    if (restaurant.contactEmail) {
      const emailContent = generatePrepScheduleEmail(restaurant, schedule);
      // In production, integrate with your email service
      logger.info("Prep schedule email queued", {
        restaurantId,
        email: restaurant.contactEmail,
        itemCount: schedule.prepItems.length,
        emailPreview: emailContent.substring(0, 100),
      });
    }

    logger.info("Prep notification sent", {
      restaurantId,
      restaurantName: restaurant.restaurantName,
      itemCount: schedule.prepItems.length,
    });
  } catch (error: any) {
    logger.error("Failed to send prep notification", {
      restaurantId,
      error: error.message,
    });
    throw error;
  }
}

/**
 * Generate clean, organized prep schedule email
 * @param {any} restaurant - The restaurant partner data
 * @param {any} schedule - The prep schedule data
 * @return {string} The formatted email content
 */
function generatePrepScheduleEmail(restaurant: any, schedule: any): string {
  const prepByMealType = schedule.prepItems.reduce((acc: any, item: any) => {
    const mealType = item.mealType || "Other";
    if (!acc[mealType]) acc[mealType] = [];
    acc[mealType].push(item);
    return acc;
  }, {});

  let emailContent = `
📋 **Weekly Prep Schedule - ${restaurant.restaurantName}**
Week of: ${schedule.weekStart}
Total Estimated Orders: ${schedule.totalEstimatedOrders}

`;

  Object.entries(prepByMealType).forEach(([mealType, items]: [string, any]) => {
    emailContent += `
🍽️ **${mealType.charAt(0).toUpperCase() + mealType.slice(1)}:**
`;
    items.forEach((item: any) => {
      emailContent += `   • ${item.mealName}: ${item.estimatedQuantity} portions\n`;
    });
    emailContent += "\n";
  });

  emailContent += `
📝 **Important Notes:**
- These are estimates based on scheduled orders
- Actual confirmed orders will be sent individually
- Contact FreshPunk support if you have questions

Best regards,
FreshPunk Team
`;

  return emailContent;
}

/**
 * Categorize meal by time of day for better organization
 * @param {string} mealName - The name of the meal to categorize
 * @return {string} The meal time category (breakfast, lunch, dinner, other)
 */
function categorizeMealTime(mealName: string): string {
  const name = mealName.toLowerCase();

  if (name.includes("breakfast") || name.includes("morning") ||
      name.includes("pancake") || name.includes("omelette") ||
      name.includes("cereal") || name.includes("toast")) {
    return "breakfast";
  }

  if (name.includes("lunch") || name.includes("sandwich") ||
      name.includes("salad") || name.includes("soup")) {
    return "lunch";
  }

  if (name.includes("dinner") || name.includes("steak") ||
      name.includes("pasta") || name.includes("roast")) {
    return "dinner";
  }

  return "other";
}

/**
 * Get restaurant notifications (for restaurant portal)
 */
export const getRestaurantNotifications = onCall(
  {
    memory: "512MiB",
    timeoutSeconds: 60,
    region: "us-east4",
  },
  async (request: any) => {
  try {
    const db = getFirestore();
    const {auth} = request;
    if (!auth) {
      throw new HttpsError("unauthenticated", "Authentication required");
    }

    const {restaurantId} = request.data;
    if (!restaurantId) {
      throw new HttpsError("invalid-argument", "Restaurant ID required");
    }

    // Verify restaurant ownership
    const restaurantDoc = await db.collection("restaurant_partners").doc(restaurantId).get();
    if (!restaurantDoc.exists || restaurantDoc.data()?.userId !== auth.uid) {
      throw new HttpsError("permission-denied", "Access denied");
    }

    // Get recent notifications
    const notificationsSnapshot = await db.collection("restaurant_notifications")
      .where("restaurantId", "==", restaurantId)
      .orderBy("createdAt", "desc")
      .limit(50)
      .get();

    const notifications = notificationsSnapshot.docs.map((doc) => ({
      id: doc.id,
      ...doc.data(),
    }));

    return {
      success: true,
      notifications,
      unreadCount: notifications.filter((n: any) => !n.isRead).length,
    };
  } catch (error: any) {
    logger.error("Failed to get restaurant notifications", error);
    throw new HttpsError("internal", `Failed to get notifications: ${error.message}`);
  }
});

// ============================================================================
// UTILITY FUNCTIONS
// ============================================================================

function categorizeItem(name: string, description: string): string {
  const text = `${name} ${description}`.toLowerCase();

  if (text.includes("breakfast") || text.includes("pancake") || text.includes("waffle") || text.includes("omelette")) {
    return "breakfast";
  }
  if (text.includes("salad") || text.includes("sandwich") || text.includes("soup") || text.includes("wrap")) {
    return "lunch";
  }
  if (text.includes("dinner") || text.includes("steak") || text.includes("pasta") || text.includes("entree")) {
    return "dinner";
  }

  return "lunch"; // Default
}

function extractTags(name: string, description: string): string[] {
  const text = `${name} ${description}`.toLowerCase();
  const tags = [];

  if (text.includes("spicy")) tags.push("spicy");
  if (text.includes("healthy")) tags.push("healthy");
  if (text.includes("protein")) tags.push("high-protein");
  if (text.includes("fresh")) tags.push("fresh");
  if (text.includes("organic")) tags.push("organic");

  return tags;
}

function estimateCalories(name: string, description: string): number {
  const text = `${name} ${description}`.toLowerCase();

  if (text.includes("salad")) return 350;
  if (text.includes("soup")) return 250;
  if (text.includes("sandwich")) return 450;
  if (text.includes("pasta")) return 550;
  if (text.includes("steak")) return 650;

  return 400; // Default estimate
}

function isVegetarian(name: string, description: string): boolean {
  const text = `${name} ${description}`.toLowerCase();
  return text.includes("vegetarian") ||
    (text.includes("veggie") && !text.includes("meat") && !text.includes("chicken") && !text.includes("beef"));
}

function isVegan(name: string, description: string): boolean {
  const text = `${name} ${description}`.toLowerCase();
  return text.includes("vegan");
}

function isGlutenFree(name: string, description: string): boolean {
  const text = `${name} ${description}`.toLowerCase();
  return text.includes("gluten-free") || text.includes("gluten free");
}
