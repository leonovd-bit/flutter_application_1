#!/usr/bin/env node
const admin = require('firebase-admin');
const serviceAccount = require('./functions/serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: "https://freshpunk-48db1.firebaseio.com"
});

const db = admin.firestore();

async function createTestOrder() {
  try {
    const orderData = {
      userId: `test-user-${Date.now()}`,
      restaurantId: "fd1JQwNpIesg7HOEMeCv",
      customerName: "Test Customer - SQUARE_ENV=production",
      customerEmail: "test@example.com",
      customerPhone: "555-0099",
      deliveryAddress: {
        streetAddress: "1500 Sand Hill Rd",
        city: "Palo Alto",
        state: "CA",
        zipCode: "94304",
      },
      specialInstructions: "Test with production SQUARE_ENV",
      meals: [
        {
          mealId: "YOwDdtwpIM6hL5A3sbdU",
          restaurantId: "fd1JQwNpIesg7HOEMeCv",
          name: "California Cobb Salad",
          price: 14.99,
          quantity: 1,
          squareItemId: "RQYPV5GFZ4SE52S2DR4OTKLI",
          squareVariationId: "3IYTE3IDQURVNOBMXLBXGPPQ",
        },
      ],
      orderType: "one_time_order",
      totalAmount: 14.99,
      subtotal: 14.99,
      tax: 0,
      deliveryFee: 0,
      total: 14.99,
      deliveryDate: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 45 * 60 * 1000)),
      deliveryTime: new Date(Date.now() + 45 * 60 * 1000).toISOString(),
      status: "confirmed",
      paymentStatus: "test",
      forwardedToSquare: false,
      emailsSent: [],
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      notes: "Test order with SQUARE_ENV=production",
    };

    const orderRef = await db.collection("orders").add(orderData);
    console.log("✅ Test order created:", orderRef.id);
    console.log("📋 Order ID:", orderRef.id);
    console.log("⏳ Waiting 5 seconds for forwardOrderOnStatusUpdate to process...");
    
    // Wait 5 seconds for the trigger to fire
    await new Promise(resolve => setTimeout(resolve, 5000));
    
    // Get the order to check status
    const orderSnap = await orderRef.get();
    const updatedOrder = orderSnap.data();
    
    console.log("\n📊 Updated order status:");
    console.log("Status:", updatedOrder.status);
    console.log("Square Orders:", JSON.stringify(updatedOrder.squareOrders, null, 2));
    
    if (updatedOrder.squareOrders && updatedOrder.squareOrders["fd1JQwNpIesg7HOEMeCv"]) {
      const sq = updatedOrder.squareOrders["fd1JQwNpIesg7HOEMeCv"];
      if (sq.status === "forwarded") {
        console.log("\n✅ SUCCESS! Order forwarded to Square");
        console.log("Square Order ID:", sq.squareOrderId);
      } else if (sq.status === "forward_failed") {
        console.log("\n❌ Order forwarding failed");
        console.log("Error:", sq.lastError);
      } else if (sq.status === "forward_exception") {
        console.log("\n❌ Order forwarding exception");
        console.log("Error:", sq.lastError);
      }
    } else {
      console.log("\n⚠️ No Square order data yet. Check logs for details.");
    }
    
    process.exit(0);
  } catch (error) {
    console.error("❌ Error:", error);
    process.exit(1);
  }
}

createTestOrder();
