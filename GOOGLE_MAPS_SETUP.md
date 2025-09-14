# Google Maps API Setup Guide 🗺️

## Step 1: Create Google Cloud Project & Enable APIs

1. **Go to Google Cloud Console**: https://console.cloud.google.com/
2. **Create new project** or select existing one
3. **Enable these APIs**:
   - Maps JavaScript API (for web)
   - Maps SDK for Android
   - Maps SDK for iOS
   - Geocoding API
   - Places API (optional, for address autocomplete)

## Step 2: Create API Keys

### For Web Application:
1. Go to **Credentials** → **Create Credentials** → **API Key**
2. **Restrict the key**:
   - Application restrictions: **HTTP referrers**
   - Website restrictions: Add your domains:
     - `https://freshpunk-48db1.web.app/*`
     - `https://freshpunk-48db1.firebaseapp.com/*`
     - `http://localhost:*` (for development)
   - API restrictions: Select **Maps JavaScript API**, **Geocoding API**

### For Android:
1. Create another API key
2. **Restrict the key**:
   - Application restrictions: **Android apps**
   - Package name: `com.example.flutterApplication1`
   - SHA-1 certificate fingerprint (get from `keytool` or Firebase)
   - API restrictions: **Maps SDK for Android**, **Geocoding API**

### For iOS:
1. Create another API key  
2. **Restrict the key**:
   - Application restrictions: **iOS apps**
   - Bundle ID: `com.example.flutterApplication1`
   - API restrictions: **Maps SDK for iOS**, **Geocoding API**

## Step 3: Configure in App

Once you have the keys, update these files:

### Web Configuration:
- Add to `web/index.html`
- Update `lib/config/environment.dart`

### Android Configuration:
- Update `android/app/src/main/AndroidManifest.xml`

### iOS Configuration:
- Update `ios/Runner/Info.plist`

## Step 4: Test

1. Build and deploy the app
2. Go to the map page in your app
3. Check browser console for any API errors

## Security Notes:
- Never commit API keys to public repositories
- Use environment variables for sensitive keys
- Restrict keys to specific domains/apps
- Monitor usage in Google Cloud Console

## Pricing:
- Google Maps has a free tier (28,000 map loads/month)
- Monitor usage to avoid unexpected charges
- Set up billing alerts

## Troubleshooting:
- If maps don't load: Check browser console for errors
- If getting 403 errors: Check API key restrictions
- If blank maps: Verify the correct APIs are enabled
