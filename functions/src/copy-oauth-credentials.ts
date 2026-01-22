/**
 * Copy OAuth credentials from restaurant_partners to restaurants collection
 */

import {onRequest} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import {getFirestore} from "firebase-admin/firestore";

export const copyOAuthCredentials = onRequest(
  {region: "us-central1"},
  async (req, res) => {
    res.set("Access-Control-Allow-Origin", "*");
    res.set("Access-Control-Allow-Methods", "POST");
    res.set("Access-Control-Allow-Headers", "Content-Type");

    if (req.method === "OPTIONS") {
      res.status(200).send("");
      return;
    }

    try {
      const {fromId, toId, merchantId} = req.body;

      const db = getFirestore();

      // Find the source restaurant (either by ID or merchant ID)
      let sourceData: any = null;
      let sourceId: string | null = null;

      if (fromId) {
        // Try to get from restaurant_partners
        const doc = await db.collection("restaurant_partners").doc(fromId).get();
        if (doc.exists) {
          sourceData = doc.data();
          sourceId = fromId;
        }
      } else if (merchantId) {
        // Find by merchant ID
        const snapshot = await db.collection("restaurant_partners")
          .where("squareMerchantId", "==", merchantId as string)
          .limit(1)
          .get();
        if (!snapshot.empty) {
          sourceData = snapshot.docs[0].data();
          sourceId = snapshot.docs[0].id;
        }
      }

      if (!sourceData || !sourceData.squareAccessToken) {
        res.status(404).json({
          success: false,
          message: "Source restaurant not found or has no access token",
        });
        return;
      }

      // Update the target restaurant
      if (!toId) {
        res.status(400).json({
          success: false,
          message: "Target restaurant ID (toId) required",
        });
        return;
      }

      await db.collection("restaurants").doc(toId).update({
        squareMerchantId: sourceData.squareMerchantId,
        squareAccessToken: sourceData.squareAccessToken,
        squareTokenExpiresAt: sourceData.squareTokenExpiresAt || null,
        squareLocationId: sourceData.squareLocationId || null,
        squareBusinessName: sourceData.squareBusinessName,
        status: "active",
        onboardingCompleted: true,
        updatedAt: new Date(),
      });

      logger.info("Copied OAuth credentials", {
        from: sourceId,
        to: toId,
        merchantId: sourceData.squareMerchantId,
      });

      res.status(200).json({
        success: true,
        message: "OAuth credentials copied successfully",
        from: sourceId,
        to: toId,
        merchantId: sourceData.squareMerchantId,
        hasAccessToken: !!sourceData.squareAccessToken,
      });
    } catch (error: any) {
      logger.error("Failed to copy OAuth credentials", {error: error.message});
      res.status(500).json({
        success: false,
        error: error.message,
      });
    }
  }
);
