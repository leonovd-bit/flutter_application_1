# Google Places API Setup Guide

## 🔑 Getting Your Google Places API Key

### Step 1: Enable APIs in Google Cloud Console
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing project
3. Enable these APIs:
   - **Places API** (for address autocomplete)
   - **Geocoding API** (for address validation)  
   - **Distance Matrix API** (for delivery estimates)
   - **Maps JavaScript API** (for map display)

### Step 2: Create API Credentials
1. Navigate to **APIs & Services > Credentials**
2. Click **+ CREATE CREDENTIALS > API key**
3. Copy the generated API key
4. **Restrict the API key** (recommended for security):
   - Click on the API key to edit
   - Under "API restrictions", select "Restrict key"
   - Choose: Places API, Geocoding API, Distance Matrix API, Maps JavaScript API

### Step 3: Add API Key to Your App
Replace `YOUR_GOOGLE_PLACES_API_KEY_HERE` in these files:

**File: `lib/app_v3/services/google_places_service.dart`**
```dart
static const String _apiKey = 'YOUR_ACTUAL_API_KEY_HERE';
```

**File: `android/app/src/main/AndroidManifest.xml`** (for Android)
```xml
<meta-data android:name="com.google.android.geo.API_KEY"
           android:value="YOUR_ACTUAL_API_KEY_HERE"/>
```

**File: `ios/Runner/AppDelegate.swift`** (for iOS)
```swift
GMSServices.provideAPIKey("YOUR_ACTUAL_API_KEY_HERE")
```

**File: `web/index.html`** (for Web)
```html
<script src="https://maps.googleapis.com/maps/api/js?key=YOUR_ACTUAL_API_KEY_HERE&libraries=places"></script>
```

## 🧪 Testing the Integration

### Test Address Autocomplete
1. Run the app: `flutter run -d chrome`
2. Navigate to **Delivery Schedule page**
3. Try typing an address in the new autocomplete field
4. Verify suggestions appear as you type

### Expected Features
- ✅ Real-time address suggestions
- ✅ Address validation with confidence scoring
- ✅ Automatic address standardization
- ✅ Integration with saved addresses
- ✅ Google Places data parsing (street, city, state, zip)

## 💰 API Usage & Costs

### Google Places API Pricing (as of 2024)
- **Autocomplete requests**: $2.83 per 1,000 requests
- **Place Details requests**: $17 per 1,000 requests  
- **Geocoding requests**: $5 per 1,000 requests
- **Distance Matrix requests**: $5 per 1,000 requests

### Cost Optimization Tips
1. **Session Tokens**: Used to group autocomplete + place details (billing optimization)
2. **Debouncing**: 300ms delay to reduce API calls while typing
3. **Caching**: Store recent addresses locally
4. **Field restrictions**: Only request needed place details fields

### Monthly Estimates (1000 active users)
- Light usage (10 address searches/user/month): ~$50/month
- Heavy usage (50 address searches/user/month): ~$250/month

## 🔧 Configuration Options

### Restrict Address Types
Current setting: `'types': 'address'` (street addresses only)

Other options:
- `'geocode'` - All geocoding results
- `'establishment'` - Businesses
- `'(regions)'` - Administrative areas

### Geographic Restrictions
Current setting: `'components': 'country:us'` (US only)

Modify for other countries:
- Canada: `'country:ca'`
- Multiple: `'country:us|country:ca'`

## 🚨 Security Notes

### API Key Protection
- ✅ **DO**: Use API restrictions in Google Cloud Console
- ✅ **DO**: Monitor API usage regularly
- ❌ **DON'T**: Commit API keys to public repositories
- ❌ **DON'T**: Use the same key for client and server apps

### Recommended Setup
1. **Client API Key**: Restricted to Places API, Geocoding API (for Flutter app)
2. **Server API Key**: Restricted to Distance Matrix API (for backend calculations)

## 📱 Next Steps

1. **Get API key and test basic integration**
2. **Implement real-time location tracking service**
3. **Add SMS notifications for delivery updates**
4. **Integrate with existing order management system**

## 🆘 Troubleshooting

### Common Issues
- **"This API project is not authorized"**: Check API restrictions
- **"REQUEST_DENIED"**: Verify billing is enabled in Google Cloud
- **No suggestions appearing**: Check API key and network connectivity
- **Quota exceeded**: Monitor usage in Google Cloud Console

### Debug Mode
Enable debug logging in `google_places_service.dart`:
```dart
debugPrint('[GooglePlaces] API response: ${response.body}');
```
