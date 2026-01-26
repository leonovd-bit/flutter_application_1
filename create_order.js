#!/usr/bin/env node
/**
 * Create order using curl (which firebase CLI uses internally)
 * This uses your authenticated firebase session
 */

const { execSync } = require('child_process');
const fs = require('fs');

const projectId = 'freshpunk-48db1';

async function createOrder() {
  try {
    console.log('🔗 Creating order via Firebase CLI...');

    // Generate order data
    const now = new Date();
    const deliveryDate = new Date(now.getTime() + 2 * 24 * 60 * 60 * 1000);
    
    const orderData = {
      userId: `test-user-${Date.now()}`,
      customerName: "John Smith",
      customerEmail: "john.smith@example.com",
      customerPhone: "212-555-0100",
      status: "confirmed",
      totalAmount: 14.99,
      subtotal: 14.99,
      tax: 0,
      deliveryFee: 0,
      total: 14.99,
      orderType: "one_time_order",
      paymentStatus: "test",
      forwardedToSquare: false,
      specialInstructions: "Test order",
      notes: "Created via firebase import",
      deliveryDate: deliveryDate.toISOString(),
      deliveryTime: deliveryDate.toISOString(),
      emailsSent: [],
      meals: [
        {
          mealId: "YOwDdtwpIM6hL5A3sbdU",
          restaurantId: "fd1JQwNpIesg7HOEMeCv",
          name: "California Cobb Salad",
          price: 14.99,
          quantity: 1,
          squareItemId: "RQYPV5GFZ4SE52S2DR4OTKLI",
          squareVariationId: "3IYTE3IDQURVNOBMXLBXGPPQ"
        }
      ],
      deliveryAddress: {
        streetAddress: "123 Broadway",
        city: "New York",
        state: "NY",
        zipCode: "10001"
      },
      createdAt: now.toISOString(),
      updatedAt: now.toISOString()
    };

    // Write temporary JSON file
    const tempJson = `order-${Date.now()}.json`;
    fs.writeFileSync(tempJson, JSON.stringify(orderData, null, 2));

    try {
      // Use firebase emulator to write (or try REST API export/import)
      console.log('\n📝 Preparing order data...');
      console.log('   Customer: John Smith');
      console.log('   Email: john.smith@example.com');
      console.log('   Phone: 212-555-0100');
      console.log('   Address: 123 Broadway, New York, NY 10001');
      console.log('   Meal: California Cobb Salad ($14.99)');
      console.log('   Status: confirmed');

      // Try to use firebase firestore:set command if available
      // Otherwise fall back to manual instruction
      try {
        const cmd = `firebase firestore:set /orders/order-${Date.now()} --data '${JSON.stringify(orderData).replace(/'/g, "\\'")}'`;
        console.log('\n⏳ Attempting to write to Firestore...');
        execSync(cmd, { stdio: 'inherit', cwd: process.cwd() });
        console.log('\n✅ Order created successfully!');
      } catch (e) {
        // Firebase CLI doesn't have a direct set command
        console.log('\n⚠️  Firebase CLI cannot directly write Firestore documents.');
        console.log('\nInstead, please:');
        console.log('\n1️⃣  Go to Firebase Console:');
        console.log('   https://console.firebase.google.com/u/0/project/freshpunk-48db1/firestore/data/orders');
        console.log('\n2️⃣  Click "+ Add document"');
        console.log('\n3️⃣  Copy and paste this data:\n');
        console.log(JSON.stringify(orderData, null, 2));
        console.log('\n4️⃣  Click Save');
        console.log('\n5️⃣  Note the Document ID that appears');
        console.log('\n6️⃣  Wait 5 seconds for Cloud Function to process');
        console.log('\n7️⃣  Reload to see squareOrders field with Square Order ID');
      }
    } finally {
      if (fs.existsSync(tempJson)) {
        fs.unlinkSync(tempJson);
      }
    }

    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

createOrder();
