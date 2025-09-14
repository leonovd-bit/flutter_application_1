# Simple Google Maps API Setup Guide

This guide shows you how to set up the **basic Google Maps API** for address validation and distance calculation - much simpler than the full Google Places API.

## What You Need

✅ **Just the Geocoding API** - One simple API instead of multiple complex ones
✅ **Much cheaper** - Basic geocoding costs much less than Places API
✅ **Easier setup** - No complex billing account requirements

## Step 1: Get Your Google Cloud API Key

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing one
3. Enable the **Geocoding API** (that's it - just one API!)
4. Go to **APIs & Services > Credentials**
5. Click **Create Credentials > API Key**
6. Copy your API key

## Step 2: Secure Your API Key (Important!)

1. Click on your new API key to edit it
2. Under **API restrictions**, select "Restrict key"
3. Choose **Geocoding API** only
4. Under **Application restrictions**, choose "HTTP referrers"
5. Add your domain (e.g., `yourdomain.com/*`)

## Step 3: Add API Key to Your App

Open `lib/app_v3/services/simple_google_maps_service.dart` and replace:

```dart
static const String _apiKey = 'YOUR_GOOGLE_MAPS_API_KEY_HERE';
```

With your actual API key:

```dart
static const String _apiKey = 'AIzaSyC...your-actual-key-here';
```

## Step 4: Test It

1. Run your Flutter app
2. Go to delivery schedule setup
3. Try typing an address in the "Add new address" field
4. It should validate and show a green checkmark

## What This Simple API Does

✅ **Address Validation**: Checks if addresses are real and deliverable
✅ **Address Formatting**: Standardizes addresses (e.g., "123 main st" → "123 Main Street")
✅ **Distance Calculation**: Calculates delivery distances and estimates
✅ **Delivery Area Check**: Verifies if addresses are in your delivery zone
✅ **City/State/ZIP Extraction**: Parses address components

## Benefits vs. Full Places API

| Feature | Simple API | Full Places API |
|---------|------------|----------------|
| Address validation | ✅ | ✅ |
| Distance calculation | ✅ | ✅ |
| Autocomplete suggestions | ❌ | ✅ |
| Place details | ❌ | ✅ |
| Setup complexity | Simple | Complex |
| Cost | Low | Higher |
| API dependencies | 1 API | 3+ APIs |

## Pricing

- **Geocoding API**: $5 per 1,000 requests
- **Free tier**: 200 requests per day
- For a food delivery app, this is very affordable

## Troubleshooting

**Address not found?**
- Make sure the address includes city and state
- Try more complete addresses

**API not working?**
- Check your API key is correct
- Verify Geocoding API is enabled
- Check API key restrictions

**Need autocomplete?**
- Users can type full addresses manually
- Consider upgrading to full Places API later if needed

## Ready to Go!

Your app now has professional address validation without the complexity of full Google Places API. Perfect for an MVP!

## Future Upgrades

If your app grows and you want autocomplete suggestions:
1. Enable Google Places API
2. Update `delivery_schedule_page_v4.dart` to use `AddressAutocompleteWidget`
3. Switch back to `google_places_service.dart`

The simple API is perfect for getting started! 🚀
