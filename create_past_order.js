#!/usr/bin/env node

/**
 * Test script to create a completed order for a user
 * Usage: node create_past_order.js <userId>
 */

const admin = require('firebase-admin');
const serviceAccount = require('./service-account.json');

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'freshpunk-48db1',
});

const db = admin.firestore();
const userId = process.argv[2] || 'vIsgEaCeQoPPgps8Uo4P8FocM1T2';

async function createPastOrder() {
  try {
    const now = new Date();
    const yesterday = new Date(now.getTime() - 24 * 60 * 60 * 1000);
    
    const orderId = `order_${Date.now()}`;
    
    const orderData = {
      orderId: orderId,
      userId: userId,
      status: 'delivered', // Must be 'delivered' or 'cancelled' for past orders query
      createdAt: yesterday, // Yesterday's date
      updatedAt: now,
      orderDate: yesterday.getTime(),
      deliveryDate: yesterday.getTime(),
      deliveryTime: new Date(yesterday.getTime() + 2 * 60 * 60 * 1000), // 2 hours after creation
      estimatedDeliveryTime: yesterday.getTime() + (2 * 60 * 60 * 1000),
      
      // Proper meals structure for OrderModelV3
      meals: [
        {
          id: 'meal_breakfast_1',
          name: 'Scrambled Eggs & Toast',
          description: 'Fresh eggs with whole grain toast',
          calories: 350,
          protein: 18,
          carbs: 35,
          fat: 12,
          ingredients: ['Eggs', 'Bread', 'Butter'],
          allergens: ['Wheat', 'Dairy'],
          mealType: 'breakfast',
          price: 12.99,
          imageUrl: '',
        },
        {
          id: 'meal_lunch_1',
          name: 'Grilled Chicken Salad',
          description: 'Organic chicken breast with fresh mixed greens',
          calories: 420,
          protein: 38,
          carbs: 15,
          fat: 18,
          ingredients: ['Chicken', 'Lettuce', 'Tomato', 'Cucumber'],
          allergens: [],
          mealType: 'lunch',
          price: 13.99,
          imageUrl: '',
        },
        {
          id: 'meal_dinner_1',
          name: 'Pasta Marinara',
          description: 'Whole wheat pasta with homemade marinara',
          calories: 480,
          protein: 16,
          carbs: 72,
          fat: 8,
          ingredients: ['Pasta', 'Tomato', 'Basil', 'Garlic'],
          allergens: ['Wheat'],
          mealType: 'dinner',
          price: 14.99,
          imageUrl: '',
        }
      ],
      
      mealPlanType: 'standard',
      deliveryAddress: '387 8th Avenue, New York, NY 10001',
      totalAmount: 45.99,
      paymentStatus: 'completed',
      fulfillmentState: 'completed',
      userConfirmed: true,
      userConfirmedAt: yesterday.getTime(),
      notes: 'Delivered successfully',
    };
    
    // Create order in the main orders collection
    await db.collection('orders').doc(orderId).set(orderData);
    console.log(`✅ Created order ${orderId} for user ${userId}`);
    
    // Also add to user's orders subcollection
    await db.collection('users').doc(userId).collection('orders').doc(orderId).set(orderData);
    console.log(`✅ Added order to user's orders subcollection`);
    
    console.log('\n📋 Order Details:');
    console.log(`   Order ID: ${orderId}`);
    console.log(`   User ID: ${userId}`);
    console.log(`   Status: delivered`);
    console.log(`   Created: ${yesterday.toISOString()}`);
    console.log(`   Delivery: ${new Date(yesterday.getTime() + 2 * 60 * 60 * 1000).toISOString()}`);
    console.log(`   Total: $${orderData.totalAmount}`);
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Error creating order:', error);
    process.exit(1);
  }
}

createPastOrder();
