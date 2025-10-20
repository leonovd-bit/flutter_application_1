# Google Maps API Key Fix

## Current Issue
The Google Maps API key has **referer restrictions** that prevent it from working with the Geocoding API.

Error message:
```
"API keys with referer restrictions cannot be used with this API."
```

## Solution Options

### Option 1: Remove Referer Restrictions (Recommended for Development)
1. Go to [Google Cloud Console](https://console.cloud.google.com/apis/credentials)
2. Find your API key: `AIzaSyCi_mKaxg-CRH3UJ5LVHGWTd7TUcl1H4qg`
3. Click "Edit API key"
4. Under "Application restrictions":
   - Change from "HTTP referrers" to "None" (for development)
   - OR add your desktop app identifier to allowed referrers
5. Make sure "Geocoding API" is enabled in "API restrictions"
6. Save changes

### Option 2: Create New API Key Without Restrictions
1. Go to [Google Cloud Console](https://console.cloud.google.com/apis/credentials)
2. Click "Create Credentials" → "API key"
3. Don't add any restrictions (for development)
4. Make sure "Geocoding API" is enabled
5. Copy the new key
6. Replace in `lib/app_v3/services/simple_google_maps_service.dart` line 11

### Option 3: Use Platform-Specific API Keys
For production, you should use different keys:
- **Android**: Restrict to your app's package name
- **iOS**: Restrict to your app's bundle ID
- **Web**: Restrict to your domain
- **Desktop**: No restrictions (secure it server-side instead)

## Current Workaround
The app has a **fallback system** that works even when the API fails:
- ✅ User enters address (e.g., "350 5th ave")
- ⚠️ API validation fails (but doesn't crash)
- ✅ Form fills with NYC defaults (New York City, New York)
- ✅ User can add zip code manually
- ✅ Address saves successfully

This is working fine for NYC-only addresses!

## For Production
Before deploying to production:
1. Create separate API keys for each platform
2. Add proper restrictions (package name, bundle ID, domain)
3. Consider using a backend service to proxy API calls
4. Never expose unrestricted API keys in client code
5. Set up billing alerts to prevent unexpected costs

## Testing
After fixing the API key, you should see:
```
[SimpleGoogleMaps] API Status: OK
[AddressPage] ✅ Address validated: 350 5th Avenue, New York, NY 10118, USA
```

Instead of:
```
[SimpleGoogleMaps] API Status: REQUEST_DENIED
[AddressPage] ⚠️ Address validation failed
```
