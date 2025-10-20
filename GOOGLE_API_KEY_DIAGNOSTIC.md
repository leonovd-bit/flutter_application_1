# Google Maps API Key Diagnostic Guide

## 🔍 Current API Key Information

**API Key:** `AIzaSyCi_mKaxg-CRH3UJ5LVHGWTd7TUcl1H4qg`

**Location:** `lib/app_v3/services/simple_google_maps_service.dart` (line 14)

---

## 🔴 Current Error

From your console logs:
```
[SimpleGoogleMaps] Response body: {
   "error_message" : "API keys with referer restrictions cannot be used with this API.",
   "results" : [],
   "status" : "REQUEST_DENIED"
}
```

**This error is NOT about billing or free trial** - it's about API key restrictions.

---

## 📊 How to Check Your Google Cloud Account

### Step 1: Find Which Account Owns This API Key

1. Go to: https://console.cloud.google.com/apis/credentials
2. Look for API key ending in: `...1H4qg`
3. The account/email shown at the top right is the owner
4. Check the project name (likely related to "freshpunk" or your app)

### Step 2: Check Billing Status

1. Go to: https://console.cloud.google.com/billing
2. Check if you have an active billing account
3. Look for:
   - ✅ **Billing account active** - Good!
   - ⚠️ **Free trial expired** - Need to enable billing
   - ❌ **No billing account** - Need to add one

**Important:** The Geocoding API has a **FREE tier**:
- **$200 free credit per month** (for all Google Cloud services)
- **First $200 of usage = FREE**
- Geocoding costs: ~$5 per 1,000 requests
- You'd need to make **40,000+ requests per month** to exceed free tier

---

## 🛠️ How to Fix the Current Error

### The Problem
Your API key has **HTTP referer restrictions** that prevent it from being used with the Geocoding API from a Flutter desktop/mobile app.

### Solution Options

#### Option 1: Remove Restrictions (Quick Fix - Development Only)
1. Go to: https://console.cloud.google.com/apis/credentials
2. Click on your API key (`AIzaSyCi_mKaxg-CRH3UJ5LVHGWTd7TUcl1H4qg`)
3. Scroll to **"Application restrictions"**
4. Change from **"HTTP referrers (web sites)"** to **"None"**
5. Click **"Save"**
6. Wait 1-2 minutes for changes to propagate
7. Test again

⚠️ **Warning:** This makes the key less secure. Only use for development/testing.

#### Option 2: Create a New Unrestricted API Key (Recommended)
1. Go to: https://console.cloud.google.com/apis/credentials
2. Click **"Create Credentials"** → **"API key"**
3. Don't add any restrictions yet
4. Copy the new key
5. Replace in `simple_google_maps_service.dart` line 14
6. For production, add proper restrictions later

#### Option 3: Set Correct Restrictions for Desktop App
1. Go to your API key settings
2. Under **"Application restrictions"**:
   - Select **"None"** (desktop apps can't use referrer restrictions)
3. Under **"API restrictions"**:
   - Select **"Restrict key"**
   - Check only: **"Geocoding API"**
4. Save and test

---

## 💰 Free Trial vs. Billing Questions

### Is Your Free Trial Over?
To check:
1. Go to: https://console.cloud.google.com/billing
2. Look for **"Free trial status"** banner
3. If expired, you'll see: *"Your free trial has ended"*

### What Happens After Free Trial?
- You still get **$200 free credit EVERY MONTH** (forever)
- You must add a credit card (but won't be charged unless you exceed $200/month)
- Geocoding API is very cheap - unlikely to exceed free tier

### Do You Need to Enable Billing?
If you see this error when trying to use the API:
```
"This API project is not authorized to use this API. Please ensure this API is activated in the Google Developers Console"
```
Then yes, you need to:
1. Go to: https://console.cloud.google.com/billing
2. Click **"Link a billing account"**
3. Add a credit card (you won't be charged if under $200/month)

---

## 🧪 Quick Test Script

To test if the issue is billing or restrictions, try this:

1. Open a new terminal
2. Run this PowerShell command (replace YOUR_API_KEY if you create a new one):

```powershell
$apiKey = "AIzaSyCi_mKaxg-CRH3UJ5LVHGWTd7TUcl1H4qg"
$address = "350 5th Ave, New York, NY"
$url = "https://maps.googleapis.com/maps/api/geocode/json?address=$address&key=$apiKey"

Invoke-RestMethod -Uri $url -Method Get | ConvertTo-Json -Depth 5
```

**Expected Results:**

If **billing issue:**
```json
{
  "error_message": "This API project is not authorized to use this API",
  "status": "REQUEST_DENIED"
}
```

If **restriction issue** (current problem):
```json
{
  "error_message": "API keys with referer restrictions cannot be used with this API",
  "status": "REQUEST_DENIED"
}
```

If **working:**
```json
{
  "status": "OK",
  "results": [...]
}
```

---

## ✅ Action Plan

### Immediate Steps:
1. ✅ Go to https://console.cloud.google.com/apis/credentials
2. ✅ Find your API key
3. ✅ Check which account/email owns it (shown in top-right corner)
4. ✅ Remove HTTP referer restrictions (set to "None")
5. ✅ Save and wait 1-2 minutes
6. ✅ Test address validation in your app

### If Still Not Working:
1. Check billing at: https://console.cloud.google.com/billing
2. Ensure Geocoding API is enabled: https://console.cloud.google.com/apis/library/geocoding-backend.googleapis.com
3. Create a new API key without restrictions
4. Update the key in your code

### For Production (Later):
1. Create separate API keys for each platform (Android, iOS, Web)
2. Add proper restrictions for each platform
3. Consider using a backend proxy to hide API keys

---

## 🔐 Security Note

**Your API key is currently exposed in your code!** This means:
- Anyone who gets your code can see the key
- They could use it and consume your quota
- For production, you should:
  - Use environment variables
  - Restrict the key properly
  - Consider a backend service

**Example of secure storage:**
```dart
// Don't commit this file to git!
// lib/config/api_keys.dart
class ApiKeys {
  static const String googleMapsKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: 'YOUR_KEY_HERE',
  );
}
```

---

## 📞 Need More Help?

If the issue persists:
1. Share screenshot of your Google Cloud Console → API Credentials page
2. Check console logs when testing (look for specific error messages)
3. Verify the API key hasn't been deleted or disabled

**Most likely solution:** Just remove the referer restrictions and your app will work! 🎉
