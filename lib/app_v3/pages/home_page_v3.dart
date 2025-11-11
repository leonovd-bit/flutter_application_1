import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import '../utils/date_utils.dart';
import '../theme/app_theme_v3.dart';
import '../models/meal_model_v3.dart';
import 'delivery/map_page_v3.dart';
import 'profile/settings_page_v3.dart';
import 'orders/past_orders_page_v3.dart';
import 'delivery/address_page_v3.dart';
import 'meals/menu_page_v3.dart';
import '../services/auth/firestore_service_v3.dart';
import '../services/orders/order_service_v3.dart';
import '../widgets/app_image.dart';
// Removed unused imports

class HomePageV3 extends StatefulWidget {
  const HomePageV3({super.key});

  @override
  State<HomePageV3> createState() => _HomePageV3State();
}

class _HomePageV3State extends State<HomePageV3> with WidgetsBindingObserver {
  // Optimized state management - reduce static data
  String _currentMealPlan = 'Pro';
  bool _hasComputedNextOrder = false; // Prevent fallback from overriding computed result

  
  // Lazy-loaded next order data
  Map<String, dynamic>? _nextOrder;
  
  // Real past orders from user data
  List<Map<String, dynamic>> _recentOrders = [];
  // User addresses (loaded from Firestore)
  List<AddressModelV3> _userAddresses = [];
  bool _isLoadingAddresses = false;
  String? _addressesError;
  StreamSubscription<QuerySnapshot>? _subActiveSub;

  // Timeline orders - expanded state
  String? _expandedOrderId;
  List<Map<String, dynamic>> _cachedTimelineOrders = []; // Cache timeline orders

  // Protein logging (removed feature)

  // Cached nutrition data
  Map<String, Map<String, int>> _cachedNutritionData = {
    'Mon': {'Calories': 0, 'Protein': 0, 'Fat': 0},
    'Tue': {'Calories': 0, 'Protein': 0, 'Fat': 0},
    'Wed': {'Calories': 0, 'Protein': 0, 'Fat': 0},
    'Thu': {'Calories': 0, 'Protein': 0, 'Fat': 0},
    'Fri': {'Calories': 0, 'Protein': 0, 'Fat': 0},
    'Sat': {'Calories': 0, 'Protein': 0, 'Fat': 0},
    'Sun': {'Calories': 0, 'Protein': 0, 'Fat': 0},
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadCurrentMealPlan();
    _loadOrderData();
    _loadAddresses();
    _listenPlanFromFirestore();
    _loadNutritionData(); // Load nutrition data from meal schedule
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subActiveSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Reload data when app comes to foreground
    if (state == AppLifecycleState.resumed) {
      _loadAddresses();
      _loadOrderData();
      // Also refresh nutrition totals so the weekly graph reflects latest selections
      _loadNutritionData();
    }
  }

  void _loadOrderData() {
    // Load real user order data
    _loadNextUpcomingOrder();
    _loadRecentOrders();
    
    // Fallback: Try loading from SharedPreferences after delay
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _loadUpcomingOrderFromLocalData();
      }
    });
  }

  /// Loads upcoming order data directly from SharedPreferences
  /// This serves as a fallback when Firebase data loading fails
  Future<void> _loadUpcomingOrderFromLocalData() async {
    try {
      debugPrint('[HomePage] Loading upcoming order from local data...');
      // Do not override if already determined via schedule logic
      if (_nextOrder != null || _hasComputedNextOrder) {
        debugPrint('[HomePage] Skipping local-data fallback: next order already set by schedule');
        return;
      }
      
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('[HomePage] No user logged in');
        return;
      }
      
      final prefs = await SharedPreferences.getInstance();
      
      // Prefer the user's selected schedule first; fallback to any meal selections key
      final selectedSchedule = prefs.getString('selected_schedule_${user.uid}') ?? 'weekly';
      Map<String, dynamic>? mealData;
      final directKey = 'meal_selections_${user.uid}_$selectedSchedule';
      final directJson = prefs.getString(directKey);
      if (directJson != null) {
        try {
          mealData = json.decode(directJson) as Map<String, dynamic>;
          debugPrint('[HomePage] Using meal selections from "$directKey"');
        } catch (e) {
          debugPrint('[HomePage] Error parsing "$directKey": $e');
        }
      }
      mealData ??= _findMealSelectionsData(prefs, user.uid);
      if (mealData == null) {
        debugPrint('[HomePage] No meal selections found');
        return;
      }
      
      // Find delivery schedule data  
      final scheduleData = _findDeliveryScheduleData(prefs, user.uid);
      if (scheduleData == null) {
        debugPrint('[HomePage] No delivery schedule found');
        return;
      }
      
      // Parse and set upcoming order
      _parseAndSetUpcomingOrder(mealData, scheduleData);
      
    } catch (e) {
      debugPrint('[HomePage] Error loading from local data: $e');
    }
  }

  /// Finds meal selections data in SharedPreferences
  Map<String, dynamic>? _findMealSelectionsData(SharedPreferences prefs, String userId) {
    final allKeys = prefs.getKeys();
    
    for (final key in allKeys) {
      if (key.contains('meal_selections_${userId}_')) {
        final jsonString = prefs.getString(key);
        if (jsonString != null) {
          try {
            return json.decode(jsonString) as Map<String, dynamic>;
          } catch (e) {
            debugPrint('[HomePage] Error parsing meal selections: $e');
          }
        }
      }
    }
    return null;
  }

  /// Finds delivery schedule data in SharedPreferences
  Map<String, dynamic>? _findDeliveryScheduleData(SharedPreferences prefs, String userId) {
    final jsonString = prefs.getString('delivery_schedule_$userId');
    if (jsonString != null) {
      try {
        return json.decode(jsonString) as Map<String, dynamic>;
      } catch (e) {
        debugPrint('[HomePage] Error parsing delivery schedule: $e');
      }
    }
    return null;
  }

  /// Parses meal and schedule data and sets the upcoming order
  void _parseAndSetUpcomingOrder(Map<String, dynamic> mealSelections, Map<String, dynamic> deliverySchedule) {
    for (final day in mealSelections.keys) {
      final dayMeals = mealSelections[day] as Map<String, dynamic>?;
      if (dayMeals == null) continue;
      
      for (final mealType in dayMeals.keys) {
        final mealData = dayMeals[mealType] as Map<String, dynamic>?;
        if (mealData == null) continue;
        
        // Get delivery time for this meal
        final timeStr = _getDeliveryTime(deliverySchedule, day, mealType);
        if (timeStr == null) continue;
        
        // Create meal object
        try {
          final meal = MealModelV3.fromJson(mealData);
          final formattedTime = _formatTimeOnly(timeStr);
          
          setState(() {
            _nextOrder = {
              'meal': meal,
              'mealName': meal.name,
              'deliveryTime': formattedTime, // Store formatted time string
              'imageUrl': meal.imagePath, // Use imagePath getter instead of imageUrl
              'calories': meal.calories,
              'protein': meal.protein,
              'deliveryAddress': 'Your Address',
              'orderId': 'upcoming_${day}_$mealType',
              'day': day,
            };
            // Reset timeline cache when upcoming order changes so status is rebuilt
            _cachedTimelineOrders = [];
            _expandedOrderId = null;
          });
          
          debugPrint('[HomePage] ✅ Set upcoming meal: ${meal.name} at $formattedTime');
          return; // Found and set the first available meal
          
        } catch (e) {
          debugPrint('[HomePage] Error creating meal object: $e');
        }
      }
    }
  }

  /// Extracts delivery time from schedule data
  String? _getDeliveryTime(Map<String, dynamic> deliverySchedule, String day, String mealType) {
    Map<String, dynamic>? daySchedule = deliverySchedule[day] as Map<String, dynamic>?;
    daySchedule ??= deliverySchedule[_toTitleCase(day)] as Map<String, dynamic>?;
    daySchedule ??= deliverySchedule[day.toLowerCase()] as Map<String, dynamic>?;

    if (daySchedule == null) return null;

    Map<String, dynamic>? mealSchedule = daySchedule[mealType] as Map<String, dynamic>?;
    mealSchedule ??= daySchedule[mealType.toLowerCase()] as Map<String, dynamic>?;
    mealSchedule ??= daySchedule[_toTitleCase(mealType)] as Map<String, dynamic>?;
    final val = mealSchedule?['time'];
    if (val is String) return val;
    return null;
  }

  /// Formats time string (HH:MM) to display format (H:MM AM/PM)
  String _formatTimeOnly(String timeStr) {
    try {
      final parts = timeStr.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
      final displayMinute = minute.toString().padLeft(2, '0');
      
      return '$displayHour:$displayMinute $period';
    } catch (e) {
      debugPrint('[HomePage] Error formatting time $timeStr: $e');
      return timeStr; // Return original if formatting fails
    }
  }

  // Load recent orders from Firebase
  Future<void> _loadRecentOrders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // no-op loading state removed

    try {
      final orders = await OrderServiceV3.getUserRecentOrders(user.uid, limit: 3);
      if (mounted) {
        setState(() {
          _recentOrders = orders;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          // Keep empty list if there's an error
          _recentOrders = [];
        });
      }
    }
  }

  Future<void> _loadNextUpcomingOrder() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _nextOrder = null);
        return;
      }

      // Load from meal schedule data instead of Firestore orders
      final prefs = await SharedPreferences.getInstance();
      
      // Check if this is a new subscription or existing one
      final hasExisting = await DateUtilsV3.hasExistingSubscription();
      debugPrint('[HomePage] Has existing subscription: $hasExisting');

      // Try current selected schedule first; if missing, pick the first meal_selections entry for this user
      String? mealSelectionsJson = prefs.getString('meal_selections_${user.uid}_${prefs.getString('selected_schedule_${user.uid}') ?? 'weekly'}');
      if (mealSelectionsJson == null) {
        final firstKey = prefs
            .getKeys()
            .firstWhere((k) => k.startsWith('meal_selections_${user.uid}_'), orElse: () => '');
        if (firstKey.isNotEmpty) {
          mealSelectionsJson = prefs.getString(firstKey);
        }
      }
      if (mealSelectionsJson == null) {
        setState(() => _nextOrder = null);
        return;
      }

      final mealSelections = json.decode(mealSelectionsJson) as Map<String, dynamic>;
      
      // Load delivery schedule to get times and addresses
      final deliveryScheduleJson = prefs.getString('delivery_schedule_${user.uid}');
      Map<String, dynamic> deliverySchedule = {};
      if (deliveryScheduleJson != null) {
        deliverySchedule = json.decode(deliveryScheduleJson) as Map<String, dynamic>;
      }
      
      // Find the next upcoming meal delivery
      final now = DateTime.now();
      final today = now.weekday;
      final currentTime = TimeOfDay.fromDateTime(now);
      
      MealModelV3? nextMeal;
      String? nextMealType;
      String? nextDeliveryTime;
      String? nextDeliveryAddress;
      String nextDay = '';
      
      // Days in order from Monday to Sunday
      final daysToCheck = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
      final nextMonday = DateUtilsV3.getNextMonday();
      
      // For new subscriptions, start from next Monday. For existing, start from today.
      final firstValidDate = hasExisting ? now : nextMonday;
      debugPrint('[HomePage] First valid date: ${firstValidDate.toIso8601String()}, hasExisting: $hasExisting');
      
      // Calculate the index offset based on firstValidDate's weekday
      final startIndex = firstValidDate.weekday - 1; // 0-based index for Monday
      debugPrint('[HomePage] Starting with weekday ${firstValidDate.weekday} (${daysToCheck[startIndex]})');

      // Iterate through 7 days, starting from the firstValidDate's weekday
      for (int offset = 0; offset < 7; offset++) {
        final dayIndex = (startIndex + offset) % 7; // Wrap around at end of week
        final checkDayName = daysToCheck[dayIndex];
        final checkDate = firstValidDate.add(Duration(days: offset));
        
        debugPrint('[HomePage] Checking day $checkDayName (${checkDate.toIso8601String()})');

        // Skip invalid dates for new subscriptions
        if (!hasExisting && checkDate.isBefore(nextMonday)) {
          debugPrint('[HomePage] Skipping $checkDayName as it\'s before next Monday');
          continue;
        }
        
        final dayMeals = _getDayMealsFlexible(mealSelections, checkDayName);
        if (dayMeals == null) continue;
        
  final dayDelivery = _getDayMealsFlexible(deliverySchedule, checkDayName);
        
        // Check breakfast, lunch, dinner in chronological order
  for (final mealType in ['breakfast', 'lunch', 'dinner']) {
          final mealData = _getMealFlexible(dayMeals, mealType);
          if (mealData == null) continue;
          
          final deliveryConfig = dayDelivery == null ? null : _getMealFlexible(dayDelivery, mealType);
          final timeStr = deliveryConfig?['time'] as String?;
          
          if (timeStr != null) {
            final timeParts = timeStr.split(':');
            if (timeParts.length == 2) {
              final hour = int.tryParse(timeParts[0]);
              final minute = int.tryParse(timeParts[1]);
              
              if (hour != null && minute != null) {
                final mealTime = TimeOfDay(hour: hour, minute: minute);
                
                // If this is today, check if the time hasn't passed yet
                if (offset == 0) {
                  final mealMinutes = mealTime.hour * 60 + mealTime.minute;
                  final currentMinutes = currentTime.hour * 60 + currentTime.minute;
                  
                  if (mealMinutes <= currentMinutes) {
                    continue; // This meal time has already passed today
                  }
                }
                
                // Found the next upcoming meal
                try {
                  nextMeal = MealModelV3.fromJson(mealData);
                  nextMealType = mealType;
                  nextDeliveryTime = timeStr;
                  nextDeliveryAddress = deliveryConfig?['address'] as String? ?? 'Address not set';
                  nextDay = checkDayName;
                  break;
                } catch (e) {
                  debugPrint('[HomePage] Error parsing meal data: $e');
                }
              }
            }
          }
        }
        
        if (nextMeal != null) break;
      }
      
      if (nextMeal != null && nextDeliveryTime != null) {
        final MealModelV3 meal = nextMeal;
        setState(() {
          _nextOrder = {
            'mealType': nextMealType ?? 'lunch',
            'mealName': meal.name,
            'deliveryTime': nextDeliveryTime,
            'imageUrl': meal.imagePath, // Use imagePath getter instead of imageUrl
            'calories': meal.calories,
            'protein': meal.protein,
            'deliveryAddress': nextDeliveryAddress ?? 'Address not set',
            'orderId': 'meal_${nextDay}_${nextMealType}',
            'day': nextDay,
          };
          // Reset timeline cache when upcoming order changes so status is rebuilt
          _cachedTimelineOrders = [];
          _expandedOrderId = null;
        });
        _hasComputedNextOrder = true;
        debugPrint('[HomePage] Found next meal: ${meal.name} on $nextDay at $nextDeliveryTime');
      } else {
        setState(() => _nextOrder = null);
        debugPrint('[HomePage] No upcoming meals found in schedule');
      }
      
    } catch (e) {
      debugPrint('[HomePage] Error loading upcoming meal from schedule: $e');
      setState(() => _nextOrder = null);
    }
  }

  // Flexible accessors for mixed-case maps coming from different pages
  Map<String, dynamic>? _getDayMealsFlexible(Map<String, dynamic> map, String dayLower) {
    debugPrint('[HomePage] 🔎 _getDayMealsFlexible called with dayLower="$dayLower"');
    debugPrint('[HomePage] 🔎 Map has ${map.length} top-level entries');
    debugPrint('[HomePage] 🔎 Top-level keys: ${map.keys.take(10).join(', ')}');
    
    if (dayLower.isEmpty) {
      debugPrint('[HomePage] ❌ Empty day name provided');
      return null;
    }

    // First standardize the input day name by removing any numbers and special characters
    final searchDay = dayLower
      .toLowerCase()
      .trim()
      .replaceAll(RegExp(r'[0-9]+'), '') // Remove numbers
      .replaceAll(RegExp(r'[^a-z]'), '') // Remove non-letters
      .trim();

    if (searchDay.isEmpty) {
      debugPrint('[HomePage] ❌ Day name contains no letters: "$dayLower"');
      return null;
    }

    debugPrint('[HomePage] 🔍 Searching with standardized day: "$searchDay"');

    // Core map of standard day names to normalized variations
    const dayMappings = {
      'monday': ['mon', 'monday', 'mondayall', 'monall', 'm'],
      'tuesday': ['tue', 'tues', 'tuesday', 'tuesdayall', 'tueall', 't'],
      'wednesday': ['wed', 'weds', 'wednesday', 'wednesdayall', 'wedall', 'w'],
      'thursday': ['thu', 'thur', 'thurs', 'thursday', 'thursdayall', 'thuall', 'th'],
      'friday': ['fri', 'friday', 'fridayall', 'friall', 'f'],
      'saturday': ['sat', 'saturday', 'saturdayall', 'satall', 's'],
      'sunday': ['sun', 'sunday', 'sundayall', 'sunall', 'su']
    };

    // Helper to normalize a key string
    String normalizeKey(String key) {
      return key
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[0-9]+'), '')
        .replaceAll(RegExp(r'[^a-z]'), '')
        .trim();
    }

    // 1. First try direct key match
    if (map.containsKey(dayLower)) {
      debugPrint('[HomePage] ✅ Found exact key match for "$dayLower"');
      return map[dayLower] as Map<String, dynamic>?;
    }

    // 2. Find standard day based on input
    String? standardDay;
    String? matchedVariant;

    // Try exact match first
    for (final entry in dayMappings.entries) {
      if (entry.value.contains(searchDay)) {
        standardDay = entry.key;
        matchedVariant = searchDay;
        break;
      }
    }

    // If no exact match, try prefix match with minimum 3 chars
    if (standardDay == null && searchDay.length >= 3) {
      for (final entry in dayMappings.entries) {
        for (final variant in entry.value) {
          if (variant.startsWith(searchDay)) {
            standardDay = entry.key;
            matchedVariant = variant;
            break;
          }
        }
        if (standardDay != null) break;
      }
    }

    if (standardDay == null) {
      debugPrint('[HomePage] ❌ Could not determine standard day for "$searchDay"');
      return null;
    }

    // 3. Try to find a matching key in various forms
    final attempts = [
      standardDay,
      '${standardDay}1',
      standardDay.substring(0, 3),
      standardDay[0].toUpperCase() + standardDay.substring(1),
      standardDay.toUpperCase(),
      matchedVariant,
    ];

    // Try direct matches first
    for (final attempt in attempts) {
      if (map.containsKey(attempt)) {
        debugPrint('[HomePage] ✅ Found direct match with attempt: "$attempt"');
        return map[attempt] as Map<String, dynamic>?;
      }
    }

    // Try case-insensitive matching on normalized keys
    for (final key in map.keys) {
      final normalizedKey = normalizeKey(key.toString());
      if (attempts.contains(normalizedKey)) {
        debugPrint('[HomePage] ✅ Found case-insensitive match: "$key" normalizes to "$normalizedKey"');
        return map[key] as Map<String, dynamic>?;
      }
    }

    // 4. Last resort: Partial matches on normalized strings
    for (final key in map.keys) {
      final normalizedKey = normalizeKey(key.toString());
      if (normalizedKey.contains(searchDay) || searchDay.contains(normalizedKey)) {
        debugPrint('[HomePage] ✅ Found partial match: "$key" contains or is contained by "$searchDay"');
        return map[key] as Map<String, dynamic>?;
      }
    }

    // 5. Try common nested containers (one level deep)
    const likelyContainers = ['days', 'schedule', 'week', 'weeks', 'delivery', 'deliverydays', 'meals'];
    for (final key in map.keys) {
      final kLower = key.toString().toLowerCase();
      if (!likelyContainers.contains(kLower)) continue;
      final val = map[key];
      if (val is Map<String, dynamic>) {
        final found = _getDayMealsFlexible(val, dayLower);
        if (found != null) {
          debugPrint('[HomePage] ✅ Found day "$dayLower" in nested container "$key"');
          return found;
        }
      }
    }

    // 6. Scan any nested maps (one level deep)
    for (final entry in map.entries) {
      final val = entry.value;
      if (val is Map<String, dynamic>) {
        final found = _getDayMealsFlexible(val, dayLower);
        if (found != null) {
          debugPrint('[HomePage] ✅ Found day "$dayLower" in nested map under key "${entry.key}"');
          return found;
        }
      }
    }
    // 4. Last resort: Partial matches on normalized strings
    debugPrint('[HomePage] ❌ No meals found for day "$dayLower" after exhausting all matching attempts');
    return null;
  }

  Map<String, dynamic>? _getMealFlexible(Map<String, dynamic> dayMap, String mealLower) {
    // Map of standard meal types to all possible variations
    final mealVariants = {
      'breakfast': ['breakfast', 'b', 'bfast', 'brek', 'brk', 'Breakfast', 'BREAKFAST'],
      'lunch': ['lunch', 'l', 'lun', 'Lunch', 'LUNCH'],
      'dinner': ['dinner', 'd', 'din', 'Dinner', 'DINNER']
    };

    // Normalize input meal type
    final searchMeal = mealLower.toLowerCase().trim();

    // First try exact match
    if (dayMap.containsKey(searchMeal)) {
      return dayMap[searchMeal] as Map<String, dynamic>?;
    }

    // Find which standard meal type this matches
    String? standardMeal;
    for (final entry in mealVariants.entries) {
      if (entry.value.contains(searchMeal)) {
        standardMeal = entry.key;
        break;
      }
    }

    if (standardMeal != null) {
      // Try all variants of this meal type
      for (final variant in mealVariants[standardMeal]!) {
        if (dayMap.containsKey(variant)) {
          return dayMap[variant] as Map<String, dynamic>?;
        }
      }

      // Try case-insensitive match
      for (final key in dayMap.keys) {
        if (mealVariants[standardMeal]!.contains(key.toString().toLowerCase().trim())) {
          return dayMap[key] as Map<String, dynamic>?;
        }
      }
    }

    // Fallback to basic variations
    return (dayMap[_toTitleCase(searchMeal)] as Map<String, dynamic>?)
        ?? (dayMap[searchMeal.toUpperCase()] as Map<String, dynamic>?);
  }

  /// Confirm the next upcoming order and create it in Firestore
  Future<void> _confirmOrder() async {
    if (_nextOrder == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No order to confirm'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final orderId = _nextOrder!['orderId'] as String;
      debugPrint('[HomePage] Confirming order: $orderId');

      // Get meal data from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final selectedSchedule = prefs.getString('selected_schedule_${user.uid}') ?? 'weekly';
      final mealSelectionsJson = prefs.getString('meal_selections_${user.uid}_$selectedSchedule');
      
      if (mealSelectionsJson == null) {
        throw Exception('No meal selections found');
      }

      final mealSelections = json.decode(mealSelectionsJson) as Map<String, dynamic>;
      debugPrint('[HomePage] Available meal days: ${mealSelections.keys.join(', ')}');
      
      // Get day and meal type, with debug logging
      final rawDay = _nextOrder!['day'] as String?;
      // Clean day name and convert to TitleCase to match saved format
      final cleanedDay = rawDay?.toLowerCase().replaceAll(RegExp(r'\s+\d+$'), '').trim();
      final dayName = cleanedDay != null && cleanedDay.isNotEmpty
          ? cleanedDay[0].toUpperCase() + cleanedDay.substring(1).toLowerCase()
          : cleanedDay;
      debugPrint('[HomePage] Looking up meals for day: "$dayName"');
      
      // Convert meal type to TitleCase to match saved format (Breakfast, Lunch, Dinner)
      final rawMealType = (_nextOrder!['mealType'] as String?)?.toLowerCase();
      final mealType = rawMealType != null && rawMealType.isNotEmpty
          ? rawMealType[0].toUpperCase() + rawMealType.substring(1).toLowerCase()
          : rawMealType;
      
      debugPrint('[HomePage] 📅 Raw day from _nextOrder: $rawDay');
      debugPrint('[HomePage] 📅 Cleaned day name (TitleCase): $dayName');
      debugPrint('[HomePage] 🍽️ Meal type (TitleCase): $mealType');
      debugPrint('[HomePage] 🔍 Available days in selections: ${mealSelections.keys.join(', ')}');
      
      if (dayName == null || mealType == null) {
        throw Exception('Invalid day or meal type');
      }
      
      // DIAGNOSTICS: Log structure before lookup
      debugPrint('[HomePage] 🔍 DIAGNOSTICS: About to look up day "$dayName" in mealSelections');
      debugPrint('[HomePage] 🔍 Top-level keys: ${mealSelections.keys.take(10).join(', ')}');
      final sample = mealSelections.entries.take(5).map((e) => '${e.key}:${e.value.runtimeType}').join(', ');
      debugPrint('[HomePage] 🔍 Structure sample: $sample');
      
      // Try direct lookup first (TitleCase keys)
      Map<String, dynamic>? dayMeals = mealSelections[dayName] as Map<String, dynamic>?;
      
      // Fall back to flexible lookup if direct fails
      if (dayMeals == null) {
        dayMeals = _getDayMealsFlexible(mealSelections, dayName);
      }

      // If not found, try scanning keys for close matches (case-insensitive or prefix)
      if (dayMeals == null) {
        debugPrint('[HomePage] ❌ FIRST NULL CHECK: Day lookup failed for "$dayName"');
        debugPrint('[HomePage] Available keys: ${mealSelections.keys.join(', ')}');
        // Extra diagnostics: show first-level structure and common containers
        try {
          for (final container in ['days','schedule','week','weeks','delivery','deliveryDays','meals']) {
            final val = mealSelections[container] ?? mealSelections[container.toLowerCase()];
            if (val is Map) {
              debugPrint('[HomePage] Container "$container" has keys: ${val.keys.join(', ')}');
            }
          }
        } catch (e) {
          debugPrint('[HomePage] Error scanning containers: $e');
        }
        for (final k in mealSelections.keys) {
          try {
            final kLower = k.toString().toLowerCase();
            if (kLower == dayName || kLower.startsWith(dayName.substring(0, 3))) {
              final candidate = mealSelections[k] as Map<String, dynamic>?;
              if (candidate != null) {
                dayMeals = candidate;
                debugPrint('[HomePage] Found day match by key "$k" for "$dayName"');
                break;
              }
            }
            // Title-case match
            if (_toTitleCase(kLower) == _toTitleCase(dayName)) {
              final candidate = mealSelections[k] as Map<String, dynamic>?;
              if (candidate != null) {
                dayMeals = candidate;
                debugPrint('[HomePage] Found day match by TitleCase key "$k" for "$dayName"');
                break;
              }
            }
          } catch (_) {
            // ignore malformed entries
          }
        }
      }

      if (dayMeals == null) throw Exception('No meals for $dayName');

      // Try direct TitleCase lookup first
      Map<String, dynamic>? mealData = dayMeals[mealType] as Map<String, dynamic>?;
      
      // Fall back to flexible lookup
      if (mealData == null) {
        mealData = _getMealFlexible(dayMeals, mealType);
      }
      
      if (mealData == null) throw Exception('No $mealType meal for $dayName');

  final meal = MealModelV3.fromJson(mealData);
      
      // Get delivery schedule to find the delivery date/time
      final deliveryScheduleJson = prefs.getString('delivery_schedule_${user.uid}');
      if (deliveryScheduleJson == null) throw Exception('No delivery schedule found');
      
  final deliverySchedule = json.decode(deliveryScheduleJson) as Map<String, dynamic>;
  final daySchedule = _getDayMealsFlexible(deliverySchedule, dayName);
  final mealSchedule = daySchedule == null ? null : _getMealFlexible(daySchedule, mealType);
  final timeStr = mealSchedule?['time'] as String? ?? '12:30';
  final address = mealSchedule?['address'] as String? ?? _nextOrder!['deliveryAddress'] ?? '350 5th ave';

      // Calculate delivery date (next occurrence of this day)
      debugPrint('[HomePage] 🗓️ Calculating delivery date for day: "$dayName"');
      final now = DateTime.now();
      final daysOfWeek = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
      
      // Normalize day name for comparison
      final normalizedDayName = dayName.toLowerCase().trim();
      debugPrint('[HomePage] 📅 Normalized day name: "$normalizedDayName"');
      
      // Find the day index with more flexible matching
      int targetDayIndex = daysOfWeek.indexOf(normalizedDayName);
      if (targetDayIndex == -1) {
        // Try prefix matching (e.g., "mon" -> "monday")
        targetDayIndex = daysOfWeek.indexWhere((day) => day.startsWith(normalizedDayName.substring(0, math.min(3, normalizedDayName.length))));
      }
      if (targetDayIndex == -1) {
        // Use Monday as fallback
        debugPrint('[HomePage] ⚠️ Could not determine day index for "$dayName", defaulting to Monday');
        targetDayIndex = 0;
      } else {
        debugPrint('[HomePage] ✅ Found day index $targetDayIndex for "$dayName"');
      }
      
      final todayIndex = (now.weekday - 1) % 7;
      
      int daysUntil = (targetDayIndex - todayIndex) % 7;
      if (daysUntil == 0) daysUntil = 7; // Next week if it's today
      
      final deliveryDate = now.add(Duration(days: daysUntil));
      final timeParts = timeStr.split(':');
      final hour = int.tryParse(timeParts[0]) ?? 12;
      final minute = timeParts.length > 1 ? int.tryParse(timeParts[1]) ?? 30 : 30;
      
      final deliveryDateTime = DateTime(
        deliveryDate.year,
        deliveryDate.month,
        deliveryDate.day,
        hour,
        minute,
      );

      // Check if order already exists in Firestore
      final orderDoc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .get();

      if (!orderDoc.exists) {
        // Create order in Firestore with all Square fields
        await FirebaseFirestore.instance.collection('orders').doc(orderId).set({
          'id': orderId,
          'userId': user.uid,
          'userEmail': user.email ?? '',
          'meals': [
            {
              'id': meal.id,
              'name': meal.name,
              'description': meal.description,
              'calories': meal.calories,
              'protein': meal.protein,
              'fat': meal.fat,
              'carbs': meal.carbs,
              'imageUrl': meal.imagePath,
              'price': meal.price,
              'mealType': mealType,
              // Include Square fields for order forwarding
              'restaurantId': meal.restaurantId,
              'squareItemId': meal.squareItemId,
              'squareVariationId': meal.squareVariationId,
            }
          ],
          'deliveryAddress': address,
          'orderDate': FieldValue.serverTimestamp(),
          'deliveryDate': Timestamp.fromDate(deliveryDateTime),
          'estimatedDeliveryTime': Timestamp.fromDate(deliveryDateTime),
          'status': 'confirmed', // Create as confirmed to trigger forwardOrderToSquare
          'totalAmount': meal.price,
          'dayName': dayName,
          'mealType': mealType,
          'source': 'home_page',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        debugPrint('[HomePage] ✅ Created order in Firestore: $orderId');
        debugPrint('[HomePage] 📦 Meal: ${meal.name}');
        debugPrint('[HomePage] 🏪 Restaurant ID: ${meal.restaurantId ?? "NULL - ORDER WILL NOT FORWARD!"}');
        debugPrint('[HomePage] 🔲 Square Item ID: ${meal.squareItemId ?? "NULL - ORDER WILL NOT FORWARD!"}');
        debugPrint('[HomePage] 🔲 Square Variation ID: ${meal.squareVariationId ?? "NULL - ORDER WILL NOT FORWARD!"}');
      } else {
        // Order exists, just update status to confirmed
        await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
          'status': 'confirmed',
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        debugPrint('[HomePage] ✅ Updated existing order to confirmed: $orderId');
      }

      // Update UI
      if (mounted) {
        setState(() {
          _cachedTimelineOrders = _cachedTimelineOrders.map((order) {
            if (order['id'] == orderId) {
              return {...order, 'status': 'confirmed'};
            }
            return order;
          }).toList();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Order confirmed! Forwarding to restaurant...'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }

    } catch (e) {
      debugPrint('[HomePage] ❌ Error confirming order: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error confirming order: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _toTitleCase(String s) {
    if (s.isEmpty) return s;
    final t = s.trim();
    return t[0].toUpperCase() + t.substring(1).toLowerCase();
  }

  /// Calculate nutrition totals from user's meal schedule
  Map<String, Map<String, int>> _calculateWeekNutrition() {
    // Return cached data that was loaded in initState
    return _cachedNutritionData;
  }

  /// Load nutrition data from SharedPreferences and cache it
  Future<void> _loadNutritionData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final prefs = await SharedPreferences.getInstance();
      
      // Find meal selections data
      String? mealSelectionsJson;
      final selectedSchedule = prefs.getString('selected_schedule_${user.uid}') ?? 'weekly';
      mealSelectionsJson = prefs.getString('meal_selections_${user.uid}_$selectedSchedule');
      
      // Fallback: find any meal_selections entry for this user
      if (mealSelectionsJson == null) {
        final firstKey = prefs
            .getKeys()
            .firstWhere((k) => k.startsWith('meal_selections_${user.uid}_'), orElse: () => '');
        if (firstKey.isNotEmpty) {
          mealSelectionsJson = prefs.getString(firstKey);
        }
      }

      if (mealSelectionsJson == null) return;

      final mealSelections = json.decode(mealSelectionsJson) as Map<String, dynamic>;
      
      // Reset cached data
      final newData = <String, Map<String, int>>{
        'Mon': {'Calories': 0, 'Protein': 0, 'Fat': 0},
        'Tue': {'Calories': 0, 'Protein': 0, 'Fat': 0},
        'Wed': {'Calories': 0, 'Protein': 0, 'Fat': 0},
        'Thu': {'Calories': 0, 'Protein': 0, 'Fat': 0},
        'Fri': {'Calories': 0, 'Protein': 0, 'Fat': 0},
        'Sat': {'Calories': 0, 'Protein': 0, 'Fat': 0},
        'Sun': {'Calories': 0, 'Protein': 0, 'Fat': 0},
      };
      
      // Map full day names to short names
      final dayMapping = {
        'monday': 'Mon',
        'tuesday': 'Tue',
        'wednesday': 'Wed',
        'thursday': 'Thu',
        'friday': 'Fri',
        'saturday': 'Sat',
        'sunday': 'Sun',
      };

      // Iterate through each day
      for (final dayEntry in mealSelections.entries) {
        final dayLower = dayEntry.key.toLowerCase();
        final shortDay = dayMapping[dayLower];
        if (shortDay == null) continue;

        final dayMeals = dayEntry.value as Map<String, dynamic>?;
        if (dayMeals == null) continue;

        // Iterate through meal types (breakfast, lunch, dinner)
        for (final mealEntry in dayMeals.entries) {
          final mealData = mealEntry.value as Map<String, dynamic>?;
          if (mealData == null) continue;

          try {
            final meal = MealModelV3.fromJson(mealData);
            
            // Add nutrition values
            newData[shortDay]!['Calories'] = 
                newData[shortDay]!['Calories']! + meal.calories;
            newData[shortDay]!['Protein'] = 
                newData[shortDay]!['Protein']! + meal.protein;
            newData[shortDay]!['Fat'] = 
                newData[shortDay]!['Fat']! + meal.fat;
          } catch (e) {
            debugPrint('[HomePage] Error parsing meal for $dayLower: $e');
          }
        }
      }

      // Update cached data and trigger rebuild
      if (mounted) {
        setState(() {
          _cachedNutritionData = newData;
        });
      }
    } catch (e) {
      debugPrint('[HomePage] Error loading nutrition data: $e');
    }
  }

  // Load the selected meal plan from storage
  Future<void> _loadCurrentMealPlan() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final serverName = await FirestoreServiceV3.getDisplayPlanName(uid);
        if (serverName != null && serverName.isNotEmpty) {
          if (!mounted) return;
          setState(() => _currentMealPlan = serverName);
          return;
        }
      }
      // Fallback to local preference
      final prefs = await SharedPreferences.getInstance();
      final prefName = prefs.getString('selected_meal_plan_display_name') ?? prefs.getString('selected_meal_plan_name');
      if (prefName != null && prefName.isNotEmpty) {
        if (!mounted) return;
        setState(() => _currentMealPlan = prefName);
      }
    } catch (e) {
      debugPrint('Error loading meal plan: $e');
    }
  }

  void _listenPlanFromFirestore() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    // Listen to the user's active subscription doc and reflect plan changes immediately
    final col = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('subscriptions');
    _subActiveSub = col
        .where('status', isEqualTo: 'active')
        .limit(1)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      if (snap.docs.isEmpty) return;
      final data = snap.docs.first.data();
      final planName = (data['planName'] as String?)?.trim();
      if (planName != null && planName.isNotEmpty) {
        setState(() {
          _currentMealPlan = planName;
        });
        return;
      }
      // Derive from mealPlanId if planName missing
      final mealPlanId = (data['mealPlanId'] as String?)?.trim();
      if (mealPlanId != null && mealPlanId.isNotEmpty) {
        final plans = MealPlanModelV3.getAvailablePlans();
        final match = plans.firstWhere(
          (p) => p.id == mealPlanId,
          orElse: () => plans.first,
        );
        setState(() {
          _currentMealPlan = match.displayName.isNotEmpty ? match.displayName : match.name;
        });
      }
    });
  }

  Future<void> _loadAddresses() async {
    setState(() {
      _isLoadingAddresses = true;
      _addressesError = null;
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
  // Load addresses from SharedPreferences (where delivery schedule saves them)
      final prefs = await SharedPreferences.getInstance();
      final addressList = prefs.getStringList('user_addresses') ?? [];
      
      debugPrint('[HomePage] Loading addresses from SharedPreferences...');
      debugPrint('[HomePage] Found ${addressList.length} address entries');
      
      final List<AddressModelV3> loadedAddresses = [];
      for (final jsonStr in addressList) {
        try {
          debugPrint('[HomePage] Parsing address: $jsonStr');
          final data = json.decode(jsonStr) as Map<String, dynamic>;
          final address = AddressModelV3(
            id: data['id'] ?? 'addr_${DateTime.now().millisecondsSinceEpoch}',
            userId: user.uid,
            label: (data['label'] ?? 'Address').toString(),
            streetAddress: (data['streetAddress'] ?? '').toString(),
            apartment: (data['apartment'] ?? '').toString(),
            city: (data['city'] ?? '').toString(),
            state: (data['state'] ?? '').toString(),
            zipCode: (data['zipCode'] ?? '').toString(),
            isDefault: data['isDefault'] == true,
            createdAt: DateTime.now(),
          );
          loadedAddresses.add(address);
        } catch (e) {
          debugPrint('[HomePage] Error parsing address: $e');
        }
      }
      
      // Sort default address first
      loadedAddresses.sort((a, b) {
        if (a.isDefault == b.isDefault) return 0;
        return a.isDefault ? -1 : 1;
      });
      
      // Fallback: if none found, try single-string delivery address saved elsewhere
      if (loadedAddresses.isEmpty) {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        final single = uid == null ? null : prefs.getString('user_delivery_address_$uid');
        if (single != null && single.trim().isNotEmpty) {
          final addr = AddressModelV3(
            id: 'addr_${DateTime.now().millisecondsSinceEpoch}',
            userId: uid ?? '',
            label: 'Delivery Address',
            streetAddress: single.trim(),
            apartment: '',
            city: '',
            state: '',
            zipCode: '',
            isDefault: true,
          );
          loadedAddresses.add(addr);
          // Persist into user_addresses list so it appears next time
          final updated = List<String>.from(addressList)..add(json.encode({
            'id': addr.id,
            'userId': addr.userId,
            'label': addr.label,
            'streetAddress': addr.streetAddress,
            'apartment': addr.apartment,
            'city': addr.city,
            'state': addr.state,
            'zipCode': addr.zipCode,
            'isDefault': addr.isDefault,
            'createdAt': DateTime.now().toIso8601String(),
          }));
          await prefs.setStringList('user_addresses', updated);
        }
      }

      if (!mounted) return;
      setState(() {
        _userAddresses = loadedAddresses;
        _addressesError = loadedAddresses.isEmpty ? 'No addresses saved' : null;
        _isLoadingAddresses = false;
      });
      
      debugPrint('[HomePage] Loaded ${loadedAddresses.length} addresses from SharedPreferences');
    } catch (e) {
      // On failure, attempt to use cached addresses
      final cached = await _loadCachedAddresses();
      if (!mounted) return;
      if (cached.isNotEmpty) {
        setState(() {
          _userAddresses = cached;
          _addressesError = null; // hide error if we have cached data
          _isLoadingAddresses = false;
        });
      } else {
        setState(() {
          _addressesError = 'Failed to load addresses';
          _isLoadingAddresses = false;
        });
      }
  // Log for debugging
  debugPrint('Error loading addresses: $e');
    }
  }

  // Removed unused _cacheAddresses helper

  Future<List<AddressModelV3>> _loadCachedAddresses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('cached_addresses');
      if (raw == null || raw.isEmpty) return [];
      final list = (jsonDecode(raw) as List<dynamic>?) ?? [];
      final addresses = list.map((e) => AddressModelV3.fromJson(Map<String, dynamic>.from(e))).toList();
      // Default-first sort
      addresses.sort((a, b) {
        if (a.isDefault == b.isDefault) return 0;
        return a.isDefault ? -1 : 1;
      });
      return addresses;
    } catch (_) {
      return [];
    }
  }

  /// Build smart address display - only show non-empty parts
  String _buildSmartAddress(AddressModelV3 address) {
    final parts = <String>[];
    
    // Add street address
    if (address.streetAddress.isNotEmpty) {
      parts.add(address.streetAddress);
    }
    
    // Add apartment if present
    if (address.apartment.isNotEmpty) {
      parts.add(address.apartment);
    }
    
    // Build city, state, zip line
    final locationParts = <String>[];
    if (address.city.isNotEmpty) {
      locationParts.add(address.city);
    }
    if (address.state.isNotEmpty) {
      locationParts.add(address.state);
    }
    if (address.zipCode.isNotEmpty) {
      locationParts.add(address.zipCode);
    }
    
    if (locationParts.isNotEmpty) {
      parts.add(locationParts.join(', '));
    }
    
    return parts.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeV3.background,
      body: Stack(
        children: [
          // Main content
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24), // Reduced top padding further
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 200), // Even more space to push circle much lower
                
                // Circle of Health - centered and lower
                Center(
                  child: _buildCircleOfHealth(),
                ),
                
                const SizedBox(height: 48), // More space after circle
                
                // Extra Protein logging removed
                const SizedBox(height: 0),
                
                // Addresses Section
                _buildAddressesSection(),
                
                const SizedBox(height: 24),
                
                // Upcoming Orders
                _buildUpcomingOrdersSection(),
                
                const SizedBox(height: 24),
                
                // Past Orders
                _buildPastOrdersSection(),
              ],
            ),
          ),
          
          // Floating header
          _buildFloatingHeader(),
        ],
      ),
    );
  }

  Widget _buildFloatingHeader() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 50, 24, 20),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            bottom: BorderSide(
              color: Colors.black,
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Map icon
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.black,
                  width: 2,
                ),
              ),
              child: IconButton(
                icon: Icon(Icons.map, size: 24, color: Colors.black),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const MapPageV3()),
                  );
                },
              ),
            ),
            
            // App logo in the center (tap to open Menu)
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MenuPageV3(menuType: 'lunch'),
                  ),
                );
              },
              child: Container(
                height: 120,
                width: 120,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.black,
                    width: 2,
                  ),
                ),
                child: Image.asset(
                  'assets/images/freshpunk_logo.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
            
            // Settings icon
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.black,
                  width: 2,
                ),
              ),
              child: IconButton(
                icon: Icon(Icons.settings, size: 24, color: Colors.black),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SettingsPageV3()),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircleOfHealth() {
    return _buildWeeklyNutritionGraph();
  }

  Widget _buildWeeklyNutritionGraph() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.black,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This Week',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Plan: '+_currentMealPlan,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 14),
          _buildNutritionTabs(),
          const SizedBox(height: 20),
          _buildBarGraph(),
        ],
      ),
    );
  }

  String _selectedMetric = 'Calories'; // 'Calories', 'Protein', 'Fat'

  Widget _buildNutritionTabs() {
    return Row(
      children: ['Calories', 'Protein', 'Fat'].map((metric) {
        final isSelected = _selectedMetric == metric;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedMetric = metric;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.black : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.black, width: 2),
                ),
                child: Text(
                  metric,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : Colors.black,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBarGraph() {
    // Load real user meal data from schedule
    final weekData = _calculateWeekNutrition();

    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    
    // Get max value for scaling
    int maxValue = 0;
    for (final day in days) {
      final value = weekData[day]?[_selectedMetric] ?? 0;
      if (value > maxValue) maxValue = value;
    }
    
    // Add 10% padding to max
    maxValue = (maxValue * 1.1).round();

    // Goal values
    final Map<String, int> goals = {
      'Calories': 2000,
      'Protein': 150,
      'Fat': 70,
    };
    
    final currentTotal = weekData.values.fold<int>(
      0,
      (sum, data) => sum + (data[_selectedMetric] ?? 0),
    );
    final goalValue = goals[_selectedMetric] ?? 0;
    final weeklyGoal = goalValue * 7;

    return Column(
      children: [
        // Current vs Goal
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
                children: [
                  TextSpan(text: 'Current: '),
                  TextSpan(
                    text: '$currentTotal',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
            RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
                children: [
                  TextSpan(text: 'Goal: '),
                  TextSpan(
                    text: '$weeklyGoal',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Bar graph
        SizedBox(
          height: 180,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(7, (index) {
              final dayKey = days[index];
              final value = weekData[dayKey]?[_selectedMetric] ?? 0;
              final height = maxValue > 0 ? (value / maxValue) * 140.0 : 0.0;
              
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Value label
                      Text(
                        '$value',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      
                      // Bar
                      Container(
                        width: double.infinity,
                        height: height,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      
                      // Day label
                      Text(
                        dayLabels[index],
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  // Extra protein logger removed (per product decision)

  Widget _buildAddressesSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.black,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.black,
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.location_on,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Your Addresses',
                  style: AppThemeV3.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.black,
                    width: 2,
                  ),
                ),
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AddressPageV3()),
                    ).then((_) => _loadAddresses());
                  },
                  child: Text(
                    'Edit',
                    style: AppThemeV3.textTheme.titleMedium?.copyWith(
                      color: Colors.black,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoadingAddresses) ...[
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(color: Colors.black, strokeWidth: 3),
                ),
              ),
            ),
          ] else if (_addressesError != null) ...[
            Text(
              _addressesError!,
              style: AppThemeV3.textTheme.bodyMedium?.copyWith(color: Colors.redAccent),
            ),
          ] else if (_userAddresses.isEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppThemeV3.borderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No addresses yet',
                    style: AppThemeV3.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add a delivery address to get started.',
                    style: AppThemeV3.textTheme.bodyMedium?.copyWith(color: AppThemeV3.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.black, width: 2),
                        ),
                        textStyle: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const AddressPageV3()),
                        ).then((_) => _loadAddresses());
                      },
                      child: const Text('Add Address'),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
          
          // Address cards
          Column(
          children: _userAddresses.map((address) => Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.black,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.black,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    address.label.toLowerCase() == 'home' 
                        ? Icons.home 
                        : Icons.work,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              address.label,
                              style: AppThemeV3.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppThemeV3.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (address.isDefault) ...[
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppThemeV3.accent,
                                    AppThemeV3.accent.withValues(alpha: 0.8),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppThemeV3.accent.withValues(alpha: 0.3),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                'DEFAULT',
                                style: AppThemeV3.textTheme.bodySmall?.copyWith(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _buildSmartAddress(address),
                        style: AppThemeV3.textTheme.bodyMedium?.copyWith(
                          color: AppThemeV3.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )).toList(),
          ),
          ],
        ],
      ),
    );
  }

  Widget _buildUpcomingOrdersSection() {
    // Build timeline orders from _nextOrder when available (works with or without a full meal object)
    if (_cachedTimelineOrders.isEmpty && _nextOrder != null) {
      MealModelV3? mealObj = _nextOrder!['meal'] as MealModelV3?;
      final mealName = _nextOrder!['mealName'] as String? ?? mealObj?.name ?? 'Meal';
      final mealType = _nextOrder!['mealType'] as String? ?? mealObj?.mealType ?? 'lunch';
      final dayRaw = (_nextOrder!['day'] as String? ?? '').toString();
      final dayDisp = dayRaw.isEmpty ? 'Today' : _toTitleCase(dayRaw);
      final time = _nextOrder!['deliveryTime'] as String? ?? '12:30 PM';
      final imageUrl = _nextOrder!['imageUrl'] ?? mealObj?.imagePath ?? '';
      final address = _nextOrder!['deliveryAddress'] as String? ?? 'Address not set';
      final calories = _nextOrder!['calories'] ?? mealObj?.calories ?? 0;
      final protein = _nextOrder!['protein'] ?? mealObj?.protein ?? 0;
      final fat = mealObj?.fat ?? 0;
      final carbs = mealObj?.carbs ?? 0;

      debugPrint('[HomePage] Building upcoming order with imageUrl: $imageUrl');

      _cachedTimelineOrders = [{
        'id': _nextOrder!['orderId'] ?? 'order-1',
        'day': dayDisp,
        'time': time,
        'mealType': _toTitleCase(mealType),
        // Start as pending so the UI shows the Confirm button
        'status': 'pending',
        'nutrition': {
          'calories': calories,
          'protein': protein,
          'fat': fat,
          'carbs': carbs,
        },
        'address': address,
        'mealName': mealName,
        'imageUrl': imageUrl,
      }];
    }
    
    // If no orders, show empty state
    if (_cachedTimelineOrders.isEmpty) {
      // Optional details helper under header when we found a next order but didn't build a timeline
      final detailsText = (_nextOrder != null && _nextOrder!['deliveryTime'] != null && _nextOrder!['day'] != null)
          ? 'Next: ${_toTitleCase((_nextOrder!['day'] as String?) ?? '')} • ${_nextOrder!['deliveryTime']}'
          : null;
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.black,
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.black,
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.schedule,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Upcoming Orders',
                  style: AppThemeV3.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (detailsText != null) ...[
              Text(
                detailsText,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
            ],
            const Text(
              'No upcoming orders. Create a delivery schedule to get started!',
              style: TextStyle(
                fontSize: 14,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.black,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.black,
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.schedule,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Upcoming Orders',
                style: AppThemeV3.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Timeline
          ..._cachedTimelineOrders.asMap().entries.map((entry) {
            final index = entry.key;
            final order = entry.value;
            final isLast = index == _cachedTimelineOrders.length - 1;
            final isExpanded = _expandedOrderId == order['id'];
            final isCompleted = order['status'] == 'confirmed';
            
            return _buildTimelineOrderCard(order, isLast, isExpanded, isCompleted);
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildTimelineOrderCard(Map<String, dynamic> order, bool isLast, bool isExpanded, bool isCompleted) {
    return RepaintBoundary(
      child: Padding(
        key: ValueKey(order['id']), // Add key to prevent unnecessary rebuilds
        padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
        child: InkWell(
          onTap: () {
            setState(() {
              _expandedOrderId = isExpanded ? null : order['id'];
            });
          },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isExpanded ? Colors.grey.shade50 : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Meal image
                  if (order['imageUrl'] != null && order['imageUrl'].toString().isNotEmpty)
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.black, width: 2),
                      ),
                      child: AppImage(
                        order['imageUrl'],
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        borderRadius: BorderRadius.circular(6),
                        fallbackIcon: Icons.restaurant,
                      ),
                    ),
                  if (order['imageUrl'] != null && order['imageUrl'].toString().isNotEmpty)
                    const SizedBox(width: 12),
                  // Meal details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Show meal name if available, otherwise meal type
                        Text(
                          order['mealName'] ?? order['mealType'],
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.black,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        // Show time and day
                        Text(
                          '${order['day']} • ${order['time']}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.black,
                  ),
                ],
              ),
              
              // Animated expandable content
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                child: isExpanded ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    const Divider(color: Colors.black, thickness: 1),
                    const SizedBox(height: 16),
                    
                    // Nutrition grid
                    const Text(
                      'Nutrition Info',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildNutritionBadge('Calories', order['nutrition']['calories'].toString()),
                        const SizedBox(width: 8),
                        _buildNutritionBadge('Protein', '${order['nutrition']['protein']}g'),
                        const SizedBox(width: 8),
                    _buildNutritionBadge('Fat', '${order['nutrition']['fat']}g'),
                    const SizedBox(width: 8),
                    _buildNutritionBadge('Carbs', '${order['nutrition']['carbs']}g'),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Address
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 16, color: Colors.black87),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        order['address'],
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Status progress (if pending)
                if (!isCompleted) ...[
                  const Text(
                    'Delivery Status',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: 0.3,
                    backgroundColor: Colors.grey.shade300,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.black),
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Preparing your meal...',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                
                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          // Cancel order
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Order cancelled'),
                              backgroundColor: Colors.black,
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black,
                          side: const BorderSide(color: Colors.black, width: 2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          // Show loading state
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Confirming order...'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                          
                          // Confirm order
                          await _confirmOrder();
                          
                          // Update UI to show confirmed state
                          setState(() {
                            _expandedOrderId = null; // Collapse card
                            _cachedTimelineOrders = _cachedTimelineOrders.map((order) {
                              if (order['id'] == _nextOrder?['orderId']) {
                                return {...order, 'status': 'confirmed'};
                              }
                              return order;
                            }).toList();
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Confirm',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Map placeholder
                Container(
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.black, width: 2),
                  ),
                  child: const Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.map, color: Colors.black54),
                        SizedBox(width: 8),
                        Text(
                          'Delivery Map',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                  ],
                ) : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildNutritionBadge(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.black, width: 2),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper removed: address display is now built inline to allow two-line layout.

  Widget _buildPastOrdersSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.black,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.black,
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.history,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Past Orders',
                style: AppThemeV3.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Show "No past orders" when empty
          if (_recentOrders.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    Icon(
                      Icons.history,
                      size: 48,
                      color: AppThemeV3.textSecondary.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No past orders',
                      style: AppThemeV3.textTheme.bodyLarge?.copyWith(
                        color: AppThemeV3.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            )
          
          // Past orders responsive list: center when fits, scroll when needed
          else LayoutBuilder(
            builder: (context, constraints) {
              const double cardWidth = 96;
              const double cardSpacing = 10;
              final int count = _recentOrders.length;
              final double needed = count * cardWidth + (count - 1) * cardSpacing;

              Widget buildCard(Map<String, dynamic> order) {
                return Container(
                  width: cardWidth,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black, width: 2),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: AppThemeV3.accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.fastfood,
                            color: AppThemeV3.accent,
                            size: 24,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          order['name'],
                          style: AppThemeV3.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              }

              // If everything fits, center them without scrolling
              if (needed <= constraints.maxWidth) {
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const PastOrdersPageV3()),
                    );
                  },
                  child: SizedBox(
                    height: 128,
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (int i = 0; i < count; i++) ...[
                            if (i > 0) const SizedBox(width: cardSpacing),
                            buildCard(_recentOrders[i]),
                          ]
                        ],
                      ),
                    ),
                  ),
                );
              }

              // Otherwise, provide smooth horizontal scrolling with safe padding
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const PastOrdersPageV3()),
                  );
                },
                child: SizedBox(
                  height: 132,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: count,
                    separatorBuilder: (_, __) => const SizedBox(width: cardSpacing),
                    itemBuilder: (context, index) => buildCard(_recentOrders[index]),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// Custom painter for Circle of Health - simplified without curved text
class CircleOfHealthPainter extends CustomPainter {
  final String mealPlan;
  final Color accentColor;
  final Color backgroundColor;
  final Color textColor;

  CircleOfHealthPainter({
    required this.mealPlan,
    required this.accentColor,
    required this.backgroundColor,
    required this.textColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2;
    final innerRadius = outerRadius * 0.7;

    // Draw outer circle (green border)
    final outerPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(center, outerRadius - 2, outerPaint);

    // Draw white background between circles
    final whitePaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, outerRadius - 4, whitePaint);

    // Draw inner circle border
    final innerBorderPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, innerRadius, innerBorderPaint);

    // Draw inner circle background with gradient effect
    final innerPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, innerRadius - 1, innerPaint);

    // Draw meal plan text in center
    final mealPlanPainter = TextPainter(
      text: TextSpan(
        text: mealPlan,
        style: TextStyle(
          color: textColor,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    mealPlanPainter.layout();
    mealPlanPainter.paint(
      canvas,
      center - Offset(mealPlanPainter.width / 2, mealPlanPainter.height / 2),
    );

    // Remove curved text - will be placed below the circle instead
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Custom painter for curved text at bottom of circle
class SimpleCurvedTextPainter extends CustomPainter {
  final String text;
  final Color color;
  final double fontSize;

  SimpleCurvedTextPainter({
    required this.text,
    required this.color,
    required this.fontSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = 130.0; // Moved up 30 pixels from 160.0
    
    // Create a simple curved text by positioning individual characters
    // Use a smaller arc for bottom positioning, rotated counterclockwise
    final startAngle = math.pi * 0.805; // Very slight counterclockwise adjustment
    final endAngle = math.pi * 1.195; // Very slight counterclockwise adjustment
    final totalAngle = endAngle - startAngle;
    
    // Process text to handle word and character spacing properly
    final words = text.split(' ');
    final allChars = <String>[];
    
    // Add characters with word separators
    for (int i = 0; i < words.length; i++) {
      final word = words[i];
      for (int j = 0; j < word.length; j++) {
        allChars.add(word[j]);
      }
      // Add word separator (except for last word)
      if (i < words.length - 1) {
        allChars.add('WORD_BREAK');
      }
    }
    
    final visibleChars = allChars.where((c) => c != 'WORD_BREAK').length;
    final wordBreaks = allChars.where((c) => c == 'WORD_BREAK').length;
    
    // Calculate spacing with much better distribution - increase overall spacing
    final baseSpacing = totalAngle / (visibleChars + wordBreaks * 2.0 - 1) * 1.8;
    
    double charIndex = 0;
    for (int i = 0; i < allChars.length; i++) {
      final char = allChars[i];
      
      if (char == 'WORD_BREAK') {
        charIndex += 2.0; // More space for word breaks
        continue;
      }
      
      final angle = startAngle - (charIndex * baseSpacing);
      
      // Calculate position
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      
      final textPainter = TextPainter(
        text: TextSpan(
          text: char,
          style: TextStyle(
            color: color,
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      
      canvas.save();
      canvas.translate(x, y);
      
      // Simple rotation to keep text upright but follow curve
      canvas.rotate(angle + math.pi / 2);
      
      // Mirror both horizontally and vertically
      canvas.scale(-1, -1);
      
      textPainter.paint(
        canvas,
        Offset(-textPainter.width / 2, -textPainter.height / 2),
      );
      
      canvas.restore();
      charIndex++;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
