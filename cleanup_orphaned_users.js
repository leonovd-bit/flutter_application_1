#!/usr/bin/env node
const admin = require('firebase-admin');
const serviceAccount = require('./functions/serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: "https://freshpunk-48db1.firebaseio.com"
});

const db = admin.firestore();

/**
 * Find and clean up orphaned user documents
 * (documents in /users collection with no corresponding Firebase Auth account)
 */
async function cleanupOrphanedUsers() {
  console.log('🧹 Starting orphaned user document cleanup...\n');

  const orphanedDocId = 'lnFgnZawxOTGcvaftW3ocJ5Mg9f2';

  try {
    // First, check if Firebase Auth account exists
    console.log(`🔍 Checking if ${orphanedDocId} has a Firebase Auth account...`);
    let hasAuthAccount = false;
    try {
      await admin.auth().getUser(orphanedDocId);
      hasAuthAccount = true;
      console.log('   ✅ Auth account exists - SKIPPING (not orphaned)');
      console.log('   ⚠️  This user should not be deleted!');
      process.exit(0);
    } catch (e) {
      console.log('   ❌ No auth account found - this is an orphaned document');
    }

    // Check what's in the document
    console.log('\n📄 Checking document contents...');
    const userDoc = await db.collection('users').doc(orphanedDocId).get();
    
    if (userDoc.exists) {
      const data = userDoc.data();
      console.log(`   Document has ${Object.keys(data).length} fields:`, Object.keys(data).join(', '));
    } else {
      console.log('   Document has no top-level fields (only subcollections)');
    }

    // Check subcollections
    console.log('\n📂 Checking subcollections...');
    const collections = await db.collection('users').doc(orphanedDocId).listCollections();
    console.log(`   Found ${collections.length} subcollection(s):`);
    
    const subcollectionData = {};
    for (const collection of collections) {
      const snapshot = await collection.get();
      console.log(`   - ${collection.id}: ${snapshot.docs.length} document(s)`);
      subcollectionData[collection.id] = snapshot.docs.length;
      
      // Show first document as example
      if (snapshot.docs.length > 0) {
        const firstDoc = snapshot.docs[0];
        console.log(`     Example doc: ${firstDoc.id}`);
      }
    }

    // Ask for confirmation
    console.log('\n⚠️  DELETION PLAN:');
    console.log(`   Delete: users/${orphanedDocId}`);
    if (userDoc.exists) {
      console.log(`   - Top-level document (${Object.keys(userDoc.data()).length} fields)`);
    }
    for (const [collectionName, count] of Object.entries(subcollectionData)) {
      console.log(`   - ${collectionName} subcollection (${count} documents)`);
    }

    console.log('\n🗑️  Starting deletion in 3 seconds...');
    console.log('   (Press Ctrl+C to cancel)');
    await new Promise(resolve => setTimeout(resolve, 3000));

    // Delete all subcollections first
    let totalDeleted = 0;
    for (const collection of collections) {
      console.log(`\n📦 Deleting ${collection.id} subcollection...`);
      const snapshot = await collection.get();
      
      const batch = db.batch();
      let batchCount = 0;
      
      for (const doc of snapshot.docs) {
        batch.delete(doc.ref);
        batchCount++;
        totalDeleted++;
        
        // Firestore batch limit is 500
        if (batchCount >= 500) {
          await batch.commit();
          console.log(`   Committed batch of ${batchCount} deletions`);
          batchCount = 0;
        }
      }
      
      if (batchCount > 0) {
        await batch.commit();
        console.log(`   Committed final batch of ${batchCount} deletions`);
      }
      
      console.log(`   ✅ Deleted ${snapshot.docs.length} documents from ${collection.id}`);
    }

    // Delete the main document
    if (userDoc.exists) {
      console.log('\n📄 Deleting main user document...');
      await db.collection('users').doc(orphanedDocId).delete();
      console.log('   ✅ Main document deleted');
    }

    console.log('\n✅ CLEANUP COMPLETE');
    console.log(`   Total documents deleted: ${totalDeleted + (userDoc.exists ? 1 : 0)}`);
    console.log(`   Orphaned user ${orphanedDocId} has been removed`);

  } catch (error) {
    console.error('\n❌ Error during cleanup:', error);
    process.exit(1);
  }

  process.exit(0);
}

// Run cleanup
cleanupOrphanedUsers();
