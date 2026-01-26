#!/usr/bin/env node
const admin = require('firebase-admin');
const serviceAccount = require('./functions/serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: "https://freshpunk-48db1.firebaseio.com"
});

const db = admin.firestore();

async function createRealUserOrder() {
  try {
    const userId = process.argv[2] || 'p1ztizHn6sevxFo9kTRagzFX7Jy1';
    
    console.log(`🔍 Fetching user data for: ${userId}`);
    
    // Get user profile
    const userDoc = await db.collection('users').doc(userId).get();
    if (!userDoc.exists) {
      console.error(`❌ User not found: ${userId}`);
      process.exit(1);
    }
    
    const userData = userDoc.data();
    console.log(`✅ Found user: ${userData.name || userData.email}`);
    
    // Get user's address
    const addressesSnap = await db.collection('users').doc(userId).collection('addresses').limit(1).get();
    let address;
    
    if (addressesSnap.empty) {
      console.log('⚠️  User has no saved addresses. Using default NYC address for testing.');
      address = {
        streetAddress: "123 Broadway",
        city: "New York",
        state: "NY",
        zipCode: "10001",
        phoneNumber: userData.phoneNumber || "212-555-0100"
      };
    } else {
      address = addressesSnap.docs[0].data();
    }
    
    console.log(`✅ Address: ${address.streetAddress}, ${address.city}, ${address.state} ${address.zipCode}`);
    
    // Use hardcoded working restaurant/meal that we know exists
    const restaurantId = "fd1JQwNpIesg7HOEMeCv";
    const restaurant = {
      restaurantName: "Test Kitchen",
      restaurantId: restaurantId
    };
    console.log(`✅ Restaurant: ${restaurant.restaurantName}`);
    
    // Hardcoded meal that exists
    const mealId = "YOwDdtwpIM6hL5A3sbdU";
    const meal = {
      name: "California Cobb Salad",
      priceCents: 1499,
      squareItemId: "RQYPV5GFZ4SE52S2DR4OTKLI",
      squareVariationId: "3IYTE3IDQURVNOBMXLBXGPPQ"
    };
    console.log(`✅ Meal: ${meal.name} - $${(meal.priceCents / 100).toFixed(2)}`);
    
    // Create order with REAL user data
    const orderData = {
      userId: userId,
      restaurantId: restaurantId,
      customerName: userData.name || userData.email || 'Customer',
      customerEmail: userData.email || 'noemail@example.com',
      customerPhone: userData.phoneNumber || address.phoneNumber || 'N/A',
      deliveryAddress: {
        streetAddress: address.streetAddress,
        city: address.city,
        state: address.state,
        zipCode: address.zipCode,
      },
      specialInstructions: "Real user order test",
      meals: [
        {
          mealId: mealId,
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
      deliveryDate: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 2 * 24 * 60 * 60 * 1000)),
      deliveryTime: new Date(Date.now() + 2 * 24 * 60 * 60 * 1000).toISOString(),
      status: "confirmed",
      paymentStatus: "test",
      forwardedToSquare: false,
      emailsSent: [],
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      notes: "Real user order created via test script",
    };

    console.log("\n📝 Creating order with REAL user data...");
    const orderRef = await db.collection("orders").add(orderData);
    const orderId = orderRef.id;
    
    console.log(`✅ Order created: ${orderId}`);
    console.log(`\n📋 ORDER DETAILS:`);
    console.log(`   Order ID: ${orderId}`);
    console.log(`   User: ${orderData.customerName}`);
    console.log(`   Email: ${orderData.customerEmail}`);
    console.log(`   Phone: ${orderData.customerPhone}`);
    console.log(`   Address: ${orderData.deliveryAddress.streetAddress}, ${orderData.deliveryAddress.city}`);
    console.log(`   Restaurant: ${restaurant.restaurantName}`);
    console.log(`   Meal: ${meal.name}`);
    console.log(`   Total: $${(meal.priceCents / 100).toFixed(2)}`);
    
    console.log(`\n⏳ Waiting 5 seconds for Cloud Function to forward to Square...`);
    await new Promise(resolve => setTimeout(resolve, 5000));
    
    // Get the order to check status
    const orderSnap = await orderRef.get();
    const updatedOrder = orderSnap.data();
    
    console.log("\n📊 Updated order status:");
    console.log("Status:", updatedOrder.status);
    console.log("Square Orders:", JSON.stringify(updatedOrder.squareOrders, null, 2));
    
    if (updatedOrder.squareOrders && updatedOrder.squareOrders[restaurantId]) {
      const sq = updatedOrder.squareOrders[restaurantId];
      if (sq.status === "forwarded") {
        console.log("\n✅ SUCCESS! Order forwarded to Square");
        console.log("Square Order ID:", sq.squareOrderId);
        console.log("\n📌 This should now appear in Square with the real customer data!");
      } else if (sq.status === "forward_failed") {
        console.log("\n❌ Order forwarding failed");
        console.log("Error:", sq.lastError);
      }
    } else {
      console.log("\n⚠️ No Square order data yet. Check logs for details.");
    }
    
    console.log(`\n📌 Order ID for database lookup: ${orderId}`);
    process.exit(0);
  } catch (error) {
    console.error("❌ Error:", error.message);
    console.error(error.stack);
    process.exit(1);
  }
}

createRealUserOrder();
