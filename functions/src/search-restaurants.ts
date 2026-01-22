/**
 * Search for restaurants by name - check Square setup
 */

import {onRequest} from "firebase-functions/v2/https";
import {getFirestore} from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";

export const searchRestaurants = onRequest(
  {region: "us-central1"},
  async (request, response): Promise<void> => {
    response.set("Access-Control-Allow-Origin", "*");

    try {
      const db = getFirestore();
      const searchTerm = (String(request.query.search || "")).toLowerCase();

      if (!searchTerm) {
        response.status(400).json({error: "search parameter required"});
        return;
      }

      // Get all restaurants from collection
      const snapshot = await db.collection("restaurant_partners").get();
      const restaurants = snapshot.docs
        .map((doc) => ({
          id: doc.id,
          ...doc.data(),
        }))
        .filter((r: any) => {
          const name = (r.name || r.restaurantName || "").toLowerCase();
          const displayName = (r.displayName || "").toLowerCase();
          return name.includes(searchTerm) || displayName.includes(searchTerm);
        });

      logger.info("Restaurant search", {
        searchTerm,
        found: restaurants.length,
      });

      const results = restaurants.map((r: any) => ({
        id: r.id,
        name: r.name || r.restaurantName || r.displayName,
        squareConnected: !!(r.squareAccessToken && r.squareLocationId),
        squareLocationId: r.squareLocationId || null,
        squareMerchantId: r.squareMerchantId || null,
        hasAccessToken: !!r.squareAccessToken,
        orderForwardingEnabled: r.orderForwardingEnabled !== false,
        createdAt: r.createdAt,
        email: r.contactEmail || r.email,
      }));

      response.json({
        searchTerm,
        found: results.length,
        results,
      });
    } catch (error: any) {
      logger.error("searchRestaurants error:", error);
      response.status(500).json({
        error: error.message,
      });
    }
  }
);
