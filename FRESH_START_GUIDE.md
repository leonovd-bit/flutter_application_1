# Complete Fresh Start Guide - Windows Crash Fix

## Problem Analysis
You're experiencing crashes because of **corrupted cached state** from an incomplete signup. When you:
1. Created an account but didn't finish setup
2. Logged in and were taken to home page with no data
3. Deleted the account
4. Tried to sign up again

The app still has cached data from the incomplete account, causing conflicts.

## Solution: Complete Data Wipe + Fresh Start

### ✅ Already Completed (Just Now)
1. ✅ `flutter clean` - Cleared build artifacts
2. ✅ Deleted `%LOCALAPPDATA%\flutter_application_1` - Local app data
3. ✅ Deleted `%APPDATA%\flutter_application_1` - Roaming app data  
4. ✅ `flutter pub get` - Reinstalled dependencies

### 🔥 Additional Firebase Cleanup (IMPORTANT)

Since you deleted an account but Firebase might still have remnants, you need to:

#### Option 1: Use Firebase Console (Recommended)
1. Go to https://console.firebase.google.com
2. Select your project
3. Go to **Authentication** > **Users**
4. Find your test user email
5. Click the 3 dots menu → **Delete account**
6. Go to **Firestore Database**
7. Find any documents with your user ID
8. Delete them manually

#### Option 2: Use the App's Account Deletion (If Available)
1. Run the app
2. Log in with your test account
3. Go to Settings
4. Use "Delete Account" feature
5. This should clean up Firebase + local data

### 📝 Next Steps for Fresh Start

1. **Make sure the app is NOT running** (close it completely)

2. **Clear Windows app data locations** (double-check):
   ```powershell
   # Run these in PowerShell
   Remove-Item -Path "$env:LOCALAPPDATA\flutter_application_1" -Recurse -Force -ErrorAction SilentlyContinue
   Remove-Item -Path "$env:APPDATA\flutter_application_1" -Recurse -Force -ErrorAction SilentlyContinue
   Remove-Item -Path "$env:TEMP\flutter_application_1*" -Recurse -Force -ErrorAction SilentlyContinue
   ```

3. **Clear browser cache** (if using web authentication):
   - Press `Ctrl + Shift + Delete`
   - Clear "Cookies and site data"
   - Clear "Cached images and files"

4. **Rebuild and run**:
   ```bash
   cd "c:\Users\dleon\OneDrive\Desktop\flutter_application_1"
   flutter clean
   flutter pub get
   flutter run -d windows
   ```

5. **Sign up with a DIFFERENT email** (important!):
   - Don't use the same email from the incomplete signup
   - Use a fresh email like: `test2@example.com` or `yourname+test@gmail.com`
   - This ensures no conflicts with old Firebase data

### 🐛 If Crash Still Happens After Fresh Start

The crash is happening in `delivery_schedule_page_v5.dart`. If it still occurs after complete data wipe, it means the issue is with the **code initialization**, not cached data.

#### Debug Steps:
1. Check the terminal output when it crashes
2. Look for the exact line where `abort()` is called
3. The error usually shows: `[DeliveryScheduleV5] ...` debug messages

#### Known Working State:
The page should show:
- Schedule name input field
- Selected meal plan display
- "Continue to Meal Selection" button

If you see ANY of these messages in the terminal before crash:
- `[DeliveryScheduleV5] Loading current plan...`
- `[DeliveryScheduleV5] Final plan: ...`
- `[DeliveryScheduleV5] Plan updated in UI: ...`

Then the crash is happening **AFTER** initialization, during render.

### 🔧 Alternative Workaround (If All Else Fails)

If the crash persists even after complete data wipe, we can:

1. **Temporarily skip the delivery schedule page** during signup
2. **Use a simpler version** without TextEditingController
3. **Add delivery schedule configuration later** in settings

Let me know:
1. Does it crash after complete fresh start with new email?
2. What's the last debug message you see before crash?
3. Do you see the page render at all, or does it crash immediately?

### 📊 Testing Checklist

After fresh start, test in this order:
- [ ] App launches successfully
- [ ] Sign up with NEW email (not the old one)
- [ ] Email verification screen appears
- [ ] Click "Already verified" or verify email
- [ ] Onboarding choice screen appears
- [ ] Select meal plan (e.g., "Standard")
- [ ] **Delivery schedule page loads** ← This is where crash was happening
- [ ] Page shows schedule name field
- [ ] Page shows selected meal plan
- [ ] Can click "Continue to Meal Selection"

### 🎯 Expected Results
After complete data wipe + new email signup:
- ✅ No cached data conflicts
- ✅ Fresh Firebase user with no incomplete data
- ✅ Clean SharedPreferences state
- ✅ Delivery schedule page loads successfully
- ✅ TextEditingController initializes properly

---

## Files Modified in This Session
1. `delivery_schedule_page_v5.dart` - Fixed TextEditingController initialization (Windows-safe)
2. `DELIVERY_SCHEDULE_FIX_SUMMARY.md` - Documentation of the fix
3. `clear_all_data.dart` - Data cleanup utility script

## Current Status
- ✅ Code fix applied (Windows-safe TextEditingController)
- ✅ Build artifacts cleaned
- ✅ Local app data cleared
- ⏳ **Next: Test with completely fresh signup using new email**
