/**
 * Manually create/update a restaurant partner with OAuth credentials
 */

import {onRequest} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import {getFirestore} from "firebase-admin/firestore";

export const manualCreateRestaurant = onRequest(
  {region: "us-central1"},
  async (req, res) => {
    res.set("Access-Control-Allow-Origin", "*");

    if (req.method === "OPTIONS") {
      res.status(200).send("");
      return;
    }

    try {
      const {restaurantId, restaurantName, squareMerchantId, squareAccessToken, squareLocationId} = req.body;

      if (!restaurantId || !squareMerchantId || !squareAccessToken) {
        res.status(400).json({error: "Missing required fields"});
        return;
      }

      const db = getFirestore();

      const docData = {
        restaurantName,
        squareMerchantId,
        squareAccessToken,
        squareLocationId: squareLocationId || null,
        status: "active",
        onboardingCompleted: true,
        menuSyncEnabled: true,
        orderForwardingEnabled: true,
        createdAt: new Date(),
        updatedAt: new Date(),
      };

      await db.collection("restaurant_partners").doc(restaurantId).set(docData);

      logger.info("Manually created restaurant partner", {restaurantId, squareMerchantId});

      res.json({
        success: true,
        message: "Restaurant partner created successfully",
        restaurantId,
        restaurantName,
        squareMerchantId,
      });
    } catch (error: any) {
      logger.error("Failed to create restaurant", {error: error.message});
      res.status(500).json({error: error.message});
    }
  }
);
