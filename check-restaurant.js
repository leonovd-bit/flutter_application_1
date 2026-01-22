const admin = require('firebase-admin');
admin.initializeApp();
const db = admin.firestore();

async function checkRestaurant() {
  try {
    const restaurantRef = db.collection('restaurant_partners').doc('fd1JQwNpIesg7HOEMeCv');
    const doc = await restaurantRef.get();
    
    if (!doc.exists) {
      console.log('❌ Restaurant not found');
      process.exit(1);
    }
    
    const data = doc.data();
    console.log('✅ Restaurant found!');
    console.log('');
    console.log('Square Credentials:');
    console.log('  squareAccessToken:', data.squareAccessToken ? '✅ SET' : '❌ MISSING');
    console.log('  squareLocationId:', data.squareLocationId || '❌ MISSING');
    console.log('  squareMerchantId:', data.squareMerchantId || '❌ MISSING');
    console.log('  squareRefreshToken:', data.squareRefreshToken ? '✅ SET' : '❌ MISSING');
    console.log('');
    console.log('All fields:');
    console.log(JSON.stringify(data, null, 2));
  } catch (error) {
    console.error('Error:', error.message);
  }
  process.exit(0);
}

checkRestaurant();
