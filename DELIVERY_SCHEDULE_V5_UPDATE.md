# Delivery Schedule V5 - Flexible Per-Day Meal Selection

## Overview
Created `DeliverySchedulePageV5` to replace V4, implementing flexible per-day meal selection. Users can now choose different meals for different days, respecting their meal plan's `mealsPerDay` limit.

## User Request
> "how can we change the delivery schedule, so that the user can decide which meal they want which day, for example, if they selected 2 meals/day option, they can choose on monday breakfast and dinner, on tuesday lunch and dinner and so on"

## Key Changes

### 1. New File Created
- **Path**: `lib/app_v3/pages/delivery_schedule_page_v5.dart`
- **Lines**: 746 lines (full implementation)

### 2. Data Structure
**V4 (Old)**: Global meal type selection
```dart
Set<String> _selectedMealTypes; // Applied to ALL days uniformly
```

**V5 (New)**: Per-day meal selection
```dart
Map<String, Set<String>> _dayMealSelections; // Each day has its own meal types
Map<String, Map<String, Map<String, dynamic>>> _dayConfigurations; // Per-day, per-meal configs
```

### 3. User Interface Improvements

#### Expandable Day Cards
- Each day shows as an expandable card
- Days display selected meal types as colored chips
- Tap to expand and see meal configuration options
- Quick meal count badge at top-right

#### Per-Day Meal Selection
- Breakfast, Lunch, Dinner chips for each day
- Toggle any combination respecting `mealsPerDay` limit
- Visual feedback when limit reached
- Clear error messages

#### Configuration Dialog
- Opens when configuring meals for a day
- Set delivery time for each meal
- Select delivery address for each meal
- Save button validates all fields

#### Meal Summary
- Shows total meals selected across all days
- Color-coded meal type breakdown
- Visual confirmation before saving

### 4. Validation Logic
- Enforces `mealsPerDay` limit per day
- Prevents saving if any day has 0 meals
- Requires at least 1 delivery day selected
- Validates time and address for all meals
- Shows clear error messages for validation failures

### 5. Navigation Updates
Updated these files to use V5 instead of V4:

1. **`choose_meal_plan_page_v3.dart`**
   - Quick Setup flow now uses V5
   - Changed import from `delivery_schedule_page_v4.dart` to `delivery_schedule_page_v5.dart`
   - Updated Navigator to push `DeliverySchedulePageV5`

2. **`ai_meal_plan_overview_page_v3.dart`**
   - AI Assisted Setup flow now uses V5
   - Changed import from `delivery_schedule_page_v4.dart` to `delivery_schedule_page_v5.dart`
   - Updated `_proceedToScheduling()` to navigate to V5

### 6. Example Use Cases

#### Use Case 1: 2 Meals/Day Plan - Varying Schedule
```
Monday: Breakfast + Dinner
Tuesday: Lunch + Dinner
Wednesday: Breakfast + Lunch
Thursday: Lunch + Dinner
Friday: Breakfast + Dinner
Saturday: OFF
Sunday: OFF
```

#### Use Case 2: 1 Meal/Day Plan - Different Times
```
Monday: Lunch @ 12:30 PM (Office)
Tuesday: Dinner @ 6:00 PM (Home)
Wednesday: Lunch @ 1:00 PM (Office)
Thursday: Breakfast @ 8:00 AM (Home)
Friday: Lunch @ 12:00 PM (Office)
```

#### Use Case 3: 3 Meals/Day Plan - Weekend Off
```
Monday-Friday: Breakfast + Lunch + Dinner
Saturday: OFF
Sunday: OFF
```

## Technical Details

### State Management
```dart
// Day selection
Set<String> _selectedDays = {};

// Per-day meal selections
Map<String, Set<String>> _dayMealSelections = {};

// Per-day, per-meal configurations
Map<String, Map<String, Map<String, dynamic>>> _dayConfigurations = {
  'Monday': {
    'Breakfast': {'time': TimeOfDay(8, 0), 'address': '123 Main St'},
    'Dinner': {'time': TimeOfDay(18, 0), 'address': '123 Main St'}
  },
  // ... other days
};
```

### Meal Count Calculation
```dart
int _getTotalMealsSelected() {
  int total = 0;
  for (final day in _selectedDays) {
    total += _dayMealSelections[day]?.length ?? 0;
  }
  return total;
}
```

### Validation Example
```dart
void _toggleMealType(String day, String mealType) {
  final currentSelections = _dayMealSelections[day] ?? {};
  
  if (currentSelections.contains(mealType)) {
    // Remove meal
    currentSelections.remove(mealType);
  } else {
    // Check limit
    if (currentSelections.length >= _selectedPlan!.mealsPerDay) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Maximum ${_selectedPlan!.mealsPerDay} meals per day'))
      );
      return;
    }
    // Add meal
    currentSelections.add(mealType);
  }
  
  setState(() {
    _dayMealSelections[day] = currentSelections;
  });
}
```

## Benefits

1. **Flexibility**: Users control exact meals for each day
2. **Personalization**: Different schedules for different days
3. **Cost Control**: Only pay for meals actually selected
4. **Work-Life Balance**: Different meals for weekdays vs weekends
5. **Clear Validation**: Impossible to exceed plan limits

## Testing Checklist

- [ ] Test with 1 meal/day plan
- [ ] Test with 2 meals/day plan
- [ ] Test with 3 meals/day plan
- [ ] Verify meal limit enforcement per day
- [ ] Test day expansion/collapse
- [ ] Test meal configuration dialog
- [ ] Verify time picker functionality
- [ ] Verify address selection
- [ ] Test save validation (all fields required)
- [ ] Test navigation from Quick Setup flow
- [ ] Test navigation from AI Assisted flow
- [ ] Verify Firestore data structure compatibility

## Next Steps

1. **Test the implementation**
   - Run the app and test both Quick Setup and AI flows
   - Verify meal selection works correctly
   - Test with different meal plans (1, 2, 3 meals/day)

2. **Update Firestore schema** (if needed)
   - Current implementation assumes compatible data structure
   - May need to update delivery schedule document format
   - Ensure backward compatibility with V4 schedules

3. **Deploy to web**
   ```bash
   flutter build web --release
   firebase deploy --only hosting
   ```

4. **User Documentation**
   - Update help section with new flexible scheduling feature
   - Add tooltips explaining meal selection limits
   - Create tutorial for first-time users

## Files Modified

1. ✅ `lib/app_v3/pages/delivery_schedule_page_v5.dart` (created)
2. ✅ `lib/app_v3/pages/choose_meal_plan_page_v3.dart` (updated navigation)
3. ✅ `lib/app_v3/pages/ai_meal_plan_overview_page_v3.dart` (updated navigation)

## Status: ✅ Ready for Testing

All compile errors resolved. Navigation wired up. Ready for user testing.
