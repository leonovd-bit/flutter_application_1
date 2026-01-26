#!/usr/bin/env node
/**
 * Send test order to Square using Firebase Firestore REST API
 * Uses Firebase CLI authentication
 */

const admin = require('firebase-admin');
const {execSync} = require('child_process');
const path = require('path');

async function sendOrder() {
  try {
    // Get Firebase config from firebase.json
    const configPath = path.join(__dirname, 'firebase.json');
    const config = require(configPath);
    const projectId = (config.projects && config.projects.default) || 'freshpunk-48db1';
    
    console.log(`🔗 Initializing Firebase Admin SDK for project: ${projectId}`);
    
    // Initialize with GOOGLE_APPLICATION_CREDENTIALS or service account
    // First try to use implicit auth from gcloud CLI
    try {
      // Try using the default ADC (application default credentials)
      admin.initializeApp({
        projectId,
        databaseURL: `https://${projectId}.firebaseio.com`
      });
    } catch (e) {
      console.error('Failed to auto-initialize:', e.message);
      // Fall back to explicit credential setup
      const {exec} = require('child_process');
      exec('firebase setup:emulators:firestore', (err) => {
        if (err) console.warn('Emulator setup not needed');
      });
    }
    
    const db = admin.firestore();
    
    console.log("✅ Connected to Firestore");
    console.log("\n🔍 Finding a restaurant with Square integration...");
    
    // Query for an active restaurant
    const restaurantsSnap = await db
      .collection("restaurant_partners")
      .where("status", "==", "active")
      .limit(1)
      .get();
    
    if (restaurantsSnap.empty) {
      console.error("❌ No active restaurant partners found. Create one first!");
      process.exit(1);
    }
    
    const restaurantDoc = restaurantsSnap.docs[0];
    const restaurant = restaurantDoc.data();
    const restaurantId = restaurantDoc.id;
    
    console.log(`✅ Found restaurant: ${restaurant.restaurantName} (${restaurantId})`);
    
    // Get a meal from this restaurant
    console.log("\n🔍 Finding meals for this restaurant...");
    
    const restaurantSlug = (restaurant.restaurantName || restaurantId)
      .toLowerCase()
      .replace(/\s+/g, "_");
    
    const mealsSnap = await db
      .collection("meals")
      .doc(restaurantSlug)
      .collection("items")
      .limit(1)
      .get();
    
    if (mealsSnap.empty) {
      console.error(`❌ No meals found for ${restaurantSlug}`);
      process.exit(1);
    }
    
    const mealDoc = mealsSnap.docs[0];
    const meal = mealDoc.data();
    
    console.log(`✅ Found meal: ${meal.name} (${mealDoc.id})`);
    console.log(`   Price: $${(meal.priceCents / 100).toFixed(2)}`);
    console.log(`   Square Item ID: ${meal.squareItemId}`);
    console.log(`   Square Variation ID: ${meal.squareVariationId}`);
    
    // Create the order
    const orderData = {
      userId: `test-user-${Date.now()}`,
      restaurantId: restaurantId,
      customerName: "John Smith",
      customerEmail: "john.smith@example.com",
      customerPhone: "212-555-0100",
      deliveryAddress: {
        streetAddress: "123 Broadway",
        city: "New York",
        state: "NY",
        zipCode: "10001",
      },
      specialInstructions: "Test order - please check Square",
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
      deliveryDate: admin.firestore.Timestamp.fromDate(
        new Date(Date.now() + 2 * 24 * 60 * 60 * 1000)
      ),
      deliveryTime: new Date(Date.now() + 2 * 24 * 60 * 60 * 1000).toISOString(),
      status: "confirmed",
      paymentStatus: "test",
      forwardedToSquare: false,
      emailsSent: [],
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      notes: "Test order created by send_order_to_square.js",
    };
    
    console.log("\n📝 Creating order in Firestore...");
    console.log("   Customer: " + orderData.customerName);
    console.log("   Email: " + orderData.customerEmail);
    console.log("   Phone: " + orderData.customerPhone);
    console.log("   Address: " + orderData.deliveryAddress.streetAddress + ", " + 
                orderData.deliveryAddress.city + ", " + orderData.deliveryAddress.state);
    
    const orderRef = await db.collection("orders").add(orderData);
    const orderId = orderRef.id;
    
    console.log(`\n✅ Order created: ${orderId}`);
    console.log(`\n📋 ORDER DETAILS:`);
    console.log(`   Order ID: ${orderId}`);
    console.log(`   Restaurant: ${restaurant.restaurantName}`);
    console.log(`   Meal: ${meal.name}`);
    console.log(`   Total: $${(meal.priceCents / 100).toFixed(2)}`);
    console.log(`   Delivery: 2 days from now`);
    
    console.log(`\n⏳ Waiting 5 seconds for Cloud Function to process...`);
    await new Promise(resolve => setTimeout(resolve, 5000));
    
    // Check if forwarded to Square
    console.log(`\n🔍 Checking if order was forwarded to Square...`);
    const updatedOrderSnap = await orderRef.get();
    const updatedOrder = updatedOrderSnap.data();
    
    if (updatedOrder.squareOrders && updatedOrder.squareOrders[restaurantId]) {
      const squareOrder = updatedOrder.squareOrders[restaurantId];
      if (squareOrder.squareOrderId) {
        console.log(`\n✅ SUCCESS! Order forwarded to Square`);
        console.log(`   Square Order ID: ${squareOrder.squareOrderId}`);
        console.log(`   Status: ${squareOrder.status}`);
        console.log(`\n📌 To find this order in the database:`);
        console.log(`   Collection: orders`);
        console.log(`   Document ID: ${orderId}`);
        console.log(`   Search by Square Order ID: ${squareOrder.squareOrderId}`);
      } else {
        console.log(`\n⚠️ Square order data exists but no squareOrderId yet`);
        console.log(`   Status: ${squareOrder.status}`);
        if (squareOrder.lastError) {
          console.log(`   Error: ${squareOrder.lastError}`);
        }
      }
    } else {
      console.log(`\n⚠️ Order not yet forwarded to Square`);
      console.log(`   Check Cloud Function logs: firebase functions:log --project=${projectId}`);
    }
    
    console.log(`\n📌 Order ID for database lookup: ${orderId}`);
    process.exit(0);
    
  } catch (error) {
    console.error("❌ Error:", error.message);
    console.error(error.stack);
    process.exit(1);
  }
}

sendOrder();
