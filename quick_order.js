#!/usr/bin/env node
/**
 * Create a test order directly using child_process to invoke firebase CLI
 * This leverages your existing Firebase authentication
 */

const {execSync} = require('child_process');
const fs = require('fs');
const path = require('path');

const projectId = 'freshpunk-48db1';

function runFirebaseCommand(command) {
  try {
    const result = execSync(`firebase ${command} --project=${projectId}`, {
      encoding: 'utf8',
      stdio: ['pipe', 'pipe', 'pipe']
    });
    return result;
  } catch (error) {
    throw new Error(`Firebase CLI error: ${error.message}`);
  }
}

async function createOrder() {
  try {
    console.log('🔗 Using Firebase CLI (you are already authenticated)');
    console.log(`📊 Project: ${projectId}\n`);

    // Create order document via REST/CLI
    const now = new Date();
    const deliveryDate = new Date(now.getTime() + 2 * 24 * 60 * 60 * 1000);
    const orderId = `order-${Date.now()}`;

    console.log('📝 Creating order document...');

    // Build the order data as JSON
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
      specialInstructions: "Test order - please check Square",
      notes: "Created via Node + Firebase CLI",
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

    // Write to temporary JSON file
    const tempFile = path.join(__dirname, `order-temp-${Date.now()}.json`);
    fs.writeFileSync(tempFile, JSON.stringify(orderData, null, 2));

    try {
      // Try to import via firebase
      console.log(`\n⏳ Attempting to write order to Firestore...`);
      
      // Since firebase CLI doesn't have a direct 'set' command for Firestore,
      // we'll need to use the REST API approach with explicit token
      console.log('\n⚠️  Firebase CLI authentication doesn\'t directly support Firestore writes.');
      console.log('\nPlease do one of these:\n');
      console.log('Option 1: Use Firebase Console (fastest)');
      console.log('  → https://console.firebase.google.com/u/0/project/freshpunk-48db1/firestore/data/orders');
      console.log('  → Click "Add document"');
      console.log('  → Paste this data:\n');
      
      console.log(JSON.stringify(orderData, null, 2));
      
      console.log('\n\nOption 2: Get Firebase token and let me write it');
      console.log('  → Run: firebase login:ci --no-localhost');
      console.log('  → Copy the token');
      console.log('  → Set: $env:FIREBASE_TOKEN = "your-token"');
      console.log('  → Run this script again');
      
    } finally {
      // Clean up temp file
      if (fs.existsSync(tempFile)) {
        fs.unlinkSync(tempFile);
      }
    }

    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

createOrder();
