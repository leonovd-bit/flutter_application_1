// Quick diagnostic script to check menu sync status
const admin = require('firebase-admin');
const serviceAccount = require('./functions/service-account-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function checkMenuSync() {
  console.log('\n=== Checking Menu Sync Status ===\n');
  
  // 1. Check restaurant_partners
  const partnersSnap = await db.collection('restaurant_partners').limit(5).get();
  console.log(`Found ${partnersSnap.size} restaurant partners:`);
  partnersSnap.forEach(doc => {
    const data = doc.data();
    console.log(`  - ${doc.id}: ${data.restaurantName || 'N/A'}`);
    console.log(`    Status: ${data.status}`);
    console.log(`    Last sync: ${data.lastMenuSync?.toDate() || 'Never'}`);
    console.log(`    Menu items: ${data.menuItemCount || 0}`);
  });
  
  // 2. Check sync_logs for most recent partner
  if (!partnersSnap.empty) {
    const firstPartner = partnersSnap.docs[0];
    console.log(`\n=== Sync Logs for ${firstPartner.id} ===`);
    const logsSnap = await firstPartner.ref.collection('sync_logs')
      .orderBy('at', 'desc')
      .limit(3)
      .get();
    
    logsSnap.forEach(log => {
      const data = log.data();
      console.log(`  ${data.at?.toDate() || 'Unknown'}:`);
      console.log(`    Matched: ${data.matchedMeals}, Unmatched: ${data.unmatchedSquareItems}, Total Square: ${data.totalSquareItems}`);
      if (data.unmatchedSamples?.length) {
        console.log(`    Unmatched samples: ${data.unmatchedSamples.slice(0, 3).join(', ')}`);
      }
    });
  }
  
  // 3. Check meals with Square IDs
  const mealsWithSquareSnap = await db.collection('meals')
    .where('squareItemId', '!=', null)
    .limit(10)
    .get();
  
  console.log(`\n=== Meals with Square IDs (${mealsWithSquareSnap.size}) ===`);
  mealsWithSquareSnap.forEach(doc => {
    const data = doc.data();
    console.log(`  - ${data.name}`);
    console.log(`    Square Item: ${data.squareItemId}, Variation: ${data.squareVariationId}`);
    console.log(`    Stock: ${data.stockQuantity || 0}, Available: ${data.isAvailable}`);
  });
  
  // 4. Check recent applications
  const appsSnap = await db.collection('restaurant_applications')
    .orderBy('createdAt', 'desc')
    .limit(3)
    .get();
  
  console.log(`\n=== Recent Applications ===`);
  appsSnap.forEach(doc => {
    const data = doc.data();
    console.log(`  - ${doc.id}: ${data.restaurantName}`);
    console.log(`    Status: ${data.status}`);
    console.log(`    Created: ${data.createdAt?.toDate()}`);
  });
  
  console.log('\n=== Done ===\n');
  process.exit(0);
}

checkMenuSync().catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
