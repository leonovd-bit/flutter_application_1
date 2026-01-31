#!/usr/bin/env node

/**
 * Delete a specific order
 * Usage: node delete_order.js <orderId> <userId>
 */

const admin = require('firebase-admin');
const serviceAccount = require('./service-account.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'freshpunk-48db1',
});

const db = admin.firestore();
const orderId = process.argv[2];
const userId = process.argv[3];

if (!orderId || !userId) {
  console.error('Usage: node delete_order.js <orderId> <userId>');
  process.exit(1);
}

async function deleteOrder() {
  try {
    // Delete from main orders collection
    await db.collection('orders').doc(orderId).delete();
    console.log(`✅ Deleted order ${orderId} from orders collection`);
    
    // Delete from user's orders subcollection
    await db.collection('users').doc(userId).collection('orders').doc(orderId).delete();
    console.log(`✅ Deleted order ${orderId} from user's orders subcollection`);
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Error deleting order:', error);
    process.exit(1);
  }
}

deleteOrder();
