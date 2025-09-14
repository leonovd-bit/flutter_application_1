# 🧪 Testing Your Simple Google Maps API

## Once Your App Loads...

### 📍 **Test Address Validation**

1. **Navigate to**: Delivery Schedule (from main menu)
2. **Look for**: "Add new address" section
3. **Test these addresses**:

**✅ Valid US Addresses** (should show green checkmark):
```
123 Main Street, New York, NY 10001
456 Broadway, Los Angeles, CA 90210  
789 Oak Avenue, Chicago, IL 60601
321 Pine Street, Miami, FL 33101
```

**❌ Invalid Addresses** (should show error):
```
asdfjklsemi
123 Fake Street, Nowhere
```

**🌎 International** (should be rejected - US only):
```
123 Main Street, Toronto, Canada
456 Oxford Street, London, UK
```

### 🎯 **What To Look For**

**When you type a valid address:**
1. Input field shows loading spinner briefly
2. Green checkmark ✅ appears  
3. Address gets formatted nicely
4. Shows "Address Validated" card below

**When address is invalid:**
1. Red error icon ❌ appears
2. Shows "Address not found" message

**When outside delivery area:**
1. Shows "Sorry, we don't deliver to this area yet"

### 🚫 **Without API Key**

If you haven't added your Google API key yet, you'll see:
- No validation happens
- No green checkmarks
- Still works for typing addresses manually

---

## 🔧 **Add Your API Key**

1. **Get key from**: https://console.cloud.google.com/
2. **Enable**: "Geocoding API" only
3. **Replace** in `lib/app_v3/services/simple_google_maps_service.dart`:

```dart
static const String _apiKey = 'YOUR_ACTUAL_API_KEY_HERE';
```

### 💡 **Pro Tips**

- **Free tier**: 200 requests/day (perfect for testing!)
- **Type complete addresses**: Include city and state for best results
- **US only**: Currently configured for US addresses only
- **NYC optimized**: Delivery area check focuses on NYC area

---

## 🐛 **Troubleshooting**

**Address validation not working?**
- Check browser console (F12) for errors
- Verify API key is correct
- Make sure Geocoding API is enabled

**Can't get to delivery schedule?**
- Try navigating from the main menu
- Look for "Delivery" or "Schedule" buttons
- Check if you need to sign in first

**App not loading?**
- Check terminal for build errors
- Try `flutter clean` and `flutter pub get`
- Restart with `flutter run -d chrome`

---

## ✅ **Success Checklist**

- [ ] App loads in browser
- [ ] Can navigate to delivery schedule
- [ ] Address input field appears
- [ ] Can type addresses
- [ ] (With API key) Green checkmarks for valid addresses
- [ ] (With API key) Error messages for invalid addresses

🎉 **You're all set!** The simple API provides everything you need for address validation in your food delivery app!
