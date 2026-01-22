const admin = require('firebase-admin');
const serviceAccount = require('./firebase_options.dart');

// Initialize with service account from environment
admin.initializeApp({
  projectId: 'freshpunk-48db1'
});

const db = admin.firestore();

async function createTestMeal() {
  try {
    console.log('🍽️  Creating test meal for Victus...');
    
    const mealRef = await db.collection('meals').add({
      restaurantId: 'fd1JQwNpIesg7HOEMeCv',
      name: 'Grilled Salmon with Vegetables',
      description: 'Fresh Atlantic salmon with seasonal vegetables and quinoa',
      price: 24.99,
      calories: 450,
      protein: 35,
      prepTime: 15,
      squareItemId: 'VICTUS_SALMON_001',
      squareVariationId: 'VICTUS_SALMON_001_VAR',
      imageUrl: 'https://via.placeholder.com/300x300?text=Salmon',
      active: true,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    });
    
    console.log('✅ Test meal created!');
    console.log('');
    console.log('📋 Meal Details:');
    console.log('  ID:', mealRef.id);
    console.log('  Name: Grilled Salmon with Vegetables');
    console.log('  Price: $24.99');
    console.log('  Square Item ID: VICTUS_SALMON_001');
    console.log('  Square Variation ID: VICTUS_SALMON_001_VAR');
    console.log('');
    console.log('🔗 Use this mealId for test order:');
    console.log('  ', mealRef.id);
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

createTestMeal();
