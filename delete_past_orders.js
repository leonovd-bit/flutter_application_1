#!/usr/bin/env node

/**
 * Delete old test orders for a user
 * Usage: node delete_past_orders.js <userId>
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

async function deletePastOrders() {
  try {
    console.log(`🗑️  Deleting orders for user: ${userId}`);
    
    // Get all orders for this user
    const snapshot = await db.collection('orders')
      .where('userId', '==', userId)
      .where('status', 'in', ['delivered', 'cancelled'])
      .get();
    
    console.log(`Found ${snapshot.docs.length} past orders to delete`);
    
    let deleted = 0;
    for (const doc of snapshot.docs) {
      const orderId = doc.id;
      
      // Delete from main orders collection
      await db.collection('orders').doc(orderId).delete();
      
      // Delete from user's orders subcollection
      await db.collection('users').doc(userId).collection('orders').doc(orderId).delete();
      
      console.log(`✅ Deleted order: ${orderId}`);
      deleted++;
    }
    
    console.log(`\n🎉 Successfully deleted ${deleted} orders`);
    process.exit(0);
  } catch (error) {
    console.error('❌ Error deleting orders:', error);
    process.exit(1);
  }
}

deletePastOrders();
