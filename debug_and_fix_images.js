// Run this in your browser console when your Flutter app is loaded
// This will check what image URLs are stored in Firestore and fix them

// First check what's stored:
console.log('Checking Firestore meal image URLs...');

// Get Firebase Firestore reference (assuming it's available in your app)
const db = firebase.firestore();

db.collection('meals').limit(5).get().then((snapshot) => {
  console.log('Sample meal image URLs:');
  snapshot.docs.forEach((doc) => {
    const data = doc.data();
    console.log(`${data.name}: ${data.imageUrl}`);
  });
}).catch((error) => {
  console.error('Error fetching meals:', error);
});

// If the URLs look wrong, run this to fix them:
function fixMealImageUrls() {
  console.log('Fixing meal image URLs...');
  
  db.collection('meals').get().then((snapshot) => {
    const batch = db.batch();
    let count = 0;
    
    snapshot.docs.forEach((doc) => {
      const data = doc.data();
      const currentUrl = data.imageUrl || '';
      
      // If it's already an asset path, skip
      if (currentUrl.startsWith('assets/')) {
        return;
      }
      
      // Try to build asset path from meal name or slug
      const slug = data.slug || data.name?.toLowerCase().replace(/[^a-z0-9]+/g, '-') || '';
      
      if (slug) {
        // Check common extensions
        const extensions = ['.jpg', '.jfif', '.png', '.jpeg'];
        const assetPath = `assets/images/meals/${slug}${extensions[0]}`; // Default to .jpg
        
        batch.update(doc.ref, { imageUrl: assetPath });
        count++;
        console.log(`Will update ${data.name}: ${assetPath}`);
      }
    });
    
    if (count > 0) {
      return batch.commit().then(() => {
        console.log(`✅ Updated ${count} meal image URLs to use assets!`);
        console.log('Refresh the page to see the changes.');
      });
    } else {
      console.log('No meals to update.');
    }
  }).catch((error) => {
    console.error('Error updating meals:', error);
  });
}

// Call this function to fix the URLs:
// fixMealImageUrls();
