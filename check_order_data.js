// Quick diagnostic script to check order and meal data in Firestore
const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json'); // You'll need to add this

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function checkData() {
  console.log('\n=== Checking Recent Orders ===');
  
  // Check most recent order
  const ordersSnapshot = await db.collection('orders')
    .orderBy('createdAt', 'desc')
    .limit(3)
    .get();
  
  if (ordersSnapshot.empty) {
    console.log('❌ No orders found in Firestore');
    return;
  }
  
  ordersSnapshot.forEach(doc => {
    const data = doc.data();
    console.log(`\n📦 Order: ${doc.id}`);
    console.log(`   Status: ${data.status}`);
    console.log(`   User: ${data.userId}`);
    console.log(`   Created: ${data.createdAt?.toDate()}`);
    console.log(`   Meals count: ${data.meals?.length || 0}`);
    
    if (data.meals && data.meals.length > 0) {
      data.meals.forEach((meal, i) => {
        console.log(`   \n   Meal ${i + 1}: ${meal.name}`);
        console.log(`      restaurantId: ${meal.restaurantId || '❌ MISSING'}`);
        console.log(`      squareItemId: ${meal.squareItemId || '❌ MISSING'}`);
        console.log(`      squareVariationId: ${meal.squareVariationId || '❌ MISSING'}`);
      });
    }
    
    if (data.squareOrders) {
      console.log(`   \n   ✅ Square Orders:`);
      Object.entries(data.squareOrders).forEach(([restaurantId, squareOrder]) => {
        console.log(`      Restaurant ${restaurantId}: ${squareOrder.squareOrderId}`);
      });
    } else {
      console.log(`   ❌ No squareOrders field (not forwarded yet)`);
    }
  });
  
  console.log('\n\n=== Checking California Cobb Salad Meal ===');
  
  // Check the meal document
  const mealsSnapshot = await db.collection('meals')
    .where('name', '==', 'California Cobb Salad')
    .limit(1)
    .get();
  
  if (!mealsSnapshot.empty) {
    const mealDoc = mealsSnapshot.docs[0];
    const mealData = mealDoc.data();
    console.log(`\n🍽️ Meal: ${mealDoc.id}`);
    console.log(`   Name: ${mealData.name}`);
    console.log(`   restaurantId: ${mealData.restaurantId || '❌ MISSING'}`);
    console.log(`   squareItemId: ${mealData.squareItemId || '❌ MISSING'}`);
    console.log(`   squareVariationId: ${mealData.squareVariationId || '❌ MISSING'}`);
    console.log(`   price: ${mealData.price}`);
  } else {
    console.log('❌ California Cobb Salad not found in meals collection');
  }
  
  console.log('\n\n=== Checking Restaurant Partners ===');
  
  const restaurantsSnapshot = await db.collection('restaurant_partners').get();
  
  if (restaurantsSnapshot.empty) {
    console.log('❌ No restaurant partners found');
  } else {
    restaurantsSnapshot.forEach(doc => {
      const data = doc.data();
      console.log(`\n🏪 Restaurant: ${doc.id}`);
      console.log(`   Name: ${data.restaurantName}`);
      console.log(`   Status: ${data.status}`);
      console.log(`   Has access token: ${!!data.squareAccessToken}`);
      console.log(`   Location ID: ${data.squareLocationId || data.squareMerchantId || '❌ MISSING'}`);
      console.log(`   Order forwarding: ${data.orderForwardingEnabled !== false ? 'Enabled' : 'Disabled'}`);
    });
  }
  
  process.exit(0);
}

checkData().catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
