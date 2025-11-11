/**
 * Square Integration Functions
 * Handles restaurant partner onboarding, menu sync, and order forwarding
 */

import {onCall, onRequest, HttpsError} from "firebase-functions/v2/https";
import {onDocumentCreated} from "firebase-functions/v2/firestore";
import * as logger from "firebase-functions/logger";
import {getFirestore, FieldValue} from "firebase-admin/firestore";
import {defineSecret} from "firebase-functions/params";

// Firebase is initialized in index.ts - no need to initialize here

// Square API configuration - use Firebase Secret Manager
const SQUARE_APPLICATION_ID = defineSecret("SQUARE_APPLICATION_ID");
const SQUARE_APPLICATION_SECRET = defineSecret("SQUARE_APPLICATION_SECRET");
const SQUARE_ENV = defineSecret("SQUARE_ENV");

function getSquareConfig() {
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

    // Request the minimal scopes we actually use:
    // - MERCHANT_PROFILE_READ: read merchant details
    // - PAYMENTS_READ: optional for reconciling payments
  // - ITEMS_READ: required to read Catalog items (/v2/catalog/*)
    // - INVENTORY_READ: required to read inventory counts
    // - ORDERS_READ: required to query/search orders
    // - ORDERS_WRITE: required to create orders when forwarding
    // Note: Request only documented Square scopes; avoid non-documented ones to prevent
    // "Invalid value for parameter `scope`" errors on the consent page.
    const scopes = [
      "MERCHANT_PROFILE_READ",
      "PAYMENTS_READ",
      "ITEMS_READ",
      // Inventory + Orders
      "INVENTORY_READ",
      "ORDERS_READ",
      "ORDERS_WRITE",
    ];

    // Build URL with explicit encoding
    const scopeStr = scopes.join(" ");
    const redirectUri = "https://completesquareoauthhttp-zp46qvhbwa-uk.a.run.app";

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
    <title>Square OAuth Test</title>
    <style>
      body { font-family: system-ui, -apple-system, Segoe UI, Roboto, Arial; max-width: 720px; margin: 40px auto; padding: 0 16px; }
      h1 { font-size: 24px; }
      label { display: block; margin: 12px 0 6px; }
      input { width: 100%; padding: 10px 12px; border: 1px solid #ccc; border-radius: 6px; }
      button { margin-top: 16px; padding: 10px 16px; border: 0; background: #2563eb; color: white; border-radius: 6px; cursor: pointer; }
      .status { margin-top: 16px; font-size: 14px; color: #374151; }
      .note { margin-top: 24px; color: #6b7280; font-size: 12px; }
      .card { border: 1px solid #e5e7eb; border-radius: 8px; padding: 16px; }
    </style>
  </head>
  <body>
  <h1>🟦 Square OAuth Test Page</h1>
  <p style="color:#6b7280">If you see this, the page rendered successfully.</p>
    <p>Use this page to connect a restaurant's Square account in Sandbox.</p>
    <div class="card">
      <label for="name">Restaurant name</label>
      <input id="name" placeholder="Green Blend" />
      <label for="email">Contact email</label>
      <input id="email" placeholder="owner@example.com" />
      <label for="phone">Contact phone (optional)</label>
      <input id="phone" placeholder="(555) 123-4567" />
      <button id="connect">Connect Square Account →</button>
      <div class="status" id="status"></div>
      <div class="note">After authorizing with Square, you'll be redirected to our callback which will display a success page.</div>
    </div>

    <script>
      console.log('Square OAuth Test Page loaded at', new Date().toISOString());
      // Derive initiateSquareOAuthHttp endpoint dynamically so we don't hard-code
      // the deployment hash or region. Each HTTPS function is a separate Cloud Run
      // service named <function>-<hash>.run.app. We can take the current origin
      // (for squareOAuthTestPage) and replace the function name prefix with the
      // initiate function's name. If the replacement fails (unexpected name), we
      // fall back to a manually provided host via ?initHost=<url> for debugging.
      const OAUTH_ENDPOINT = (() => {
        try {
          const origin = window.location.origin;
          const paramOverride = new URLSearchParams(window.location.search).get('initHost');
          if (paramOverride) return paramOverride; // allow explicit override
          // Build from current URL, swapping only the function prefix in the host
          // e.g. squareoauthtestpage-<hash>-ue.a.run.app -> initiatesquareoauthhttp-<hash>-ue.a.run.app
          const u = new URL(origin);
          if (u.host.startsWith('squareoauthtestpage-')) {
            const host = u.host.replace(/^squareoauthtestpage-/, 'initiatesquareoauthhttp-');
            return u.protocol + '//' + host;
          }
          // Fallback: generic string replace (works even if service name moved)
          return origin.replace('squareoauthtestpage', 'initiatesquareoauthhttp');
        } catch (e) {
          console.warn('Dynamic OAUTH_ENDPOINT derivation failed, please supply ?initHost=<url>', e);
          return 'https://initiatesquareoauthhttp-zp46qvhbwa-uc.a.run.app'; // fallback to last known
        }
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
            // Show OAuth URL with copy button before redirect
            status.innerHTML = 
              '<div style="margin-bottom:12px"><strong>OAuth URL Generated!</strong></div>' +
              '<div style="margin-bottom:8px">If the Square page appears blank, try opening in a new tab or copy this URL and paste it directly into the address bar:</div>' +
              '<textarea readonly style="width:100%;height:80px;font-size:11px;padding:8px;margin-bottom:8px">' + data.oauthUrl + '</textarea>' +
              '<div style="display:flex;gap:8px;flex-wrap:wrap;margin-bottom:8px">' +
              '<button onclick="navigator.clipboard.writeText(\\'' + data.oauthUrl.replace(/'/g, "\\\\'") + '\\');alert(\\'Copied!\\');" style="padding:8px 16px;background:#28a745;color:white;border:none;border-radius:4px;cursor:pointer">Copy URL</button>' +
              '<button onclick="window.location.href=\\'' + data.oauthUrl.replace(/'/g, "\\\\'") + '\\';" style="padding:8px 16px;background:#007bff;color:white;border:none;border-radius:4px;cursor:pointer">Continue (same tab)</button>' +
              '<button onclick="window.open(\\'' + data.oauthUrl.replace(/'/g, "\\\\'") + '\\', \\'_blank\\', \\'noopener\\');" style="padding:8px 16px;background:#6b7280;color:white;border:none;border-radius:4px;cursor:pointer">Open in new tab</button>' +
              '</div>' +
              '<div style="margin-top:8px"><a href="' + data.oauthUrl + '" target="_blank" rel="noopener" style="font-size:12px">Open Square consent in a new tab ↗</a></div>' +
              '<div style="margin-top:12px;font-size:12px;color:#666">Auto-redirecting in 10 seconds...</div>' +
              '<div style="margin-top:12px;font-size:12px;color:#9CA3AF">Tip: If it still looks blank, try an Incognito/Private window, disable content blockers for squareupsandbox.com, or revoke the app in your Square Sandbox seller dashboard and retry.</div>';
            
            // Auto-redirect after 10 seconds
            setTimeout(() => {
              window.location.href = data.oauthUrl;
            }, 10000);
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

    const redirectUri = "https://completesquareoauthhttp-zp46qvhbwa-uk.a.run.app";

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
    const {access_token, merchant_id, expires_at} = tokenData;

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
          <p>Your Square POS is now connected to FreshPunk. Here's what happens next:</p>
          <ul>
            <li>✅ Customer orders will automatically appear in your Square dashboard</li>
            <li>✅ Payments are processed through your existing Square system</li>
            <li>✅ Your menu items are synced with FreshPunk</li>
            <li>✅ No additional login or portal access needed</li>
          </ul>
          <p><strong>Next steps:</strong> Simply monitor your Square dashboard for incoming FreshPunk orders. That's it!</p>
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
      const redirectUri = "https://completesquareoauthhttp-zp46qvhbwa-uk.a.run.app";
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
    secrets: [SQUARE_APPLICATION_ID, SQUARE_APPLICATION_SECRET, SQUARE_ENV],
  },
  async (event: any) => {
  try {
    const orderData = event.data?.data();
    if (!orderData) return;

    // Only forward confirmed orders with Square restaurant items
    if (orderData.status !== "confirmed") return;

    const meals = orderData.meals || [];
    const squareMeals = meals.filter((meal: any) => meal.restaurantId && meal.squareItemId);

    if (squareMeals.length === 0) return;

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
      `freshpunk_forecast_${orderId}` :
      `freshpunk_order_${orderId}`;

    // Square reference_id has 40 char limit - truncate if needed
    const truncatedReference = orderReference.length > 40 ?
      orderReference.substring(0, 40) :
      orderReference;

    const orderNote = orderType === "prep_forecast" ?
      `PREP FORECAST - Week of ${orderData.weekStart || "TBD"}` :
      `FreshPunk Order #${orderId}`;

    const squareOrder = {
      order: {
        location_id: locationId,
        reference_id: truncatedReference,
        source: {
          name: orderType === "prep_forecast" ? "FreshPunk Prep Forecast" : "FreshPunk Delivery",
        },
        line_items: meals.map((meal) => ({
          name: meal.name,
          quantity: meal.quantity?.toString() || "1",
          catalog_object_id: meal.squareVariationId,
          // Include base_price_money for variably-priced items
          base_price_money: meal.price ? {
            amount: Math.round(meal.price * 100), // Convert dollars to cents
            currency: "USD",
          } : undefined,
          modifiers: [],
          note: orderNote,
        })),
        fulfillments: orderType === "prep_forecast" ? [] : [{
          type: "DELIVERY",
          state: "PROPOSED",
          delivery_details: {
            recipient: {
              display_name: orderData.customerName || "FreshPunk Customer",
              phone_number: orderData.customerPhone,
            },
            address: {
              address_line_1: orderData.deliveryAddress,
            },
            schedule_type: "ASAP",
            note: `Delivery for ${orderNote}`,
          },
        }],
        metadata: {
          freshpunk_order_id: orderId,
          freshpunk_customer_id: orderData.userId,
          freshpunk_order_type: orderType,
        },
      },
    };

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

      logger.info("Order forwarded to Square", {
        orderId,
        restaurantId,
        squareOrderId,
        orderType,
        location_id,
        reference_id,
        lineItemCount,
      });
    } else {
      const errorData = await response.text();
      logger.error("Square order creation failed", {
        orderId,
        restaurantId,
        orderType,
        error: errorData,
      });
    }
  } catch (error: any) {
    logger.error("Square order forwarding failed", {
      orderId,
      restaurantId,
      orderType,
      error: error.message,
    });
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
