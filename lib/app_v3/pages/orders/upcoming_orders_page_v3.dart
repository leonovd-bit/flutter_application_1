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
import '../../services/orders/order_generation_service.dart';

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
  final Set<String> _confirmedScheduleIds = <String>{};
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _confirmedSub;
  String? _userId;
  String? _confirmingOrderId;
  bool _showingScheduleFallback = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _userId = FirestoreServiceV3.getCurrentUserId();
    _subscribeConfirmed();
    _loadUpcomingOrders();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _confirmedSub?.cancel();
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
          _showingScheduleFallback = false;
        });
        return;
      }
      final remoteOrdersData = await FirestoreServiceV3.getUpcomingOrders(userId);
      if (remoteOrdersData.isNotEmpty) {
        final orders = remoteOrdersData
            .map((data) => OrderModelV3.fromJson(data))
            .toList()
          ..sort((a, b) => a.deliveryDate.compareTo(b.deliveryDate));

        setState(() {
          _upcomingOrders = orders;
          _isLoading = false;
          _showingScheduleFallback = false;
        });
        debugPrint('[UpcomingOrders] Loaded ${orders.length} upcoming orders from Firestore');
        return;
      }

      final fallbackOrders = await _buildFallbackOrders(userId);
      setState(() {
        _upcomingOrders = fallbackOrders;
        _isLoading = false;
        _showingScheduleFallback = true;
      });
      debugPrint('[UpcomingOrders] Loaded ${fallbackOrders.length} fallback orders from schedule');
      
    } catch (e) {
      debugPrint('[UpcomingOrders] Error loading upcoming orders: $e');
      setState(() {
        _upcomingOrders = [];
        _isLoading = false;
        _showingScheduleFallback = false;
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

  MealPlanModelV3 _resolveCurrentPlan(SharedPreferences prefs) {
    final planId = prefs.getString('selected_meal_plan_id');
    final availablePlans = MealPlanModelV3.getAvailablePlans();
    if (planId == null) {
      return availablePlans.first;
    }
    return availablePlans.firstWhere(
      (p) => p.id == planId,
      orElse: () => availablePlans.first,
    );
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

  Future<List<OrderModelV3>> _buildFallbackOrders(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final currentPlan = _resolveCurrentPlan(prefs);
    debugPrint('[UpcomingOrders] Using fallback plan ${currentPlan.name} (${currentPlan.pricePerMeal}/meal)');

    final upcomingMeals = await _loadUpcomingMealsFromSchedule(userId);
    final localConfirmed = (prefs.getStringList('confirmed_schedule_ids_$userId') ?? const []).toSet();
    final allConfirmed = {..._confirmedScheduleIds, ...localConfirmed};

    final List<OrderModelV3> orders = [];
    for (final mealData in upcomingMeals) {
      try {
        final mealJson = mealData['meal'] as Map<String, dynamic>?;
        if (mealJson == null) continue;
        final checkDayName = (mealData['day'] as String? ?? 'monday').toLowerCase();
        final deliveryDate = (mealData['deliveryDate'] as DateTime?) ?? DateTime.now();
        final mealType = mealData['mealType'] ?? mealData['type'] ?? 'meal';
        final scheduleKey = _generateScheduleKey(checkDayName, mealType, deliveryDate);
        final isConfirmed = allConfirmed.contains(scheduleKey);

        orders.add(OrderModelV3(
          id: mealData['orderId'] ?? 'meal_${deliveryDate.millisecondsSinceEpoch}',
          userId: userId,
          meals: [MealModelV3.fromJson(mealJson)],
          deliveryAddress: mealData['address'] ?? 'Address not set',
          orderDate: DateTime.now(),
          deliveryDate: deliveryDate,
          estimatedDeliveryTime: deliveryDate,
          status: isConfirmed ? OrderStatus.confirmed : OrderStatus.pending,
          totalAmount: currentPlan.pricePerMeal,
          mealPlanType: _getMealPlanType(currentPlan.mealsPerDay),
          userConfirmed: isConfirmed,
          dispatchReadyAt: isConfirmed ? deliveryDate.subtract(const Duration(hours: 1)) : null,
          dispatchWindowMinutes: 60,
        ));
      } catch (e) {
        debugPrint('[UpcomingOrders] Error creating fallback order: $e');
      }
    }

    return orders;
  }

  @override
  Widget build(BuildContext context) {
    return SwipeablePage(
      child: Scaffold(
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
      ),
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
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        children: [
          if (_showingScheduleFallback) ...[
            _buildFallbackBanner(),
            const SizedBox(height: 16),
          ],
          _buildNextOrderHeader(nextOrder),
          if (_upcomingOrders.length > 1) ...[
            const SizedBox(height: 24),
            _buildLaterOrdersSection(_upcomingOrders.skip(1).toList()),
          ],
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
    final bool awaitingConfirmation = order.status == OrderStatus.pending && !order.userConfirmed;
    final bool queuedForDispatch = order.status == OrderStatus.pending && order.userConfirmed;
    final bool canReplace = awaitingConfirmation && minutesToGo > 60;
    final bool canCancel = order.status == OrderStatus.pending && order.status != OrderStatus.cancelled;
    final bool isConfirming = _confirmingOrderId == order.id;
    final DateTime dispatchReadyAt = order.dispatchReadyAt ??
        when.subtract(Duration(minutes: order.dispatchWindowMinutes));

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

          ..._buildOrderStateMessages(
            order: order,
            awaitingConfirmation: awaitingConfirmation,
            queuedForDispatch: queuedForDispatch,
            minutesToGo: minutesToGo,
            dispatchReadyAt: dispatchReadyAt,
          ),

          // Replace / Cancel
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: canReplace ? () => _replaceMeal(order) : null,
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
                  onPressed: canCancel ? () => _cancelOrder(order) : null,
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

          // Confirm button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: awaitingConfirmation && !isConfirming ? () => _confirmOrder(order) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppThemeV3.primaryGreen,
                foregroundColor: Colors.white,
              ),
              child: isConfirming
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(_confirmButtonLabel(order, awaitingConfirmation)),
            ),
          ),

          if (order.userConfirmed ||
              order.status == OrderStatus.confirmed ||
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

  List<Widget> _buildOrderStateMessages({
    required OrderModelV3 order,
    required bool awaitingConfirmation,
    required bool queuedForDispatch,
    required int minutesToGo,
    required DateTime dispatchReadyAt,
  }) {
    final widgets = <Widget>[];

    if (order.status == OrderStatus.cancelled) {
      widgets.add(_infoBanner(
        'This delivery was cancelled.',
        icon: Icons.cancel,
        backgroundColor: Colors.red.withOpacity(0.08),
        textColor: Colors.red,
      ));
      return widgets;
    }

    if (order.status == OrderStatus.delivered) {
      widgets.add(_infoBanner(
        'Delivered — tap below to leave a review.',
        icon: Icons.emoji_food_beverage,
        backgroundColor: AppThemeV3.primaryGreen.withValues(alpha: 0.08),
        textColor: AppThemeV3.primaryGreen,
      ));
      return widgets;
    }

    if (order.status == OrderStatus.outForDelivery) {
      widgets.add(_infoBanner(
        'Driver is en route. You can track progress below.',
        icon: Icons.local_shipping,
        backgroundColor: Colors.orange.withOpacity(0.08),
        textColor: Colors.orange.shade800,
      ));
      return widgets;
    }

    if (order.status == OrderStatus.preparing) {
      widgets.add(_infoBanner(
        'The kitchen is preparing your meal.',
        icon: Icons.restaurant,
      ));
    } else if (order.status == OrderStatus.confirmed && !queuedForDispatch) {
      widgets.add(_infoBanner(
        'Sent to the kitchen. We\'ll ping you when it heads out.',
        icon: Icons.restaurant_menu,
      ));
    }

    if (awaitingConfirmation) {
      widgets.add(_infoBanner(
        'Confirm this delivery so we can prep it on time. Only the next order unlocks for confirmation.',
        icon: Icons.check_circle_outline,
      ));
      if (minutesToGo <= 60) {
        widgets.add(_infoBanner(
          'Meal changes lock within an hour of delivery.',
          icon: Icons.lock_clock,
        ));
      }
    } else if (queuedForDispatch) {
      widgets.add(_infoBanner(
        'You\'re confirmed. We\'ll dispatch to the kitchen around ${_formatDispatchLabel(dispatchReadyAt)}.',
        icon: Icons.timer_outlined,
        backgroundColor: Colors.blue.withOpacity(0.08),
        textColor: Colors.blue.shade700,
      ));
    }

    return widgets;
  }

  String _confirmButtonLabel(OrderModelV3 order, bool awaitingConfirmation) {
    if (awaitingConfirmation) {
      return 'Confirm Next Order';
    }
    if (order.status == OrderStatus.cancelled) return 'Cancelled';
    if (order.status == OrderStatus.delivered) return 'Delivered';
    if (order.status == OrderStatus.outForDelivery) return 'Out for delivery';
    if (order.status == OrderStatus.preparing) return 'Preparing';
    if (order.userConfirmed || order.status == OrderStatus.confirmed) return 'Confirmed';
    return _statusLabel(order);
  }

  Widget _buildFallbackBanner() {
    return _infoBanner(
      'Previewing upcoming meals from your saved schedule. Orders will sync automatically once generated.',
      icon: Icons.schedule,
      backgroundColor: AppThemeV3.primaryGreen.withValues(alpha: 0.08),
      textColor: AppThemeV3.primaryGreen,
    );
  }

  Widget _buildLaterOrdersSection(List<OrderModelV3> orders) {
    final preview = orders.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Later this week',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        const SizedBox(height: 8),
        for (final order in preview) ...[
          _compactOrderTile(order),
          const SizedBox(height: 10),
        ],
        if (orders.length > preview.length)
          Text(
            '+${orders.length - preview.length} more deliveries scheduled',
            style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w600),
          ),
      ],
    );
  }

  Widget _compactOrderTile(OrderModelV3 order) {
    final deliveryTime = order.estimatedDeliveryTime ?? order.deliveryDate;
    final dateLabel = _formatDeliveryDateLabel(deliveryTime);
    final timeLabel = _formatTimeOnly(deliveryTime);
    final mealName = order.meals.isNotEmpty
        ? order.meals.first.name
        : _getMealPlanDisplayName(order.mealPlanType);
    final statusLabel = _statusLabel(order);
    final statusColor = _statusColor(order);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.calendar_today, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$dateLabel • $timeLabel',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  mealName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _statusLabel(OrderModelV3 order) {
    if (order.status == OrderStatus.cancelled) return 'Cancelled';
    if (order.status == OrderStatus.delivered) return 'Delivered';
    if (order.status == OrderStatus.outForDelivery) return 'On the way';
    if (order.status == OrderStatus.preparing) return 'Preparing';
    if (order.userConfirmed || order.status == OrderStatus.confirmed) return 'Confirmed';
    return 'Pending';
  }

  Color _statusColor(OrderModelV3 order) {
    if (order.status == OrderStatus.cancelled) return Colors.red;
    if (order.status == OrderStatus.delivered || order.userConfirmed) {
      return AppThemeV3.primaryGreen;
    }
    if (order.status == OrderStatus.outForDelivery) return Colors.orange.shade700;
    if (order.status == OrderStatus.preparing || order.status == OrderStatus.confirmed) {
      return Colors.blue.shade700;
    }
    return Colors.orange.shade800;
  }

  Widget _infoBanner(
    String text, {
    IconData icon = Icons.info_outline,
    Color? backgroundColor,
    Color? textColor,
  }) {
    final bg = backgroundColor ?? Colors.grey.shade100;
    final fg = textColor ?? Colors.grey.shade800;
    final borderColor = backgroundColor != null
        ? backgroundColor.withOpacity(0.6)
        : Colors.grey.shade200;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: fg, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDeliveryDateLabel(DateTime date) {
    final now = DateTime.now();
    final dateOnly = DateTime(date.year, date.month, date.day);
    final today = DateTime(now.year, now.month, now.day);
    final diffDays = dateOnly.difference(today).inDays;
    if (diffDays == 0) return 'Today';
    if (diffDays == 1) return 'Tomorrow';
    const weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final shortDay = weekdayNames[(date.weekday - 1) % 7];
    return '$shortDay ${date.month}/${date.day}';
  }

  String _formatDispatchLabel(DateTime date) {
    final label = _formatDeliveryDateLabel(date);
    final time = _formatTimeOnly(date);
    if (label == 'Today') return '$time today';
    if (label == 'Tomorrow') return '$time tomorrow';
    return '$time on $label';
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
      ),
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
    final confirmedReached = order.userConfirmed || order.status.index >= OrderStatus.confirmed.index;
    final preparingReached = order.status.index >= OrderStatus.preparing.index;
    final outForDeliveryReached = order.status.index >= OrderStatus.outForDelivery.index;
    final steps = [
      (label: 'Confirmed', icon: Icons.check_circle, reached: confirmedReached),
      (label: 'Ready', icon: Icons.restaurant, reached: preparingReached),
      (label: 'Picked Up', icon: Icons.shopping_bag, reached: outForDeliveryReached),
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
    if (_confirmingOrderId != null && _confirmingOrderId != order.id) {
      return;
    }
    setState(() => _confirmingOrderId = order.id);
    try {
      final result = await OrderGenerationService.confirmNextOrder(orderId: order.id);
      if (result['success'] == true) {
        final dispatchIso = result['dispatchReadyAt'] as String?;
        final dispatchTime = dispatchIso != null ? DateTime.tryParse(dispatchIso) : null;
        final dispatchLabel = dispatchTime != null ? _formatDispatchLabel(dispatchTime) : null;

        // Cancel any scheduled reminder notification since it's now confirmed
        await NotificationServiceV3.instance.cancel(order.id.hashCode & 0x7fffffff);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              dispatchLabel != null
                  ? 'Order confirmed. We\'ll dispatch it around $dispatchLabel.'
                  : 'Order confirmed.',
            ),
          ),
        );
        await _loadUpcomingOrders();
      } else {
        if (!mounted) return;
        final message = (result['error'] ?? result['details'] ?? 'Failed to confirm order').toString();
        _showError(message);
      }
    } catch (e) {
      debugPrint('[UpcomingOrders] Error confirming order: $e');
      if (mounted) {
        _showError('Failed to confirm: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _confirmingOrderId = null);
      } else {
        _confirmingOrderId = null;
      }
    }
  }

  // === Helper: generate stable schedule key ===
  String _generateScheduleKey(String dayName, String mealType, DateTime date) {
    final d = date;
    final normalizedDay = dayName.toLowerCase();
    final normalizedMeal = mealType.toLowerCase();
    return 'sched_${normalizedDay}_${normalizedMeal}_${d.year}_${d.month}_${d.day}';
  }

  void _subscribeConfirmed() {
    final uid = _userId;
    if (uid == null) return;
    _confirmedSub = FirebaseFirestore.instance
        .collection('orders')
        .where('userId', isEqualTo: uid)
        .where('status', isEqualTo: 'confirmed')
        .snapshots()
        .listen((snap) {
      final next = <String>{};
      for (final doc in snap.docs) {
        final data = doc.data();
        final sched = data['mealScheduleId'];
        if (sched is String && sched.isNotEmpty) {
          next.add(sched);
        }
      }
      setState(() {
        _confirmedScheduleIds
          ..clear()
          ..addAll(next);
      });
    });
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
        if (p != null && p is Map) {
          final lat = p['lat'];
          final lng = p['lng'];
          if (lat is double && lng is double) {
            _driver = LatLng(lat, lng);
          } else {
            _driver = null;
          }
          final status = p['status'] as String?;
          _status = _driver != null
              ? (widget.isOutForDelivery ? 'Driver en route' : 'Driver assigned')
              : (status != null ? status : 'Waiting for driver…');
        } else {
          _driver = null;
          _status = 'Waiting for driver…';
        }
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
