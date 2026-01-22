/**
 * Debug: Check what's actually in restaurant_partners after OAuth
 */

import {onRequest} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import {getFirestore} from "firebase-admin/firestore";

export const debugRestaurantPartners = onRequest(
  {region: "us-central1"},
  async (req, res) => {
    res.set("Access-Control-Allow-Origin", "*");

    try {
      const db = getFirestore();

      // Get all restaurant partners with Victus name
      const snapshot = await db.collection("restaurant_partners")
        .where("restaurantName", "==", "Victus")
        .get();

      const restaurants = snapshot.docs.map((doc) => ({
        id: doc.id,
        ...doc.data(),
        squareAccessToken: doc.data()!.squareAccessToken ? "PRESENT (***)" : "MISSING",
      }));

      // Also get all with merchant ID
      const snapshot2 = await db.collection("restaurant_partners")
        .where("squareMerchantId", "==", "ML1DYZC2EQC7A")
        .get();

      const byMerchant = snapshot2.docs.map((doc) => ({
        id: doc.id,
        ...doc.data(),
        squareAccessToken: doc.data()!.squareAccessToken ? "PRESENT (***)" : "MISSING",
      }));

      res.json({
        found_by_name: {
          count: restaurants.length,
          data: restaurants,
        },
        found_by_merchant: {
          count: byMerchant.length,
          data: byMerchant,
        },
      });
    } catch (error: any) {
      logger.error("Debug error", {error: error.message});
      res.status(500).json({error: error.message});
    }
  }
);
