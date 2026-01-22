/**
 * Get OAuth credentials for a restaurant from restaurant_partners collection
 */

import {onRequest} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import {getFirestore} from "firebase-admin/firestore";

export const getRestaurantOAuthCredentials = onRequest(
  {region: "us-central1"},
  async (req, res) => {
    res.set("Access-Control-Allow-Origin", "*");
    res.set("Access-Control-Allow-Methods", "POST, GET");
    res.set("Access-Control-Allow-Headers", "Content-Type");

    if (req.method === "OPTIONS") {
      res.status(200).send("");
      return;
    }

    try {
      const {restaurantId, restaurantName, merchantId} = req.query;

      const db = getFirestore();

      if (restaurantId) {
        // Look up by restaurant ID
        const doc = await db.collection("restaurant_partners").doc(restaurantId as string).get();
        if (doc.exists) {
          const data = doc.data()!;
          res.status(200).json({
            found: true,
            collection: "restaurant_partners",
            id: restaurantId,
            restaurantName: data.restaurantName,
            squareMerchantId: data.squareMerchantId,
            squareLocationId: data.squareLocationId,
            hasAccessToken: !!data.squareAccessToken,
            accessTokenPrefix: data.squareAccessToken ? data.squareAccessToken.substring(0, 20) : null,
            status: data.status,
          });
          return;
        }
      }

      // Try looking up by merchant ID
      if (merchantId) {
        const snapshot = await db.collection("restaurant_partners")
          .where("squareMerchantId", "==", merchantId as string)
          .limit(1)
          .get();

        if (!snapshot.empty) {
          const doc = snapshot.docs[0];
          const data = doc.data();
          res.status(200).json({
            found: true,
            collection: "restaurant_partners",
            id: doc.id,
            restaurantName: data.restaurantName,
            squareMerchantId: data.squareMerchantId,
            squareLocationId: data.squareLocationId,
            hasAccessToken: !!data.squareAccessToken,
            accessTokenPrefix: data.squareAccessToken ? data.squareAccessToken.substring(0, 20) : null,
            status: data.status,
          });
          return;
        }
      }

      // Try looking up by restaurant name
      if (restaurantName) {
        const snapshot = await db.collection("restaurant_partners")
          .where("restaurantName", "==", restaurantName as string)
          .orderBy("createdAt", "desc")
          .limit(1)
          .get();

        if (!snapshot.empty) {
          const doc = snapshot.docs[0];
          const data = doc.data();
          res.status(200).json({
            found: true,
            collection: "restaurant_partners",
            id: doc.id,
            restaurantName: data.restaurantName,
            squareMerchantId: data.squareMerchantId,
            squareLocationId: data.squareLocationId,
            hasAccessToken: !!data.squareAccessToken,
            accessTokenPrefix: data.squareAccessToken ? data.squareAccessToken.substring(0, 20) : null,
            status: data.status,
          });
          return;
        }
      }

      res.status(404).json({
        found: false,
        message: "No restaurant found matching criteria",
      });
    } catch (error: any) {
      logger.error("Failed to get OAuth credentials", {error: error.message});
      res.status(500).json({
        error: error.message,
      });
    }
  }
);
