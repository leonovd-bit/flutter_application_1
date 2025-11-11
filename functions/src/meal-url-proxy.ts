import * as functions from "firebase-functions/v2";
import * as logger from "firebase-functions/logger";
import {FieldValue, getFirestore} from "firebase-admin/firestore";

// Get Firestore instance
const db = getFirestore();

// Function to update meal URLs to use the proxy
export const updateMealUrlsToProxy = functions.https.onRequest(async (req, res) => {
    try {
        // Get all meals with images
        const mealsRef = db.collectionGroup("items");
        const snapshot = await mealsRef.get();

        let updatedCount = 0;
        let batchCount = 0;

        const proxyUrl = "https://us-central1-freshpunk-48db1.cloudfunctions.net/proxyImage";
        let currentBatch = db.batch();

        for (const doc of snapshot.docs) {
            const data = doc.data();
            if (!data.imageUrl) continue;

            // Skip if already using proxy
            if (data.imageUrl.includes("/proxyImage?")) continue;

            // Convert direct storage URL to proxy URL
            let newUrl = data.imageUrl;
            if (data.imageUrl.includes("firebasestorage.googleapis.com")) {
                newUrl = `${proxyUrl}?url=${encodeURIComponent(data.imageUrl)}`;
            }

            if (newUrl !== data.imageUrl) {
                currentBatch.update(doc.ref, {
                    imageUrl: newUrl,
                    updatedAt: FieldValue.serverTimestamp(),
                });
                updatedCount++;
                batchCount++;
            }

            // Commit batch every 500 updates
            if (batchCount >= 500) {
                await currentBatch.commit();
                logger.info(`Committed batch of ${batchCount} updates`);
                batchCount = 0;
                currentBatch = db.batch();
            }
        }

        // Commit any remaining updates
        if (batchCount > 0) {
            await currentBatch.commit();
            logger.info(`Committed final batch of ${batchCount} updates`);
        }

        res.json({
            success: true,
            updatedCount,
            message: `Updated ${updatedCount} meal image URLs to use proxy`,
        });
    } catch (error: any) {
        logger.error("Error updating meal URLs:", error);
        res.status(500).json({
            success: false,
            error: error.message || "Unknown error",
        });
    }
});
