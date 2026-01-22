/**
 * Direct database diagnostic - check if restaurant and OAuth credentials exist
 */

import {onRequest} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import {getFirestore} from "firebase-admin/firestore";

export const diagnoseDatabase = onRequest(
  {region: "us-central1", timeoutSeconds: 30},
  async (req, res) => {
    res.set("Access-Control-Allow-Origin", "*");

    try {
      const db = getFirestore();

      // Try to directly read the new restaurant record
      const newRestaurant = await db.collection("restaurant_partners").doc("d1SlUZdWJ2RjkBsJ9bV").get();

      // Try to read the old restaurant record
      const oldRestaurant = await db.collection("restaurants").doc("fd1JQwNpIesg7HOEMeCv").get();

      const results = {
        timestamp: new Date().toISOString(),
        new_restaurant: {
          id: "d1SlUZdWJ2RjkBsJ9bV",
          exists: newRestaurant.exists,
          data: newRestaurant.exists ? {
            restaurantName: newRestaurant.data()!.restaurantName,
            squareMerchantId: newRestaurant.data()!.squareMerchantId,
            hasAccessToken: !!newRestaurant.data()!.squareAccessToken,
            status: newRestaurant.data()!.status,
          } : null,
        },
        old_restaurant: {
          id: "fd1JQwNpIesg7HOEMeCv",
          exists: oldRestaurant.exists,
          data: oldRestaurant.exists ? {
            restaurantName: oldRestaurant.data()!.restaurantName,
            squareMerchantId: oldRestaurant.data()!.squareMerchantId,
            hasAccessToken: !!oldRestaurant.data()!.squareAccessToken,
            status: oldRestaurant.data()!.status,
          } : null,
        },
      };

      res.json(results);
    } catch (error: any) {
      logger.error("Diagnosis error", {error: error.message});
      res.status(500).json({error: error.message, timestamp: new Date().toISOString()});
    }
  }
);
