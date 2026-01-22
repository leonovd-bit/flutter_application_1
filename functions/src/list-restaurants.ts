/**
 * List all restaurants with their Square status
 */

import {onCall} from "firebase-functions/v2/https";
import {getFirestore} from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";

export const listAllRestaurants = onCall(
  {memory: "256MiB"},
  async (request: any): Promise<any> => {
    try {
      const db = getFirestore();
      const snapshot = await db.collection("restaurant_partners").get();

      const restaurants = snapshot.docs.map((doc) => {
        const data = doc.data();
        return {
          id: doc.id,
          name: data.name || data.restaurantName || data.displayName || "Unknown",
          squareConnected: !!(data.squareAccessToken && data.squareLocationId),
          squareLocationId: data.squareLocationId || null,
          squareMerchantId: data.squareMerchantId || null,
          hasAccessToken: !!data.squareAccessToken,
        };
      });

      logger.info("Listed all restaurants", {count: restaurants.length});

      return {
        total: restaurants.length,
        restaurants: restaurants.sort((a: any, b: any) =>
          (a.name || "").localeCompare(b.name || "")
        ),
      };
    } catch (error: any) {
      logger.error("listAllRestaurants error:", error);
      throw error;
    }
  }
);
