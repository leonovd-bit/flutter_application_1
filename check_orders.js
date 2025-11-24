// Quick script to check if orders exist in Firestore
const admin = require('firebase-admin');

// Initialize Firebase Admin
const serviceAccount = require('./functions/serviceAccountKey.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function checkOrders() {
  const userId = 'gLRydXhhxPNkz09X58R2dJZN21Z2';
  
  console.log(`\n=== Checking orders for user: ${userId} ===\n`);
  
  // Query 1: All orders for this user
  const allOrders = await db.collection('orders')
    .where('userId', '==', userId)
    .get();
  
  console.log(`Total orders for this user: ${allOrders.docs.length}\n`);
  
  if (allOrders.docs.length > 0) {
    console.log('Order details:');
    allOrders.docs.forEach((doc, index) => {
      const data = doc.data();
      console.log(`\n${index + 1}. Order ID: ${doc.id}`);
      console.log(`   Status: ${data.status}`);
      console.log(`   User ID: ${data.userId}`);
      console.log(`   Delivery Date: ${data.deliveryDate ? data.deliveryDate.toDate() : 'N/A'}`);
      console.log(`   User Confirmed: ${data.userConfirmed}`);
      console.log(`   Created At: ${data.createdAt ? data.createdAt.toDate() : 'N/A'}`);
    });
  }
  
  // Query 2: Pending orders (what the app queries for)
  console.log('\n\n=== Querying pending orders (same as app) ===\n');
  const pendingOrders = await db.collection('orders')
    .where('userId', '==', userId)
    .where('status', '==', 'pending')
    .orderBy('deliveryDate')
    .limit(1)
    .get();
  
  console.log(`Pending orders found: ${pendingOrders.docs.length}`);
  
  if (pendingOrders.docs.length > 0) {
    const doc = pendingOrders.docs[0];
    const data = doc.data();
    console.log(`\nNext pending order:`);
    console.log(`   Order ID: ${doc.id}`);
    console.log(`   Status: ${data.status}`);
    console.log(`   Delivery Date: ${data.deliveryDate ? data.deliveryDate.toDate() : 'N/A'}`);
    console.log(`   Meals: ${JSON.stringify(data.meals, null, 2)}`);
  }
  
  process.exit(0);
}

checkOrders().catch((error) => {
  console.error('Error:', error);
  process.exit(1);
});
