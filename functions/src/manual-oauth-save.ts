/**
 * Manual OAuth Save - Emergency fix to save known OAuth credentials
 * When OAuth callback save fails but we have the credentials from the success page
 */

import {onRequest, HttpsError} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import {getFirestore, FieldValue} from "firebase-admin/firestore";

export const manualOAuthSave = onRequest(
  {region: "us-central1"},
  async (req, res) => {
    // Enable CORS
    res.set("Access-Control-Allow-Origin", "*");
    res.set("Access-Control-Allow-Methods", "POST");
    res.set("Access-Control-Allow-Headers", "Content-Type");

    if (req.method === "OPTIONS") {
      res.status(200).send("");
      return;
    }

    try {
      const {
        restaurantId,
        restaurantName,
        squareMerchantId,
        squareAccessToken,
        squareLocationId,
      } = req.body;

      if (!restaurantId || !squareMerchantId || !squareAccessToken) {
        throw new HttpsError(
          "invalid-argument",
          "Missing required fields: restaurantId, squareMerchantId, squareAccessToken"
        );
      }

      const db = getFirestore();

      // Update the restaurants collection (legacy/old)
      await db.collection("restaurants").doc(restaurantId).update({
        squareMerchantId,
        squareAccessToken,
        squareLocationId: squareLocationId || null,
        status: "active",
        onboardingCompleted: true,
        updatedAt: FieldValue.serverTimestamp(),
      });

      logger.info("Manual OAuth save successful", {
        restaurantId,
        restaurantName,
        merchantId: squareMerchantId,
        hasToken: !!squareAccessToken,
        hasLocation: !!squareLocationId,
      });

      res.status(200).json({
        success: true,
        message: "OAuth credentials saved successfully",
        restaurantId,
        restaurantName,
        squareMerchantId,
        squareLocationId: squareLocationId || "No location set",
      });
    } catch (error: any) {
      logger.error("Manual OAuth save failed", {error: error.message});
      res.status(500).json({
        success: false,
        error: error.message,
      });
    }
  }
);
