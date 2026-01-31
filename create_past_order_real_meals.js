#!/usr/bin/env node

/**
 * Test script to create a completed order with real meals from database
 * Usage: node create_past_order_real_meals.js <userId>
 */

const admin = require('firebase-admin');
const serviceAccount = require('./service-account.json');

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'freshpunk-48db1',
});

const db = admin.firestore();
const userId = process.argv[2] || '5OpTmkJtG9SLPpKYKMwbSHMh0h13';

async function createPastOrderWithRealMeals() {
  try {
    console.log('📥 Fetching meal from database...');
    
    // Fetch from meals/greenblend/items
    const itemsSnapshot = await db.collection('meals').doc('greenblend').collection('items').limit(1).get();
    
    if (itemsSnapshot.empty) {
      console.error('❌ No meals found in meals/greenblend/items');
      process.exit(1);
    }
    
    const mealDoc = itemsSnapshot.docs[0];
    const mealData = mealDoc.data();
    
    const meals = [{
      id: mealDoc.id,
      name: mealData.name || 'Meal',
      description: mealData.description || '',
      calories: mealData.calories || 400,
      protein: mealData.protein || 20,
      carbs: mealData.carbs || 50,
      fat: mealData.fat || 15,
      ingredients: mealData.ingredients || [],
      allergens: mealData.allergens || [],
      mealType: mealData.mealType || 'lunch',
      price: mealData.price || 12.99,
      imageUrl: mealData.imageUrl || '',
    }];
    
    console.log(`✅ Fetched meal from database:`);
    meals.forEach((meal, i) => {
      console.log(`   • ${meal.name} (${meal.mealType}) - $${meal.price}`);
    });
    
    const now = new Date();
    const yesterday = new Date(now.getTime() - 24 * 60 * 60 * 1000);
    
    const orderId = `order_${Date.now()}`;
    
    const orderData = {
      id: orderId,
      orderId: orderId,
      userId: userId,
      status: 'delivered',
      createdAt: yesterday,
      updatedAt: now,
      orderDate: yesterday.getTime(),
      deliveryDate: yesterday.getTime(),
      deliveryTime: new Date(yesterday.getTime() + 2 * 60 * 60 * 1000),
      estimatedDeliveryTime: yesterday.getTime() + (2 * 60 * 60 * 1000),
      
      // Real meals from database
      meals: meals,
      
      mealPlanType: 'standard',
      deliveryAddress: '387 8th Avenue, New York, NY 10001',
      totalAmount: meals.reduce((sum, meal) => sum + meal.price, 0),
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
    console.log(`   Total: $${orderData.totalAmount.toFixed(2)}`);
    console.log(`   Meals: ${meals.length}`);
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Error creating order:', error);
    process.exit(1);
  }
}

createPastOrderWithRealMeals();
