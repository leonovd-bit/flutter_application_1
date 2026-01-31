#!/usr/bin/env node
const admin = require('firebase-admin');
const serviceAccount = require('./functions/serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: "https://freshpunk-48db1.firebaseio.com"
});

const db = admin.firestore();

async function investigate() {
  console.log('🔍 Investigating duplicate user documents...\n');

  const userId1 = 'lnFgnZawxOTGcvaftW3ocJ5Mg9f2';
  const userId2 = 'vIsgEaCeQoPPgps8Uo4P8FocM1T2';
  const customerId = 'cus_Ts9cyKvfLnSuEI';

  // Check both user documents
  console.log('📄 Checking user document 1 (with only invoices):');
  const user1Doc = await db.collection('users').doc(userId1).get();
  if (user1Doc.exists) {
    const data = user1Doc.data();
    console.log(`   Document ID: ${userId1}`);
    console.log(`   Fields: ${Object.keys(data).join(', ')}`);
    console.log(`   Data:`, JSON.stringify(data, null, 2));
  } else {
    console.log(`   ❌ Document does not exist (only has subcollections)`);
  }

  // Check subcollections
  const invoices1 = await db.collection('users').doc(userId1).collection('invoices').get();
  console.log(`   Invoices: ${invoices1.docs.length} documents`);

  console.log('\n📄 Checking user document 2 (with all info):');
  const user2Doc = await db.collection('users').doc(userId2).get();
  if (user2Doc.exists) {
    const data = user2Doc.data();
    console.log(`   Document ID: ${userId2}`);
    console.log(`   Fields: ${Object.keys(data).join(', ')}`);
    console.log(`   Email: ${data.email || 'N/A'}`);
    console.log(`   Full Name: ${data.fullName || 'N/A'}`);
    console.log(`   Stripe Customer ID: ${data.stripeCustomerId || 'N/A'}`);
  } else {
    console.log(`   ❌ Document does not exist`);
  }

  const invoices2 = await db.collection('users').doc(userId2).collection('invoices').get();
  console.log(`   Invoices: ${invoices2.docs.length} documents`);

  // Check if customerId links to either user
  console.log('\n🔗 Checking which user has the Stripe customer ID:');
  const usersWithCustomer = await db.collection('users')
    .where('stripeCustomerId', '==', customerId)
    .get();
  
  console.log(`   Found ${usersWithCustomer.docs.length} user(s) with customerId ${customerId}:`);
  usersWithCustomer.docs.forEach(doc => {
    console.log(`   - ${doc.id} (${doc.data().email})`);
  });

  // Check Firebase Auth
  console.log('\n🔐 Checking Firebase Auth accounts:');
  try {
    const auth1 = await admin.auth().getUser(userId1);
    console.log(`   ✅ Auth account exists for ${userId1}:`);
    console.log(`      Email: ${auth1.email}`);
    console.log(`      Created: ${auth1.metadata.creationTime}`);
  } catch (e) {
    console.log(`   ❌ No Auth account for ${userId1}: ${e.message}`);
  }

  try {
    const auth2 = await admin.auth().getUser(userId2);
    console.log(`   ✅ Auth account exists for ${userId2}:`);
    console.log(`      Email: ${auth2.email}`);
    console.log(`      Created: ${auth2.metadata.creationTime}`);
  } catch (e) {
    console.log(`   ❌ No Auth account for ${userId2}: ${e.message}`);
  }

  // Check if same email
  console.log('\n🔍 Checking if both UIDs belong to same email:');
  try {
    const auth1 = await admin.auth().getUser(userId1);
    const auth2 = await admin.auth().getUser(userId2);
    if (auth1.email === auth2.email) {
      console.log(`   ⚠️  DUPLICATE ACCOUNTS FOUND!`);
      console.log(`   Both UIDs have email: ${auth1.email}`);
      console.log(`   This user has TWO Firebase Auth accounts!`);
    } else {
      console.log(`   Different emails:`);
      console.log(`   ${userId1}: ${auth1.email}`);
      console.log(`   ${userId2}: ${auth2.email}`);
    }
  } catch (e) {
    console.log(`   Could not compare: ${e.message}`);
  }

  process.exit(0);
}

investigate().catch(error => {
  console.error('Error:', error);
  process.exit(1);
});
