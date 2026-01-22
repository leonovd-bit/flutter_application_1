/**
 * Debug: Dump all restaurants to logs so we can see them
 */

import {onRequest} from "firebase-functions/v2/https";
import {getFirestore} from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";

export const dumpAllRestaurants = onRequest(
  {region: "us-central1"},
  async (request, response): Promise<void> => {
    response.set("Access-Control-Allow-Origin", "*");

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
          email: data.contactEmail || data.email || null,
        };
      });

      // Log each restaurant
      restaurants.forEach((r, idx) => {
        logger.info(`Restaurant ${idx + 1}/${restaurants.length}`, r);
      });

      logger.info("ALL_RESTAURANTS_SUMMARY", {
        total: restaurants.length,
        connected: restaurants.filter((r) => r.squareConnected).length,
        restaurants: restaurants,
      });

      response.json({
        total: restaurants.length,
        connected: restaurants.filter((r) => r.squareConnected).length,
        restaurants,
      });
    } catch (error: any) {
      logger.error("dumpAllRestaurants error:", error);
      response.status(500).json({error: error.message});
    }
  }
);
