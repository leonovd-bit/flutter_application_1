/**
 * Refresh OAuth Token - Direct token refresh without browser flow
 * Allows refreshing expired OAuth tokens programmatically
 */

import {onRequest} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import {getFirestore, FieldValue} from "firebase-admin/firestore";
import {defineSecret} from "firebase-functions/params";

const SQUARE_APPLICATION_ID = defineSecret("SQUARE_APPLICATION_ID");
const SQUARE_APPLICATION_SECRET = defineSecret("SQUARE_APPLICATION_SECRET");
const SQUARE_ENV = defineSecret("SQUARE_ENV");

function getSquareConfig() {
  const env = (SQUARE_ENV.value() || "production").toLowerCase();
  const baseUrl = env === "sandbox" ?
    "https://connect.squareupsandbox.com" :
    "https://connect.squareup.com";
  return {baseUrl};
}

export const refreshOAuthToken = onRequest(
  {
    region: "us-central1",
    secrets: [SQUARE_APPLICATION_ID, SQUARE_APPLICATION_SECRET, SQUARE_ENV],
    timeoutSeconds: 60,
  },
  async (req, res) => {
    res.set("Access-Control-Allow-Origin", "*");
    res.set("Access-Control-Allow-Methods", "POST");
    res.set("Access-Control-Allow-Headers", "Content-Type");

    if (req.method === "OPTIONS") {
      res.status(200).send("");
      return;
    }

    try {
      const {restaurantId, authorizationCode} = req.body;

      if (!restaurantId || !authorizationCode) {
        res.status(400).json({
          success: false,
          error: "Missing restaurantId or authorizationCode",
        });
        return;
      }

      const {baseUrl} = getSquareConfig();
      const applicationId = process.env.SQUARE_APPLICATION_ID;
      const applicationSecret = process.env.SQUARE_APPLICATION_SECRET;

      if (!applicationId || !applicationSecret) {
        logger.error("Missing Square credentials");
        res.status(500).json({
          success: false,
          error: "Server configuration error",
        });
        return;
      }

      const redirectUri = "https://us-east4-freshpunk-48db1.cloudfunctions.net/completeSquareOAuthHttp";

      // Exchange authorization code for access token
      const tokenResponse = await fetch(`${baseUrl}/oauth2/token`, {
        method: "POST",
        headers: {
          "Square-Version": "2023-10-18",
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          client_id: applicationId,
          client_secret: applicationSecret,
          code: authorizationCode,
          grant_type: "authorization_code",
          redirect_uri: redirectUri,
        }),
      });

      if (!tokenResponse.ok) {
        const errorText = await tokenResponse.text();
        logger.error("Token exchange failed", {error: errorText});
        res.status(400).json({
          success: false,
          error: `Token exchange failed: ${errorText}`,
        });
        return;
      }

      const tokenData = await tokenResponse.json() as any;
      const {access_token, merchant_id, expires_at} = tokenData;

      if (!access_token || !merchant_id) {
        logger.error("Missing token or merchant_id in response");
        res.status(400).json({
          success: false,
          error: "Invalid token response from Square",
        });
        return;
      }

      // Get merchant information for location
      const merchantResponse = await fetch(`${baseUrl}/v2/merchants/${merchant_id}`, {
        headers: {
          "Square-Version": "2023-10-18",
          "Authorization": `Bearer ${access_token}`,
        },
      });

      let squareLocationId: string | null = null;
      if (merchantResponse.ok) {
        try {
          const locationsResp = await fetch(`${baseUrl}/v2/locations`, {
            headers: {
              "Square-Version": "2023-10-18",
              "Authorization": `Bearer ${access_token}`,
            },
          });
          if (locationsResp.ok) {
            const locData = await locationsResp.json() as any;
            const active = (locData.locations || []).find((l: any) => l.status === "ACTIVE") ||
              (locData.locations || [])[0];
            squareLocationId = active?.id || null;
          }
        } catch (_) {/* ignore location fetch error */}
      }

      // Update restaurant_partners with new token
      const db = getFirestore();
      await db.collection("restaurant_partners").doc(restaurantId).update({
        squareAccessToken: access_token,
        squareTokenExpiresAt: expires_at ? new Date(expires_at) : null,
        squareLocationId: squareLocationId,
        squareMerchantId: merchant_id,
        status: "active",
        onboardingCompleted: true,
        orderForwardingEnabled: true,
        updatedAt: FieldValue.serverTimestamp(),
      });

      logger.info("OAuth token refreshed successfully", {
        restaurantId,
        merchantId: merchant_id,
        expiresAt: expires_at,
      });

      res.status(200).json({
        success: true,
        message: "OAuth token refreshed successfully",
        restaurantId,
        merchantId: merchant_id,
        expiresAt: expires_at,
        locationId: squareLocationId,
      });
    } catch (error: any) {
      logger.error("Token refresh failed", {error: error.message});
      res.status(500).json({
        success: false,
        error: error.message,
      });
    }
  }
);
