#!/usr/bin/env node

/**
 * List all meals in the database
 */

const admin = require('firebase-admin');
const serviceAccount = require('./service-account.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'freshpunk-48db1',
});

const db = admin.firestore();

async function listMeals() {
  try {
    const mealsSnapshot = await db.collection('meals').get();
    
    if (mealsSnapshot.empty) {
      console.log('❌ No meals documents found in meals collection');
      process.exit(0);
    }
    
    console.log(`✅ Found ${mealsSnapshot.size} partner documents:\n`);
    
    for (const doc of mealsSnapshot.docs) {
      console.log(`Partner: ${doc.id}`);
      
      // Check if meals are in a subcollection
      const subMealsSnapshot = await doc.ref.collection('meals').get();
      
      if (!subMealsSnapshot.empty) {
        console.log(`  Meals subcollection: ${subMealsSnapshot.size} meals`);
        subMealsSnapshot.docs.forEach((mealDoc, index) => {
          const mealData = mealDoc.data();
          console.log(`    ${index + 1}. ${mealData.name || 'N/A'}`);
          console.log(`       ID: ${mealDoc.id}`);
          console.log(`       Type: ${mealData.mealType || 'N/A'}`);
          console.log(`       Price: $${mealData.price || 'N/A'}`);
        });
      } else {
        console.log(`  No meals subcollection found`);
      }
      console.log('');
    }
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Error listing meals:', error);
    process.exit(1);
  }
}

listMeals();
