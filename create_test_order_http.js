#!/usr/bin/env node
/**
 * Create a test order via HTTP Cloud Function call
 * This requires the Cloud Function to be deployed first
 */

const fetch = require('node-fetch');

async function createTestOrder() {
  const functionUrl = 'https://us-east4-freshpunk-48db1.cloudfunctions.net/generateOrderFromMealSelection';
  
  const payload = {
    mealSelections: [
      {
        restaurantId: 'fd1JQwNpIesg7HOEMeCv',
        mealId: 'YOwDdtwpIM6hL5A3sbdU',
        name: 'California Cobb Salad',
        price: 14.99,
        quantity: 1,
        squareItemId: 'RQYPV5GFZ4SE52S2DR4OTKLI',
        squareVariationId: '3IYTE3IDQURVNOBMXLBXGPPQ',
      }
    ],
    deliverySchedule: {
      dayName: 'Monday',
      time: '12:00 PM'
    },
    deliveryAddress: '1234 Test Street, Test City, CA 12345'
  };

  try {
    console.log('📤 Calling Cloud Function...');
    console.log(`URL: ${functionUrl}`);
    console.log('Payload:', JSON.stringify(payload, null, 2));

    const response = await fetch(functionUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(payload)
    });

    const data = await response.json();
    
    if (response.ok) {
      console.log('✅ Success!');
      console.log('Response:', JSON.stringify(data, null, 2));
      
      if (data.result && data.result.orderId) {
        console.log(`\n📌 Order created with ID: ${data.result.orderId}`);
      }
    } else {
      console.log('❌ Error:', response.status, response.statusText);
      console.log('Response:', JSON.stringify(data, null, 2));
    }
  } catch (error) {
    console.error('Error:', error.message);
  }
}

createTestOrder();
