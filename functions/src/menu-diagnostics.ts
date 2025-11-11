import {onRequest} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import {getFirestore} from "firebase-admin/firestore";

/**
 * Quick diagnostic endpoint to check menu sync status
 */
export const checkMenuSyncStatus = onRequest(
  {
    region: "us-east4",
  },
  async (req, res) => {
    try {
      const db = getFirestore();
      const results: any = {};

      // 1. Check restaurant_partners
      const partnersSnap = await db.collection("restaurant_partners").limit(5).get();
      results.partners = partnersSnap.docs.map((doc) => {
        const data = doc.data();
        return {
          id: doc.id,
          restaurantName: data.restaurantName,
          status: data.status,
          lastMenuSync: data.lastMenuSync,
          menuItemCount: data.menuItemCount || 0,
          squareMerchantId: data.squareMerchantId,
        };
      });

      // 2. Check sync_logs for ALL partners
      results.syncLogs = [];
      for (const partnerDoc of partnersSnap.docs) {
        const logsSnap = await partnerDoc.ref
          .collection("sync_logs")
          .orderBy("at", "desc")
          .limit(2)
          .get();

        logsSnap.docs.forEach((doc) => {
          results.syncLogs.push({
            restaurantId: partnerDoc.id,
            restaurantName: partnerDoc.data().restaurantName,
            ...doc.data(),
          });
        });
      }

      // 3. Check meals with Square IDs
      const mealsWithSquareSnap = await db
        .collection("meals")
        .where("squareItemId", "!=", null)
        .limit(10)
        .get();

      results.mealsWithSquare = mealsWithSquareSnap.docs.map((doc) => {
        const data = doc.data();
        return {
          id: doc.id,
          name: data.name,
          squareItemId: data.squareItemId,
          squareVariationId: data.squareVariationId,
          stockQuantity: data.stockQuantity,
          isAvailable: data.isAvailable,
        };
      });

      // 4. Check recent applications
      const appsSnap = await db
        .collection("restaurant_applications")
        .orderBy("createdAt", "desc")
        .limit(3)
        .get();

      results.recentApplications = appsSnap.docs.map((doc) => {
        const data = doc.data();
        return {
          id: doc.id,
          restaurantName: data.restaurantName,
          status: data.status,
          createdAt: data.createdAt,
        };
      });

      logger.info("Menu sync status checked", results);

      res.status(200).json({
        success: true,
        data: results,
        summary: {
          partnersCount: results.partners.length,
          mealsWithSquareCount: results.mealsWithSquare.length,
          recentAppsCount: results.recentApplications.length,
        },
      });
    } catch (error: any) {
      logger.error("Failed to check menu sync status", error);
      res.status(500).json({success: false, message: error.message});
    }
  }
);
