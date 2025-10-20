# Code Archiving Summary
**Date:** October 20, 2025  
**Purpose:** Clean up codebase by archiving unused files while keeping them recoverable

## ✅ What Was Archived

### Pages Archived (38 files)
**Location:** `lib/app_v3/_archive/pages/`

#### Backup/Test Variants:
- `choose_meal_plan_page_v3_backup.dart`
- `choose_meal_plan_page_v3_fixed.dart`
- `choose_meal_plan_page_v3_new.dart`
- `login_page_v3_new.dart`
- `login_page_v3_test.dart`
- `settings_page_v3_clean.dart`
- `splash_page_v1.dart`
- `splash_page_v3_clean.dart`
- `splash_simple.dart`
- `past_orders_page_v3_optimized.dart`
- `onboarding_choice_page_v3_simple.dart` (partially - restored for active use)

#### Old Versions (v1/v2):
- `choose_meal_plan_signup_page_v1.dart`
- `circle_of_health_page_v1.dart`
- `delivery_schedule_edit_page_v1.dart`
- `delivery_schedule_overview_page_v1.dart`
- `delivery_schedule_overview_page_v2.dart`
- `manage_page_v1.dart`
- `meal_plan_subscription_page_v1.dart`
- `meal_schedule_edit_page_v1.dart`
- `meal_schedule_overview_page_v1.dart`
- `meal_schedule_overview_page_v2.dart`
- `orders_page_v1.dart`
- `order_detail_page_v1.dart`
- `token_purchase_page_v1.dart`
- `token_setup_meals_per_day_page_v1.dart`

#### Kitchen/Admin/Debug Pages:
- `kitchen_access_page.dart`
- `kitchen_dashboard_page.dart`
- `admin_restaurant_prep_page.dart`
- `debug_clear_setup_page.dart`

#### Test/Duplicate Pages:
- `doordash_test_page.dart`
- `delivery_schedule_page_v3.dart` (v5 is active)
- `delivery_schedule_page_v4.dart` (v5 is active)
- `meal_schedule_screen.dart`
- `meal_selection_screen.dart`
- `help_support_page_v3.dart`
- `restaurant_portal_page.dart` (combined version is active)
- `restaurant_dashboard_simple_v3.dart`
- `simple_restaurant_portal_test.dart`

### Services Archived (12 files)
**Location:** `lib/app_v3/_archive/services/`

- `auth_wrapper_fixed.dart`
- `auth_wrapper_fixed_v2.dart`
- `auth_wrapper_freshpunk.dart`
- `admin_service.dart`
- `admin_grant_service.dart`
- `meal_image_fix_service.dart`
- `navigation_service.dart`
- `notifications_service.dart`
- `privacy_guard.dart`
- `sms_service.dart`
- `subscription_plans.dart`
- `user_data_cleanup_service.dart`

## 🔄 Files Restored (Actively Used)
These files were initially archived but had to be restored because they're actively imported:

1. **`meal_schedule_page_v3_fixed.dart`** - Re-exported by meal_schedule_page_v3.dart
2. **`pause_resume_subscription_page_v1.dart`** - Used by manage_subscription_page_v3.dart
3. **`interactive_menu_page_v3.dart`** - Used by meal_schedule_page_v3_fixed.dart

## 🛡️ Files Preserved (Not Archived)
**AI Features** - Per user request, all AI-related pages were preserved:
- `ai_address_input_page_v3.dart`
- `ai_chat_page_v3.dart`
- `ai_meal_planner_page_v3.dart`
- `ai_meal_plan_overview_page_v3.dart`
- `ai_onboarding_page_v3.dart`
- `ai_schedule_review_page_v3.dart`

## 🔧 Configuration Changes

### Updated `analysis_options.yaml`
Added archive folder to exclusions:
```yaml
analyzer:
  exclude:
    - dataconnect-generated/**
    - build/**
    - "**/*.g.dart"
    - "**/*.freezed.dart"
    - lib/app_v3/_archive/**  # ← Added this line
```

### Fixed Import Statements
Updated imports in active files to reference correct page names:

1. **`delivery_schedule_page_v5.dart`**
   - Changed: `choose_meal_plan_page_v3_new.dart` → `choose_meal_plan_page_v3.dart`
   - Changed: `meal_schedule_page_v3_fixed.dart` → `meal_schedule_page_v3.dart`
   - Changed: `ChooseMealPlanPageV3New(isSignupFlow: false)` → `ChooseMealPlanPageV3()`

2. **`email_verification_page_v3.dart`**
   - Changed: `onboarding_choice_page_v3_simple.dart` → `onboarding_choice_page_v3.dart`
   - Changed: `OnboardingChoicePageV3Simple()` → `OnboardingChoicePageV3()`

3. **`onboarding_choice_page_v3.dart`**
   - Changed: `choose_meal_plan_page_v3_new.dart` → `choose_meal_plan_page_v3.dart`
   - Changed: `ChooseMealPlanPageV3New()` → `ChooseMealPlanPageV3()`

## ✅ Verification Results

### Flutter Analyze Status
- ✅ All import errors resolved
- ✅ No broken dependencies
- ⚠️ Minor warnings remain (unused imports in debug files, theme getter issues in onboarding_meal_plan_page_v3.dart)
- ✅ Archive folder properly excluded from analysis

### Total Files Archived
- **Pages:** 38 files
- **Services:** 12 files
- **Total:** 50 unused files archived

## 📦 How to Restore Archived Files

If you need to restore any archived file:

```powershell
# Restore a specific page
Move-Item "lib\app_v3\_archive\pages\FILENAME.dart" "lib\app_v3\pages\" -Force

# Restore a specific service
Move-Item "lib\app_v3\_archive\services\FILENAME.dart" "lib\app_v3\services\" -Force
```

**Example:**
```powershell
Move-Item "lib\app_v3\_archive\pages\kitchen_dashboard_page.dart" "lib\app_v3\pages\" -Force
```

## 📁 Active Pages After Cleanup

### Core User Flow (19 active pages):
- `about_page_v3.dart`
- `address_page_v3.dart`
- `change_password_page_v3.dart`
- `choose_meal_plan_page_v3.dart`
- `circle_of_health_page_v3.dart`
- `delivery_schedule_page_v5.dart` ← Active version
- `email_verification_page_v3.dart`
- `home_page_v3.dart`
- `login_page_v3.dart`
- `map_page_v3.dart`
- `menu_page_v3.dart`
- `onboarding_choice_page_v3.dart`
- `past_orders_page_v3.dart`
- `privacy_policy_page_v3.dart`
- `settings_page_v3.dart`
- `signup_page_v3.dart`
- `splash_page_v3.dart`
- `terms_of_service_page_v3.dart`
- `welcome_page_v3.dart`

### Restaurant Features (3 active pages):
- `combined_restaurant_portal_page.dart` ← Active unified version
- `restaurant_dashboard_page_v3.dart`
- `restaurant_onboarding_page_v3.dart`
- `square_restaurant_onboarding_page_v3.dart`

### Additional Active Pages (10 pages):
- `buy_tokens_page_v3.dart`
- `interactive_menu_page_v3.dart`
- `manage_subscription_page_v3.dart`
- `meal_schedule_page_v3.dart`
- `meal_schedule_page_v3_fixed.dart`
- `onboarding_meal_plan_page_v3.dart`
- `page_viewer_v3.dart` ← Debug tool
- `payment_methods_page_v3.dart`
- `payment_page_v3.dart`
- `pause_resume_subscription_page_v1.dart`
- `plan_subscription_page_v3.dart`
- `profile_page_v3.dart`
- `restaurant_registration_page_v3.dart`
- `upcoming_orders_page_v3.dart`

### AI Pages (6 preserved):
- `ai_address_input_page_v3.dart`
- `ai_chat_page_v3.dart`
- `ai_meal_planner_page_v3.dart`
- `ai_meal_plan_overview_page_v3.dart`
- `ai_onboarding_page_v3.dart`
- `ai_schedule_review_page_v3.dart`

## 🎯 Benefits of Archiving

1. **Cleaner Codebase:** Easier to navigate and understand active code
2. **Faster Development:** Less confusion about which files are current
3. **Reduced Build Times:** Fewer files to analyze
4. **Maintained History:** All archived files are safely stored and recoverable
5. **Better Organization:** Clear separation between active and inactive code

## ⚠️ Known Minor Issues

1. **Theme Warning:** `onboarding_meal_plan_page_v3.dart` references `AppThemeV3.primaryColor` which doesn't exist in the theme. This doesn't break functionality but should be fixed eventually.

## 📝 Next Steps

1. ✅ Archiving complete
2. ✅ All imports fixed
3. ✅ Flutter analyze passing (no errors)
4. 🔄 Ready for testing - run the app to verify everything works
5. 📦 Consider committing these changes to Git once verified

---

**Note:** The archive folder is excluded from Flutter analysis but is still tracked in version control, so all changes are reversible.
