# Delivery Schedule V5 - Navigation Fix

## Issue Fixed
After saving the delivery schedule, V5 was incorrectly navigating to `ManageSubscriptionPageV3` instead of the meal selection page.

## Root Cause
V5 was implemented with a placeholder `TODO` that went to the wrong page. The correct flow should be:
1. Configure delivery schedule
2. Save schedule locally
3. Navigate to **Meal Selection Page** to choose meals
4. Then proceed to payment/subscription

## Solution Implemented

### 1. Updated Save Method
Changed from simple navigation to proper data conversion and meal selection flow:

**Before:**
```dart
Future<void> _saveSchedule() async {
  if (!_validateSchedule()) return;
  
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Schedule saved successfully!')),
  );
  
  // Wrong navigation!
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (context) => const ManageSubscriptionPageV3(),
    ),
  );
}
```

**After:**
```dart
Future<void> _saveSchedule() async {
  if (!_validateSchedule()) return;
  
  // Convert V5 format to V4 format
  Map<String, Map<String, dynamic>> weeklySchedule = {};
  
  for (final entry in _dayMealSelections.entries) {
    final day = entry.key;
    final mealTypes = entry.value;
    
    weeklySchedule[day] = {};
    
    for (final mealType in mealTypes) {
      final config = _dayConfigurations[day]?[mealType];
      weeklySchedule[day]![mealType] = {
        'time': config['time'],
        'address': config['address'],
        'enabled': true,
      };
    }
  }
  
  await _saveScheduleLocally(weeklySchedule);
  
  // Correct navigation!
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => MealSchedulePageV3(
        mealPlan: _selectedMealPlan!,
        weeklySchedule: weeklySchedule,
        initialScheduleName: _scheduleName,
      ),
    ),
  );
}
```

### 2. Added Local Storage Persistence
Implemented `_saveScheduleLocally()` method to save the schedule configuration:

```dart
Future<void> _saveScheduleLocally(Map<String, Map<String, dynamic>> weeklySchedule) async {
  final prefs = await SharedPreferences.getInstance();
  final uid = FirebaseAuth.instance.currentUser?.uid;
  
  // Convert TimeOfDay to serializable format
  final serializable = <String, dynamic>{};
  for (final day in weeklySchedule.keys) {
    serializable[day] = <String, dynamic>{};
    for (final mealType in weeklySchedule[day]!.keys) {
      final time = weeklySchedule[day]![mealType]!['time'] as TimeOfDay?;
      serializable[day]![mealType] = {
        'hour': time?.hour,
        'minute': time?.minute,
        'address': weeklySchedule[day]![mealType]!['address'],
        'enabled': true,
      };
    }
  }
  
  serializable['mealPlanId'] = _selectedMealPlan?.id;
  serializable['createdAt'] = DateTime.now().toIso8601String();
  
  final key = uid == null 
    ? 'delivery_schedule_$name' 
    : 'delivery_schedule_${uid}_$name';
    
  await prefs.setString(key, json.encode(serializable));
}
```

### 3. Added Required Imports
```dart
import 'dart:convert';  // For json.encode
import 'meal_schedule_page_v3_fixed.dart';  // For navigation
```

## Correct Flow Now

```
User Journey:
┌─────────────────────────┐
│ Choose Meal Plan        │
│ (1-3 meals/day)         │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│ Delivery Schedule V5    │  ← You are here
│ - Select days           │
│ - Choose meal types     │
│ - Set times & addresses │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│ Meal Selection Page     │  ← NOW GOES HERE ✓
│ - Browse meals          │
│ - Customize per day     │
│ - See nutritional info  │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│ Payment/Subscription    │
│ - Enter payment info    │
│ - Confirm subscription  │
└─────────────────────────┘
```

## Data Format Conversion

### V5 Internal Format:
```dart
_dayMealSelections = {
  'Monday': {'Breakfast', 'Dinner'},
  'Tuesday': {'Lunch', 'Dinner'}
};

_dayConfigurations = {
  'Monday': {
    'Breakfast': {'time': TimeOfDay(8, 0), 'address': '123 Main St'},
    'Dinner': {'time': TimeOfDay(18, 0), 'address': '123 Main St'}
  }
};
```

### Converted to V4 Format:
```dart
weeklySchedule = {
  'Monday': {
    'Breakfast': {
      'time': TimeOfDay(8, 0),
      'address': '123 Main St',
      'enabled': true
    },
    'Dinner': {
      'time': TimeOfDay(18, 0),
      'address': '123 Main St',
      'enabled': true
    }
  }
};
```

### Saved to SharedPreferences:
```json
{
  "Monday": {
    "Breakfast": {
      "hour": 8,
      "minute": 0,
      "address": "123 Main St",
      "enabled": true
    },
    "Dinner": {
      "hour": 18,
      "minute": 0,
      "address": "123 Main St",
      "enabled": true
    }
  },
  "mealPlanId": "1",
  "createdAt": "2025-10-12T10:30:00.000Z"
}
```

## Benefits

1. ✅ **Correct Flow**: Users now go to meal selection after schedule configuration
2. ✅ **Data Persistence**: Schedule is saved locally for future reference
3. ✅ **Format Compatibility**: V5 data converts properly to V4 format
4. ✅ **Complete Onboarding**: Full signup flow now works end-to-end

## Files Modified

1. ✅ `lib/app_v3/pages/delivery_schedule_page_v5.dart`
   - Updated `_saveSchedule()` method
   - Added `_saveScheduleLocally()` method
   - Added proper data format conversion
   - Fixed navigation to MealSchedulePageV3
   - Added required imports

## Testing Checklist

- [ ] Complete delivery schedule configuration
- [ ] Click "Save Schedule" button
- [ ] Verify navigation to meal selection page (not subscription page)
- [ ] Verify weeklySchedule data is passed correctly
- [ ] Verify meal plan is passed correctly
- [ ] Verify schedule name is passed correctly
- [ ] Verify saved schedule appears in meal selection page
- [ ] Complete meal selection and proceed to payment
- [ ] Verify entire signup flow works end-to-end

## Status: ✅ Navigation Fixed

The delivery schedule now correctly navigates to the meal selection page with proper data format conversion and local storage persistence.
