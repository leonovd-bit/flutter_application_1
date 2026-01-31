/**
 * Square Integration Functions
 * Handles restaurant partner onboarding, menu sync, and order forwarding
 */

import {onCall, onRequest, HttpsError} from "firebase-functions/v2/https";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {onDocumentCreated, onDocumentUpdated} from "firebase-functions/v2/firestore";
import * as logger from "firebase-functions/logger";
import {getFirestore, FieldValue, Timestamp} from "firebase-admin/firestore";
import {defineSecret} from "firebase-functions/params";
import * as crypto from "crypto";

// Firebase is initialized in index.ts - no need to initialize here

// Square API configuration - use Firebase Secret Manager
const SQUARE_APPLICATION_ID = defineSecret("SQUARE_APPLICATION_ID");
const SQUARE_APPLICATION_SECRET = defineSecret("SQUARE_APPLICATION_SECRET");
const SQUARE_ENV = defineSecret("SQUARE_ENV");

const SQUARE_OAUTH_SCOPES = [
  "MERCHANT_PROFILE_READ",
  "PAYMENTS_WRITE",
  "ITEMS_READ",
  "ORDERS_READ",
  "ORDERS_WRITE",
  "CUSTOMERS_READ",
  "CUSTOMERS_WRITE",
];

export function getSquareConfig() {
  const rawEnv = SQUARE_ENV.value();
  const env = (rawEnv ? rawEnv.trim() : "sandbox").toLowerCase();
  const appId = SQUARE_APPLICATION_ID.value();
  const appSecret = SQUARE_APPLICATION_SECRET.value();
  return {
    applicationId: appId ? appId.trim() : "",
    applicationSecret: appSecret ? appSecret.trim() : "",
    env,
    baseUrl: env === "production" ?
      "https://connect.squareup.com" :
      "https://connect.squareupsandbox.com",
  };
}

// Firebase services will be accessed inside functions

// ============================================================================
// RESTAURANT ONBOARDING & OAUTH
// ============================================================================

/**
 * Initiate Square OAuth flow for restaurant partner onboarding (HTTP version)
 */
export const initiateSquareOAuthHttp = onRequest(
  {
    // Include all referenced secrets to avoid runtime warnings, even if not directly used
    secrets: [SQUARE_APPLICATION_ID, SQUARE_ENV, SQUARE_APPLICATION_SECRET],
  },
  async (req, res) => {
  try {
    const db = getFirestore();
  const {applicationId, baseUrl, env} = getSquareConfig();

    // Set CORS headers for restaurant portal
    res.set("Access-Control-Allow-Origin", "*");
    res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
    res.set("Access-Control-Allow-Headers", "Content-Type");

    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }

    if (req.method !== "POST") {
      res.status(405).json({success: false, message: "Method not allowed"});
      return;
    }

    // Generate a temporary user ID for restaurant onboarding
    const userId = `temp_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;

    const {restaurantName, contactEmail, contactPhone} = req.body;

    if (!restaurantName || !contactEmail) {
      res.status(400).json({success: false, message: "Restaurant name and contact email required"});
      return;
    }

    // Create pending restaurant application
    const applicationRef = await db.collection("restaurant_applications").add({
      userId,
      restaurantName,
      contactEmail,
      contactPhone: contactPhone || null,
      status: "pending_oauth",
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    // Validate config first (avoid generating broken URLs)
    const cleanAppId = (applicationId || "").replace(/[\r\n]+/g, "").trim();
    if (!cleanAppId) {
      logger.error("Missing SQUARE_APPLICATION_ID secret; cannot start OAuth");
      res.status(500).json({
        success: false,
        message: "Server is missing Square application ID. Configure SQUARE_APPLICATION_ID secret.",
      });
      return;
    }

    // Generate Square OAuth URL (properly encoded)
    const state = applicationRef.id; // Use application ID as state parameter

    const scopes = SQUARE_OAUTH_SCOPES;

    // Build URL with explicit encoding
    const scopeStr = scopes.join(" ");
    // Use stable functions.net domain for redirect in all environments.
    // Avoid hashed Cloud Run service URL which can change on redeploy.
    const redirectUri = "https://us-east4-freshpunk-48db1.cloudfunctions.net/completeSquareOAuthHttp";

    const oauthUrl = `${baseUrl}/oauth2/authorize` +
      `?client_id=${encodeURIComponent(cleanAppId)}` +
      "&response_type=code" +
      `&scope=${encodeURIComponent(scopeStr)}` +
      `&redirect_uri=${encodeURIComponent(redirectUri)}` +
      `&state=${encodeURIComponent(state)}`;

    logger.info(`Square OAuth initiated for restaurant: ${restaurantName}`, {
      applicationId: applicationRef.id,
      userId,
      baseUrl,
      env,
      oauthUrl,
      clientIdPrefix: cleanAppId.substring(0, 12),
      clientIdLength: cleanAppId.length,
      redirectUri,
      scopes,
    });

    res.status(200).json({
      success: true,
      oauthUrl,
      applicationId: applicationRef.id,
      message: "Complete OAuth flow to connect your Square account",
      debug: {
        baseUrl,
        env,
        redirectUri,
        scopes,
        clientIdPrefix: cleanAppId.substring(0, 12),
        clientIdLength: cleanAppId.length,
      },
    });
  } catch (error: any) {
    logger.error("Square OAuth initiation failed", error);
    res.status(500).json({success: false, message: `OAuth setup failed: ${error.message}`});
  }
});

/**
 * Lightweight hosted test page to initiate the Square OAuth flow.
 * This avoids needing Firebase Hosting to serve a static HTML file.
 */
export const squareOAuthTestPage = onRequest(
  {
    region: "us-east4",
  },
  async (req, res) => {
    try {
      // Prevent any aggressive caching or SW interference
      res.set("Cache-Control", "no-store, no-cache, must-revalidate, proxy-revalidate, max-age=0");

      // Minimal plain-text probe for debugging
      if (String(req.query.plain || "") === "1") {
        logger.info("squareOAuthTestPage plain probe");
        res.type("text/plain").send(`Square Test OK @ ${new Date().toISOString()}`);
        return;
      }

      logger.info("Serving Square OAuth Test Page");
      res.set("Content-Type", "text/html; charset=utf-8");
      res.send(`<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Victus Square Connection</title>
    <style>
      body { font-family: system-ui, -apple-system, Segoe UI, Roboto, Arial; max-width: 720px; margin: 40px auto; padding: 0 16px; }
      h1 { font-size: 24px; }
      label { display: block; margin: 12px 0 6px; }
      input { width: 100%; padding: 10px 12px; border: 1px solid #ccc; border-radius: 6px; }
      button { margin-top: 16px; padding: 10px 16px; border: 0; background: #2563eb; color: white; border-radius: 6px; cursor: pointer; }
      .status { margin-top: 16px; font-size: 14px; color: #374151; }
      .card { border: 1px solid #e5e7eb; border-radius: 8px; padding: 16px; }
    </style>
  </head>
  <body>
  <h1>🟦 Victus Square Connection</h1>
    <p>Connect your Square account to Victus to start receiving orders.</p>
    <div class="card">
      <label for="name">Restaurant name</label>
      <input id="name" placeholder="Your restaurant name" />
      <label for="email">Contact email</label>
      <input id="email" placeholder="owner@restaurant.com" />
      <label for="phone">Contact phone (optional)</label>
      <input id="phone" placeholder="+1 (555) 123-4567" />
      <button id="connect">Connect with Square →</button>
      <div class="status" id="status"></div>
    </div>

    <script>
      console.log('Square OAuth Test Page loaded at', new Date().toISOString());
      // initiateSquareOAuthHttp is deployed to us-central1, while this test page is in us-east4.
      // Use the stable .cloudfunctions.net URL for cross-region invocation.
      // Allow override via ?initHost=<url> for testing alternate deployments.
      const OAUTH_ENDPOINT = (() => {
        const paramOverride = new URLSearchParams(window.location.search).get('initHost');
        if (paramOverride) return paramOverride;
        
        // Use the known stable URL for initiateSquareOAuthHttp (us-central1)
        return 'https://us-central1-freshpunk-48db1.cloudfunctions.net/initiateSquareOAuthHttp';
      })();

      document.getElementById('connect').addEventListener('click', async () => {
        const status = document.getElementById('status');
        const restaurantName = document.getElementById('name').value.trim();
        const contactEmail = document.getElementById('email').value.trim();
        const contactPhone = document.getElementById('phone').value.trim();

        if (!restaurantName || !contactEmail) {
          status.textContent = 'Please enter restaurant name and contact email.';
          return;
        }

        status.textContent = 'Creating application…';
        try {
          const resp = await fetch(OAUTH_ENDPOINT, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ restaurantName, contactEmail, contactPhone })
          });
          const data = await resp.json();
          if (data.success && data.oauthUrl) {
            // Redirect immediately to Square
            status.textContent = 'Redirecting to Square...';
            window.location.href = data.oauthUrl;
          } else {
            status.textContent = 'Failed: ' + (data.message || 'Unknown error');
          }
        } catch (e) {
          status.textContent = 'Error: ' + (e && e.message ? e.message : e);
        }
      });
    </script>
  </body>
</html>`);
    } catch (err: any) {
      logger.error("Failed to serve Square OAuth test page", {error: err.message});
      res.status(500).send("Internal Server Error");
    }
  }
);

/**
 * Initiate Square OAuth flow for reauthorizing an existing restaurant.
 * Updates the existing restaurant record instead of creating a new one.
 */
export const initiateSquareReauthHttp = onRequest(
  {
    region: "us-central1",
    secrets: [SQUARE_APPLICATION_ID, SQUARE_ENV, SQUARE_APPLICATION_SECRET],
  },
  async (req, res) => {
    try {
      const db = getFirestore();
      const {applicationId, baseUrl, env} = getSquareConfig();

      res.set("Access-Control-Allow-Origin", "*");
      res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
      res.set("Access-Control-Allow-Headers", "Content-Type");

      if (req.method === "OPTIONS") {
        res.status(204).send("");
        return;
      }

      if (req.method !== "POST") {
        res.status(405).json({success: false, message: "Method not allowed"});
        return;
      }

      const {restaurantId} = req.body || {};
      if (!restaurantId) {
        res.status(400).json({success: false, message: "restaurantId is required"});
        return;
      }

      const restaurantDoc = await db.collection("restaurant_partners").doc(restaurantId).get();
      if (!restaurantDoc.exists) {
        res.status(404).json({success: false, message: "Restaurant not found"});
        return;
      }

      const cleanAppId = (applicationId || "").replace(/[\r\n]+/g, "").trim();
      if (!cleanAppId) {
        logger.error("Missing SQUARE_APPLICATION_ID secret; cannot start OAuth reauth");
        res.status(500).json({success: false, message: "Server is missing Square application ID"});
        return;
      }

      const state = `reauth:${restaurantId}`;
      const scopeStr = SQUARE_OAUTH_SCOPES.join(" ");
      const redirectUri = "https://us-east4-freshpunk-48db1.cloudfunctions.net/completeSquareOAuthHttp";

      const oauthUrl = `${baseUrl}/oauth2/authorize` +
        `?client_id=${encodeURIComponent(cleanAppId)}` +
        "&response_type=code" +
        `&scope=${encodeURIComponent(scopeStr)}` +
        `&redirect_uri=${encodeURIComponent(redirectUri)}` +
        `&state=${encodeURIComponent(state)}`;

      logger.info("Square OAuth reauth initiated", {
        restaurantId,
        baseUrl,
        env,
        redirectUri,
      });

      res.status(200).json({
        success: true,
        oauthUrl,
        message: "Complete OAuth flow to reauthorize Square connection",
      });
    } catch (error: any) {
      logger.error("Square OAuth reauth initiation failed", error);
      res.status(500).json({success: false, message: `OAuth setup failed: ${error.message}`});
    }
  }
);

/**
 * OAuth callback for reauthorizing existing restaurant.
 */
export const completeSquareReauthHttp = onRequest(
  {
    region: "us-east4",
    secrets: [SQUARE_APPLICATION_ID, SQUARE_ENV, SQUARE_APPLICATION_SECRET],
  },
  async (req, res) => {
    try {
      const db = getFirestore();
      const {applicationId, applicationSecret, baseUrl} = getSquareConfig();

      const code = req.query.code as string | undefined;
      const state = req.query.state as string | undefined;

      if (!code || !state || !state.startsWith("reauth:")) {
        res.status(400).send("Invalid reauth request");
        return;
      }

      const restaurantId = state.replace("reauth:", "");
      const restaurantDoc = await db.collection("restaurant_partners").doc(restaurantId).get();
      if (!restaurantDoc.exists) {
        res.status(404).send("Restaurant not found");
        return;
      }

      const cleanAppId = (applicationId || "").replace(/[\r\n]+/g, "").trim();
      const cleanAppSecret = (applicationSecret || "").replace(/[\r\n]+/g, "").trim();
      if (!cleanAppId || !cleanAppSecret) {
        res.status(500).send("Missing Square credentials");
        return;
      }

      const redirectUri = "https://us-east4-freshpunk-48db1.cloudfunctions.net/completeSquareReauthHttp";

      const tokenResponse = await fetch(`${baseUrl}/oauth2/token`, {
        method: "POST",
        headers: {
          "Square-Version": "2023-10-18",
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          client_id: cleanAppId,
          client_secret: cleanAppSecret,
          code,
          grant_type: "authorization_code",
          redirect_uri: redirectUri,
        }),
      });

      if (!tokenResponse.ok) {
        const errorData = await tokenResponse.text();
        logger.error("Square reauth token exchange failed", {error: errorData});
        res.status(500).send("Failed to obtain Square access token");
        return;
      }

      const tokenData = await tokenResponse.json();
      const {access_token, merchant_id, expires_at, refresh_token} = tokenData as any;

      let squareLocationId: string | null = null;
      try {
        const locationsResp = await fetch(`${baseUrl}/v2/locations`, {
          headers: {
            "Square-Version": "2023-10-18",
            "Authorization": `Bearer ${access_token}`,
          },
        });
        if (locationsResp.ok) {
          const locData = await locationsResp.json();
          const active = (locData.locations || []).find((l: any) => l.status === "ACTIVE") ||
            (locData.locations || [])[0];
          squareLocationId = active?.id || null;
        }
      } catch (e) {
        logger.warn("Square locations fetch failed during reauth", e as any);
      }

      await db.collection("restaurant_partners").doc(restaurantId).set({
        squareMerchantId: merchant_id || null,
        squareAccessToken: access_token,
        squareRefreshToken: refresh_token || null,
        squareTokenExpiresAt: expires_at ? new Date(expires_at) : null,
        squareLocationId: squareLocationId,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});

      res.status(200).send("Square reauthorization successful. You can close this window.");
    } catch (error: any) {
      logger.error("Square reauth failed", {error: error.message});
      res.status(500).send("Square reauthorization failed");
    }
  }
);

/**
 * Simple test page for reauthorizing an existing restaurant.
 */
export const squareReauthTestPage = onRequest(
  {
    region: "us-east4",
  },
  async (req, res) => {
    res.set("Cache-Control", "no-store, no-cache, must-revalidate, proxy-revalidate, max-age=0");
    res.set("Content-Type", "text/html; charset=utf-8");

    const restaurantId = String(req.query.restaurantId || "");
    res.send(`<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Square Reauthorize</title>
    <style>
      body { font-family: system-ui, -apple-system, Segoe UI, Roboto, Arial; max-width: 720px; margin: 40px auto; padding: 0 16px; }
      label { display: block; margin: 12px 0 6px; }
      input { width: 100%; padding: 10px 12px; border: 1px solid #ccc; border-radius: 6px; }
      button { margin-top: 16px; padding: 10px 16px; border: 0; background: #2563eb; color: white; border-radius: 6px; cursor: pointer; }
      .status { margin-top: 16px; font-size: 14px; color: #374151; }
    </style>
  </head>
  <body>
    <h1>Square Reauthorization</h1>
    <p>Use this to reauthorize an existing restaurant with the updated customer permissions.</p>
    <label for="restaurantId">Restaurant ID</label>
    <input id="restaurantId" value="${restaurantId}" placeholder="restaurant id" />
    <button id="connect">Reauthorize Square →</button>
    <div class="status" id="status"></div>
    <script>
      const endpoint = 'https://us-central1-freshpunk-48db1.cloudfunctions.net/initiateSquareReauthHttp';
      document.getElementById('connect').addEventListener('click', async () => {
        const status = document.getElementById('status');
        const restaurantId = document.getElementById('restaurantId').value.trim();
        if (!restaurantId) {
          status.textContent = 'Restaurant ID is required.';
          return;
        }
        status.textContent = 'Requesting OAuth link...';
        try {
          const resp = await fetch(endpoint, {
            method: 'POST',
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify({restaurantId}),
          });
          const data = await resp.json();
          if (!resp.ok || !data.oauthUrl) {
            throw new Error(data.message || 'Failed to get OAuth URL');
          }
          window.location.href = data.oauthUrl;
        } catch (err) {
          status.textContent = err.message || String(err);
        }
      });
    </script>
  </body>
</html>`);
  }
);

/**
 * Complete Square OAuth flow and setup restaurant integration (HTTP version)
 */
export const completeSquareOAuthHttp = onRequest(
  {
    memory: "1GiB",
    timeoutSeconds: 300,
    region: "us-east4",
    secrets: [SQUARE_APPLICATION_ID, SQUARE_APPLICATION_SECRET, SQUARE_ENV],
  },
  async (req, res) => {
  try {
    logger.info("Square OAuth callback received", {query: req.query});

    const db = getFirestore();
    const {applicationId, applicationSecret, baseUrl} = getSquareConfig();

    // Set CORS headers
    res.set("Access-Control-Allow-Origin", "*");
    res.set("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
    res.set("Access-Control-Allow-Headers", "Content-Type");

    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }

    // Get OAuth parameters from query string (Square sends them as GET parameters)
    const {code, state, error, error_description} = req.query;

    logger.info("OAuth parameters", {code: !!code, state, error, error_description});

    // Check if Square returned an error
    if (error) {
      const errorMsg = error_description || error;
      logger.error("Square OAuth error", {error, error_description});
      res.send(`
        <!DOCTYPE html>
        <html>
        <head>
          <title>Square Connection Failed</title>
          <style>
            body { font-family: Arial, sans-serif; max-width: 600px; margin: 50px auto; padding: 20px; text-align: center; }
            .error { color: #dc3545; font-size: 24px; margin-bottom: 20px; }
          </style>
        </head>
        <body>
          <div class="error">✗ Authorization Failed</div>
          <p>${errorMsg}</p>
          <a href="/square_test.html">Try Again</a>
        </body>
        </html>
      `);
      return;
    }

    if (!code || !state) {
      logger.warn("Missing code or state", {code: !!code, state: !!state});
      res.send(`
        <!DOCTYPE html>
        <html>
        <head>
          <title>Missing Parameters</title>
          <style>
            body { font-family: Arial, sans-serif; max-width: 600px; margin: 50px auto; padding: 20px; text-align: center; }
            .error { color: #dc3545; font-size: 24px; margin-bottom: 20px; }
          </style>
        </head>
        <body>
          <div class="error">✗ Missing Required Parameters</div>
          <p>Authorization code and state are required</p>
          <a href="/square_test.html">Try Again</a>
        </body>
        </html>
      `);
      return;
    }

    // Reauth flow: state prefixed with reauth: and updates existing restaurant
    const stateStr = String(state);
    if (stateStr.startsWith("reauth:")) {
      const restaurantId = stateStr.replace("reauth:", "");
      const restaurantDoc = await db.collection("restaurant_partners").doc(restaurantId).get();
      if (!restaurantDoc.exists) {
        res.status(404).send("Restaurant not found");
        return;
      }

      const cleanAppId = (applicationId || "").replace(/[\r\n]+/g, "").trim();
      const cleanAppSecret = (applicationSecret || "").replace(/[\r\n]+/g, "").trim();
      const redirectUri = "https://us-east4-freshpunk-48db1.cloudfunctions.net/completeSquareOAuthHttp";

      const tokenResponse = await fetch(`${baseUrl}/oauth2/token`, {
        method: "POST",
        headers: {
          "Square-Version": "2023-10-18",
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          client_id: cleanAppId,
          client_secret: cleanAppSecret,
          code,
          grant_type: "authorization_code",
          redirect_uri: redirectUri,
        }),
      });

      if (!tokenResponse.ok) {
        const errorData = await tokenResponse.text();
        logger.error("Square reauth token exchange failed", {error: errorData});
        res.status(500).send("Failed to obtain Square access token");
        return;
      }

      const tokenData = await tokenResponse.json();
      const {access_token, merchant_id, expires_at, refresh_token} = tokenData;

      let squareLocationId: string | null = null;
      try {
        const locationsResp = await fetch(`${baseUrl}/v2/locations`, {
          headers: {
            "Square-Version": "2023-10-18",
            "Authorization": `Bearer ${access_token}`,
          },
        });
        if (locationsResp.ok) {
          const locData = await locationsResp.json();
          const active = (locData.locations || []).find((l: any) => l.status === "ACTIVE") ||
            (locData.locations || [])[0];
          squareLocationId = active?.id || null;
        }
      } catch (e) {
        logger.warn("Square locations fetch failed during reauth", e as any);
      }

      await db.collection("restaurant_partners").doc(restaurantId).set({
        squareMerchantId: merchant_id || null,
        squareAccessToken: access_token,
        squareRefreshToken: refresh_token || null,
        squareTokenExpiresAt: expires_at ? new Date(expires_at) : null,
        squareLocationId: squareLocationId,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});

      res.status(200).send("Square reauthorization successful. You can close this window.");
      return;
    }

    // Get restaurant application
    const applicationDoc = await db.collection("restaurant_applications").doc(state as string).get();
    if (!applicationDoc.exists) {
      res.status(404).json({success: false, message: "Restaurant application not found"});
      return;
    }

    const applicationData = applicationDoc.data()!;

    // Clean credentials (remove CRLF)
    const cleanAppId = (applicationId || "").replace(/[\r\n]+/g, "").trim();
    const cleanAppSecret = (applicationSecret || "").replace(/[\r\n]+/g, "").trim();

    // Log minimal diagnostics (no secrets)
    logger.info("Preparing Square token exchange", {
      baseUrl,
      appIdPrefix: cleanAppId.substring(0, 12),
      appIdLength: cleanAppId.length,
      hasSecret: cleanAppSecret.length > 0,
      secretLength: cleanAppSecret.length,
    });

    // Must exactly match the redirect URI used during authorization.
    const redirectUri = "https://us-east4-freshpunk-48db1.cloudfunctions.net/completeSquareOAuthHttp";

    // Exchange code for access token
    const tokenResponse = await fetch(`${baseUrl}/oauth2/token`, {
      method: "POST",
      headers: {
        "Square-Version": "2023-10-18",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        client_id: cleanAppId,
        client_secret: cleanAppSecret,
        code,
        grant_type: "authorization_code",
        redirect_uri: redirectUri,
      }),
    });

    if (!tokenResponse.ok) {
      const errorData = await tokenResponse.text();
      logger.error("Square token exchange failed", {error: errorData});
      res.status(500).json({success: false, message: "Failed to obtain Square access token"});
      return;
    }

    const tokenData = await tokenResponse.json();
    const {access_token, merchant_id, expires_at, refresh_token} = tokenData;

    // Get merchant information
    const merchantResponse = await fetch(`${baseUrl}/v2/merchants/${merchant_id}`, {
      headers: {
        "Square-Version": "2023-10-18",
        "Authorization": `Bearer ${access_token}`,
      },
    });
    // Fetch locations to determine a default locationId for orders
    let squareLocationId: string | null = null;
    try {
      const locationsResp = await fetch(`${baseUrl}/v2/locations`, {
        headers: {
          "Square-Version": "2023-10-18",
          "Authorization": `Bearer ${access_token}`,
        },
      });
      if (locationsResp.ok) {
        const locData = await locationsResp.json();
        const active = (locData.locations || []).find((l: any) => l.status === "ACTIVE") ||
          (locData.locations || [])[0];
        squareLocationId = active?.id || null;
      }
    } catch (e) {
      logger.warn("Square locations fetch failed", e as any);
    }

    const merchantData = await merchantResponse.json();
    const merchant = merchantData.merchant;

    // Create restaurant partner record
    const restaurantRef = await db.collection("restaurant_partners").add({
      userId: applicationData.userId,
      applicationId: state,

      // Square integration
      squareMerchantId: merchant_id,
      squareAccessToken: access_token, // In production, encrypt this!
      squareRefreshToken: refresh_token || null,
      squareTokenExpiresAt: expires_at ? new Date(expires_at) : null,
  squareLocationId: squareLocationId,

      // Restaurant info
      restaurantName: applicationData.restaurantName,
      squareBusinessName: merchant.business_name,
      contactEmail: applicationData.contactEmail,
      contactPhone: applicationData.contactPhone,

      // Address from Square
      address: merchant.main_location?.address ? {
        addressLine1: merchant.main_location.address.address_line_1,
        addressLine2: merchant.main_location.address.address_line_2,
        locality: merchant.main_location.address.locality,
        administrativeDistrictLevel1: merchant.main_location.address.administrative_district_level_1,
        postalCode: merchant.main_location.address.postal_code,
        country: merchant.main_location.address.country,
      } : null,

      // Status
      status: "active",
      onboardingCompleted: true,
      menuSyncEnabled: true,
      orderForwardingEnabled: true,

      // Timestamps
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
      lastMenuSync: null,
    });

    // Update application status
    await applicationDoc.ref.update({
      status: "completed",
      restaurantPartnerId: restaurantRef.id,
      completedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    // ALSO update the legacy "restaurants" collection entry if it exists
    // This ensures backward compatibility with existing code that references old restaurant IDs
    try {
      // Look for the restaurant by name in the old collection
      const restaurantsSnapshot = await db.collection("restaurants")
        .where("restaurantName", "==", applicationData.restaurantName)
        .limit(1)
        .get();

      if (!restaurantsSnapshot.empty) {
        const legacyRestaurantRef = restaurantsSnapshot.docs[0].ref;
        await legacyRestaurantRef.update({
          squareMerchantId: merchant_id,
          squareAccessToken: access_token,
          squareRefreshToken: refresh_token || null,
          squareTokenExpiresAt: expires_at ? new Date(expires_at) : null,
          squareLocationId: squareLocationId,
          squareBusinessName: merchant.business_name,
          status: "active",
          onboardingCompleted: true,
          updatedAt: FieldValue.serverTimestamp(),
        });
        logger.info("Updated legacy restaurant record", {
          legacyId: restaurantsSnapshot.docs[0].id,
          merchantId: merchant_id,
        });
      }
    } catch (legacyError: any) {
      logger.warn("Failed to update legacy restaurant record (non-critical)", {
        error: legacyError.message,
      });
    }

    // Trigger initial menu sync (non-blocking, log errors but don't fail OAuth)
    try {
      await triggerMenuSync(restaurantRef.id, access_token, merchant_id);
      logger.info("Menu sync completed successfully", {restaurantId: restaurantRef.id});
    } catch (syncError: any) {
      logger.warn("Menu sync failed (non-critical)", {
        restaurantId: restaurantRef.id,
        error: syncError.message,
      });
    }

    logger.info("Square OAuth completed successfully", {
      restaurantId: restaurantRef.id,
      merchantId: merchant_id,
      businessName: merchant.business_name,
    });

    // For testing: Send HTML response with success message
    res.send(`
      <!DOCTYPE html>
      <html>
      <head>
        <title>Square Connection Successful</title>
        <style>
          body { font-family: Arial, sans-serif; max-width: 600px; margin: 50px auto; padding: 20px; text-align: center; }
          .success { color: #28a745; font-size: 24px; margin-bottom: 20px; }
          .details { background: #f8f9fa; padding: 20px; border-radius: 8px; margin: 20px 0; }
          .info { background: #e7f3ff; padding: 20px; border-radius: 8px; margin: 20px 0; text-align: left; }
          .info h3 { margin-top: 0; color: #0066cc; }
          .info ul { margin: 10px 0; padding-left: 20px; }
          .info li { margin: 8px 0; }
        </style>
      </head>
      <body>
        <div class="success">✓ Square Account Connected Successfully!</div>
        <div class="details">
          <h3>Restaurant: ${merchant.business_name}</h3>
          <p><strong>Merchant ID:</strong> ${merchant_id}</p>
          <p><strong>Restaurant ID:</strong> ${restaurantRef.id}</p>
        </div>
        <div class="info">
          <h3>🎉 You're all set!</h3>
          <p>Your Square POS is now connected to Victus. Here's what happens next:</p>
          <ul>
            <li>✅ Customer orders will automatically appear in your Square dashboard</li>
            <li>✅ Payments are processed through your existing Square system</li>
            <li>✅ Your menu items are synced with Victus</li>
            <li>✅ No additional login or portal access needed</li>
          </ul>
          <p><strong>Next steps:</strong> Simply monitor your Square dashboard for incoming Victus orders. That's it!</p>
        </div>
        <p style="color: #666; font-size: 14px; margin-top: 30px;">You can close this window now.</p>
      </body>
      </html>
    `);
  } catch (error: any) {
    logger.error("Square OAuth completion failed", error);
    res.send(`
      <!DOCTYPE html>
      <html>
      <head>
        <title>Square Connection Failed</title>
        <style>
          body { font-family: Arial, sans-serif; max-width: 600px; margin: 50px auto; padding: 20px; text-align: center; }
          .error { color: #dc3545; font-size: 24px; margin-bottom: 20px; }
          .details { background: #f8f9fa; padding: 20px; border-radius: 8px; margin: 20px 0; }
          .button { display: inline-block; padding: 12px 24px; background: #007bff; color: white; text-decoration: none; border-radius: 4px; margin-top: 20px; }
        </style>
      </head>
      <body>
        <div class="error">✗ Connection Failed</div>
        <div class="details">
          <p><strong>Error:</strong> ${error.message}</p>
        </div>
        <a href="/square_test.html" class="button">Try Again</a>
      </body>
      </html>
    `);
  }
});

/**
 * Diagnostics endpoint: checks Square OAuth authorize endpoint reachability
 * from the Cloud Functions environment and returns status/headers.
 */
export const diagnoseSquareOAuth = onRequest(
  {
    region: "us-east4",
    secrets: [SQUARE_APPLICATION_ID, SQUARE_ENV],
  },
  async (req, res) => {
    try {
      const {applicationId, baseUrl, env} = getSquareConfig();
      const cleanAppId = (applicationId || "").replace(/[\r\n]+/g, "").trim();
  // Use same stable redirect URI for diagnostics (value itself not invoked here, but kept consistent).
  const redirectUri = "https://us-east4-freshpunk-48db1.cloudfunctions.net/completeSquareOAuthHttp";
      const urlWithParams = `${baseUrl}/oauth2/authorize?client_id=${encodeURIComponent(cleanAppId)}&response_type=code&scope=${encodeURIComponent("MERCHANT_PROFILE_READ")}&redirect_uri=${encodeURIComponent(redirectUri)}&state=diag`;

      // Try a GET without following redirects to capture the first response
      const resp = await fetch(urlWithParams, {method: "GET", redirect: "manual" as any});
      const hdr = Object.fromEntries((resp.headers as any).entries?.() ?? []);

      // Also probe the bare authorize endpoint (expected 400/403)
      const bare = await fetch(`${baseUrl}/oauth2/authorize`, {method: "GET", redirect: "manual" as any});
      const bareHdr = Object.fromEntries((bare.headers as any).entries?.() ?? []);

      res.json({
        ok: true,
        env,
        baseUrl,
        clientIdPrefix: cleanAppId.substring(0, 8),
        authorizeWithParams: {status: resp.status, statusText: resp.statusText, headers: hdr},
        authorizeBare: {status: bare.status, statusText: bare.statusText, headers: bareHdr},
        note: "If your browser is blocked by Cloudflare (403), but this shows 200/3xx, the issue is client-network specific.",
      });
    } catch (e: any) {
      res.status(500).json({ok: false, error: e?.message || String(e)});
    }
  }
);

/**
 * Dev-only: List recent Square orders for a restaurant's location.
 * Useful to verify orders are landing in the expected seller/location.
 * Query/body: restaurantId (required)
 */
export const devListRecentSquareOrders = onRequest(
  {
    region: "us-east4",
    secrets: [SQUARE_ENV],
  },
  async (req, res) => {
    try {
      const db = getFirestore();
      const restaurantId = (req.method === "POST" ? req.body?.restaurantId : req.query.restaurantId) as string;
      if (!restaurantId) {
        res.status(400).json({success: false, message: "restaurantId required"});
        return;
      }

      const doc = await db.collection("restaurant_partners").doc(restaurantId).get();
      if (!doc.exists) {
        res.status(404).json({success: false, message: "Restaurant partner not found"});
        return;
      }
      const restaurant = doc.data()!;

      const accessToken = restaurant.squareAccessToken;
      const locationId = restaurant.squareLocationId || restaurant.squareMerchantId;
      if (!accessToken || !locationId) {
        res.status(400).json({success: false, message: "Missing Square access token or locationId on restaurant"});
        return;
      }

      const {baseUrl} = getSquareConfig();
      const searchPayload = {
        location_ids: [locationId],
        sort: {field: "CREATED_AT", order: "DESC"},
        limit: 20,
      } as any;

      const resp = await fetch(`${baseUrl}/v2/orders/search`, {
        method: "POST",
        headers: {
          "Square-Version": "2023-10-18",
          "Authorization": `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(searchPayload),
      });

      if (!resp.ok) {
        const text = await resp.text().catch(() => "<no-body>");
        res.status(500).json({success: false, message: `Square search failed ${resp.status}: ${text.slice(0, 500)}`});
        return;
      }

      const data = await resp.json();
      const orders = (data.orders || []).map((o: any) => ({
        id: o.id,
        state: o.state,
        created_at: o.created_at,
        location_id: o.location_id,
        reference_id: o.reference_id,
        lineItems: (o.line_items || []).length,
      }));

      res.json({success: true, restaurantId, locationId, count: orders.length, orders});
    } catch (e: any) {
      res.status(500).json({success: false, message: e?.message || String(e)});
    }
  }
);

/**
 * Dev-only: Find a Square order by FreshPunk reference or orderId.
 * Query/body: restaurantId (required), reference OR orderId (one required)
 * reference format we use: "freshpunk_order_<orderId>" truncated to 40 chars
 */
export const devFindSquareOrderByReference = onRequest(
  {
    region: "us-east4",
    secrets: [SQUARE_ENV],
  },
  async (req, res) => {
    try {
      const db = getFirestore();
      const restaurantId = (req.method === "POST" ? req.body?.restaurantId : req.query.restaurantId) as string;
      const providedReference = (req.method === "POST" ? req.body?.reference : req.query.reference) as string | undefined;
      const providedOrderId = (req.method === "POST" ? req.body?.orderId : req.query.orderId) as string | undefined;

      if (!restaurantId) {
        res.status(400).json({success: false, message: "restaurantId required"});
        return;
      }

      let reference = providedReference?.toString().trim();
      if (!reference) {
        if (!providedOrderId) {
          res.status(400).json({success: false, message: "Provide reference or orderId"});
          return;
        }
        const base = `freshpunk_order_${providedOrderId}`;
        reference = base.length > 40 ? base.substring(0, 40) : base;
      }

      const doc = await db.collection("restaurant_partners").doc(restaurantId).get();
      if (!doc.exists) {
        res.status(404).json({success: false, message: "Restaurant partner not found"});
        return;
      }
      const restaurant = doc.data()!;
      const accessToken = restaurant.squareAccessToken;
      const locationId = restaurant.squareLocationId || restaurant.squareMerchantId;
      if (!accessToken || !locationId) {
        res.status(400).json({success: false, message: "Missing Square access token or locationId on restaurant"});
        return;
      }

      const {baseUrl} = getSquareConfig();
      const payload: any = {
        location_ids: [locationId],
        limit: 20,
        query: {
          filter: {
            reference_filter: {
              reference_ids: [reference],
            },
          },
        },
      };

      const resp = await fetch(`${baseUrl}/v2/orders/search`, {
        method: "POST",
        headers: {
          "Square-Version": "2023-10-18",
          "Authorization": `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(payload),
      });

      if (!resp.ok) {
        const text = await resp.text().catch(() => "<no-body>");
        res.status(500).json({success: false, message: `Square search failed ${resp.status}: ${text.slice(0, 500)}`});
        return;
      }

      const data = await resp.json();
      const orders = (data.orders || []);

      // Return a concise view plus the first order raw (if any)
      const summary = orders.map((o: any) => ({
        id: o.id,
        state: o.state,
        created_at: o.created_at,
        location_id: o.location_id,
        reference_id: o.reference_id,
        lineItems: (o.line_items || []).length,
        fulfillments: (o.fulfillments || []).map((f: any) => ({type: f.type, state: f.state})),
        hasTenders: Array.isArray(o.tenders) && o.tenders.length > 0,
      }));

      res.json({success: true, restaurantId, locationId, reference, count: orders.length, summary, order: orders[0] || null});
    } catch (e: any) {
      res.status(500).json({success: false, message: e?.message || String(e)});
    }
  }
);

/**
 * Dev-only: Get full Square order details by Square order ID.
 * Query/body: restaurantId, squareOrderId
 * Returns raw order plus a visibilityAnalysis section explaining likely dashboard behavior.
 */
export const devGetSquareOrderDetails = onRequest(
  {
    region: "us-east4",
    secrets: [SQUARE_ENV],
  },
  async (req, res) => {
    try {
      const db = getFirestore();
      const restaurantId = (req.method === "POST" ? req.body?.restaurantId : req.query.restaurantId) as string;
      const squareOrderId = (req.method === "POST" ? req.body?.squareOrderId : req.query.squareOrderId) as string;

      if (!restaurantId || !squareOrderId) {
        res.status(400).json({success: false, message: "restaurantId and squareOrderId required"});
        return;
      }

      const doc = await db.collection("restaurant_partners").doc(restaurantId).get();
      if (!doc.exists) {
        res.status(404).json({success: false, message: "Restaurant partner not found"});
        return;
      }
      const restaurant = doc.data()!;
      const accessToken = restaurant.squareAccessToken;
      const locationId = restaurant.squareLocationId || restaurant.squareMerchantId;
      if (!accessToken || !locationId) {
        res.status(400).json({success: false, message: "Missing Square access token or locationId on restaurant"});
        return;
      }

      const {baseUrl} = getSquareConfig();
      const resp = await fetch(`${baseUrl}/v2/orders/${squareOrderId}`, {
        method: "GET",
        headers: {
          "Square-Version": "2023-10-18",
          "Authorization": `Bearer ${accessToken}`,
        },
      });

      if (!resp.ok) {
        const text = await resp.text().catch(() => "<no-body>");
        res.status(resp.status).json({success: false, message: `Square get order failed ${resp.status}`, details: text.slice(0, 600)});
        return;
      }
      const data = await resp.json();
      const order = data.order || {};

      // Heuristic visibility analysis
      const visibility: any = {};
      visibility.state = order.state;
      visibility.fulfillmentCount = (order.fulfillments || []).length;
      visibility.hasMultipleFulfillments = visibility.fulfillmentCount > 1;
      visibility.lineItemCount = (order.line_items || []).length;
      visibility.hasTenders = (order.tenders || []).length > 0;
      visibility.deliveryScheduling = (order.fulfillments || [])
        .map((f: any) => ({type: f.type, state: f.state, deliver_at: f.delivery_details?.deliver_at, pickup_at: f.pickup_details?.pickup_at}))
        .slice(0, 5);
      visibility.reference_id = order.reference_id;
      visibility.location_id = order.location_id;
      visibility.created_at = order.created_at;
      visibility.filterNotes = [] as string[];

      if (visibility.state === "OPEN") {
        visibility.filterNotes.push("Order is OPEN (expected to appear under Active / All). Square may delay indexing briefly.");
      }
      if (!visibility.hasTenders) {
        visibility.filterNotes.push("No tender recorded; some dashboard views emphasize paid orders.");
      }
      if (visibility.fulfillmentCount === 0) {
        visibility.filterNotes.push("No fulfillment; some views hide orders lacking a fulfillment.");
      }
      const futureDeliveries = visibility.deliveryScheduling.filter((s: any) => s.deliver_at && new Date(s.deliver_at) > new Date());
      if (futureDeliveries.length > 0) {
        visibility.filterNotes.push("Fulfillment deliver_at in future; may appear under Scheduled rather than All depending on filters.");
      }

      res.json({success: true, restaurantId, squareOrderId, order, visibilityAnalysis: visibility});
    } catch (e: any) {
      res.status(500).json({success: false, message: e?.message || String(e)});
    }
  }
);

/**
 * squareWhoAmI
 * Returns merchant + locations info for a restaurant's stored Square token.
 * Use to verify which seller/location the access token actually belongs to.
 * Query/body: restaurantId
 */
export const squareWhoAmI = onRequest(
  {
    region: "us-east4",
    secrets: [SQUARE_ENV],
  },
  async (req, res) => {
    try {
      res.set("Access-Control-Allow-Origin", "*");
      res.set("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
      res.set("Access-Control-Allow-Headers", "Content-Type");
      if (req.method === "OPTIONS") {
        res.status(204).send("");
        return;
      }
      const restaurantId = (req.method === "POST" ? req.body?.restaurantId : req.query.restaurantId) as string;
      if (!restaurantId) {
        res.status(400).json({success: false, message: "restaurantId required"});
        return;
      }
      const db = getFirestore();
      const doc = await db.collection("restaurant_partners").doc(restaurantId).get();
      if (!doc.exists) {
        res.status(404).json({success: false, message: "Restaurant partner not found"});
        return;
      }
      const data = doc.data()!;
      const accessToken = data.squareAccessToken;
      if (!accessToken) {
        res.status(400).json({success: false, message: "Missing Square access token on restaurant"});
        return;
      }
      const {baseUrl} = getSquareConfig();
      const headers: Record<string, string> = {
        "Square-Version": "2023-10-18",
        "Authorization": `Bearer ${accessToken}`,
      };
      const merchantResp = await fetch(`${baseUrl}/v2/merchants/me`, {headers});
      const merchantJson = await merchantResp.json();
      const locationsResp = await fetch(`${baseUrl}/v2/locations`, {headers});
      const locationsJson = await locationsResp.json();
      res.json({
        success: true,
        restaurantId,
        environment: (SQUARE_ENV.value() || "sandbox").toLowerCase(),
        merchant: merchantJson.merchant || merchantJson,
        locations: locationsJson.locations || [],
      });
    } catch (e: any) {
      res.status(500).json({success: false, message: e?.message || String(e)});
    }
  }
);

// ============================================================================
// MENU SYNCHRONIZATION
// ============================================================================

/**
 * Sync restaurant menu from Square to FreshPunk
 */
export const syncSquareMenu = onCall(
  {
    memory: "1GiB",
    timeoutSeconds: 540,
    region: "us-east4",
  },
  async (request: any) => {
  try {
    const db = getFirestore();
    const {auth} = request;
    if (!auth) {
      throw new HttpsError("unauthenticated", "Authentication required");
    }

    const {restaurantId} = request.data;
    if (!restaurantId) {
      throw new HttpsError("invalid-argument", "Restaurant ID required");
    }

    // Get restaurant partner record
    const restaurantDoc = await db.collection("restaurant_partners").doc(restaurantId).get();
    if (!restaurantDoc.exists) {
      throw new HttpsError("not-found", "Restaurant partner not found");
    }

    const restaurant = restaurantDoc.data()!;

    // Verify ownership
    if (restaurant.userId !== auth.uid) {
      throw new HttpsError("permission-denied", "Access denied");
    }

    const syncResult = await triggerMenuSync(
      restaurantId,
      restaurant.squareAccessToken,
      restaurant.squareMerchantId
    );

    return {
      success: true,
      ...syncResult,
    };
  } catch (error: any) {
    logger.error("Manual menu sync failed", error);
    throw new HttpsError("internal", `Menu sync failed: ${error.message}`);
  }
});

/**
 * Dev-only HTTP endpoint to force a Square menu sync.
 * Guarded to run only in sandbox environment.
 */
export const devForceSyncSquareMenu = onRequest(
  {
    region: "us-east4",
    secrets: [SQUARE_ENV],
  },
  async (req, res) => {
    try {
      const db = getFirestore();
      const {env} = getSquareConfig();
      if (env !== "sandbox") {
        res.status(403).json({success: false, message: "Not available in production"});
        return;
      }

      const restaurantId = (req.method === "POST" ? req.body?.restaurantId : req.query.restaurantId) as string;
      if (!restaurantId) {
        res.status(400).json({success: false, message: "restaurantId required"});
        return;
      }

      const doc = await db.collection("restaurant_partners").doc(restaurantId).get();
      if (!doc.exists) {
        res.status(404).json({success: false, message: "Restaurant partner not found"});
        return;
      }
      const data = doc.data()!;

      const result = await triggerMenuSync(restaurantId, data.squareAccessToken, data.squareMerchantId);
      res.status(200).json({success: true, ...result});
    } catch (err: any) {
      logger.error("devForceSyncSquareMenu failed", err);
      res.status(500).json({success: false, message: err.message});
    }
  }
);

/**
 * Internal function to sync menu from Square
 * Links existing FreshPunk meals to Square items for order forwarding
 * @param {string} restaurantId - The restaurant ID
 * @param {string} accessToken - Square API access token
 * @param {string} merchantId - Square merchant ID
 * @return {Promise<void>}
 */
async function triggerMenuSync(restaurantId: string, accessToken: string, merchantId: string) {
  // merchantId is passed for future use with multi-location support
  const db = getFirestore();
  const {baseUrl} = getSquareConfig();
  try {
    // Get catalog items from Square
  const catalogResponse = await fetch(`${baseUrl}/v2/catalog/list?types=ITEM`, {
      headers: {
        "Square-Version": "2023-10-18",
        "Authorization": `Bearer ${accessToken}`,
      },
    });

    if (!catalogResponse.ok) {
      const text = await catalogResponse.text().catch(() => "<no-body>");
      const errorMsg = `Square catalog error ${catalogResponse.status} ${catalogResponse.statusText}: ${text.slice(0, 200)}`;
      // Include details directly in the log message so it's visible in the simple log view
      logger.error(`Square catalog fetch failed: ${errorMsg}`);
      // Also emit structured details for the advanced logs
      logger.error("Square catalog fetch details", {
        status: catalogResponse.status,
        statusText: catalogResponse.statusText,
        body: text?.slice(0, 500),
        url: `${baseUrl}/v2/catalog/list?types=ITEM`,
      });
      throw new Error(errorMsg);
    }

    const catalogData = await catalogResponse.json();
    const squareItems = catalogData.objects || [];

    // Get restaurant record to find the restaurant name/slug used in Firestore path
    const restaurantDoc = await db.collection("restaurant_partners").doc(restaurantId).get();
    if (!restaurantDoc.exists) {
      throw new Error("Restaurant partner not found");
    }
    const restaurantData = restaurantDoc.data()!;

    // Derive restaurant slug from name (lowercase, underscores for spaces)
    const restaurantName = (restaurantData.restaurantName || "").toLowerCase().replace(/\s+/g, "_");
    const restaurantSlug = restaurantName || restaurantId;

    // Try common variations of the restaurant name (greenblend, sen_saigon, etc.)
    const slugCandidates = [
      restaurantSlug,
      restaurantName.replace(/_/g, ""),
      restaurantName.replace(/_/g, " "),
      "greenblend", // fallback defaults
      "sen_saigon",
    ];

    // Query meals from nested structure: meals/{restaurantSlug}/items
    let existingMealsDocs: FirebaseFirestore.QueryDocumentSnapshot[] = [];
    let actualRestaurantSlug = restaurantSlug;
    for (const slug of slugCandidates) {
      try {
        const itemsSnap = await db
          .collection("meals")
          .doc(slug)
          .collection("items")
          .limit(1000)
          .get();
        if (!itemsSnap.empty) {
          existingMealsDocs = itemsSnap.docs;
          actualRestaurantSlug = slug;
          logger.info(`Found ${itemsSnap.size} existing meals under meals/${slug}/items`);
          break;
        }
      } catch (err) {
        logger.warn(`Could not query meals/${slug}/items`, {error: (err as any).message});
      }
    }

    const existingMeals = existingMealsDocs.map((doc) => {
      const data = doc.data();
      return {
        id: doc.id,
        ref: doc.ref,
        name: data.name || "",
        restaurantSlug: actualRestaurantSlug,
        ...data,
      };
    });

    logger.info("Menu sync started", {
      restaurantId,
      squareItemsFound: squareItems.length,
      existingMealsToMatch: existingMeals.length,
    });

    // Get current inventory levels
    const inventoryResponse = await fetch(`${baseUrl}/v2/inventory/batch-retrieve-counts`, {
      method: "POST",
      headers: {
        "Square-Version": "2023-10-18",
        "Authorization": `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        catalog_object_ids: squareItems.map((item: any) => item.id),
      }),
    });

    let inventoryCounts: any[] = [];
    if (inventoryResponse.ok) {
      const inventoryData = await inventoryResponse.json();
      inventoryCounts = inventoryData.counts || [];
    } else {
      const text = await inventoryResponse.text().catch(() => "<no-body>");
      logger.warn("Square inventory fetch failed; continuing without counts", {
        status: inventoryResponse.status,
        body: text?.slice(0, 500),
      });
    }

    // Create inventory lookup
    const inventoryLookup = inventoryCounts.reduce((acc: any, count: any) => {
      acc[count.catalog_object_id] = count.quantity || "0";
      return acc;
    }, {});

    // Track sync results
    let matchedCount = 0;
    let unmatchedSquareItems = 0;
    const unmatchedNames: string[] = [];
    const batch = db.batch();

    // If there are no existing FreshPunk meals, seed minimal meals from Square
    if (existingMeals.length === 0 && squareItems.length > 0) {
      logger.info(`No existing FreshPunk meals found; seeding from Square catalog to meals/${actualRestaurantSlug}/items`);
      for (const item of squareItems) {
        if (item.type !== "ITEM" || !item.item_data) continue;
        const itemData = item.item_data;
        const variations = itemData.variations || [];
        for (const variation of variations) {
          if (variation.type !== "ITEM_VARIATION") continue;

          const inventoryCount = parseInt((inventoryLookup as any)[variation.id] || "0");
          const docRef = db.collection("meals").doc(actualRestaurantSlug).collection("items").doc();
          const seedData: any = {
            name: itemData.name || "",
            restaurant: actualRestaurantSlug,
            squareItemId: item.id,
            squareVariationId: variation.id,
            priceCents: variation.item_variation_data?.price_money?.amount || 0,
            stockQuantity: inventoryCount,
            isAvailable: inventoryCount > 0,
            isActive: true,
            createdAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
            lastSquareSync: FieldValue.serverTimestamp(),
          };

          // Only add optional fields if they exist
          if (itemData.description) {
            seedData.description = itemData.description;
          }
          if (itemData.category_id) {
            seedData.squareCategoryId = itemData.category_id;
          }
          if (variation.item_variation_data?.price_money?.currency) {
            seedData.currency = variation.item_variation_data.price_money.currency;
          }

          batch.set(docRef, seedData);
          matchedCount++;
        }
      }

      await batch.commit();
      await db.collection("restaurant_partners").doc(restaurantId).update({
        lastMenuSync: FieldValue.serverTimestamp(),
        menuItemCount: matchedCount,
        updatedAt: FieldValue.serverTimestamp(),
      });

      await db.collection("restaurant_partners").doc(restaurantId)
        .collection("sync_logs").add({
          at: FieldValue.serverTimestamp(),
          seededFromSquare: true,
          matchedMeals: matchedCount,
          unmatchedSquareItems: 0,
          totalSquareItems: squareItems.length,
          existingMealsConsidered: 0,
          unmatchedSamples: [],
        });

      logger.info("Seeding from Square completed", {restaurantId, createdMeals: matchedCount});
      return {
        itemsSynced: matchedCount,
        unmatchedSquareItems: 0,
        message: `Seeded ${matchedCount} meals from Square (no existing FreshPunk meals).`,
      };
    }

    // Match Square items to existing FreshPunk meals
    for (const item of squareItems) {
      if (item.type === "ITEM" && item.item_data) {
        const itemData = item.item_data;
        const squareItemName = (itemData.name || "").toLowerCase().trim();
        const variations = itemData.variations || [];

        for (const variation of variations) {
          if (variation.type === "ITEM_VARIATION") {
            // Find best matching FreshPunk meal by name
            let bestMatch = null;
            let highestScore = 0;

            for (const meal of existingMeals) {
              const mealName = (meal.name || "").toLowerCase().trim();
              const score = calculateNameSimilarity(squareItemName, mealName);

              if (score > highestScore && score >= 0.6) { // 60% similarity threshold
                highestScore = score;
                bestMatch = meal;
              }
            }

            if (bestMatch) {
              // Found a match! Update existing meal with Square IDs
              const inventoryCount = parseInt(inventoryLookup[variation.id] || "0");

              const updateData: any = {
                restaurant: actualRestaurantSlug,
                restaurantId: restaurantId, // Restaurant partner ID for order forwarding
                squareItemId: item.id,
                squareVariationId: variation.id,
                stockQuantity: inventoryCount,
                isAvailable: inventoryCount > 0,
                lastSquareSync: FieldValue.serverTimestamp(),
                updatedAt: FieldValue.serverTimestamp(),
              };

              // Only add category if it exists
              if (itemData.category_id) {
                updateData.squareCategoryId = itemData.category_id;
              }

              batch.update(bestMatch.ref, updateData);

              matchedCount++;
              logger.info("Matched meal to Square item", {
                mealId: bestMatch.id,
                mealName: bestMatch.name,
                squareItemName: itemData.name,
                similarity: highestScore.toFixed(2),
              });
            } else {
              // No match found - this Square item doesn't match any FreshPunk meal
              unmatchedSquareItems++;
              if (itemData?.name) unmatchedNames.push(itemData.name);
              logger.info("No match found for Square item", {
                squareItemName: itemData.name,
                squareVariationId: variation.id,
              });
            }
          }
        }
      }
    }

  // Commit match updates batch
    await batch.commit();

    // Update restaurant sync status
    await db.collection("restaurant_partners").doc(restaurantId).update({
      lastMenuSync: FieldValue.serverTimestamp(),
      menuItemCount: matchedCount,
      updatedAt: FieldValue.serverTimestamp(),
    });

    logger.info("Menu sync completed", {
      restaurantId,
      matchedMeals: matchedCount,
      unmatchedSquareItems: unmatchedSquareItems,
      totalSquareItems: squareItems.length,
    });

    // Persist a lightweight sync summary for debugging in Firestore
    await db.collection("restaurant_partners").doc(restaurantId)
      .collection("sync_logs").add({
        at: FieldValue.serverTimestamp(),
        matchedMeals: matchedCount,
        unmatchedSquareItems,
        totalSquareItems: squareItems.length,
        existingMealsConsidered: existingMeals.length,
        unmatchedSamples: unmatchedNames.slice(0, 10),
      });

    return {
      itemsSynced: matchedCount,
      unmatchedSquareItems: unmatchedSquareItems,
      message: `Successfully synced ${matchedCount} meals with Square items. ${unmatchedSquareItems} Square items had no match.`,
    };
  } catch (error: any) {
    // Put the error message inline for easy viewing
    logger.error(`Menu sync failed: ${error?.message || error}`, {restaurantId});
    throw error;
  }
}

// ============================================================================
// ORDER FORWARDING TO SQUARE
// ============================================================================

/**
 * Forward FreshPunk order to Square POS when order is confirmed
 * This handles individual confirmed orders (separate from weekly prep forecasts)
 */
export const forwardOrderToSquare = onDocumentCreated(
  {
    document: "orders/{orderId}",
    memory: "1GiB",
    timeoutSeconds: 300,
    region: "us-east4",
    // Include secrets so getSquareConfig() can access them without warnings
    secrets: [
      SQUARE_APPLICATION_ID,
      SQUARE_APPLICATION_SECRET,
      SQUARE_ENV,
    ],
  },
  async (event: any) => {
  try {
    const orderData = event.data?.data();
    if (!orderData) return;

    // Only forward confirmed orders with Square restaurant items
    if (orderData.status !== "confirmed") {
      logger.info("forwardOrderToSquare skip: status not confirmed", {
        orderId: event.params.orderId,
        status: orderData.status,
      });
      return;
    }

    const meals = orderData.meals || [];
    const squareMeals = meals.filter((meal: any) => meal.restaurantId && meal.squareItemId);

    if (squareMeals.length === 0) {
      logger.info("forwardOrderToSquare skip: no square-qualified meals", {
        orderId: event.params.orderId,
        mealCount: (meals || []).length,
      });
      return;
    }

    // Group by restaurant
    const ordersByRestaurant = squareMeals.reduce((acc: any, meal: any) => {
      const restaurantId = meal.restaurantId;
      if (!acc[restaurantId]) {
        acc[restaurantId] = [];
      }
      acc[restaurantId].push(meal);
      return acc;
    }, {});

    // Forward to each restaurant
    for (const [restaurantId, restaurantMeals] of Object.entries(ordersByRestaurant)) {
      await forwardToSquareRestaurant(
        event.params.orderId,
        restaurantId,
        restaurantMeals as any[],
        orderData,
        "confirmed_order" // This is a real confirmed order, not a forecast
      );
    }

    logger.info("Confirmed order forwarded to Square restaurants", {
      orderId: event.params.orderId,
      restaurantCount: Object.keys(ordersByRestaurant).length,
    });
  } catch (error: any) {
    logger.error("Order forwarding failed", {orderId: event.params.orderId, error: error.message});
  }
});

/**
 * Forward order to Square when status changes to confirmed
 * Handles cases where order is created first, then confirmed later
 */
export const forwardOrderOnStatusUpdate = onDocumentUpdated(
  {
    document: "orders/{orderId}",
    memory: "1GiB",
    timeoutSeconds: 300,
    region: "us-east4",
    secrets: [
      SQUARE_APPLICATION_ID,
      SQUARE_APPLICATION_SECRET,
      SQUARE_ENV,
    ],
  },
  async (event: any) => {
    try {
      const beforeData = event.data?.before.data();
      const afterData = event.data?.after.data();

      if (!beforeData || !afterData) return;

      // Handle status changes: confirmed (forward) or cancelled (cancel in Square)
      const statusChanged = beforeData.status !== afterData.status;
      const nowConfirmed = afterData.status === "confirmed" && beforeData.status !== "confirmed";
      const nowCancelled = afterData.status === "cancelled" && beforeData.status !== "cancelled";

      if (!statusChanged || (!nowConfirmed && !nowCancelled)) {
        logger.info("forwardOrderOnStatusUpdate skip: no relevant status change", {
          orderId: event.params.orderId,
          beforeStatus: beforeData.status,
          afterStatus: afterData.status,
        });
        return;
      }

      // Handle cancellation
      if (nowCancelled) {
        logger.info("Order cancelled, cancelling in Square", {
          orderId: event.params.orderId,
          previousStatus: beforeData.status,
        });

        const squareOrders = afterData.squareOrders || {};

        // Cancel each Square order that was forwarded
        for (const [restaurantId, squareOrderData] of Object.entries(squareOrders)) {
          const squareOrderId = (squareOrderData as any)?.squareOrderId;
          if (!squareOrderId) continue;

          try {
            await cancelSquareOrder(event.params.orderId, restaurantId, squareOrderId);
            logger.info("Square order cancelled", {
              orderId: event.params.orderId,
              restaurantId,
              squareOrderId,
            });
          } catch (error: any) {
            logger.error("Failed to cancel Square order", {
              orderId: event.params.orderId,
              restaurantId,
              squareOrderId,
              error: error.message,
            });
          }
        }

        return; // Done handling cancellation
      }

      // Handle confirmation (existing logic)
      if (!nowConfirmed) {
        return;
      }

      logger.info("Order status changed to confirmed, forwarding to Square", {
        orderId: event.params.orderId,
        previousStatus: beforeData.status,
      });

      const meals = afterData.meals || [];
      const squareMeals = meals.filter((meal: any) => meal.restaurantId && meal.squareItemId);

      if (squareMeals.length === 0) {
        logger.info("forwardOrderOnStatusUpdate skip: no square-qualified meals", {
          orderId: event.params.orderId,
          mealCount: (meals || []).length,
        });
        return;
      }

      // Group by restaurant
      const ordersByRestaurant = squareMeals.reduce((acc: any, meal: any) => {
        const restaurantId = meal.restaurantId;
        if (!acc[restaurantId]) {
          acc[restaurantId] = [];
        }
        acc[restaurantId].push(meal);
        return acc;
      }, {});

      // Forward to each restaurant
      for (const [restaurantId, restaurantMeals] of Object.entries(ordersByRestaurant)) {
        await forwardToSquareRestaurant(
          event.params.orderId,
          restaurantId,
          restaurantMeals as any[],
          afterData,
          "confirmed_order"
        );
      }

      logger.info("Order forwarded to Square on status update", {
        orderId: event.params.orderId,
        restaurantCount: Object.keys(ordersByRestaurant).length,
      });
    } catch (error: any) {
      logger.error("Order forwarding on update failed", {
        orderId: event.params.orderId,
        error: error.message,
      });
    }
  }
);

const DISPATCH_BATCH_SIZE = Number(process.env.FP_DISPATCH_BATCH_SIZE || 20);

/**
 * Promote user-confirmed orders to confirmed status when dispatch window opens.
 * This defers Square order creation until roughly an hour before delivery.
 */
export const dispatchConfirmedOrders = onSchedule({
  schedule: "every 5 minutes",
  timeZone: "Etc/UTC",
}, async () => {
  const db = getFirestore();
  const now = Timestamp.now();

  try {
    const snapshot = await db.collection("orders")
      .where("status", "==", "pending")
      .where("userConfirmed", "==", true)
      .where("dispatchReadyAt", "<=", now)
      .orderBy("dispatchReadyAt", "asc")
      .limit(DISPATCH_BATCH_SIZE)
      .get();

    if (snapshot.empty) {
      logger.debug("dispatchConfirmedOrders: no orders ready", {checkedAt: now.toDate().toISOString()});
      return;
    }

    const updates = snapshot.docs.map(async (doc) => {
      try {
        await doc.ref.update({
          status: "confirmed",
          dispatchTriggeredAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
        logger.info("dispatchConfirmedOrders: promoted order", {
          orderId: doc.id,
          userId: doc.data().userId,
          dispatchReadyAt: doc.data().dispatchReadyAt,
        });
      } catch (error: any) {
        logger.error("dispatchConfirmedOrders: update failed", {
          orderId: doc.id,
          error: error?.message,
        });
      }
    });

    await Promise.all(updates);
  } catch (error: any) {
    logger.error("dispatchConfirmedOrders: query failed", {error: error?.message});
  }
});

/**
 * Cancel a Square order
 * @param {string} orderId - FreshPunk order ID
 * @param {string} restaurantId - Restaurant ID
 * @param {string} squareOrderId - Square order ID to cancel
 */
async function cancelSquareOrder(
  orderId: string,
  restaurantId: string,
  squareOrderId: string
): Promise<void> {
  const db = getFirestore();

  try {
    // Get restaurant access token
    const restaurantDoc = await db.collection("restaurant_partners").doc(restaurantId).get();
    if (!restaurantDoc.exists) {
      throw new Error(`Restaurant ${restaurantId} not found`);
    }

    const restaurantData = restaurantDoc.data()!;
    const accessToken = restaurantData.squareAccessToken;

    if (!accessToken) {
      throw new Error(`No Square access token for restaurant ${restaurantId}`);
    }

    const {baseUrl} = getSquareConfig();

    // First, retrieve current order to get version
    const getResp = await fetch(`${baseUrl}/v2/orders/${squareOrderId}`, {
      method: "GET",
      headers: {
        "Square-Version": "2023-10-18",
        "Authorization": `Bearer ${accessToken}`,
      },
    });

    if (!getResp.ok) {
      const errorText = await getResp.text();
      throw new Error(`Failed to retrieve order: ${errorText}`);
    }

    const orderData = await getResp.json();
    const currentVersion = orderData.order?.version;

    if (!currentVersion) {
      throw new Error("Could not determine order version");
    }

    // Update order state to CANCELED
    const updateResp = await fetch(`${baseUrl}/v2/orders/${squareOrderId}`, {
      method: "PUT",
      headers: {
        "Square-Version": "2023-10-18",
        "Authorization": `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        order: {
          version: currentVersion,
          state: "CANCELED",
        },
      }),
    });

    if (!updateResp.ok) {
      const errorText = await updateResp.text();
      throw new Error(`Failed to cancel order: ${errorText}`);
    }

    // Update FreshPunk order to reflect cancellation
    await db.collection("orders").doc(orderId).update({
      [`squareOrders.${restaurantId}.status`]: "cancelled_in_square",
      [`squareOrders.${restaurantId}.cancelledAt`]: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    logger.info("Square order cancelled successfully", {
      orderId,
      restaurantId,
      squareOrderId,
    });
  } catch (error: any) {
    logger.error("Square order cancellation failed", {
      orderId,
      restaurantId,
      squareOrderId,
      error: error.message,
    });

    // Mark cancellation failure in Firestore
    await db.collection("orders").doc(orderId).update({
      [`squareOrders.${restaurantId}.cancellationFailed`]: true,
      [`squareOrders.${restaurantId}.cancellationError`]: error.message,
      updatedAt: FieldValue.serverTimestamp(),
    });

    throw error;
  }
}

// ============================================================================
// SAUSE DELIVERY INTEGRATION
// ============================================================================
// Sause delivery is integrated with the kitchen's Square account.
// When an order is created in Square with delivery details, the kitchen
// can mark it as ready in their Square dashboard, which automatically
// triggers Sause to dispatch a driver. No additional API integration needed.

/**
 * Forward order to specific Square restaurant
 * @param {string} orderId - The order ID
 * @param {string} restaurantId - The restaurant ID
 * @param {any[]} meals - Array of meals in the order
 * @param {any} orderData - Complete order data
 * @param {string} orderType - Type: "confirmed_order" or "prep_forecast"
 * @return {Promise<void>}
 */
async function forwardToSquareRestaurant(
  orderId: string,
  restaurantId: string,
  meals: any[],
  orderData: any,
  orderType = "confirmed_order"
) {
  const db = getFirestore();
  const {baseUrl} = getSquareConfig();
  try {
    // Build a cross-document idempotency key so multiple distinct order docs
    // representing the same logical meal/day don't create multiple Square orders.
    // Prefer a client-provided forwardKey; otherwise derive from stable fields.
    const normalize = (v: any) => String(v || "").toLowerCase().trim().replace(/[^a-z0-9_-]+/g, "-");
    const canonicalMealType = () => {
      const raw = normalize(orderData.mealType || orderData.meal_type || "meal");
      // strip trailing indexes like _0, -1, etc.
      const stripped = raw.replace(/[-_]*\d+$/g, "");
      if (stripped.includes("breakfast")) return "breakfast";
      if (stripped.includes("lunch")) return "lunch";
      if (stripped.includes("dinner")) return "dinner";
      return stripped || "meal";
    };
    const deriveDayKey = () => {
      // Prefer calendar date (UTC yyyymmdd) for stability across client naming
      const ts = orderData.deliveryDate?._seconds || orderData.scheduledDate?._seconds || undefined;
      if (ts) {
        const d = new Date(ts * 1000);
        const y = d.getUTCFullYear();
        const m = String(d.getUTCMonth() + 1).padStart(2, "0");
        const dd = String(d.getUTCDate()).padStart(2, "0");
        return `${y}${m}${dd}`;
      }
      if (orderData.dayName) return normalize(orderData.dayName);
      if (orderData.day) return normalize(orderData.day);
      return "unknown";
    };
    const userKey = normalize(orderData.userId || orderData.user_id || orderData.customerId || orderData.customer_id || "anon");
    const dayKey = deriveDayKey();
    const mealKey = canonicalMealType();
    const forwardBaseRoot = normalize(orderData.forwardKey) || `${userKey}_${dayKey}_${mealKey}`;
    const crossDocForwardKey = `${forwardBaseRoot}_${normalize(restaurantId)}`.slice(0, 120);

    // Emit structured diagnostics for the derived key
    logger.info("Forward key derived", {
      orderId,
      restaurantId,
      forwardBaseRoot,
      crossDocForwardKey,
      parts: {userKey, dayKey, mealKey},
    });

    // Cross-document idempotency guard 0: check global index first
    try {
      const idxRef = db.collection("order_forward_index").doc(crossDocForwardKey);
      const idxSnap = await idxRef.get();
      const idxData = idxSnap.data() as any;
      if (idxSnap.exists && idxData?.squareOrderId) {
        logger.info("Order already forwarded via index, skipping", {
          orderId,
          restaurantId,
          crossDocForwardKey,
          squareOrderId: idxData.squareOrderId,
        });
        // Best-effort: reflect the linkage onto this order document too
        try {
          await db.collection("orders").doc(orderId).update({
            [`squareOrders.${restaurantId}`]: {
              squareOrderId: idxData.squareOrderId,
              restaurantId,
              forwardedAt: FieldValue.serverTimestamp(),
              status: "forwarded",
              viaIndex: true,
            },
            updatedAt: FieldValue.serverTimestamp(),
          });
        } catch (_) {/* ignore */}
        return;
      }
    } catch (e) {
      logger.warn("Forward index pre-check failed; continuing", {orderId, restaurantId, crossDocForwardKey});
    }
    // Idempotency guard 1: check if this order was already forwarded for this restaurant
    try {
      const existing = await db.collection("orders").doc(orderId).get();
      const sq = (existing.data() as any)?.squareOrders;
      const existingForward = sq && typeof sq === "object" ? sq[restaurantId] : undefined;
      if (existingForward?.squareOrderId) {
        logger.info("Order already forwarded for restaurant, skipping", {
          orderId,
          restaurantId,
          squareOrderId: existingForward.squareOrderId,
        });
        return;
      }
      // If a forwarding lock exists and is recent (<2min) AND status is "forwarding", skip to avoid races
      // But if status is "forward_failed", allow retry by clearing the lock
      if (existingForward?.lockStartedAt?.seconds) {
        const lockAgeMs = Date.now() - existingForward.lockStartedAt.seconds * 1000;
        const currentStatus = existingForward.status;

        if (currentStatus === "forward_failed") {
          // Clear failed state to allow retry
          logger.info("Clearing forward_failed state for retry", {orderId, restaurantId, lockAgeMs});
          await db.collection("orders").doc(orderId).update({
            [`squareOrders.${restaurantId}.status`]: "retrying",
            [`squareOrders.${restaurantId}.lastError`]: FieldValue.delete(),
            [`squareOrders.${restaurantId}.lockStartedAt`]: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
          });
        } else if (currentStatus === "forwarding" && lockAgeMs < 120000) {
          logger.info("Forwarding lock active, skipping duplicate attempt", {
            orderId,
            restaurantId,
            lockAgeMs,
            status: currentStatus,
          });
          return;
        }
      }
    } catch (e) {
      // Non-fatal: continue without idempotency pre-check
      logger.warn("Idempotency pre-check failed; proceeding", {orderId, restaurantId});
    }

    // Set a pre-flight lock to signal forwarding in progress (best-effort)
    try {
      await db.collection("orders").doc(orderId).update({
        [`squareOrders.${restaurantId}.lockStartedAt`]: FieldValue.serverTimestamp(),
        [`squareOrders.${restaurantId}.status`]: "forwarding",
        updatedAt: FieldValue.serverTimestamp(),
      });
    } catch (e) {
      logger.warn("Failed to set forwarding lock; will proceed", {orderId, restaurantId});
    }

    // Cross-document idempotency guard 1: attempt to acquire index lock transactionally
    let acquiredIndexLock = false;
    const idxRef = db.collection("order_forward_index").doc(crossDocForwardKey);
    try {
      await db.runTransaction(async (t) => {
        const snap = await t.get(idxRef);
        const data = snap.data() as any;
        if (snap.exists && data?.squareOrderId) {
          // Another writer already created Square order for this logical key
          return;
        }
        // consider stale/empty as acquirable
        const stale = data?.lockStartedAt?.seconds ? (Date.now() - data.lockStartedAt.seconds * 1000) > 30000 : true;
        if (!snap.exists || stale) {
          t.set(idxRef, {
            orderId,
            restaurantId,
            baseRoot: forwardBaseRoot,
            key: crossDocForwardKey,
            status: "forwarding",
            lockStartedAt: FieldValue.serverTimestamp(),
            createdAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
          });
          acquiredIndexLock = true;
          return;
        }
        // If exists without squareOrderId, consider stale lock; proceed but don't flip acquired flag
      });
      if (!acquiredIndexLock) {
        logger.info("Forward index indicates prior or concurrent forwarding, skipping", {
          orderId,
          restaurantId,
          crossDocForwardKey,
        });
        return;
      }
      logger.info("Acquired forward index lock", {orderId, restaurantId, crossDocForwardKey});
    } catch (e) {
      logger.warn("Failed to acquire forward index lock; proceeding optimistically", {orderId, restaurantId, crossDocForwardKey});
    }
    // Get restaurant Square credentials
    const restaurantDoc = await db.collection("restaurant_partners").doc(restaurantId).get();
    if (!restaurantDoc.exists) return;

    const restaurant = restaurantDoc.data()!;
    // Skip check - orderForwardingEnabled defaults to true unless explicitly disabled
    if (restaurant.orderForwardingEnabled === false) {
      logger.info("Order forwarding disabled for restaurant", {restaurantId});
      return;
    }

    const accessToken = restaurant.squareAccessToken;
    const locationId = restaurant.squareLocationId || restaurant.squareMerchantId;

    // Create Square order with proper labeling
    const orderReference = orderType === "prep_forecast" ?
      `victus_forecast_${orderId}` :
      `victus_order_${orderId}`;

    // Square reference_id has 40 char limit - truncate if needed
    const truncatedReference = orderReference.length > 40 ?
      orderReference.substring(0, 40) :
      orderReference;

    const orderNote = orderType === "prep_forecast" ?
      `PREP FORECAST - Week of ${orderData.weekStart || "TBD"}` :
      `Victus Order #${orderId}`;

  // Use crossDocForwardKey for Square idempotency so distinct docs dedupe
  const idempotencyKey = `fp_${crossDocForwardKey}`.slice(0, 45);

    // Calculate prep time and delivery window for POS integration
    const deliveryTime = orderData.deliveryDate?._seconds ?
      new Date(orderData.deliveryDate._seconds * 1000) :
      new Date(Date.now() + 2 * 60 * 60 * 1000); // Default: 2 hours from now

    // Prep time: 30 minutes before delivery (ISO 8601 duration format)
    const prepTimeDuration = "PT30M";

    const squareOrder = {
      idempotency_key: idempotencyKey,
      order: {
        location_id: locationId,
        reference_id: truncatedReference,
        // OPEN state makes order appear in active POS queue
        state: "OPEN",
        source: {
          // Mark as third-party delivery so it appears in correct POS category
          name: orderType === "prep_forecast" ? "Victus Prep Forecast" : "Victus (Third Party Delivery)",
        },
        line_items: meals.map((meal) => ({
          name: meal.name,
          quantity: meal.quantity?.toString() || "1",
          catalog_object_id: meal.squareVariationId,
          // Always include a price for clearer dashboard visibility.
          // Prefer meal.price (USD dollars) -> cents, else priceCents/price_cents, else $10 fallback in sandbox.
          base_price_money: {
            amount: (typeof meal.price === "number" && !isNaN(meal.price)) ?
              Math.round(meal.price * 100) :
              (typeof meal.priceCents === "number" && !isNaN(meal.priceCents)) ?
                Math.round(meal.priceCents) :
                (typeof meal.price_cents === "number" && !isNaN(meal.price_cents)) ?
                  Math.round(meal.price_cents) :
                  1000, // $10 fallback for sandbox visibility
            currency: "USD",
          },
          modifiers: [],
          note: orderNote,
        })),
        // Use DELIVERY fulfillment type with customer details, address, and scheduled delivery time
        // This matches what restaurants see in Square (customer recipient, delivery address, delivery time)
        fulfillments: orderType === "prep_forecast" ? [] : [
          {
            type: "DELIVERY",
            state: "PROPOSED",
            delivery_details: {
              // Scheduled delivery triggers kitchen prep workflow in POS
              schedule_type: "SCHEDULED",
              deliver_at: deliveryTime.toISOString(),
              prep_time_duration: prepTimeDuration,
              recipient: {
                // Display name - address shown separately in delivery_address object
                display_name: orderData.customerName || orderData.userEmail || "Customer",
                phone_number: orderData.customerPhone || undefined,
                email_address: orderData.userEmail || undefined,
              },
              delivery_address: {
                // Extract address fields safely - handle both object and string formats
                address_line_1: (
                  (typeof orderData.deliveryAddress === "object" ?
                    orderData.deliveryAddress?.streetAddress :
                    orderData.deliveryAddress) || ""
                ).slice(0, 255),
                address_line_2: (
                  typeof orderData.deliveryAddress === "object" ?
                    (orderData.deliveryAddress?.streetAddress2 || "") :
                    ""
                ).slice(0, 255),
                locality: (
                  typeof orderData.deliveryAddress === "object" ?
                    (orderData.deliveryAddress?.city || "") :
                    ""
                ).slice(0, 255),
                administrative_district_level_1: (
                  typeof orderData.deliveryAddress === "object" ?
                    (orderData.deliveryAddress?.state || "") :
                    ""
                ).slice(0, 10),
                postal_code: (
                  typeof orderData.deliveryAddress === "object" ?
                    (orderData.deliveryAddress?.zipCode || "") :
                    ""
                ).slice(0, 10),
                country: "US",
              },
              note: `Customer: ${orderData.customerName || orderData.userEmail || "N/A"}. Phone: ${orderData.customerPhone || "N/A"}. Special instructions: ${orderData.specialInstructions || "None"}. Expected delivery: ${deliveryTime.toLocaleTimeString()}.`,
              // Set is_no_contact to enable contactless delivery option
              is_no_contact: orderData.contactlessDelivery || false,
            },
          },
        ],
        tickets: [
          {
            name: "Kitchen",
            // Note field appears on kitchen ticket printout
            note: `🚗 DELIVERY ORDER - Ready by ${deliveryTime.toLocaleTimeString()}\nCustomer: ${orderData.customerName || orderData.userEmail || "N/A"}\nPhone: ${orderData.customerPhone || "N/A"}\nDeliver to: ${orderData.deliveryAddress?.streetAddress || orderData.deliveryAddress || "TBD"}\nCity/State: ${orderData.deliveryAddress?.city || "TBD"}, ${orderData.deliveryAddress?.state || "TBD"} ${orderData.deliveryAddress?.zipCode || ""}\nSpecial instructions: ${orderData.specialInstructions || "None"}`,
          },
        ],
        metadata: {
          freshpunk_order_id: orderId,
          freshpunk_customer_id: orderData.userId,
          freshpunk_order_type: orderType,
          // Convert address object to string (Square metadata requires strings, not objects)
          delivery_address: typeof orderData.deliveryAddress === "object" ?
            `${orderData.deliveryAddress?.streetAddress || ""}, ${orderData.deliveryAddress?.city || ""}, ${orderData.deliveryAddress?.state || ""} ${orderData.deliveryAddress?.zipCode || ""}`.trim() :
            (orderData.deliveryAddress || ""),
          customer_name: orderData.customerName || orderData.userEmail || "",
        },
      },
    };

    // Log the address fields we're about to send to Square for debugging
    const delivAddressObj = squareOrder.order.fulfillments?.[0]?.delivery_details?.delivery_address;
    if (delivAddressObj) {
      logger.info("DEBUG: Delivery address being sent to Square", {
        orderId,
        address_line_1: delivAddressObj.address_line_1,
        address_line_2: delivAddressObj.address_line_2,
        locality: delivAddressObj.locality,
        administrative_district_level_1: delivAddressObj.administrative_district_level_1,
        postal_code: delivAddressObj.postal_code,
        country: delivAddressObj.country,
        sourceDeliveryAddress: orderData.deliveryAddress,
      });
    }

    // Send to Square
    const response = await fetch(`${baseUrl}/v2/orders`, {
      method: "POST",
      headers: {
        "Square-Version": "2023-10-18",
        "Authorization": `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(squareOrder),
    });

    if (response.ok) {
      const responseData = await response.json();
      const squareOrderId = responseData.order.id;
        const lineItemCount = (responseData.order?.line_items || []).length;
        const location_id = responseData.order?.location_id;
        const reference_id = responseData.order?.reference_id;
        let finalState = responseData.order?.state || "UNKNOWN";

      logger.info("Square order created", {orderId, restaurantId, squareOrderId, state: finalState});

      // Record external payment (Stripe) in Square so the order appears as paid in Dashboard
      // Approach: Create a Payment with source_id=EXTERNAL linked to the order_id.
      // This does not move money but marks the order paid and adds a tender.
      if (orderType !== "prep_forecast") {
        const totalAmount = Number(responseData.order?.total_money?.amount || 0);
        if (totalAmount > 0) {
          try {
              // Square Payments API idempotency_key max length is 45 chars
              const paymentIdem = `${idempotencyKey}_ext`.slice(0, 45);
            const createPaymentResp = await fetch(`${baseUrl}/v2/payments`, {
              method: "POST",
              headers: {
                "Square-Version": "2023-10-18",
                "Authorization": `Bearer ${accessToken}`,
                "Content-Type": "application/json",
              },
              body: JSON.stringify({
                idempotency_key: paymentIdem,
                location_id: locationId,
                amount_money: {amount: totalAmount, currency: "USD"},
                source_id: "EXTERNAL",
                external_details: {
                  type: "OTHER",
                  source: "FreshPunk (Stripe)",
                },
                order_id: squareOrderId,
                autocomplete: true,
              }),
            });

            if (createPaymentResp.ok) {
              const paymentData = await createPaymentResp.json();
              finalState = paymentData.payment?.order?.state || finalState;
              logger.info("Square external payment recorded", {
                orderId,
                restaurantId,
                squareOrderId,
                paymentId: paymentData.payment?.id,
                orderState: finalState,
                paidAmount: paymentData.payment?.amount_money?.amount,
              });

              // ==================== SAUSE DELIVERY INTEGRATION ====================
              // Sause is integrated with the kitchen's Square account
              // Kitchen marks order as ready in Square, Sause automatically dispatches driver
              logger.info("Order created in Square for kitchen dispatch", {
                orderId,
                restaurantId,
                squareOrderId,
                note: "Kitchen will mark ready in Square, triggering Sause dispatch",
              });
            } else {
              const text = await createPaymentResp.text().catch(() => "<no-body>");
              logger.error("Square CreatePayment (EXTERNAL) failed", {
                orderId,
                restaurantId,
                squareOrderId,
                status: createPaymentResp.status,
                error: text?.slice(0, 600),
              });
              // If insufficient scopes, annotate the order so ops knows to reauthorize
              try {
                const insufficient = createPaymentResp.status === 403 && /INSUFFICIENT_SCOPES|PAYMENTS_WRITE/i.test(text || "");
                if (insufficient) {
                  await db.collection("orders").doc(orderId).update({
                    [
                      `squareOrders.${restaurantId}.status`
                    ]: "forwarded_unpaid",
                    [
                      `squareOrders.${restaurantId}.lastError`
                    ]: "Square payments scope missing (PAYMENTS_WRITE). Reconnect Square via OAuth.",
                    [
                      `squareOrders.${restaurantId}.squareOrderId`
                    ]: squareOrderId,
                    updatedAt: FieldValue.serverTimestamp(),
                  });
                }
              } catch (_) {/* ignore annotation failure */}
            }
          } catch (e: any) {
            logger.error("Square CreatePayment threw", {orderId, restaurantId, squareOrderId, error: e?.message});
          }
        } else {
          logger.warn("Order total is zero or missing; skipping external payment record", {orderId, restaurantId, squareOrderId});
        }
      }

  // NOTE: Skip fulfillment completion and order closing for now
  // Orders in OPEN state with RESERVED fulfillments are visible in the dashboard
  // Attempting to close causes validation errors with fulfillment states
  // Controlled by env var FP_ENABLE_ORDER_FINALIZE; leave disabled unless explicitly enabled.
  if (process.env.FP_ENABLE_ORDER_FINALIZE === "1" && orderType !== "prep_forecast") {
        try {
          let currentVersion = responseData.order?.version;
          const fulfillments = responseData.order?.fulfillments || [];

          // Step 1: Update each fulfillment through state transitions: RESERVED -> PREPARED -> COMPLETED
          let allFulfillmentsUpdated = true;
          let lastFulfillmentError = "";

          for (const fulfillment of fulfillments) {
            // Transition through PREPARED state first (required by Square)
            try {
              // Step 1a: RESERVED -> PREPARED
              const prepareResp = await fetch(`${baseUrl}/v2/orders/${squareOrderId}`, {
                method: "PUT",
                headers: {
                  "Square-Version": "2023-10-18",
                  "Authorization": `Bearer ${accessToken}`,
                  "Content-Type": "application/json",
                },
                body: JSON.stringify({
                  order: {
                    version: currentVersion,
                    fulfillments: [{
                      uid: fulfillment.uid,
                      state: "PREPARED",
                    }],
                  },
                  idempotency_key: `${idempotencyKey}_prepare_${fulfillment.uid}`,
                }),
              });

              if (prepareResp.ok) {
                const prepareData = await prepareResp.json();
                currentVersion = prepareData.order?.version || currentVersion;
                logger.info("Fulfillment transitioned to PREPARED", {
                  orderId,
                  restaurantId,
                  squareOrderId,
                  fulfillmentUid: fulfillment.uid,
                });
              } else {
                const errText = await prepareResp.text().catch(() => "<no-body>");
                allFulfillmentsUpdated = false;
                lastFulfillmentError = `PREPARED transition failed: ${errText?.slice(0, 300)}`;
                logger.error("Fulfillment PREPARED transition failed", {
                  orderId,
                  restaurantId,
                  squareOrderId,
                  fulfillmentUid: fulfillment.uid,
                  status: prepareResp.status,
                  error: errText?.slice(0, 500),
                });
                continue;
              }

              // Step 1b: PREPARED -> COMPLETED
              const completeResp = await fetch(`${baseUrl}/v2/orders/${squareOrderId}`, {
                method: "PUT",
                headers: {
                  "Square-Version": "2023-10-18",
                  "Authorization": `Bearer ${accessToken}`,
                  "Content-Type": "application/json",
                },
                body: JSON.stringify({
                  order: {
                    version: currentVersion,
                    fulfillments: [{
                      uid: fulfillment.uid,
                      state: "COMPLETED",
                    }],
                  },
                  idempotency_key: `${idempotencyKey}_complete_${fulfillment.uid}`,
                }),
              });

              if (completeResp.ok) {
                const completeData = await completeResp.json();
                currentVersion = completeData.order?.version || currentVersion;
                logger.info("Fulfillment transitioned to COMPLETED", {
                  orderId,
                  restaurantId,
                  squareOrderId,
                  fulfillmentUid: fulfillment.uid,
                  newVersion: currentVersion,
                });
              } else {
                const errText = await completeResp.text().catch(() => "<no-body>");
                allFulfillmentsUpdated = false;
                lastFulfillmentError = `COMPLETED transition failed: ${errText?.slice(0, 300)}`;
                logger.error("Fulfillment COMPLETED transition failed", {
                  orderId,
                  restaurantId,
                  squareOrderId,
                  fulfillmentUid: fulfillment.uid,
                  status: completeResp.status,
                  error: errText?.slice(0, 500),
                });
              }
            } catch (e: any) {
              allFulfillmentsUpdated = false;
              lastFulfillmentError = e?.message || "Unknown error";
              logger.error("Fulfillment update threw", {
                orderId,
                restaurantId,
                squareOrderId,
                fulfillmentUid: fulfillment.uid,
                error: e?.message,
              });
            }
          } // If any fulfillment update failed, don't try to close - mark as failed and stop
          if (!allFulfillmentsUpdated) {
            logger.error("Cannot close order - fulfillment updates failed", {
              orderId,
              restaurantId,
              squareOrderId,
              lastError: lastFulfillmentError,
            });

            try {
              await db.collection("orders").doc(orderId).update({
                [`squareOrders.${restaurantId}.status`]: "forward_failed",
                [`squareOrders.${restaurantId}.lastError`]: `Fulfillment update failed: ${lastFulfillmentError}`,
                [`squareOrders.${restaurantId}.squareOrderId`]: squareOrderId,
                updatedAt: FieldValue.serverTimestamp(),
              });
            } catch (_) {/* ignore */}

            return;
          }

          // Step 2: Close the order now that fulfillments are COMPLETED
          const closeResp = await fetch(`${baseUrl}/v2/orders/${squareOrderId}/close`, {
            method: "POST",
            headers: {
              "Square-Version": "2023-10-18",
              "Authorization": `Bearer ${accessToken}`,
              "Content-Type": "application/json",
            },
            body: JSON.stringify({version: currentVersion}),
          });

          if (closeResp.ok) {
            const closeData = await closeResp.json().catch(() => ({} as any));
            finalState = closeData.order?.state || finalState;
            logger.info("Square order closed successfully", {orderId, restaurantId, squareOrderId, state: finalState});
          } else {
            const errText = await closeResp.text().catch(() => "<no-body>");
            logger.error("Square order close failed", {
              orderId,
              restaurantId,
              squareOrderId,
              status: closeResp.status,
              error: errText?.slice(0, 500),
            });

            // Mark as failed so user can see the error
            try {
              await db.collection("orders").doc(orderId).update({
                [`squareOrders.${restaurantId}.status`]: "forward_failed",
                [`squareOrders.${restaurantId}.lastError`]: errText?.slice(0, 500) || "Close order failed",
                [`squareOrders.${restaurantId}.squareOrderId`]: squareOrderId, // Store ID even on failure
                updatedAt: FieldValue.serverTimestamp(),
              });
            } catch (_) {/* ignore */}

            // Don't proceed to mark as forwarded
            return;
          }
        } catch (e: any) {
          logger.error("Square order finalization threw", {orderId, restaurantId, squareOrderId, error: e?.message});

          // Mark as failed
          try {
            await db.collection("orders").doc(orderId).update({
              [`squareOrders.${restaurantId}.status`]: "forward_failed",
              [`squareOrders.${restaurantId}.lastError`]: e?.message || "Finalization error",
              updatedAt: FieldValue.serverTimestamp(),
            });
          } catch (_) {/* ignore */}

          return;
        }
      }

      // Update FreshPunk order with Square order ID
      await db.collection("orders").doc(orderId).update({
        [`squareOrders.${restaurantId}`]: {
          squareOrderId,
          restaurantId,
          forwardedAt: FieldValue.serverTimestamp(),
          status: "forwarded",
        },
        updatedAt: FieldValue.serverTimestamp(),
      });

      // Update forward index to reflect success
      try {
        await db.collection("order_forward_index").doc(crossDocForwardKey).set({
          orderId,
          restaurantId,
          baseRoot: forwardBaseRoot,
          key: crossDocForwardKey,
          squareOrderId,
          status: "forwarded",
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
      } catch (e) {
        logger.warn("Failed to update forward index after success", {orderId, restaurantId, crossDocForwardKey});
      }

      logger.info("Order forwarded to Square", {
        orderId,
        restaurantId,
        squareOrderId,
        orderType,
        location_id,
        reference_id,
        lineItemCount,
        state: finalState,
        idempotency_key: idempotencyKey,
      });
    } else {
      const errorText = await response.text();

      // Check if this is an idempotency conflict (Square already has an order with this key)
      // In that case, we should treat it as success and extract the existing order ID
      let errorData: any = null;
      try {
        errorData = JSON.parse(errorText);
      } catch {
        errorData = {errors: [{detail: errorText}]};
      }

      // Square sometimes returns the existing order in the response even on conflict
      // Check if we have an order object in the error response
      if (errorData?.order?.id) {
        const existingSquareOrderId = errorData.order.id;
        logger.info("Square idempotency match: order already exists", {
          orderId,
          restaurantId,
          squareOrderId: existingSquareOrderId,
          idempotencyKey,
        });

        // Treat as success - update Firestore with the existing Square order ID
        await db.collection("orders").doc(orderId).update({
          [`squareOrders.${restaurantId}`]: {
            squareOrderId: existingSquareOrderId,
            restaurantId,
            forwardedAt: FieldValue.serverTimestamp(),
            status: "forwarded",
            idempotencyMatch: true,
          },
          updatedAt: FieldValue.serverTimestamp(),
        });

        await db.collection("order_forward_index").doc(crossDocForwardKey).set({
          orderId,
          restaurantId,
          baseRoot: forwardBaseRoot,
          key: crossDocForwardKey,
          squareOrderId: existingSquareOrderId,
          status: "forwarded",
          idempotencyMatch: true,
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});

        return; // Success path
      }

      // Otherwise, this is a real error
      logger.error("Square order creation failed", {
        orderId,
        restaurantId,
        orderType,
        error: errorText,
        idempotency_key: idempotencyKey,
      });
      // Mark failure state (non-terminal; can retry later)
      try {
        await db.collection("orders").doc(orderId).update({
          [`squareOrders.${restaurantId}.status`]: "forward_failed",
          [`squareOrders.${restaurantId}.lastError`]: errorText?.slice(0, 500) || "unknown",
          updatedAt: FieldValue.serverTimestamp(),
        });
      } catch (_) {/* ignore */}

      // Reflect failure into forward index so retriers can see reason
      try {
        await db.collection("order_forward_index").doc(crossDocForwardKey).set({
          orderId,
          restaurantId,
          baseRoot: forwardBaseRoot,
          key: crossDocForwardKey,
          status: "forward_failed",
          lastError: (errorText || "").slice(0, 500),
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
      } catch (_) {/* ignore */}
    }
  } catch (error: any) {
    logger.error("Square order forwarding failed", {
      orderId,
      restaurantId,
      orderType,
      error: error.message,
    });
    try {
      await db.collection("orders").doc(orderId).update({
        [`squareOrders.${restaurantId}.status`]: "forward_exception",
        [`squareOrders.${restaurantId}.lastError`]: error.message?.slice(0, 500) || "exception",
        updatedAt: FieldValue.serverTimestamp(),
      });
    } catch (_) {/* ignore */}
    try {
      // Recompute forward index key locally to avoid referencing out-of-scope vars
      const normalizeLocal = (v: any) => String(v || "").toLowerCase().trim().replace(/[^a-z0-9_-]+/g, "-");
      const deriveDayLocal = () => {
        if (orderData.dayName) return normalizeLocal(orderData.dayName);
        if (orderData.day) return normalizeLocal(orderData.day);
        const ts = orderData.deliveryDate?._seconds || orderData.deliveryDate?._seconds;
        if (ts) {
          const d = new Date(ts * 1000);
          const y = d.getUTCFullYear();
          const m = String(d.getUTCMonth() + 1).padStart(2, "0");
          const dd = String(d.getUTCDate()).padStart(2, "0");
          return `${y}${m}${dd}`;
        }
        return "unknown";
      };
      const baseRootLocal = normalizeLocal(orderData.forwardKey) ||
        `${normalizeLocal(orderData.userId)}_${deriveDayLocal()}_${normalizeLocal(orderData.mealType || orderData.meal_type || "meal")}`;
      const idxKeyLocal = `${baseRootLocal}_${normalizeLocal(restaurantId)}`.slice(0, 120);
      await db.collection("order_forward_index").doc(idxKeyLocal).set({
        orderId,
        restaurantId,
        baseRoot: baseRootLocal,
        key: idxKeyLocal,
        status: "forward_exception",
        lastError: error.message?.slice(0, 500) || "exception",
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
    } catch (_) {/* ignore */}
  }
}

// ============================================================================
// RESTAURANT SCHEDULE FILTERING & COMMUNICATION
// ============================================================================

/**
 * Send filtered weekly prep schedules to restaurants
 * Only sends schedule parts that use their specific meals
 */
export const sendWeeklyPrepSchedules = onCall(
  {
    memory: "1GiB",
    timeoutSeconds: 300,
    region: "us-east4",
  },
  async (request: any) => {
  try {
    const db = getFirestore();
    const {auth} = request;
    if (!auth) {
      throw new HttpsError("unauthenticated", "Authentication required");
    }

    const {weekStartDate} = request.data;
    if (!weekStartDate) {
      throw new HttpsError("invalid-argument", "Week start date required");
    }

    // Get all active restaurant partners
    const restaurantsSnapshot = await db.collection("restaurant_partners")
      .where("status", "==", "active")
      .get();

    const results = [];

    for (const restaurantDoc of restaurantsSnapshot.docs) {
      const restaurant = restaurantDoc.data();
      const restaurantId = restaurantDoc.id;

      // Get restaurant's menu items
      const mealsSnapshot = await db.collection("meals")
        .where("restaurantId", "==", restaurantId)
        .get();

      const restaurantMealIds = mealsSnapshot.docs.map((doc) => doc.id);

      if (restaurantMealIds.length === 0) continue;

      // Get scheduled orders for the week that include restaurant's meals
      const weekStart = new Date(weekStartDate);
      const weekEnd = new Date(weekStart);
      weekEnd.setDate(weekEnd.getDate() + 7);

      const scheduledOrdersSnapshot = await db.collection("scheduled_orders")
        .where("scheduledDate", ">=", weekStart)
        .where("scheduledDate", "<", weekEnd)
        .get();

      // Filter and organize relevant schedule items
      const relevantSchedule = {
        restaurantName: restaurant.restaurantName,
        weekStart: weekStartDate,
        prepItems: [] as any[],
        totalEstimatedOrders: 0,
      };

      const mealQuantities = new Map<string, number>();

      scheduledOrdersSnapshot.docs.forEach((doc) => {
        const order = doc.data();
        const meals = order.meals || [];

        meals.forEach((meal: any) => {
          if (restaurantMealIds.includes(meal.id)) {
            const key = `${meal.id}-${meal.name}`;
            mealQuantities.set(key, (mealQuantities.get(key) || 0) + 1);
          }
        });
      });

      // Convert to prep schedule format
      mealQuantities.forEach((quantity, key) => {
        const [mealId, mealName] = key.split("-", 2);
        relevantSchedule.prepItems.push({
          mealId,
          mealName,
          estimatedQuantity: quantity,
          mealType: categorizeMealTime(mealName),
        });
        relevantSchedule.totalEstimatedOrders += quantity;
      });

      // Only send if restaurant has relevant items
      if (relevantSchedule.prepItems.length > 0) {
        // Send notification to restaurant
        await sendRestaurantPrepNotification(restaurantId, restaurant, relevantSchedule);
        results.push({
          restaurantId,
          restaurantName: restaurant.restaurantName,
          itemsSent: relevantSchedule.prepItems.length,
          totalQuantity: relevantSchedule.totalEstimatedOrders,
        });
      }
    }

    logger.info("Weekly prep schedules sent", {
      weekStart: weekStartDate,
      restaurantsNotified: results.length,
    });

    return {
      success: true,
      weekStart: weekStartDate,
      restaurantsNotified: results.length,
      results,
      message: `Sent prep schedules to ${results.length} restaurants`,
    };
  } catch (error: any) {
    logger.error("Weekly prep schedule sending failed", error);
    throw new HttpsError("internal", `Failed to send prep schedules: ${error.message}`);
  }
});

/**
 * Send prep notification to specific restaurant
 * @param {string} restaurantId - The restaurant partner ID
 * @param {any} restaurant - The restaurant data object
 * @param {any} schedule - The filtered prep schedule data
 * @return {Promise<void>}
 */
async function sendRestaurantPrepNotification(restaurantId: string, restaurant: any, schedule: any) {
  const db = getFirestore();

  try {
    // Store prep schedule in restaurant's notifications
    await db.collection("restaurant_notifications").add({
      restaurantId,
      type: "weekly_prep_schedule",
      title: `Prep Schedule for Week of ${schedule.weekStart}`,
      message: `${schedule.totalEstimatedOrders} estimated orders requiring your meals`,
      data: {
        weekStart: schedule.weekStart,
        prepItems: schedule.prepItems,
        totalEstimatedOrders: schedule.totalEstimatedOrders,
      },
      priority: "medium",
      isRead: false,
      createdAt: FieldValue.serverTimestamp(),
    });

    // Send email notification (simplified)
    if (restaurant.contactEmail) {
      const emailContent = generatePrepScheduleEmail(restaurant, schedule);
      // In production, integrate with your email service
      logger.info("Prep schedule email queued", {
        restaurantId,
        email: restaurant.contactEmail,
        itemCount: schedule.prepItems.length,
        emailPreview: emailContent.substring(0, 100),
      });
    }

    logger.info("Prep notification sent", {
      restaurantId,
      restaurantName: restaurant.restaurantName,
      itemCount: schedule.prepItems.length,
    });
  } catch (error: any) {
    logger.error("Failed to send prep notification", {
      restaurantId,
      error: error.message,
    });
    throw error;
  }
}

/**
 * Generate clean, organized prep schedule email
 * @param {any} restaurant - The restaurant partner data
 * @param {any} schedule - The prep schedule data
 * @return {string} The formatted email content
 */
function generatePrepScheduleEmail(restaurant: any, schedule: any): string {
  const prepByMealType = schedule.prepItems.reduce((acc: any, item: any) => {
    const mealType = item.mealType || "Other";
    if (!acc[mealType]) acc[mealType] = [];
    acc[mealType].push(item);
    return acc;
  }, {});

  let emailContent = `
📋 **Weekly Prep Schedule - ${restaurant.restaurantName}**
Week of: ${schedule.weekStart}
Total Estimated Orders: ${schedule.totalEstimatedOrders}

`;

  Object.entries(prepByMealType).forEach(([mealType, items]: [string, any]) => {
    emailContent += `
🍽️ **${mealType.charAt(0).toUpperCase() + mealType.slice(1)}:**
`;
    items.forEach((item: any) => {
      emailContent += `   • ${item.mealName}: ${item.estimatedQuantity} portions\n`;
    });
    emailContent += "\n";
  });

  emailContent += `
📝 **Important Notes:**
- These are estimates based on scheduled orders
- Actual confirmed orders will be sent individually
- Contact FreshPunk support if you have questions

Best regards,
FreshPunk Team
`;

  return emailContent;
}

/**
 * Categorize meal by time of day for better organization
 * @param {string} mealName - The name of the meal to categorize
 * @return {string} The meal time category (breakfast, lunch, dinner, other)
 */
function categorizeMealTime(mealName: string): string {
  const name = mealName.toLowerCase();

  if (name.includes("breakfast") || name.includes("morning") ||
      name.includes("pancake") || name.includes("omelette") ||
      name.includes("cereal") || name.includes("toast")) {
    return "breakfast";
  }

  if (name.includes("lunch") || name.includes("sandwich") ||
      name.includes("salad") || name.includes("soup")) {
    return "lunch";
  }

  if (name.includes("dinner") || name.includes("steak") ||
      name.includes("pasta") || name.includes("roast")) {
    return "dinner";
  }

  return "other";
}

/**
 * Get restaurant notifications (for restaurant portal)
 */
export const getRestaurantNotifications = onCall(
  {
    memory: "512MiB",
    timeoutSeconds: 60,
    region: "us-east4",
  },
  async (request: any) => {
  try {
    const db = getFirestore();
    const {auth} = request;
    if (!auth) {
      throw new HttpsError("unauthenticated", "Authentication required");
    }

    const {restaurantId} = request.data;
    if (!restaurantId) {
      throw new HttpsError("invalid-argument", "Restaurant ID required");
    }

    // Verify restaurant ownership
    const restaurantDoc = await db.collection("restaurant_partners").doc(restaurantId).get();
    if (!restaurantDoc.exists || restaurantDoc.data()?.userId !== auth.uid) {
      throw new HttpsError("permission-denied", "Access denied");
    }

    // Get recent notifications
    const notificationsSnapshot = await db.collection("restaurant_notifications")
      .where("restaurantId", "==", restaurantId)
      .orderBy("createdAt", "desc")
      .limit(50)
      .get();

    const notifications = notificationsSnapshot.docs.map((doc) => ({
      id: doc.id,
      ...doc.data(),
    }));

    return {
      success: true,
      notifications,
      unreadCount: notifications.filter((n: any) => !n.isRead).length,
    };
  } catch (error: any) {
    logger.error("Failed to get restaurant notifications", error);
    throw new HttpsError("internal", `Failed to get notifications: ${error.message}`);
  }
});

// ============================================================================
// UTILITY FUNCTIONS
// ============================================================================

/**
 * Calculate name similarity score between two strings (0-1)
 * Uses combination of exact match, word overlap, and Levenshtein distance
 * @param {string} str1 - First string to compare
 * @param {string} str2 - Second string to compare
 * @return {number} Similarity score from 0 to 1
 */
function calculateNameSimilarity(str1: string, str2: string): number {
  const s1 = str1.toLowerCase().trim();
  const s2 = str2.toLowerCase().trim();

  // Exact match
  if (s1 === s2) return 1.0;

  // Remove common food words that don't help matching
  const commonWords = ["bowl", "plate", "sandwich", "wrap", "salad", "meal", "fresh", "grilled"];
  let clean1 = s1;
  let clean2 = s2;
  for (const word of commonWords) {
    clean1 = clean1.replace(new RegExp(`\\b${word}\\b`, "g"), "").trim();
    clean2 = clean2.replace(new RegExp(`\\b${word}\\b`, "g"), "").trim();
  }

  // If one contains the other after cleaning
  if (clean1.includes(clean2) || clean2.includes(clean1)) return 0.85;

  // Word overlap score
  const words1 = new Set(s1.split(/\s+/).filter((w) => w.length > 2));
  const words2 = new Set(s2.split(/\s+/).filter((w) => w.length > 2));
  const intersection = new Set([...words1].filter((w) => words2.has(w)));
  const union = new Set([...words1, ...words2]);
  const overlapScore = union.size > 0 ? intersection.size / union.size : 0;

  // Simple Levenshtein distance for character similarity
  const maxLen = Math.max(s1.length, s2.length);
  const distance = levenshteinDistance(s1, s2);
  const charScore = 1 - (distance / maxLen);

  // Weighted combination: favor word overlap
  return (overlapScore * 0.7) + (charScore * 0.3);
}

/**
 * Calculate Levenshtein distance between two strings
 * @param {string} str1 - First string
 * @param {string} str2 - Second string
 * @return {number} Edit distance between strings
 */
function levenshteinDistance(str1: string, str2: string): number {
  const matrix: number[][] = [];

  for (let i = 0; i <= str2.length; i++) {
    matrix[i] = [i];
  }
  for (let j = 0; j <= str1.length; j++) {
    matrix[0][j] = j;
  }

  for (let i = 1; i <= str2.length; i++) {
    for (let j = 1; j <= str1.length; j++) {
      if (str2.charAt(i - 1) === str1.charAt(j - 1)) {
        matrix[i][j] = matrix[i - 1][j - 1];
      } else {
        matrix[i][j] = Math.min(
          matrix[i - 1][j - 1] + 1, // substitution
          matrix[i][j - 1] + 1, // insertion
          matrix[i - 1][j] + 1 // deletion
        );
      }
    }
  }

  return matrix[str2.length][str1.length];
}

// ============================================================================
// SQUARE WEBHOOK HANDLER FOR POS ORDERS
// ============================================================================

/**
 * Handle Square Webhook events for order.created and order.updated
 * Automatically routes POS orders to the kitchen's Square account for dispatch via Sause
 */
export const squareWebhookHandler = onRequest(
  {secrets: [SQUARE_APPLICATION_SECRET, SQUARE_APPLICATION_ID, SQUARE_ENV]},
  async (req: any, res: any) => {
    try {
      const db = getFirestore();
      const {applicationSecret} = getSquareConfig();

      // Verify webhook signature
      const signature = req.get("X-Square-Hmac-SHA256");
      const body = req.rawBody || JSON.stringify(req.body);

      // Parse request body first
      let event: any;
      try {
        event = typeof req.body === "string" ? JSON.parse(req.body) : req.body;
      } catch (e) {
        logger.error("Failed to parse webhook body", {error: e});
        return res.status(400).send("Bad request: Invalid JSON");
      }

      // Check signature if present (production events always have it)
      if (signature && applicationSecret) {
        const hash = crypto
          .createHmac("sha256", applicationSecret)
          .update(body)
          .digest("base64");

        const signatureValid = hash === signature;
        if (!signatureValid) {
          logger.warn("Webhook signature verification failed", {
            received: signature,
            computed: hash,
            match: false,
            eventType: event.type,
          });
          // Don't reject - Square test events may not have valid signatures
        } else {
          logger.info("Webhook signature verified successfully");
        }
      } else if (!signature) {
        // Test event from Square Dashboard - no signature
        logger.info("Webhook received without signature (likely test event)", {
          eventType: event.type,
        });
      } else {
        logger.error("Square application secret not configured");
        return res.status(500).send("Server error: Secret not configured");
      }

      const eventId = event.id || `test_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
      const eventType = event.type;

      logger.info("Square webhook received", {eventId, eventType});

      // Deduplicate: check if we've already processed this webhook
      if (!eventId) {
        logger.error("Cannot process webhook without eventId");
        return res.status(400).send("Bad request: Missing event ID");
      }

      const eventRef = db.collection("square_webhook_events").doc(eventId);
      const eventSnap = await eventRef.get();

      if (eventSnap.exists) {
        logger.info("Webhook event already processed (deduplicated)", {eventId, eventType});
        return res.status(200).send({received: true});
      }

      // Record webhook event to prevent duplicates
      await eventRef.set({
        eventType,
        processedAt: FieldValue.serverTimestamp(),
        data: event.data,
      });

      // Handle different event types
      if (eventType === "order.created" || eventType === "order.updated") {
        // Handle both production events (event.data.object.order)
        // and test events (event.data.object.order_created)
        const order = event.data?.object?.order || event.data?.object?.order_created;

        if (!order) {
          logger.warn("Order webhook missing order data", {
            eventId,
            eventType,
            eventDataKeys: Object.keys(event.data || {}),
            eventDataObjectKeys: Object.keys(event.data?.object || {}),
          });
          return res.status(200).send({received: true});
        }

        const squareOrderId = order.id;
        const locationId = order.location_id;
        const customerEmail = order.customer_id;

        // Check if order has delivery requirements
        const fulfillments = order.fulfillments || [];
        const hasDeliveryFulfillment = fulfillments.some((f: any) => f.type === "DELIVERY");

        if (!hasDeliveryFulfillment) {
          logger.info("Order webhook: No delivery fulfillment, skipping", {squareOrderId});
          return res.status(200).send({received: true});
        }

        // Extract delivery address
        const delivery = fulfillments.find((f: any) => f.type === "DELIVERY");
        const deliveryAddress = delivery?.delivery_details?.recipient?.address;

        if (!deliveryAddress) {
          logger.warn("Order webhook: No delivery address found", {squareOrderId});
          return res.status(200).send({received: true});
        }

        // Get total amount
        const totalAmount = Number(order.total_money?.amount || 0);

        if (totalAmount <= 0) {
          logger.warn("Order webhook: Invalid or zero total", {squareOrderId, totalAmount});
          return res.status(200).send({received: true});
        }

        // Extract line items/meals
        const meals = (order.line_items || []).map((item: any) => ({
          name: item.name || "Item",
          description: item.note || "",
          price: Number(item.gross_sales_money?.amount || 0) / 100, // Convert cents to dollars
        }));

        // Build order data for Sause delivery (via kitchen's Square account)
        const orderData = {
          customerName: delivery?.delivery_details?.recipient?.display_name || "Customer",
          customerPhone: delivery?.delivery_details?.recipient?.phone_number || "+1-555-0000",
          specialInstructions: delivery?.delivery_details?.notes || "",
          deliveryAddress: {
            streetAddress: deliveryAddress.address_line_1 || "",
            city: deliveryAddress.city || "",
            state: deliveryAddress.administrative_district_level_1 || "",
            zipCode: deliveryAddress.postal_code || "",
          },
        };

        logger.info("Processing Square POS order for DoorDash delivery", {
          squareOrderId,
          locationId,
          totalAmount: `$${(totalAmount / 100).toFixed(2)}`,
          meals: meals.length,
        });

        // Sause delivery handled by kitchen through their Square integration
        // Kitchen marks order as ready in Square, Sause automatically dispatches
        logger.info("Square POS order ready for kitchen dispatch via Sause", {
          squareOrderId,
          locationId,
          note: "Kitchen will mark ready in Square, triggering Sause dispatch",
        });

        // Store order for tracking (without DoorDash integration)
        await db.collection("square_pos_orders").doc(squareOrderId).set(
          {
            squareOrderId,
            locationId,
            totalAmount,
            customerEmail,
            meals,
            orderData,
            processedAt: FieldValue.serverTimestamp(),
            status: "order_created",
            deliveryProvider: "sause",
            note: "Kitchen manages dispatch through their Square/Sause integration",
          },
          {merge: true}
        );
      }

      // Always return 200 to acknowledge receipt
      res.status(200).send({received: true});
    } catch (error: any) {
      logger.error("Square webhook handler error", {error: error.message});
      // Still return 200 to prevent Square from retrying indefinitely
      res.status(200).send({error: error.message});
    }
  }
);

// ============================================================================
// SAUSE DELIVERY MANAGEMENT
// ============================================================================
// Sause delivery is handled entirely through the kitchen's Square integration
// No polling or webhooks needed from our backend
// Kitchen marks orders as ready in Square → Sause automatically dispatches driver

