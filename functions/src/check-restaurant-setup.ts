/**
 * Quick diagnostic - check if restaurant has Square credentials
 */

import {onRequest} from "firebase-functions/v2/https";
import {getFirestore} from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";

export const checkRestaurantSquareSetup = onRequest(
  {region: "us-central1"},
  async (request, response): Promise<void> => {
    response.set("Access-Control-Allow-Origin", "*");

    try {
      const db = getFirestore();
      const restaurantId = "fd1JQwNpIesg7HOEMeCv"; // Victus

      const restaurantDoc = await db.collection("restaurant_partners").doc(restaurantId).get();

      if (!restaurantDoc.exists) {
        response.status(404).json({
          error: "Restaurant not found",
          restaurantId,
        });
        return;
      }

      const data = restaurantDoc.data();

      logger.info("Restaurant document:", {
        restaurantId,
        hasSquareAccessToken: !!data?.squareAccessToken,
        hasSquareLocationId: !!data?.squareLocationId,
        hasSquareMerchantId: !!data?.squareMerchantId,
        hasSquareApplicationId: !!data?.squareApplicationId,
        orderForwardingEnabled: data?.orderForwardingEnabled,
        keys: Object.keys(data || {}),
      });

      response.json({
        restaurantId,
        found: true,
        credentials: {
          squareAccessToken: data?.squareAccessToken ? "✅ SET" : "❌ MISSING",
          squareLocationId: data?.squareLocationId ? `✅ ${data.squareLocationId}` : "❌ MISSING",
          squareMerchantId: data?.squareMerchantId ? `✅ ${data.squareMerchantId}` : "❌ MISSING",
          squareApplicationId: data?.squareApplicationId ? "✅ SET" : "❌ MISSING",
        },
        orderForwardingEnabled: data?.orderForwardingEnabled !== false ? "✅ ENABLED" : "❌ DISABLED",
        allFields: Object.keys(data || {}),
        status: (data?.squareAccessToken && data?.squareLocationId) ? "✅ Ready to forward" : "❌ Missing credentials",
      });
    } catch (error: any) {
      logger.error("checkRestaurantSquareSetup error:", error);
      response.status(500).json({
        error: error.message,
      });
    }
  }
);
