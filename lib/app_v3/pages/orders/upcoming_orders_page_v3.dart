import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme_v3.dart';
import '../../models/meal_model_v3.dart';
import '../../services/auth/firestore_service_v3.dart';
import '../../services/notifications/notification_service_v3.dart';
import '../meals/interactive_menu_page_v3.dart';

class UpcomingOrdersPageV3 extends StatefulWidget {
  const UpcomingOrdersPageV3({super.key});

  @override
  State<UpcomingOrdersPageV3> createState() => _UpcomingOrdersPageV3State();
}

class _UpcomingOrdersPageV3State extends State<UpcomingOrdersPageV3> with WidgetsBindingObserver {
  List<OrderModelV3> _upcomingOrders = [];
  bool _isLoading = true;
  bool _showFullDesc = false; // toggles meal description expansion
  // Single-order view; no status filters

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUpcomingOrders();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-check upcoming order on resume to enforce auto-confirm window
      _loadUpcomingOrders();
    }
  }

  Future<void> _loadUpcomingOrders() async {
    try {
      setState(() => _isLoading = true);
      
      // Get current user ID
      final userId = FirestoreServiceV3.getCurrentUserId();
      if (userId == null) {
        setState(() {
          _upcomingOrders = [];
          _isLoading = false;
        });
        return;
      }

      // Load current meal plan
      final prefs = await SharedPreferences.getInstance();
      final planId = prefs.getString('selected_meal_plan_id');
      MealPlanModelV3? currentPlan;
      if (planId != null) {
        final availablePlans = MealPlanModelV3.getAvailablePlans();
        currentPlan = availablePlans.firstWhere(
          (p) => p.id == planId,
          orElse: () => availablePlans.first,
        );
      }
      currentPlan ??= MealPlanModelV3.getAvailablePlans().first;
      
      debugPrint('[UpcomingOrders] Current plan: ${currentPlan.name}, mealsPerDay: ${currentPlan.mealsPerDay}, pricePerMeal: ${currentPlan.pricePerMeal}');

      // Load upcoming meals from meal schedule data
      final upcomingMeals = await _loadUpcomingMealsFromSchedule(userId);
      
      // Convert meals to OrderModelV3 objects
      final List<OrderModelV3> orders = [];
      for (final mealData in upcomingMeals) {
        try {
          final order = OrderModelV3(
            id: mealData['orderId'] ?? 'meal_${DateTime.now().millisecondsSinceEpoch}',
            userId: userId,
            meals: [MealModelV3.fromJson(mealData['meal'])],
            deliveryAddress: mealData['address'] ?? 'Address not set',
            orderDate: DateTime.now(),
            deliveryDate: mealData['deliveryDate'] ?? DateTime.now(),
            estimatedDeliveryTime: mealData['deliveryDate'] ?? DateTime.now(),
            status: OrderStatus.confirmed,
            totalAmount: currentPlan.pricePerMeal, // Use actual plan price
            mealPlanType: _getMealPlanType(currentPlan.mealsPerDay), // Determine type from meals per day
          );
          orders.add(order);
        } catch (e) {
          debugPrint('[UpcomingOrders] Error creating order from meal data: $e');
        }
      }
      
      setState(() {
        _upcomingOrders = orders;
        _isLoading = false;
      });
      
      debugPrint('[UpcomingOrders] Loaded ${orders.length} upcoming meals from schedule');
      
    } catch (e) {
      debugPrint('[UpcomingOrders] Error loading upcoming orders: $e');
      setState(() {
        _upcomingOrders = [];
        _isLoading = false;
      });
    }
  }

  MealPlanType _getMealPlanType(int mealsPerDay) {
    switch (mealsPerDay) {
      case 1:
        return MealPlanType.standard; // Standard (1 meal/day)
      case 2:
        return MealPlanType.pro; // Pro (2 meals/day)
      case 3:
        return MealPlanType.premium; // Premium (3 meals/day)
      default:
        return MealPlanType.standard;
    }
  }

  Future<List<Map<String, dynamic>>> _loadUpcomingMealsFromSchedule(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Get current selected schedule
    final selectedSchedule = prefs.getString('selected_schedule_$userId') ?? 'weekly';
    debugPrint('[UpcomingOrders] Selected schedule: $selectedSchedule');
    
    // Load meal selections
    final mealSelectionsKey = 'meal_selections_${userId}_$selectedSchedule';
    final mealSelectionsJson = prefs.getString(mealSelectionsKey);
    debugPrint('[UpcomingOrders] Loading meal selections from key: $mealSelectionsKey');
    debugPrint('[UpcomingOrders] Meal selections found: ${mealSelectionsJson != null}');
    
    if (mealSelectionsJson == null) {
      debugPrint('[UpcomingOrders] No meal selections found for schedule: $selectedSchedule');
      return [];
    }
    
    final mealSelections = json.decode(mealSelectionsJson) as Map<String, dynamic>;
    debugPrint('[UpcomingOrders] Meal selections days: ${mealSelections.keys.toList()}');
    
    // Load delivery schedule to get times and addresses
    final deliveryScheduleKey = 'delivery_schedule_$userId';
    final deliveryScheduleJson = prefs.getString(deliveryScheduleKey);
    debugPrint('[UpcomingOrders] Loading delivery schedule from key: $deliveryScheduleKey');
    debugPrint('[UpcomingOrders] Delivery schedule found: ${deliveryScheduleJson != null}');
    
    Map<String, dynamic> deliverySchedule = {};
    if (deliveryScheduleJson != null) {
      deliverySchedule = json.decode(deliveryScheduleJson) as Map<String, dynamic>;
      debugPrint('[UpcomingOrders] Delivery schedule days: ${deliverySchedule.keys.toList()}');
    }
    
    final List<Map<String, dynamic>> upcomingMeals = [];
    final now = DateTime.now();
    final today = now.weekday;
    
    // Get next 7 days of meals
    final daysToCheck = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    
    for (int dayOffset = 0; dayOffset < 7; dayOffset++) {
      final checkDayIndex = (today - 1 + dayOffset) % 7;
      final checkDayName = daysToCheck[checkDayIndex];
      final checkDate = now.add(Duration(days: dayOffset));
      
      final dayMeals = mealSelections[checkDayName] as Map<String, dynamic>?;
      if (dayMeals == null) continue;
      
      final dayDelivery = deliverySchedule[checkDayName] as Map<String, dynamic>?;
      
      // Check each meal type for this day
      for (final mealType in ['breakfast', 'lunch', 'dinner']) {
        final mealData = dayMeals[mealType] as Map<String, dynamic>?;
        if (mealData == null) continue;
        
        final deliveryConfig = dayDelivery?[mealType] as Map<String, dynamic>?;
        final timeStr = deliveryConfig?['time'] as String?;
        final address = deliveryConfig?['address'] as String?;
        
        if (timeStr != null) {
          final timeParts = timeStr.split(':');
          if (timeParts.length == 2) {
            final hour = int.tryParse(timeParts[0]);
            final minute = int.tryParse(timeParts[1]);
            
            if (hour != null && minute != null) {
              final deliveryDateTime = DateTime(
                checkDate.year, checkDate.month, checkDate.day, hour, minute
              );
              
              // Only include future meals
              if (deliveryDateTime.isAfter(now)) {
                upcomingMeals.add({
                  'meal': mealData,
                  'mealType': mealType,
                  'deliveryDate': deliveryDateTime,
                  'address': address ?? 'Address not set',
                  'day': checkDayName,
                  'orderId': 'meal_${checkDayName}_${mealType}_${checkDate.millisecondsSinceEpoch}',
                });
              }
            }
          }
        }
      }
    }
    
    // Sort by delivery time
    upcomingMeals.sort((a, b) => 
      (a['deliveryDate'] as DateTime).compareTo(b['deliveryDate'] as DateTime)
    );
    
    return upcomingMeals;
  }

  void _handleLegacyOrders() async {
    try {
      // Get current user ID
      final userId = FirestoreServiceV3.getCurrentUserId();
      if (userId != null) {
        // Check for any legacy Firestore orders and handle them
        final data = await FirestoreServiceV3.getNextUpcomingOrder(userId);
        if (data != null) {
          // No upcoming order found; show a mock order for now
          _loadSampleOrders();
        }
      } else {
        // User not logged in, use sample data
        _loadSampleOrders();
      }
    } catch (e) {
      // Use sample data if Firebase fails
      _loadSampleOrders();
    }
  }

  // Returns true if an auto-confirm was performed
  Future<bool> _autoConfirmIfDue(OrderModelV3 order) async {
    final when = order.estimatedDeliveryTime ?? order.deliveryDate;
    final now = DateTime.now();
    final isWithinAutoConfirmWindow = now.isAfter(when.subtract(const Duration(minutes: 15)));
    final isTerminal = order.status == OrderStatus.delivered || order.status == OrderStatus.cancelled;
    if (!isTerminal && order.status != OrderStatus.confirmed && isWithinAutoConfirmWindow) {
      try {
        await FirestoreServiceV3.updateOrderStatus(orderId: order.id, status: OrderStatus.confirmed);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Order auto-confirmed')),
          );
        }
        // Cancel any scheduled reminder for this order (if any)
        await NotificationServiceV3.instance.cancel(order.id.hashCode & 0x7fffffff);
        return true;
      } catch (_) {
        // If it fails, just continue without blocking
        return false;
      }
    }
    return false;
  }

  Map<String, dynamic> _normalizeOrderMap(Map<String, dynamic> data) {
    final map = Map<String, dynamic>.from(data);
    dynamic toMs(dynamic v) {
      if (v is Timestamp) return v.millisecondsSinceEpoch;
      if (v is DateTime) return v.millisecondsSinceEpoch;
      return v;
    }
    map['orderDate'] = toMs(map['orderDate']);
    map['deliveryDate'] = toMs(map['deliveryDate']);
    map['estimatedDeliveryTime'] = toMs(map['estimatedDeliveryTime']);
    return map;
  }

  void _loadSampleOrders() {
    // Ensure we include a meal so the header shows meal name & description
    final sampleMeal = MealModelV3.getSampleMeals().first;
    setState(() {
      _upcomingOrders = [
        OrderModelV3(
          id: 'mock_order_1',
          userId: 'mock_user',
          mealPlanType: MealPlanType.standard,
          meals: [sampleMeal],
          deliveryAddress: '123 Mock St, Springfield',
          orderDate: DateTime.now().subtract(const Duration(hours: 1)),
          deliveryDate: DateTime.now().add(const Duration(hours: 3)),
          status: OrderStatus.preparing,
          totalAmount: 13.00,
          estimatedDeliveryTime: DateTime.now().add(const Duration(hours: 3)),
        ),
      ];
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Upcoming Orders', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AppThemeV3.primaryGreen)))
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_upcomingOrders.isEmpty) {
      return _buildEmptyState();
    }

    final nextOrder = _upcomingOrders.first;
    return RefreshIndicator(
      onRefresh: _loadUpcomingOrders,
      color: AppThemeV3.primaryGreen,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        children: [
          _buildNextOrderHeader(nextOrder),
        ],
      ),
    );
  }

  // Top header showing the next order: meal image, name/desc, address/time, and actions
  Widget _buildNextOrderHeader(OrderModelV3 order) {
    final meal = order.meals.isNotEmpty ? order.meals.first : null;
    final now = DateTime.now();
    final when = order.estimatedDeliveryTime ?? order.deliveryDate;
  final timeOnly = _formatTimeOnly(when);
  final desc = meal?.description ?? 'Scheduled meal delivery';
  final bool isNew = now.difference(order.orderDate).inHours < 24 && order.status == OrderStatus.pending;
    final minutesToGo = when.difference(now).inMinutes;
    final canModify = minutesToGo > 60 &&
        order.status != OrderStatus.outForDelivery &&
        order.status != OrderStatus.delivered &&
        order.status != OrderStatus.cancelled;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row with meal details and address/time box
    Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Meal image/icon
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
      width: 60,
      height: 60,
                  color: Colors.grey.shade100,
                  child: (meal != null && meal.imageUrl.isNotEmpty && meal.imageUrl.startsWith('http'))
                      ? Image.network(
                          meal.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) => Icon(
                            meal.icon,
                            color: AppThemeV3.accent,
                            size: 30,
                          ),
                        )
                      : Icon(meal?.icon ?? Icons.fastfood, color: AppThemeV3.accent, size: 30),
                ),
              ),
        const SizedBox(width: 10),
              // Meal details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meal?.name ?? _getMealPlanDisplayName(order.mealPlanType),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
                    ),
                    if (isNew) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppThemeV3.primaryGreen.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppThemeV3.primaryGreen.withValues(alpha: 0.6)),
                        ),
                        child: Text(
                          'NEW',
                          style: TextStyle(
                            color: AppThemeV3.primaryGreen,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    _expandableDescription(desc),
                    const SizedBox(height: 8),
                    if (meal != null)
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _infoChip('${meal.calories} cal'),
                            const SizedBox(width: 6),
                            _infoChip('P ${meal.protein}g'),
                            const SizedBox(width: 6),
                            _infoChip('C ${meal.carbs}g'),
                            const SizedBox(width: 6),
                            _infoChip('F ${meal.fat}g'),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Address/time compact box
              ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 110),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.place, size: 14),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _addressDisplayName(order.deliveryAddress),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.access_time, size: 14),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              timeOnly,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Replace / Cancel
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: canModify ? () => _replaceMeal(order) : null,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppThemeV3.primaryGreen),
                    foregroundColor: AppThemeV3.primaryGreen,
                  ),
                  child: const Text('Replace'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: canModify ? () => _cancelOrder(order) : null,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    foregroundColor: Colors.red,
                  ),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          if (!canModify)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.lock_clock, size: 18, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Modifications are disabled within 1 hour of delivery.',
                      style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),

          if (order.status != OrderStatus.confirmed && minutesToGo > 15)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 18, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'If you don\'t confirm, your order will auto-confirm 15 minutes before delivery.',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ),
                ],
              ),
            ),

          // Confirm button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: order.status == OrderStatus.confirmed ? null : () => _confirmOrder(order),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppThemeV3.primaryGreen,
                foregroundColor: Colors.white,
              ),
              child: Text(order.status == OrderStatus.confirmed ? 'Confirmed' : 'Confirm'),
            ),
          ),

          if (order.status == OrderStatus.confirmed ||
              order.status == OrderStatus.preparing ||
              order.status == OrderStatus.outForDelivery)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _buildTracker(order),
            ),

          if (order.status == OrderStatus.delivered)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _buildReviewCta(order),
            ),
        ],
      ),
    );
  }

  Widget _infoChip(String text) {
    return Container(
  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
  child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  // Expand/collapse description when tapping the ellipsis
  Widget _expandableDescription(String desc) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final span = TextSpan(text: desc, style: TextStyle(color: Colors.grey[700], fontSize: 13));
        final tp = TextPainter(
          text: span,
          maxLines: _showFullDesc ? null : 2,
          textDirection: TextDirection.ltr,
          ellipsis: _showFullDesc ? null : '…',
        );
        tp.layout(maxWidth: constraints.maxWidth);
        final isOverflow = tp.didExceedMaxLines;

        final textWidget = Text(
          desc,
          style: TextStyle(color: Colors.grey[700], fontSize: 13),
          maxLines: _showFullDesc ? null : 2,
          overflow: _showFullDesc ? TextOverflow.visible : TextOverflow.ellipsis,
        );

        if (!isOverflow) return textWidget;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _showFullDesc = !_showFullDesc),
          child: textWidget,
        );
      },
    );
  }

  String _addressDisplayName(String fullAddress) {
    final lower = fullAddress.toLowerCase();
    if (lower.contains('home')) return 'Home';
    if (lower.contains('work')) return 'Work';
    if (lower.contains('office')) return 'Office';
    return 'Address';
  }

  Widget _buildTracker(OrderModelV3 order) {
    // Steps: Confirmed -> Ready -> Picked Up -> Out for Delivery -> Delivered
    final steps = [
      (label: 'Confirmed', icon: Icons.check_circle, reached: order.status.index >= OrderStatus.confirmed.index),
      (label: 'Ready', icon: Icons.restaurant, reached: order.status.index >= OrderStatus.preparing.index),
      (label: 'Picked Up', icon: Icons.shopping_bag, reached: order.status.index >= OrderStatus.outForDelivery.index),
      (label: 'Out', icon: Icons.local_shipping, reached: order.status == OrderStatus.outForDelivery || order.status == OrderStatus.delivered),
      (label: 'Delivered', icon: Icons.done_all, reached: order.status == OrderStatus.delivered),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Delivery Tracker', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        // Vertical tracker layout
        Column(
          children: [
            for (int i = 0; i < steps.length; i++) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon + vertical connector
                  Column(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: steps[i].reached ? AppThemeV3.primaryGreen : Colors.grey.shade300,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(steps[i].icon, size: 20, color: Colors.white),
                      ),
                      if (i < steps.length - 1)
                        Container(
                          width: 3,
                          height: 32,
                          color: steps[i + 1].reached ? AppThemeV3.primaryGreen : Colors.grey.shade300,
                        ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        steps[i].label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: steps[i].reached ? Colors.black87 : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (i < steps.length - 1) const SizedBox(height: 12),
            ],
          ],
        ),
        const SizedBox(height: 12),
        // Live Map (compact) – disabled on web unless configured with Maps API key
        if (!kIsWeb)
          _LiveMapTracker(
            orderId: order.id,
            deliveryAddress: order.deliveryAddress,
            isOutForDelivery: order.status == OrderStatus.outForDelivery,
          ),
      ],
    );
  }

  // Old horizontal tracker step widget removed (vertical tracker in use)

  Widget _buildReviewCta(OrderModelV3 order) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          const Icon(Icons.rate_review, color: Colors.amber),
          const SizedBox(width: 10),
          const Expanded(child: Text('Your order was delivered. Leave a review?')),
          ElevatedButton(
            onPressed: () => _leaveReview(order),
            style: ElevatedButton.styleFrom(backgroundColor: AppThemeV3.primaryGreen, foregroundColor: Colors.white),
            child: const Text('Review'),
          )
        ],
      ),
    );
  }

  // Removed filters/list helpers for single-order view

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.restaurant_menu,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No Upcoming Orders',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your upcoming meal deliveries will appear here',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppThemeV3.primaryGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Order Now'),
          ),
        ],
      ),
    );
  }

  // Removed old list card and status helpers; tracker remains for confirmed and later

  String _getMealPlanDisplayName(MealPlanType type) {
    switch (type) {
      case MealPlanType.standard:
        return 'Standard Plan';
      case MealPlanType.pro:
        return 'Pro Plan';
      case MealPlanType.premium:
        return 'Premium Plan';
    }
  }

  String _formatDeliveryTime(DateTime? deliveryTime) {
    if (deliveryTime == null) return 'Time not set';
    final now = DateTime.now();
    final day = DateTime(deliveryTime.year, deliveryTime.month, deliveryTime.day);
    final today = DateTime(now.year, now.month, now.day);
    final isToday = day == today;
    final isTomorrow = day == today.add(const Duration(days: 1));
    final hour = deliveryTime.hour;
    final minute = deliveryTime.minute.toString().padLeft(2, '0');
    final ampm = hour >= 12 ? 'PM' : 'AM';
    final h12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final time = '$h12:$minute $ampm';
    final prefix = isToday
        ? 'Today'
        : (isTomorrow ? 'Tomorrow' : '${deliveryTime.month}/${deliveryTime.day}');
    return '$prefix • $time';
  }

  String _formatTimeOnly(DateTime deliveryTime) {
    final hour = deliveryTime.hour;
    final minute = deliveryTime.minute.toString().padLeft(2, '0');
    final ampm = hour >= 12 ? 'PM' : 'AM';
    final h12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$h12:$minute $ampm';
  }

  // _trackOrder removed in single-order simplification

  void _cancelOrder(OrderModelV3 order) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel Order'),
        content: const Text('Are you sure you want to cancel this order?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await FirestoreServiceV3.updateOrderStatus(orderId: order.id, status: OrderStatus.cancelled);
                // Cancel any scheduled notification
                await NotificationServiceV3.instance.cancel(order.id.hashCode & 0x7fffffff);
                await _loadUpcomingOrders();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Order cancelled successfully'),
                    backgroundColor: Colors.red,
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to cancel: $e')),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }

  // _contactSupport removed in single-order simplification

  // _viewOrderDetails removed in single-order simplification

  Future<void> _confirmOrder(OrderModelV3 order) async {
    try {
      await FirestoreServiceV3.updateOrderStatus(orderId: order.id, status: OrderStatus.confirmed);
      // Cancel any scheduled reminder notification since it's now confirmed
      await NotificationServiceV3.instance.cancel(order.id.hashCode & 0x7fffffff);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order confirmed')),
      );
      await _loadUpcomingOrders();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to confirm: $e')),
      );
    }
  }

  Future<void> _replaceMeal(OrderModelV3 order) async {
    // Navigate to interactive menu and allow picking a replacement for the first meal
    final current = order.meals.isNotEmpty ? order.meals.first : null;
  final newMeal = await Navigator.of(context).push<MealModelV3>(
      MaterialPageRoute(
        builder: (_) => InteractiveMenuPageV3(
          menuType: current?.mealType ?? 'lunch',
          day: _formatDeliveryTime(order.estimatedDeliveryTime ?? order.deliveryDate),
          menuCategory: 'premade',
          onMealSelected: (m) => Navigator.of(context).pop(m),
          selectedMeal: current,
        ),
      ),
    );
  if (!mounted) return;
    if (newMeal != null) {
      try {
        final updatedMeals = [newMeal, ...order.meals.skip(1)];
        await FirestoreServiceV3.updateOrderMeals(orderId: order.id, meals: updatedMeals);
    if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Meal replaced')),
        );
        await _loadUpcomingOrders();
      } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to replace: $e')),
        );
      }
    }
  }

  void _leaveReview(OrderModelV3 order) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Leave a review', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            const TextField(decoration: InputDecoration(labelText: 'Comments', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: AppThemeV3.primaryGreen, foregroundColor: Colors.white),
                child: const Text('Submit'),
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _LiveMapTracker extends StatefulWidget {
  final String orderId;
  final String deliveryAddress;
  final bool isOutForDelivery;

  const _LiveMapTracker({
    required this.orderId,
    required this.deliveryAddress,
    required this.isOutForDelivery,
  });

  @override
  State<_LiveMapTracker> createState() => _LiveMapTrackerState();
}

class _LiveMapTrackerState extends State<_LiveMapTracker> {
  GoogleMapController? _controller;
  LatLng? _destination;
  LatLng? _driver;
  String _status = 'Fetching location…';
  StreamSubscription? _driverSub;

  // NYC fallback
  static const LatLng _nyc = LatLng(40.7589, -73.9851);

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _driverSub?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    // Geocode destination (best-effort). Skip on web unless configured.
    try {
      if (!kIsWeb) {
        final addr = widget.deliveryAddress.trim();
        if (addr.isNotEmpty && addr.length > 3) {
          final results = await geocoding.locationFromAddress(addr);
          if (results.isNotEmpty) {
            _destination = LatLng(results.first.latitude, results.first.longitude);
          }
        }
      }
    } catch (_) {}

    if (!mounted) return;

    // Subscribe to driver location stream
    _driverSub = FirestoreServiceV3.trackOrderDriverLocation(widget.orderId).listen((p) {
      if (!mounted) return;
      setState(() {
        _driver = (p != null) ? LatLng(p.lat, p.lng) : null;
        _status = _driver != null
            ? (widget.isOutForDelivery ? 'Driver en route' : 'Driver assigned')
            : 'Waiting for driver…';
      });
      _fitBounds();
    });
    setState(() {});
  }

  void _onMapCreated(GoogleMapController c) {
    _controller = c;
    _fitBounds();
  }

  void _fitBounds() {
    final controller = _controller;
    if (controller == null) return;
    final points = <LatLng>[
      if (_destination != null) _destination!,
      if (_driver != null) _driver!,
    ];
    if (points.isEmpty) return;
    if (points.length == 1) {
      controller.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(target: points.first, zoom: 13)));
    } else {
      final lats = points.map((e) => e.latitude);
      final lngs = points.map((e) => e.longitude);
      final sw = LatLng(lats.reduce((a, b) => a < b ? a : b), lngs.reduce((a, b) => a < b ? a : b));
      final ne = LatLng(lats.reduce((a, b) => a > b ? a : b), lngs.reduce((a, b) => a > b ? a : b));
      controller.animateCamera(CameraUpdate.newLatLngBounds(LatLngBounds(southwest: sw, northeast: ne), 60));
    }
  }

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>{};
    if (_destination != null) {
      markers.add(Marker(
        markerId: const MarkerId('dest'),
        position: _destination!,
        infoWindow: const InfoWindow(title: 'Destination'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ));
    }
    if (_driver != null) {
      markers.add(Marker(
        markerId: const MarkerId('driver'),
        position: _driver!,
        infoWindow: const InfoWindow(title: 'Driver'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.map, size: 18, color: Colors.grey),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Live Map (beta) • $_status',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 180,
            child: GoogleMap(
              onMapCreated: _onMapCreated,
              initialCameraPosition: const CameraPosition(target: _nyc, zoom: 12),
              markers: markers,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
            ),
          ),
        ),
      ],
    );
  }
}
