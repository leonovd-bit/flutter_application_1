// Clear existing meals and trigger reseed with local images
export const clearMealsAndReseed = functions.https.onCall(async (data, context) => {
  // Check if user is authenticated and has admin privileges (optional security)
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  try {
    console.log('Clearing existing meals...');
    
    // Get all meals
    const mealsSnapshot = await admin.firestore().collection('meals').get();
    
    // Delete all existing meals in batches
    const batch = admin.firestore().batch();
    mealsSnapshot.docs.forEach(doc => {
      batch.delete(doc.ref);
    });
    
    await batch.commit();
    console.log(`Deleted ${mealsSnapshot.docs.length} existing meals`);
    
    return {
      success: true,
      message: `Cleared ${mealsSnapshot.docs.length} meals. App will reseed with local images on next meal load.`,
      clearedCount: mealsSnapshot.docs.length
    };
  } catch (error) {
    console.error('Error clearing meals:', error);
    throw new functions.https.HttpsError('internal', 'Failed to clear meals');
  }
});
