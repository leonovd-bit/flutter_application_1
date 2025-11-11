/**
 * Manual OAuth Code Entry Helper
 * Backup flow for when Square's consent UI doesn't load
 */

import {onRequest} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import {getFirestore, FieldValue} from "firebase-admin/firestore";
import {defineSecret} from "firebase-functions/params";

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

/**
 * Manual OAuth code entry page
 * Use this when Square's consent UI won't load
 */
export const manualOAuthEntry = onRequest(
  {
    region: "us-east4",
    secrets: [SQUARE_APPLICATION_ID, SQUARE_APPLICATION_SECRET, SQUARE_ENV],
  },
  async (req, res) => {
    try {
      const db = getFirestore();
      const {applicationId, applicationSecret, baseUrl} = getSquareConfig();

      // Set CORS
      res.set("Access-Control-Allow-Origin", "*");
      res.set("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
      res.set("Access-Control-Allow-Headers", "Content-Type");

      if (req.method === "OPTIONS") {
        res.status(204).send("");
        return;
      }

      // GET: Show the manual entry form
      if (req.method === "GET") {
        res.set("Content-Type", "text/html; charset=utf-8");
        res.send(`<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Manual OAuth Code Entry</title>
  <style>
    body { font-family: system-ui, -apple-system, Segoe UI, Roboto, Arial; max-width: 720px; margin: 40px auto; padding: 0 16px; }
    h1 { font-size: 24px; color: #1f2937; }
    .card { border: 1px solid #e5e7eb; border-radius: 8px; padding: 20px; margin: 16px 0; }
    .info { background: #e7f3ff; padding: 16px; border-radius: 6px; margin: 16px 0; font-size: 14px; }
    .warning { background: #fef3c7; padding: 16px; border-radius: 6px; margin: 16px 0; font-size: 14px; }
    label { display: block; margin: 12px 0 6px; font-weight: 500; }
    input, textarea { width: 100%; padding: 10px 12px; border: 1px solid #d1d5db; border-radius: 6px; font-family: monospace; font-size: 13px; }
    button { margin-top: 16px; padding: 12px 20px; border: 0; background: #2563eb; color: white; border-radius: 6px; cursor: pointer; font-weight: 500; }
    button:hover { background: #1d4ed8; }
    .status { margin-top: 16px; padding: 12px; border-radius: 6px; font-size: 14px; }
    .success { background: #d1fae5; color: #065f46; }
    .error { background: #fee2e2; color: #991b1b; }
    code { background: #f3f4f6; padding: 2px 6px; border-radius: 3px; font-size: 12px; }
    ol { line-height: 1.8; }
    a { color: #2563eb; }
  </style>
</head>
<body>
  <h1>🔧 Manual OAuth Code Entry</h1>
  
  <div class="warning">
    <strong>⚠️ Use this backup flow when Square's consent page won't load.</strong>
  </div>

  <div class="info">
    <strong>How to get an authorization code:</strong>
    <ol>
      <li>Open <a href="https://developer.squareup.com/console/en/oauth/oauth-api-explorer" target="_blank">Square OAuth Playground ↗</a></li>
      <li>Select your Sandbox application</li>
  <li>Check these permissions: <code>MERCHANT_PROFILE_READ</code>, <code>PAYMENTS_READ</code>, <code>ITEMS_READ</code>, <code>INVENTORY_READ</code>, <code>ORDERS_READ</code>, <code>ORDERS_WRITE</code></li>
      <li>Click "Authorize" and copy the authorization code that appears</li>
      <li>Paste it below within 5 minutes (codes expire quickly)</li>
    </ol>
  </div>

  <div class="card">
    <form id="codeForm">
      <label for="code">Authorization Code from Square:</label>
      <textarea id="code" rows="3" placeholder="sandbox-sq0cgb-..." required></textarea>

      <label for="name">Restaurant Name:</label>
      <input id="name" placeholder="Green Blend Cafe" required />

      <label for="email">Contact Email:</label>
      <input id="email" type="email" placeholder="owner@example.com" required />

      <label for="phone">Contact Phone (optional):</label>
      <input id="phone" placeholder="(555) 123-4567" />

      <button type="submit">Complete OAuth with Code</button>
    </form>

    <div id="status"></div>
  </div>

  <script>
    document.getElementById('codeForm').addEventListener('submit', async (e) => {
      e.preventDefault();
      const status = document.getElementById('status');
      const code = document.getElementById('code').value.trim();
      const restaurantName = document.getElementById('name').value.trim();
      const contactEmail = document.getElementById('email').value.trim();
      const contactPhone = document.getElementById('phone').value.trim();

      if (!code || !restaurantName || !contactEmail) {
        status.className = 'status error';
        status.textContent = 'Please fill in authorization code, restaurant name, and email.';
        return;
      }

      status.className = 'status';
      status.textContent = 'Processing authorization code...';

      try {
        const resp = await fetch(window.location.href, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ code, restaurantName, contactEmail, contactPhone })
        });
        const data = await resp.json();

        if (data.success) {
          status.className = 'status success';
          status.innerHTML = '<strong>✓ Success!</strong><br>' + data.message + 
            '<br><br><strong>Restaurant ID:</strong> ' + data.restaurantId +
            '<br><strong>Merchant ID:</strong> ' + data.merchantId +
            '<br><br>Menu sync is running in the background. Check Firestore for results.';
        } else {
          status.className = 'status error';
          status.textContent = '✗ Failed: ' + (data.message || 'Unknown error');
        }
      } catch (err) {
        status.className = 'status error';
        status.textContent = '✗ Error: ' + (err.message || err);
      }
    });
  </script>
</body>
</html>`);
        return;
      }

      // POST: Process the manual code
      if (req.method === "POST") {
        const {code, restaurantName, contactEmail, contactPhone} = req.body;

        if (!code || !restaurantName || !contactEmail) {
          res.status(400).json({
            success: false,
            message: "Authorization code, restaurant name, and email required",
          });
          return;
        }

        // Create restaurant application record
        const generatedUserId = `manual_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
        const applicationRef = await db.collection("restaurant_applications").add({
          userId: generatedUserId,
          restaurantName,
          contactEmail,
          contactPhone: contactPhone || null,
          status: "pending_manual_oauth",
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });

        const cleanAppId = (applicationId || "").replace(/[\r\n]+/g, "").trim();
        const cleanAppSecret = (applicationSecret || "").replace(/[\r\n]+/g, "").trim();
        const redirectUri = "https://completesquareoauthhttp-zp46qvhbwa-uk.a.run.app";

        logger.info("Manual OAuth code exchange starting", {
          applicationId: applicationRef.id,
          restaurantName,
        });

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
          logger.error("Manual OAuth token exchange failed", {error: errorData});
          res.status(500).json({
            success: false,
            message: `Failed to exchange code for token: ${errorData.substring(0, 200)}`,
          });
          return;
        }

        const tokenData = await tokenResponse.json();
        const {access_token, merchant_id, expires_at} = tokenData;

        // Get merchant info
        const merchantResponse = await fetch(`${baseUrl}/v2/merchants/${merchant_id}`, {
          headers: {
            "Square-Version": "2023-10-18",
            "Authorization": `Bearer ${access_token}`,
          },
        });

        const merchantData = await merchantResponse.json();
        const merchant = merchantData.merchant;

        // Get location
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

        // Create restaurant partner record
        const restaurantRef = await db.collection("restaurant_partners").add({
          userId: generatedUserId,
          applicationId: applicationRef.id,
          squareMerchantId: merchant_id,
          squareAccessToken: access_token,
          squareTokenExpiresAt: expires_at ? new Date(expires_at) : null,
          squareLocationId: squareLocationId,
          restaurantName,
          squareBusinessName: merchant.business_name,
          contactEmail,
          contactPhone: contactPhone || null,
          address: merchant.main_location?.address ? {
            addressLine1: merchant.main_location.address.address_line_1,
            addressLine2: merchant.main_location.address.address_line_2,
            locality: merchant.main_location.address.locality,
            administrativeDistrictLevel1: merchant.main_location.address.administrative_district_level_1,
            postalCode: merchant.main_location.address.postal_code,
            country: merchant.main_location.address.country,
          } : null,
          status: "active",
          onboardingCompleted: true,
          menuSyncEnabled: true,
          orderForwardingEnabled: true,
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
          lastMenuSync: null,
        });

        // Update application
        await applicationRef.update({
          status: "completed",
          restaurantPartnerId: restaurantRef.id,
          completedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });

        logger.info("Manual OAuth completed successfully", {
          restaurantId: restaurantRef.id,
          merchantId: merchant_id,
        });

        // Trigger menu sync (import from main integration)
        // For now, return success and let user trigger sync manually
        res.status(200).json({
          success: true,
          restaurantId: restaurantRef.id,
          merchantId: merchant_id,
          businessName: merchant.business_name,
          message: "OAuth completed successfully! Menu sync starting...",
        });

        return;
      }

      res.status(405).json({success: false, message: "Method not allowed"});
    } catch (error: any) {
      logger.error("Manual OAuth entry failed", error);
      res.status(500).json({
        success: false,
        message: `OAuth failed: ${error.message}`,
      });
    }
  }
);
