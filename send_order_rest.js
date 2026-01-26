#!/usr/bin/env node
/**
 * Send test order to Square using Firestore REST API
 * Requires FIREBASE_TOKEN environment variable set via: firebase login:ci
 */

const https = require('https');
const fs = require('fs');
const path = require('path');

// Get project ID from firebase.json
const firebaseConfig = JSON.parse(fs.readFileSync(path.join(__dirname, 'firebase.json'), 'utf8'));
const projectId = firebaseConfig.projects?.default || 'freshpunk-48db1';

console.log(`🔗 Using Firebase project: ${projectId}`);

// Helper to make HTTPS requests
function httpRequest(method, path, data = null) {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: `firestore.googleapis.com`,
      port: 443,
      path: `/v1/projects/${projectId}/databases/(default)/documents${path}`,
      method: method,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${accessToken}`,
      },
    };

    const req = https.request(options, (res) => {
      let body = '';
      res.on('data', chunk => body += chunk);
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode, data: JSON.parse(body) });
        } catch (e) {
          resolve({ status: res.statusCode, data: body });
        }
      });
    });

    req.on('error', reject);
    if (data) req.write(JSON.stringify(data));
    req.end();
  });
}

async function sendOrder() {
  try {
    // Check if FIREBASE_TOKEN is set
    if (!process.env.FIREBASE_TOKEN) {
      console.log(`\n⚠️  FIREBASE_TOKEN not set. To use this script:`);
      console.log(`   1. Run: firebase login:ci`);
      console.log(`   2. Copy the token`);
      console.log(`   3. Set: $env:FIREBASE_TOKEN = "your-token-here"`);
      console.log(`\nAlternatively, use the Firebase Console to create the order manually.`);
      process.exit(1);
    }

    console.log("✅ Using Firebase REST API");

    // Exchange CI token for access token
    const tokenResponse = await new Promise((resolve, reject) => {
      const tokenReq = https.request({
        hostname: 'www.googleapis.com',
        path: '/oauth2/v4/token',
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' }
      }, (res) => {
        let data = '';
        res.on('data', chunk => data += chunk);
        res.on('end', () => {
          try { resolve(JSON.parse(data)); }
          catch (e) { reject(e); }
        });
      });
      
      tokenReq.on('error', reject);
      tokenReq.write(`client_id=764086051850-6qr4p6gpi6hn506pt8ejuq83di341hur.apps.googleusercontent.com&client_secret=d-FL95Q19q7MQmFpd7hHD0Ty&refresh_token=${process.env.FIREBASE_TOKEN}&grant_type=refresh_token`);
      tokenReq.end();
    });

    if (!tokenResponse.access_token) {
      throw new Error('Failed to get access token: ' + JSON.stringify(tokenResponse));
    }

    const accessToken = tokenResponse.access_token;
    console.log("✅ Got access token");

    // For this simple example, hardcode restaurant and meal IDs
    // In production, you'd query to find these
    const restaurantId = "fd1JQwNpIesg7HOEMeCv";  // The test restaurant
    const mealName = "California Cobb Salad";
    const mealPrice = 14.99;
    const squareItemId = "RQYPV5GFZ4SE52S2DR4OTKLI";
    const squareVariationId = "3IYTE3IDQURVNOBMXLBXGPPQ";

    console.log(`\n📝 Creating order...`);
    console.log(`   Restaurant: ${restaurantId}`);
    console.log(`   Meal: ${mealName} ($${mealPrice})`);

    // Create order document
    const now = new Date();
    const deliveryDate = new Date(now.getTime() + 2 * 24 * 60 * 60 * 1000);
    
    const orderData = {
      fields: {
        userId: { stringValue: `test-user-${Date.now()}` },
        customerName: { stringValue: "John Smith" },
        customerEmail: { stringValue: "john.smith@example.com" },
        customerPhone: { stringValue: "212-555-0100" },
        status: { stringValue: "confirmed" },
        totalAmount: { doubleValue: mealPrice },
        subtotal: { doubleValue: mealPrice },
        tax: { doubleValue: 0 },
        deliveryFee: { doubleValue: 0 },
        total: { doubleValue: mealPrice },
        orderType: { stringValue: "one_time_order" },
        paymentStatus: { stringValue: "test" },
        forwardedToSquare: { booleanValue: false },
        specialInstructions: { stringValue: "Test order - Please check Square" },
        notes: { stringValue: "Test order created via REST API" },
        deliveryDate: { timestampValue: deliveryDate.toISOString() },
        deliveryTime: { stringValue: deliveryDate.toISOString() },
        emailsSent: { arrayValue: { values: [] } },
        meals: {
          arrayValue: {
            values: [
              {
                mapValue: {
                  fields: {
                    mealId: { stringValue: "YOwDdtwpIM6hL5A3sbdU" },
                    restaurantId: { stringValue: restaurantId },
                    name: { stringValue: mealName },
                    price: { doubleValue: mealPrice },
                    quantity: { integerValue: 1 },
                    squareItemId: { stringValue: squareItemId },
                    squareVariationId: { stringValue: squareVariationId },
                  }
                }
              }
            ]
          }
        },
        deliveryAddress: {
          mapValue: {
            fields: {
              streetAddress: { stringValue: "123 Broadway" },
              city: { stringValue: "New York" },
              state: { stringValue: "NY" },
              zipCode: { stringValue: "10001" },
            }
          }
        },
        createdAt: { timestampValue: now.toISOString() },
        updatedAt: { timestampValue: now.toISOString() },
      }
    };

    const response = await httpRequest('POST', '/orders', orderData);
    
    if (response.status >= 200 && response.status < 300) {
      const orderId = response.data.name?.split('/').pop();
      console.log(`\n✅ Order created: ${orderId}`);
      console.log(`\n📋 CUSTOMER INFO (will be sent to Square):`);
      console.log(`   Name: John Smith`);
      console.log(`   Email: john.smith@example.com`);
      console.log(`   Phone: 212-555-0100`);
      console.log(`   Address: 123 Broadway, New York, NY 10001`);
      console.log(`\n💰 ORDER AMOUNT: $${mealPrice}`);
      console.log(`\n⏳ Waiting 5 seconds for Cloud Function to forward to Square...`);
      
      await new Promise(resolve => setTimeout(resolve, 5000));

      // Check order status
      const statusResponse = await httpRequest('GET', `/orders/${orderId}`);
      
      if (statusResponse.status === 200) {
        const order = statusResponse.data.fields || {};
        console.log(`\n✅ Order data retrieved`);
        
        if (order.squareOrders?.mapValue?.fields) {
          const squareOrders = order.squareOrders.mapValue.fields;
          const restaurantSquareOrder = squareOrders[restaurantId];
          
          if (restaurantSquareOrder?.mapValue?.fields) {
            const squareOrderId = restaurantSquareOrder.mapValue.fields.squareOrderId?.stringValue;
            const status = restaurantSquareOrder.mapValue.fields.status?.stringValue;
            
            if (squareOrderId) {
              console.log(`\n✅ SUCCESS! Order forwarded to Square`);
              console.log(`   Square Order ID: ${squareOrderId}`);
              console.log(`   Status: ${status || 'forwarded'}`);
            }
          }
        }
      }
      
      console.log(`\n📌 Order ID for database lookup: ${orderId}`);
    } else {
      console.error(`\n❌ Failed to create order`);
      console.error(`   Status: ${response.status}`);
      console.error(`   Response:`, JSON.stringify(response.data, null, 2));
    }

    process.exit(0);
  } catch (error) {
    console.error("❌ Error:", error.message);
    process.exit(1);
  }
}

sendOrder();
