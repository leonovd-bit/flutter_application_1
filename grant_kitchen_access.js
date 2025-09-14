// Simple script to grant kitchen access to a user
const admin = require('firebase-admin');

// Initialize Firebase Admin (uses default credentials)
if (!admin.apps.length) {
  admin.initializeApp({
    projectId: 'freshpunk-48db1'
  });
}

async function grantKitchenAccess(email) {
  try {
    // Get user by email
    const userRecord = await admin.auth().getUserByEmail(email);
    
    // Set custom claims
    await admin.auth().setCustomUserClaims(userRecord.uid, {
      kitchen: true,
      kitchenId: "freshpunk_main",
      kitchenName: "FreshPunk Main Kitchen",
      partnerName: "Test Kitchen Partner",
      partnerEmail: email,
      kitchenGrantedAt: Date.now()
    });
    
    console.log(`✅ Kitchen access granted to ${email}`);
    console.log(`User UID: ${userRecord.uid}`);
    console.log(`Kitchen ID: freshpunk_main`);
    console.log(`Kitchen Name: FreshPunk Main Kitchen`);
    
    // Verify the claims were set
    const updatedUser = await admin.auth().getUser(userRecord.uid);
    console.log('\n📋 Custom Claims:');
    console.log(JSON.stringify(updatedUser.customClaims, null, 2));
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

// Usage: node grant_kitchen_access.js email@example.com
const email = process.argv[2];
if (!email) {
  console.error('❌ Please provide an email address');
  console.error('Usage: node grant_kitchen_access.js email@example.com');
  process.exit(1);
}

grantKitchenAccess(email);
