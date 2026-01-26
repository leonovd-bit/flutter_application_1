#!/usr/bin/env node
/**
 * Send an order to Square
 * This script creates a test order in Firestore that will trigger Cloud Functions
 * to forward it to Square.
 * 
 * Authentication: Uses firebase CLI's existing authentication
 */
const admin = require('firebase-admin');
const {initializeApp, cert} = require('firebase-admin/app');

// Try to initialize with default credentials, fallback to uncertified
try {
  admin.initializeApp({
    projectId: 'freshpunk-48db1',
    databaseURL: "https://freshpunk-48db1.firebaseio.com"
  });
} catch (e) {
  // If admin is already initialized, that's ok
  if (!e.message.includes('already initialized')) {
    console.error("Warning: Could not initialize admin with credentials:", e.message);
  }
}

const db = admin.firestore();

async function sendOrderToSquare() {
  try {
    console.log("🔍 Finding a restaurant with Square integration...");
    
    // Get first restaurant partner
    const restaurantsSnap = await db.collection("restaurant_partners")
      .where("status", "==", "active")
      .limit(1)
      .get();
    
    if (restaurantsSnap.empty) {
      console.error("❌ No active restaurant partners found");
      process.exit(1);
    }
    
    const restaurantDoc = restaurantsSnap.docs[0];
    const restaurant = restaurantDoc.data();
    const restaurantId = restaurantDoc.id;
    
    console.log(`✅ Found restaurant: ${restaurant.restaurantName} (${restaurantId})`);
    console.log(`   Square Merchant ID: ${restaurant.squareMerchantId}`);
    
    // Get a meal from this restaurant
    console.log("\n🔍 Finding meals for this restaurant...");
    
    const mealsSnap = await db.collection("meals")
      .doc(restaurant.restaurantName?.toLowerCase().replace(/\s+/g, "_") || restaurantId)
      .collection("items")
      .limit(1)
      .get();
    
    if (mealsSnap.empty) {
      console.error("❌ No meals found for this restaurant");
      process.exit(1);
    }
    
    const mealDoc = mealsSnap.docs[0];
    const meal = mealDoc.data();
    
    console.log(`✅ Found meal: ${meal.name} (${mealDoc.id})`);
    console.log(`   Square Item ID: ${meal.squareItemId}`);
    console.log(`   Square Variation ID: ${meal.squareVariationId}`);
    console.log(`   Price: $${(meal.priceCents / 100).toFixed(2)}`);
    
    // Create test order
    const orderData = {
      userId: `test-user-${Date.now()}`,
      customerName: "Test Customer",
      customerEmail: "test@example.com",
      customerPhone: "555-0100",
      deliveryAddress: {
        streetAddress: "1234 Test St",
        city: "Test City",
        state: "CA",
        zipCode: "12345",
      },
      specialInstructions: "Test order sent via send_order_to_square.js",
      meals: [
        {
          mealId: mealDoc.id,
          restaurantId: restaurantId,
          name: meal.name,
          price: meal.priceCents / 100,
          quantity: 1,
          squareItemId: meal.squareItemId,
          squareVariationId: meal.squareVariationId,
        },
      ],
      orderType: "one_time_order",
      totalAmount: meal.priceCents / 100,
      subtotal: meal.priceCents / 100,
      tax: 0,
      deliveryFee: 0,
      total: meal.priceCents / 100,
      deliveryDate: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 2 * 24 * 60 * 60 * 1000)), // 2 days from now
      deliveryTime: new Date(Date.now() + 2 * 24 * 60 * 60 * 1000).toISOString(),
      status: "confirmed",
      paymentStatus: "test",
      forwardedToSquare: false,
      emailsSent: [],
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      notes: "Test order sent via send_order_to_square.js",
    };

    console.log("\n📝 Creating order...");
    const orderRef = await db.collection("orders").add(orderData);
    const orderId = orderRef.id;
    
    console.log(`✅ Order created: ${orderId}`);
    console.log(`\n📋 ORDER DETAILS:`);
    console.log(`   Order ID: ${orderId}`);
    console.log(`   Restaurant: ${restaurant.restaurantName}`);
    console.log(`   Restaurant ID: ${restaurantId}`);
    console.log(`   Meal: ${meal.name}`);
    console.log(`   Total: $${(meal.priceCents / 100).toFixed(2)}`);
    console.log(`   Delivery: 2 days from now`);
    
    console.log(`\n⏳ Waiting 5 seconds for Cloud Function to process order...`);
    await new Promise(resolve => setTimeout(resolve, 5000));
    
    // Check status
    console.log(`\n🔍 Checking order status...`);
    const updatedOrderSnap = await orderRef.get();
    const updatedOrder = updatedOrderSnap.data();
    
    console.log(`\n📊 ORDER STATUS:`);
    console.log(`   Status: ${updatedOrder.status}`);
    console.log(`   Forwarded to Square: ${updatedOrder.forwardedToSquare || false}`);
    
    if (updatedOrder.squareOrders && updatedOrder.squareOrders[restaurantId]) {
      const squareOrder = updatedOrder.squareOrders[restaurantId];
      console.log(`\n✅ SQUARE ORDER CREATED`);
      console.log(`   Square Order ID: ${squareOrder.squareOrderId}`);
      console.log(`   Status: ${squareOrder.status}`);
      console.log(`   Forwarded At: ${squareOrder.forwardedAt?.toDate?.() || squareOrder.forwardedAt}`);
      console.log(`\n🎉 SUCCESS! Order has been sent to Square.`);
      console.log(`\n📌 You can find this order in the database with:`)
      console.log(`   Collection: orders`);
      console.log(`   Document ID: ${orderId}`);
    } else {
      console.log(`\n⚠️ Order created but not yet forwarded to Square.`);
      console.log(`   Check Cloud Function logs for details.`);
      console.log(`\n📌 Order ID for database lookup: ${orderId}`);
    }
    
    process.exit(0);
  } catch (error) {
    console.error("❌ Error:", error.message);
    process.exit(1);
  }
}

sendOrderToSquare();
