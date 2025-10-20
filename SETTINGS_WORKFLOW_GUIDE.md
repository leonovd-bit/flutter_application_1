# Settings Workflow Implementation Guide

## Overview
Implemented intelligent workflow for subscription/meal plan changes that affect other app features.

## What Was Implemented

### 1. Smart Detection
When users change their subscription/meal plan in Settings → Manage Subscription, the app now:
- **Detects if the change affects schedules** (meals per day or plan type changes)
- **Shows confirmation dialog** explaining what needs to be updated
- **Only saves if they complete the workflow**

### 2. Confirmation Dialog
Shows users exactly what changed:
```
⚠️ Schedule Update Required

Changing your meal plan will affect your delivery and meal schedules:
• Meals per day: 2 → 3
• Plan type: NutritiousJr → NutritiousAdult

You'll need to update your:
1. Delivery schedule
2. Meal selections

If you back out, your changes won't be saved.

[Cancel] [Continue]
```

### 3. Guided Workflow
If user clicks "Continue":
1. **Navigates to Delivery Schedule V5** - User configures delivery times and addresses
2. **If they back out**: Shows dialog asking if they want to continue or cancel all changes
3. **Navigates to Meal Schedule** - User selects meals for each day
4. **Only saves subscription change if they complete both steps**

### 4. Save Behavior
- ✅ User completes both workflows → Changes saved, subscription updated
- ❌ User backs out at any step → Nothing saved, reverts to old plan
- ⚠️ Shows clear feedback about what happened

## When It Triggers

### Triggers Workflow (Requires schedule updates):
- ✅ Changing meals per day (2 → 3, 3 → 2, etc.)
- ✅ Changing plan type (NutritiousJr → NutritiousAdult)

### No Workflow Needed:
- ❌ Changing payment method (only affects billing)
- ❌ Managing addresses standalone (only affects addresses)
- ❌ Changing delivery schedule alone (no dependencies)
- ❌ Pausing/resuming subscription (doesn't change plan structure)

## Files Modified

### `manage_subscription_page_v3.dart`
**Added:**
1. `_showScheduleUpdateDialog()` - Shows confirmation with change details
2. `_navigateConfigurationWorkflow()` - Guides through delivery + meal setup
3. Enhanced `_save()` - Detects changes and triggers workflow when needed

**Imports Added:**
- `delivery_schedule_page_v5.dart`
- `meal_schedule_page_v3_fixed.dart`

## User Experience Flow

### Example: User changes from 2 meals/day to 3 meals/day

1. **Settings Page** → Manage Subscription
2. **Select new plan** → Tap "Save changes"
3. **See warning dialog** → "Schedule Update Required"
4. **Confirm** → Navigate to Delivery Schedule V5
5. **Configure delivery** → Set times/addresses for 3 meals/day
6. **Complete delivery** → Navigate to Meal Schedule
7. **Select meals** → Choose meals for each meal type
8. **Complete meals** → Subscription saved successfully! ✅

### If User Backs Out:

**At Delivery Schedule:**
- Shows "Incomplete Setup" dialog
- Option to continue or cancel all
- If cancel → Returns to Manage Subscription (no changes saved)

**At Meal Schedule:**
- Same incomplete dialog
- Can cancel → Returns to Manage Subscription (no changes saved)

## Benefits

1. **Prevents Broken States**: Users can't have 3 meals/day subscription but 2 meals/day schedules
2. **Clear Guidance**: Users know exactly what they need to do
3. **Safe Cancellation**: Can back out without breaking anything
4. **Flexible**: Only triggers when necessary (direct dependencies)

## Future Enhancements (Optional)

1. **Progress Indicator**: Show "Step 1 of 2" during workflow
2. **Save Draft**: Option to save partial configuration and continue later
3. **Skip Options**: "Keep existing schedule" if compatible
4. **Auto-migrate**: Automatically adjust existing schedules when possible

## Testing Checklist

- [ ] Change meals per day → Workflow triggers
- [ ] Change plan type → Workflow triggers  
- [ ] Back out of delivery schedule → No save, revert plan
- [ ] Back out of meal schedule → No save, revert plan
- [ ] Complete both workflows → Save successful
- [ ] Change payment method → No workflow (direct save)
- [ ] Same meals per day, different plan → No workflow needed (if compatible)

## Notes

- Workflow only applies to **subscription/meal plan changes**
- Address changes in address page → No workflow (standalone)
- Payment method changes → No workflow (only affects billing)
- This prevents the "subscription updated but schedules broken" bug
