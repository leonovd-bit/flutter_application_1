import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import '../theme/app_theme_v3.dart';
import '../models/meal_model_v3.dart';
import 'delivery/map_page_v3.dart';
import 'profile/settings_page_v3.dart';
import 'orders/past_orders_page_v3.dart';
import 'delivery/address_page_v3.dart';
import 'meals/menu_page_v3.dart';
import '../services/auth/firestore_service_v3.dart';
import '../services/orders/order_generation_service.dart';
import '../services/orders/order_functions_service.dart';
import '../services/notifications/notification_service_v3.dart';
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

  // Lazy-loaded next order data
  Map<String, dynamic>? _nextOrder;
  bool _nextOrderFromFirestore = false;
  bool _showingScheduleFallback = false;
  bool _isLoadingNextOrder = true;
  String? _confirmingOrderId;
  
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
  Map<String, Map<String, int>> _cachedNutritionData = {
    'Mon': {'Calories': 0, 'Protein': 0, 'Fat': 0},
    'Tue': {'Calories': 0, 'Protein': 0, 'Fat': 0},
    'Wed': {'Calories': 0, 'Protein': 0, 'Fat': 0},
    'Thu': {'Calories': 0, 'Protein': 0, 'Fat': 0},
    'Fri': {'Calories': 0, 'Protein': 0, 'Fat': 0},
    'Sat': {'Calories': 0, 'Protein': 0, 'Fat': 0},
    'Sun': {'Calories': 0, 'Protein': 0, 'Fat': 0},
  };
  static const Map<String, List<String>> _dayVariants = {
    'monday': ['monday', 'mon', 'mondayall', 'monall', 'mo'],
    'tuesday': ['tuesday', 'tue', 'tues', 'tuesdayall', 'tueall', 'tu'],
    'wednesday': ['wednesday', 'wed', 'weds', 'wednesdayall', 'wedall', 'we'],
    'thursday': ['thursday', 'thu', 'thur', 'thurs', 'thursdayall', 'thuall', 'th'],
    'friday': ['friday', 'fri', 'fridayall', 'friall', 'fr'],
    'saturday': ['saturday', 'sat', 'saturdayall', 'satall', 'sa'],
    'sunday': ['sunday', 'sun', 'sundayall', 'sunall', 'su'],
  };

  static const Map<String, List<String>> _mealVariants = {
    'breakfast': ['breakfast', 'bfast', 'b', 'brk', 'morning'],
    'lunch': ['lunch', 'lun', 'l'],
    'dinner': ['dinner', 'din', 'd', 'supper'],
    'snack': ['snack', 'snk', 'sn'],
  };

  static const List<String> _scheduleContainers = [
    'days',
    'schedule',
    'week',
    'weeks',
    'delivery',
    'deliverydays',
    'meals',
  ];

  static const List<String> _weekdayOrder = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadInitialData();
  }

  void _loadInitialData() {
    _loadCurrentMealPlan();
    _listenPlanFromFirestore();
    _loadNutritionData();
    _loadAddresses();
    _loadNextUpcomingOrder();
    _loadRecentOrders();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subActiveSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshVisibleData();
    }
  }

  Future<void> _refreshVisibleData() async {
    await Future.wait([
      _loadNextUpcomingOrder(),
      _loadRecentOrders(),
      _loadAddresses(),
    ]);
  }

  Map<String, dynamic>? _getDayMealsFlexible(Map<String, dynamic>? source, String? dayName) {
    if (source == null || source.isEmpty || dayName == null || dayName.trim().isEmpty) {
      return null;
    }

    final normalizedTarget = _normalizeKey(dayName);
    final canonicalTarget = _resolveDayKey(normalizedTarget);

    Map<String, dynamic>? search(Map<String, dynamic> candidate) {
      // Direct key match
      for (final entry in candidate.entries) {
        final value = entry.value;
        if (value is! Map) continue;
        final normalizedKey = _normalizeKey(entry.key.toString());
        if (normalizedKey == normalizedTarget || normalizedKey == canonicalTarget) {
          return Map<String, dynamic>.from(value);
        }
      }

      // Prefix match across day variants
      for (final entry in candidate.entries) {
        final value = entry.value;
        if (value is! Map) continue;
        final normalizedKey = _normalizeKey(entry.key.toString());
        if (normalizedKey.startsWith(normalizedTarget) || normalizedTarget.startsWith(normalizedKey)) {
          return Map<String, dynamic>.from(value);
        }
      }

      // Search inside common container keys
      for (final entry in candidate.entries) {
        final value = entry.value;
        if (value is! Map) continue;
        final normalizedKey = _normalizeKey(entry.key.toString());
        if (_scheduleContainers.contains(normalizedKey)) {
          final nested = search(Map<String, dynamic>.from(value));
          if (nested != null) {
            return nested;
          }
        }
      }
      return null;
    }

    return search(source);
  }

  Map<String, dynamic>? _getMealFlexible(Map<String, dynamic>? dayMap, String? mealName) {
    if (dayMap == null || dayMap.isEmpty || mealName == null || mealName.trim().isEmpty) {
      return null;
    }

    final normalizedTarget = _normalizeKey(mealName);
    final candidates = <String>[
      mealName,
      mealName.toLowerCase(),
      _toTitleCase(mealName),
      mealName.toUpperCase(),
    ];

    for (final key in candidates) {
      final value = dayMap[key];
      if (value is Map<String, dynamic>) {
        return value;
      }
    }

    String canonicalMeal = normalizedTarget;
    for (final entry in _mealVariants.entries) {
      if (entry.value.contains(normalizedTarget)) {
        canonicalMeal = entry.key;
        break;
      }
      if (entry.value.any((variant) => normalizedTarget.startsWith(variant) || variant.startsWith(normalizedTarget))) {
        canonicalMeal = entry.key;
        break;
      }
    }

    for (final entry in dayMap.entries) {
      final value = entry.value;
      if (value is! Map<String, dynamic>) continue;
      final normalizedKey = _normalizeKey(entry.key.toString());
      if (normalizedKey == canonicalMeal || normalizedKey.startsWith(canonicalMeal)) {
        return value;
      }
    }

    return null;
  }

  String _normalizeKey(String value) {
    return value
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[0-9]+'), '')
        .replaceAll(RegExp(r'[^a-z]'), '')
        .trim();
  }

  String _resolveDayKey(String normalizedKey) {
    for (final entry in _dayVariants.entries) {
      if (entry.value.contains(normalizedKey)) {
        return entry.key;
      }
      if (entry.value.any((variant) => normalizedKey.startsWith(variant) || variant.startsWith(normalizedKey))) {
        return entry.key;
      }
    }
    return normalizedKey;
  }

  String _toTitleCase(String s) {
    if (s.isEmpty) return s;
    final t = s.trim();
    return t[0].toUpperCase() + t.substring(1).toLowerCase();
  }

  String _formatDeliveryDateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    if (target == today) return 'Today';
    if (target == today.add(const Duration(days: 1))) return 'Tomorrow';
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final weekdayLabel = weekdays[target.weekday - 1];
    final monthLabel = months[target.month - 1];
    return '$weekdayLabel, $monthLabel ${target.day}';
  }

  String _formatTimeOnlyFromDate(DateTime date) {
    final hour = date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    final ampm = hour >= 12 ? 'PM' : 'AM';
    final h12 = hour % 12 == 0 ? 12 : hour % 12;
    return '$h12:$minute $ampm';
  }

  DateTime? _parseDateField(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is int) {
      // Heuristic: treat as milliseconds since epoch if large enough
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
      final numValue = int.tryParse(value);
      if (numValue != null) {
        return DateTime.fromMillisecondsSinceEpoch(numValue);
      }
    }
    return null;
  }

  String _formatDispatchLabel(DateTime date) {
    return '${_formatDeliveryDateLabel(date)} • ${_formatTimeOnlyFromDate(date)}';
  }

  /// Calculate nutrition totals from user's meal schedule
  Map<String, Map<String, int>> _calculateWeekNutrition() {
    // Return cached data that was loaded in initState
    return _cachedNutritionData;
  }

  /// Load nutrition data from delivered orders only (not scheduled meals)
  Future<void> _loadNutritionData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

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

      // Get delivered orders from Firestore
      final db = FirebaseFirestore.instance;
      
      // Calculate date range: current week (Monday to Sunday)
      final now = DateTime.now();
      final currentWeekday = now.weekday; // 1 = Monday, 7 = Sunday
      final startOfWeek = now.subtract(Duration(days: currentWeekday - 1));
      final startOfWeekMidnight = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
      final endOfWeek = startOfWeekMidnight.add(const Duration(days: 7));

      debugPrint('[HomePage] Loading nutrition for week: ${startOfWeekMidnight.toIso8601String()} to ${endOfWeek.toIso8601String()}');

      // Query orders that have been delivered this week
      final ordersSnapshot = await db
          .collection('orders')
          .where('userId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'delivered') // Only count delivered orders
          .where('deliveryDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfWeekMidnight))
          .where('deliveryDate', isLessThan: Timestamp.fromDate(endOfWeek))
          .get();

      debugPrint('[HomePage] Found ${ordersSnapshot.docs.length} delivered orders this week');

      // Map full day names to short names
      final dayMapping = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

      // Process each delivered order
      for (final doc in ordersSnapshot.docs) {
        try {
          final orderData = doc.data();
          final deliveryDate = (orderData['deliveryDate'] as Timestamp?)?.toDate();
          if (deliveryDate == null) continue;

          // Get day of week (1 = Monday, 7 = Sunday)
          final weekday = deliveryDate.weekday;
          final shortDay = dayMapping[weekday - 1]; // Convert to 0-indexed

          // Get meal nutrition from order
          final meals = orderData['meals'] as List<dynamic>?;
          if (meals == null || meals.isEmpty) continue;

          for (final mealData in meals) {
            final meal = mealData as Map<String, dynamic>?;
            if (meal == null) continue;

            final calories = (meal['calories'] as num?)?.toInt() ?? 0;
            final protein = (meal['protein'] as num?)?.toInt() ?? 0;
            final fat = (meal['fat'] as num?)?.toInt() ?? 0;

            // Add to day's totals
            newData[shortDay]!['Calories'] = newData[shortDay]!['Calories']! + calories;
            newData[shortDay]!['Protein'] = newData[shortDay]!['Protein']! + protein;
            newData[shortDay]!['Fat'] = newData[shortDay]!['Fat']! + fat;

            debugPrint('[HomePage] Added nutrition for $shortDay: $calories cal, ${protein}g protein, ${fat}g fat');
          }
        } catch (e) {
          debugPrint('[HomePage] Error processing order ${doc.id}: $e');
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

  Future<void> _loadNextUpcomingOrder() async {
    if (!mounted) return;
    setState(() {
      _isLoadingNextOrder = true;
    });

    bool loadedFromFirestore = false;
    try {
      loadedFromFirestore = await _loadNextOrderFromFirestore();
      if (!loadedFromFirestore) {
        await _loadNextOrderPreviewFromSchedule();
      }
    } catch (e) {
      debugPrint('[HomePage] Error loading next order: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingNextOrder = false;
          _nextOrderFromFirestore = loadedFromFirestore;
          _showingScheduleFallback = !loadedFromFirestore && _nextOrder != null;
        });
      }
    }
  }

  Future<bool> _loadNextOrderFromFirestore() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return false;

      final data = await FirestoreServiceV3.getNextUpcomingOrder(uid);
      if (data == null) {
        return false;
      }

      final order = OrderModelV3.fromJson(data);
      final payload = _mapOrderToNextOrderPayload(order);

      if (!mounted) return false;
      setState(() {
        _nextOrder = payload;
        _cachedTimelineOrders = [_buildTimelineEntryFromPayload(payload)];
        _nextOrderFromFirestore = true;
        _showingScheduleFallback = false;
      });
      return true;
    } catch (e) {
      debugPrint('[HomePage] Error loading Firestore order: $e');
      return false;
    }
  }

  Future<void> _loadNextOrderPreviewFromSchedule() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final prefs = await SharedPreferences.getInstance();
      final selectedSchedule = prefs.getString('selected_schedule_${user.uid}') ?? 'weekly';
      final mealSelectionsJson = prefs.getString('meal_selections_${user.uid}_$selectedSchedule');
      final deliveryScheduleJson = prefs.getString('delivery_schedule_${user.uid}');

      if (mealSelectionsJson == null || deliveryScheduleJson == null) {
        if (mounted) {
          setState(() {
            _nextOrder = null;
            _cachedTimelineOrders = [];
            _showingScheduleFallback = false;
          });
        }
        return;
      }

      final mealSelections = Map<String, dynamic>.from(json.decode(mealSelectionsJson) as Map<String, dynamic>);
      final deliverySchedule = Map<String, dynamic>.from(json.decode(deliveryScheduleJson) as Map<String, dynamic>);

      final now = DateTime.now();
      MealModelV3? chosenMeal;
      DateTime? chosenDateTime;
      String? chosenDayName;
      String chosenMealType = 'lunch';
      String deliveryAddress = _userAddresses.isNotEmpty ? _buildSmartAddress(_userAddresses.first) : 'Address not set';

      for (int offset = 0; offset < 7; offset++) {
        final candidateDate = DateTime(now.year, now.month, now.day).add(Duration(days: offset));
        final dayName = _weekdayOrder[candidateDate.weekday - 1];
        final dayMeals = _getDayMealsFlexible(mealSelections, dayName);
        if (dayMeals == null) continue;

        for (final mealType in ['lunch', 'dinner', 'breakfast']) {
          final rawMeal = _getMealFlexible(dayMeals, mealType);
          if (rawMeal == null) continue;

          final scheduleDay = _getDayMealsFlexible(deliverySchedule, dayName);
          final scheduleMeal = scheduleDay == null ? null : _getMealFlexible(scheduleDay, mealType);
          final timeStr = (scheduleMeal?['time'] ?? scheduleMeal?['deliveryTime'] ?? '12:30').toString();
          final parts = timeStr.split(':');
          final hour = int.tryParse(parts.first) ?? 12;
          final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
          final candidateDateTime = DateTime(candidateDate.year, candidateDate.month, candidateDate.day, hour, minute);
          final scheduleAddress = (scheduleMeal?['address'] ?? '').toString().trim();

          chosenMeal = MealModelV3.fromJson(Map<String, dynamic>.from(rawMeal));
          chosenDateTime = candidateDateTime;
          chosenDayName = dayName;
          chosenMealType = mealType;
          if (scheduleAddress.isNotEmpty) {
            deliveryAddress = scheduleAddress;
          }
          break;
        }

        if (chosenMeal != null) {
          break;
        }
      }

      if (chosenMeal == null || chosenDateTime == null || chosenDayName == null) {
        if (mounted) {
          setState(() {
            _nextOrder = null;
            _cachedTimelineOrders = [];
          });
        }
        return;
      }

      final payload = {
        'orderId': 'preview-${chosenDateTime.millisecondsSinceEpoch}',
        'id': 'preview-${chosenDateTime.millisecondsSinceEpoch}',
        'meal': chosenMeal,
        'mealName': chosenMeal.name,
        'mealType': chosenMealType,
        'day': _toTitleCase(chosenDayName),
        'deliveryDateTime': chosenDateTime.toIso8601String(),
        'deliveryTime': _formatTimeOnlyFromDate(chosenDateTime),
        'deliveryAddress': deliveryAddress,
        'status': 'pending',
        'userConfirmed': false,
        'dispatchReadyAt': null,
        'dispatchWindowMinutes': 60,
        'calories': chosenMeal.calories,
        'protein': chosenMeal.protein,
        'fat': chosenMeal.fat,
        'carbs': chosenMeal.carbs,
        'imageUrl': chosenMeal.imagePath,
        'nutrition': {
          'calories': chosenMeal.calories,
          'protein': chosenMeal.protein,
          'fat': chosenMeal.fat,
          'carbs': chosenMeal.carbs,
        },
        'isPreview': true,
      };

      if (mounted) {
        setState(() {
          _nextOrder = payload;
          _cachedTimelineOrders = [_buildTimelineEntryFromPayload(payload)];
          _showingScheduleFallback = true;
          _nextOrderFromFirestore = false;
        });
      }
    } catch (e) {
      debugPrint('[HomePage] Error building schedule preview: $e');
      if (mounted) {
        setState(() {
          _showingScheduleFallback = true;
          _nextOrderFromFirestore = false;
        });
      }
    }
  }

  Map<String, dynamic> _mapOrderToNextOrderPayload(OrderModelV3 order) {
    final meal = order.meals.isNotEmpty ? order.meals.first : null;
    final deliveryDateTime = order.estimatedDeliveryTime ?? order.deliveryDate;
    final dispatchReadyAt = order.dispatchReadyAt;

    return {
      'orderId': order.id,
      'id': order.id,
      'meal': meal,
      'mealName': meal?.name ?? 'Meal',
      'mealType': meal?.mealType ?? 'lunch',
      'day': _formatDeliveryDateLabel(deliveryDateTime),
      'deliveryDateTime': deliveryDateTime.toIso8601String(),
      'deliveryTime': _formatTimeOnlyFromDate(deliveryDateTime),
      'deliveryAddress': order.deliveryAddress,
      'status': order.status.name,
      'userConfirmed': order.userConfirmed,
      'dispatchReadyAt': dispatchReadyAt?.toIso8601String(),
      'dispatchWindowMinutes': order.dispatchWindowMinutes,
      'calories': meal?.calories ?? 0,
      'protein': meal?.protein ?? 0,
      'fat': meal?.fat ?? 0,
      'carbs': meal?.carbs ?? 0,
      'imageUrl': meal?.imagePath ?? meal?.imageUrl ?? '',
      'nutrition': {
        'calories': meal?.calories ?? 0,
        'protein': meal?.protein ?? 0,
        'fat': meal?.fat ?? 0,
        'carbs': meal?.carbs ?? 0,
      },
      'isPreview': false,
    };
  }

  Map<String, dynamic> _buildTimelineEntryFromPayload(Map<String, dynamic> payload) {
    final MealModelV3? meal = payload['meal'] as MealModelV3?;
    final DateTime? deliveryDateTime = _parseDateField(payload['deliveryDateTime']);
    final nutrition = payload['nutrition'] as Map<String, dynamic>? ?? {
      'calories': payload['calories'] ?? 0,
      'protein': payload['protein'] ?? 0,
      'fat': payload['fat'] ?? 0,
      'carbs': payload['carbs'] ?? 0,
    };

    return {
      'id': payload['orderId'] ?? payload['id'] ?? 'order-${DateTime.now().millisecondsSinceEpoch}',
      'day': payload['day'] ?? (deliveryDateTime != null ? _formatDeliveryDateLabel(deliveryDateTime) : 'Today'),
      'time': payload['deliveryTime'] ?? (deliveryDateTime != null ? _formatTimeOnlyFromDate(deliveryDateTime) : '12:30 PM'),
      'mealType': _toTitleCase(payload['mealType']?.toString() ?? 'Lunch'),
      'status': (payload['status'] ?? 'pending').toString(),
      'userConfirmed': payload['userConfirmed'] == true,
      'dispatchReadyAt': payload['dispatchReadyAt'],
      'dispatchWindowMinutes': payload['dispatchWindowMinutes'] ?? 60,
      'deliveryDateTime': deliveryDateTime?.toIso8601String(),
      'nutrition': nutrition,
      'address': payload['deliveryAddress'] ?? 'Address not set',
      'mealName': payload['mealName'] ?? meal?.name ?? payload['mealType'] ?? 'Meal',
      'imageUrl': payload['imageUrl'] ?? meal?.imagePath ?? '',
    };
  }

  Future<void> _loadRecentOrders() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final orders = await FirestoreServiceV3.getPastOrders(uid);
      if (!mounted) return;

      final mapped = orders.take(12).map((order) {
        final meals = (order['meals'] as List<dynamic>? ?? []);
        String name = order['mealName']?.toString() ?? 'Meal';
        String imageUrl = '';
        if (meals.isNotEmpty) {
          final first = meals.first;
          if (first is Map<String, dynamic>) {
            if (first['name'] != null) {
              name = first['name'].toString();
            }
            if (first['imageUrl'] != null) {
              imageUrl = first['imageUrl'].toString();
            }
          }
        }
        return {
          'id': order['id'] ?? '',
          'name': name,
          'imageUrl': imageUrl,
        };
      }).toList();

      setState(() {
        _recentOrders = mapped;
      });
    } catch (e) {
      debugPrint('[HomePage] Error loading past orders: $e');
    }
  }

  // Load the selected meal plan from storage
  Future<void> _loadCurrentMealPlan() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final prefs = await SharedPreferences.getInstance();
      
      // Try to load from the saved delivery schedule
      if (uid != null) {
        // Get the selected schedule name
        final scheduleName = prefs.getString('selected_schedule_$uid');
        if (scheduleName != null) {
          // Load that schedule's data
          final scheduleKey = 'delivery_schedule_${uid}_$scheduleName';
          final scheduleJson = prefs.getString(scheduleKey);
          if (scheduleJson != null) {
            try {
              final scheduleData = json.decode(scheduleJson) as Map<String, dynamic>;
              final planDisplayName = scheduleData['mealPlanDisplayName'] as String?;
              final planName = scheduleData['mealPlanName'] as String?;
              final planId = scheduleData['mealPlanId'] as String?;
              
              if (planDisplayName != null && planDisplayName.isNotEmpty) {
                if (!mounted) return;
                setState(() => _currentMealPlan = planDisplayName);
                return;
              } else if (planName != null && planName.isNotEmpty) {
                if (!mounted) return;
                setState(() => _currentMealPlan = planName);
                return;
              } else if (planId != null && planId.isNotEmpty) {
                // Derive from planId
                final plans = MealPlanModelV3.getAvailablePlans();
                final match = plans.firstWhere((p) => p.id == planId, orElse: () => plans.first);
                if (!mounted) return;
                setState(() => _currentMealPlan = match.displayName.isNotEmpty ? match.displayName : match.name);
                return;
              }
            } catch (e) {
              debugPrint('Error parsing schedule data: $e');
            }
          }
        }
        
        // Fallback to server data
        final serverName = await FirestoreServiceV3.getDisplayPlanName(uid);
        if (serverName != null && serverName.isNotEmpty) {
          if (!mounted) return;
          setState(() => _currentMealPlan = serverName);
          return;
        }
      }
      
      // Last resort: local preference
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
      
      // Deduplicate addresses by street address (case-insensitive)
      final seen = <String>{};
      final deduplicatedAddresses = <AddressModelV3>[];
      for (final addr in loadedAddresses) {
        final key = addr.streetAddress.trim().toLowerCase();
        if (!seen.contains(key)) {
          seen.add(key);
          deduplicatedAddresses.add(addr);
        } else {
          debugPrint('[HomePage] Filtered duplicate address: ${addr.streetAddress}');
        }
      }
      
      // Fallback: if none found, try single-string delivery address saved elsewhere
      if (loadedAddresses.isEmpty) {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        final single = uid == null ? null : prefs.getString('user_delivery_address_$uid');
        if (single != null && single.trim().isNotEmpty) {
          // Check if this address already exists to avoid duplicates
          final alreadyExists = loadedAddresses.any((addr) => 
            addr.streetAddress.trim().toLowerCase() == single.trim().toLowerCase()
          );
          
          if (!alreadyExists) {
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
      }

      if (!mounted) return;
      setState(() {
        _userAddresses = deduplicatedAddresses;
        _addressesError = deduplicatedAddresses.isEmpty ? 'No addresses saved' : null;
        _isLoadingAddresses = false;
      });
      
      debugPrint('[HomePage] Loaded ${deduplicatedAddresses.length} addresses from SharedPreferences (${loadedAddresses.length - deduplicatedAddresses.length} duplicates removed)');
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

    return Column(
      children: [
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
    if (_isLoadingNextOrder) {
      return _buildUpcomingOrdersLoadingState();
    }

    // Build timeline orders from _nextOrder when available
    if (_cachedTimelineOrders.isEmpty && _nextOrder != null) {
      final MealModelV3? mealObj = _nextOrder!['meal'] as MealModelV3?;
      final mealName = _nextOrder!['mealName'] as String? ?? mealObj?.name ?? 'Meal';
      final mealType = _nextOrder!['mealType'] as String? ?? mealObj?.mealType ?? 'lunch';
      final dayRaw = (_nextOrder!['day'] as String? ?? '').toString();
      final deliveryIso = _nextOrder!['deliveryDateTime'] as String?;
      final deliveryDateTime = deliveryIso != null ? DateTime.tryParse(deliveryIso) : null;
      final dayDisp = deliveryDateTime != null ? _formatDeliveryDateLabel(deliveryDateTime) : (dayRaw.isEmpty ? 'Today' : _toTitleCase(dayRaw));
      final time = _nextOrder!['deliveryTime'] as String?
          ?? (deliveryDateTime != null ? _formatTimeOnlyFromDate(deliveryDateTime) : '12:30 PM');
      final imageUrl = (_nextOrder!['imageUrl'] ?? mealObj?.imagePath ?? '').toString();
      final address = _nextOrder!['deliveryAddress'] as String? ?? 'Address not set';
      final calories = (_nextOrder!['calories'] ?? mealObj?.calories ?? 0) as num;
      final protein = (_nextOrder!['protein'] ?? mealObj?.protein ?? 0) as num;
      final fat = (_nextOrder!['fat'] ?? mealObj?.fat ?? 0) as num;
      final carbs = (_nextOrder!['carbs'] ?? mealObj?.carbs ?? 0) as num;
      final status = (_nextOrder!['status'] ?? 'pending').toString();
      final userConfirmed = _nextOrder!['userConfirmed'] == true;
      final dispatchReadyAt = _nextOrder!['dispatchReadyAt'];

      _cachedTimelineOrders = [
        {
          'id': _nextOrder!['orderId'] ?? 'order-1',
          'day': dayDisp,
          'time': time,
          'mealType': _toTitleCase(mealType),
          'status': status,
          'userConfirmed': userConfirmed,
          'dispatchReadyAt': dispatchReadyAt,
          'dispatchWindowMinutes': _nextOrder!['dispatchWindowMinutes'] ?? 60,
          'deliveryDateTime': deliveryDateTime?.toIso8601String(),
          'nutrition': {
            'calories': calories,
            'protein': protein,
            'fat': fat,
            'carbs': carbs,
          },
          'address': address,
          'mealName': mealName,
          'imageUrl': imageUrl,
        },
      ];
    }

    if (_cachedTimelineOrders.isEmpty) {
      return _buildUpcomingOrdersEmptyState();
    }

    final isPreview = _showingScheduleFallback && !_nextOrderFromFirestore;
    final isLive = _nextOrderFromFirestore;

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
              const Spacer(),
              if (isLive) _buildStatusPill('Live order', AppThemeV3.primaryGreen),
              if (isPreview) ...[
                if (isLive) const SizedBox(width: 8),
                _buildStatusPill('Schedule preview', Colors.amber.shade700),
              ],
            ],
          ),
          const SizedBox(height: 16),
          if (isPreview) ...[
            _buildFallbackBanner(),
            const SizedBox(height: 16),
          ],
          ..._cachedTimelineOrders.asMap().entries.map((entry) {
            final index = entry.key;
            final order = entry.value;
            final isLast = index == _cachedTimelineOrders.length - 1;
            final isExpanded = _expandedOrderId == order['id'];
            return _buildTimelineOrderCard(order, isLast, isExpanded);
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildTimelineOrderCard(Map<String, dynamic> order, bool isLast, bool isExpanded) {
    return RepaintBoundary(
      child: Padding(
        key: ValueKey(order['id']),
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  child: isExpanded
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 16),
                            const Divider(color: Colors.black, thickness: 1),
                            const SizedBox(height: 16),
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
                            ..._buildStatusBlock(order),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => _cancelOrder(order),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.black,
                                      side: const BorderSide(color: Colors.black, width: 2),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _canConfirmOrder(order)
                                        ? () async {
                                            await _confirmOrder();
                                          }
                                        : null,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.black,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: _buildConfirmButtonChild(order),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            GestureDetector(
                              onTap: () {
                                // Open live map directly
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const MapPageV3(),
                                  ),
                                );
                              },
                              child: Container(
                                height: 100,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.black, width: 2),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(Icons.map_outlined, color: Colors.black87),
                                    SizedBox(width: 10),
                                    Text(
                                      'View on map',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    SizedBox(width: 6),
                                    Icon(Icons.arrow_forward, color: Colors.black54, size: 18),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'See delivery location and driver tracking.',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildStatusBlock(Map<String, dynamic> order) {
    final status = (order['status'] as String? ?? 'pending').toLowerCase();
    final userConfirmed = order['userConfirmed'] == true;
    final awaitingConfirmation = status == 'pending' && !userConfirmed;
    final queuedForDispatch = status == 'pending' && userConfirmed;
    final kitchenConfirmed = status == 'confirmed' || status == 'preparing' || status == 'outfordelivery';
    final isCancelled = status == 'cancelled';
    final dispatchReadyAt = _parseDateField(order['dispatchReadyAt']);

    double progressValue;
    if (isCancelled) {
      progressValue = 0;
    } else if (awaitingConfirmation) {
      progressValue = 0.25;
    } else if (queuedForDispatch) {
      progressValue = 0.6;
    } else if (kitchenConfirmed) {
      progressValue = 0.9;
    } else {
      progressValue = 0.4;
    }

    String progressLabel;
    if (isCancelled) {
      progressLabel = 'Order cancelled';
    } else if (awaitingConfirmation) {
      progressLabel = 'Confirm soon to guarantee this delivery.';
    } else if (queuedForDispatch) {
      progressLabel = dispatchReadyAt != null
          ? 'Confirmed. Dispatch window opens ${_formatDispatchLabel(dispatchReadyAt)}.'
          : 'Confirmed. We\'ll queue it for dispatch soon.';
    } else if (kitchenConfirmed) {
      progressLabel = 'Kitchen has received your order.';
    } else {
      progressLabel = 'Status: ${_toTitleCase(status)}';
    }

    return [
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
        value: isCancelled ? 0 : progressValue,
        backgroundColor: Colors.grey.shade300,
        valueColor: AlwaysStoppedAnimation<Color>(isCancelled ? Colors.red : Colors.black),
        minHeight: 6,
      ),
      const SizedBox(height: 6),
      Text(
        progressLabel,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
      const SizedBox(height: 16),
    ];
  }

  Future<void> _confirmOrder() async {
    final next = _nextOrder;
    if (next == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No order to confirm yet.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final orderId = (next['orderId'] ?? next['id'])?.toString();
    if (orderId == null || orderId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Missing order identifier.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (!_nextOrderFromFirestore) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('We will confirm once the kitchen syncs this preview.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    if (_confirmingOrderId != null && _confirmingOrderId != orderId) {
      return;
    }

    setState(() {
      _confirmingOrderId = orderId;
    });

    try {
      final result = await OrderGenerationService.confirmNextOrder(orderId: orderId);
      if (result['success'] == true) {
        final dispatchIso = result['dispatchReadyAt'] as String? ?? next['dispatchReadyAt'] as String?;
        final dispatchTime = dispatchIso != null ? DateTime.tryParse(dispatchIso) : null;

        await NotificationServiceV3.instance.cancel(orderId.hashCode & 0x7fffffff);

        if (!mounted) return;

        setState(() {
          _nextOrder = {
            ...?_nextOrder,
            'status': 'confirmed',
            'userConfirmed': true,
            'dispatchReadyAt': dispatchIso,
          };
          _cachedTimelineOrders = _cachedTimelineOrders.map((order) {
            if (order['id'] == orderId) {
              return {
                ...order,
                'status': 'confirmed',
                'userConfirmed': true,
                'dispatchReadyAt': dispatchIso ?? order['dispatchReadyAt'],
              };
            }
            return order;
          }).toList();
        });

        final dispatchLabel = dispatchTime != null ? _formatDispatchLabel(dispatchTime) : null;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              dispatchLabel != null
                  ? 'Order confirmed. Dispatch window opens $dispatchLabel.'
                  : 'Order confirmed. We\'ll queue it for dispatch shortly.',
            ),
          ),
        );

        await _loadNextUpcomingOrder();
      } else {
        final message = (result['error'] ?? result['details'] ?? 'Failed to confirm order').toString();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('[HomePage] Error confirming order: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error confirming order: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _confirmingOrderId = null;
        });
      } else {
        _confirmingOrderId = null;
      }
    }
  }

  bool _canConfirmOrder(Map<String, dynamic> order) {
    final status = (order['status'] as String? ?? 'pending').toLowerCase();
    final awaitingConfirmation = status == 'pending' && order['userConfirmed'] != true;
    final isSameOrder = order['id'] == _nextOrder?['orderId'];
    if (!awaitingConfirmation || !isSameOrder || !_nextOrderFromFirestore) {
      return false;
    }
    if (_confirmingOrderId != null && _confirmingOrderId != order['id']) {
      return false;
    }
    return true;
  }

  Future<void> _cancelOrder(Map<String, dynamic> order) async {
    final orderId = (order['orderId'] ?? order['id'])?.toString();
    
    // For schedule preview, just clear it
    if (_showingScheduleFallback || orderId == null || orderId.isEmpty || orderId.startsWith('preview-')) {
      setState(() {
        _nextOrder = null;
        _cachedTimelineOrders = [];
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preview cleared')),
        );
      }
      return;
    }

    // Show confirmation dialog for real orders
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Order?'),
        content: const Text('Are you sure you want to cancel this order?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Order'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Cancel Order'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final success = await OrderFunctionsService.instance.cancelOrder(orderId);
      
      if (success) {
        setState(() {
          _nextOrder = null;
          _cachedTimelineOrders = [];
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Order cancelled successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
        await _loadNextUpcomingOrder();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to cancel order'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[HomePage] Error cancelling order: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildConfirmButtonChild(Map<String, dynamic> order) {
    final status = (order['status'] as String? ?? 'pending').toLowerCase();
    final awaitingConfirmation = status == 'pending' && order['userConfirmed'] != true;
    final bool isConfirming = _confirmingOrderId == order['id'];

    if (!awaitingConfirmation) {
      return Text(
        status == 'pending' ? 'Confirmed' : _toTitleCase(status),
        style: const TextStyle(fontWeight: FontWeight.w700),
      );
    }

    if (isConfirming) {
      return const SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }

    return const Text(
      'Confirm order',
      style: TextStyle(fontWeight: FontWeight.w700),
    );
  }

  Widget _buildUpcomingOrdersLoadingState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Row(
        children: const [
          SizedBox(
            height: 28,
            width: 28,
            child: CircularProgressIndicator(strokeWidth: 3, valueColor: AlwaysStoppedAnimation<Color>(Colors.black)),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              'Fetching your next delivery…',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingOrdersEmptyState() {
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

  Widget _buildStatusPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 0.4),
      ),
    );
  }

  Widget _buildFallbackBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Icon(Icons.info_outline, size: 18, color: Colors.amber),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'This is a preview from your meal schedule. We\'ll finalize it once the kitchen confirms.',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
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
                debugPrint('[HomePage] Order card imageUrl: ${order['imageUrl']}');
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
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: order['imageUrl'] != null && (order['imageUrl'] as String).isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    order['imageUrl'],
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Icon(
                                        Icons.fastfood,
                                        color: AppThemeV3.accent,
                                        size: 24,
                                      );
                                    },
                                  ),
                                )
                              : Icon(
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
