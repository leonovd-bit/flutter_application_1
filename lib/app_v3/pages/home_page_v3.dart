import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import '../theme/app_theme_v3.dart';
import '../models/meal_model_v3.dart';
import 'map_page_v3.dart';
import 'settings_page_v3.dart';
import 'circle_of_health_page_v3.dart';
import 'upcoming_orders_page_v3.dart';
import 'past_orders_page_v3.dart';
import 'address_page_v3.dart';
import 'menu_page_v3.dart';
import '../services/firestore_service_v3.dart';
import '../services/order_service_v3.dart';
import '../widgets/app_image.dart';

class HomePageV3 extends StatefulWidget {
  const HomePageV3({super.key});

  @override
  State<HomePageV3> createState() => _HomePageV3State();
}

class _HomePageV3State extends State<HomePageV3> {
  // Optimized state management - reduce static data
  String _currentMealPlan = 'DietKnight';
  final Map<String, int> _todayStats = {'calories': 850, 'protein': 45};
  final String _mostEatenMealType = 'High Protein';
  
  // Lazy-loaded next order data
  Map<String, dynamic>? _nextOrder;
  
  // Real past orders from user data
  List<Map<String, dynamic>> _recentOrders = [];
  bool _isLoadingOrders = false;
  
  // User addresses (loaded from Firestore)
  List<AddressModelV3> _userAddresses = [];
  bool _isLoadingAddresses = false;
  String? _addressesError;
  StreamSubscription<QuerySnapshot>? _subActiveSub;

  @override
  void initState() {
    super.initState();
    _loadCurrentMealPlan();
    _loadOrderData();
    _loadAddresses();
    _listenPlanFromFirestore();
  }

  @override
  void dispose() {
    _subActiveSub?.cancel();
    super.dispose();
  }

  void _loadOrderData() {
    // Load real user order data
    _loadNextUpcomingOrder();
    _loadRecentOrders();
  }

  // Load recent orders from Firebase
  Future<void> _loadRecentOrders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _isLoadingOrders = true;
    });

    try {
      final orders = await OrderServiceV3.getUserRecentOrders(user.uid, limit: 3);
      if (mounted) {
        setState(() {
          _recentOrders = orders;
          _isLoadingOrders = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingOrders = false;
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
      
      // Get current selected schedule from SharedPreferences
      final selectedSchedule = prefs.getString('selected_schedule_${user.uid}') ?? 'weekly';
      
      // Load meal selections
      final mealSelectionsJson = prefs.getString('meal_selections_${user.uid}_$selectedSchedule');
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
      
      // Check today first, then future days
      final daysToCheck = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
      final todayName = daysToCheck[today - 1];
      
      for (int dayOffset = 0; dayOffset < 7; dayOffset++) {
        final checkDayIndex = (today - 1 + dayOffset) % 7;
        final checkDayName = daysToCheck[checkDayIndex];
        
        final dayMeals = mealSelections[checkDayName] as Map<String, dynamic>?;
        if (dayMeals == null) continue;
        
        final dayDelivery = deliverySchedule[checkDayName] as Map<String, dynamic>?;
        
        // Check breakfast, lunch, dinner in chronological order
        for (final mealType in ['breakfast', 'lunch', 'dinner']) {
          final mealData = dayMeals[mealType] as Map<String, dynamic>?;
          if (mealData == null) continue;
          
          final deliveryConfig = dayDelivery?[mealType] as Map<String, dynamic>?;
          final timeStr = deliveryConfig?['time'] as String?;
          
          if (timeStr != null) {
            final timeParts = timeStr.split(':');
            if (timeParts.length == 2) {
              final hour = int.tryParse(timeParts[0]);
              final minute = int.tryParse(timeParts[1]);
              
              if (hour != null && minute != null) {
                final mealTime = TimeOfDay(hour: hour, minute: minute);
                
                // If this is today, check if the time hasn't passed yet
                if (dayOffset == 0) {
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
        setState(() {
          _nextOrder = {
            'mealType': nextMealType ?? 'lunch',
            'mealName': nextMeal!.name,
            'deliveryTime': nextDeliveryTime,
            'imageUrl': nextMeal!.imageUrl,
            'calories': nextMeal!.calories,
            'protein': nextMeal!.protein,
            'deliveryAddress': nextDeliveryAddress ?? 'Address not set',
            'orderId': 'meal_${nextDay}_${nextMealType}',
            'day': nextDay,
          };
        });
        debugPrint('[HomePage] Found next meal: ${nextMeal!.name} on $nextDay at $nextDeliveryTime');
      } else {
        setState(() => _nextOrder = null);
        debugPrint('[HomePage] No upcoming meals found in schedule');
      }
      
    } catch (e) {
      debugPrint('[HomePage] Error loading upcoming meal from schedule: $e');
      setState(() => _nextOrder = null);
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
      
      final List<AddressModelV3> loadedAddresses = [];
      for (final jsonStr in addressList) {
        try {
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

  Future<void> _cacheAddresses(List<AddressModelV3> addresses) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = addresses
          .map((a) => {
                'id': a.id,
                'userId': a.userId,
                'label': a.label,
                'streetAddress': a.streetAddress,
                'apartment': a.apartment,
                'city': a.city,
                'state': a.state,
                'zipCode': a.zipCode,
                'isDefault': a.isDefault,
                'createdAt': a.createdAt?.millisecondsSinceEpoch,
              })
          .toList();
      await prefs.setString('cached_addresses', jsonEncode(data));
    } catch (_) {
      // ignore cache errors silently
    }
  }

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
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppThemeV3.surface,
              AppThemeV3.surface.withValues(alpha: 0.95),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 16,
              offset: const Offset(0, 4),
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Map icon
            Container(
              decoration: BoxDecoration(
                color: AppThemeV3.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppThemeV3.accent.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: Icon(Icons.map, size: 28, color: AppThemeV3.accent),
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
                  boxShadow: [
                    BoxShadow(
                      color: AppThemeV3.accent.withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                      spreadRadius: 2,
                    ),
                  ],
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
                color: AppThemeV3.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppThemeV3.accent.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: Icon(Icons.settings, size: 28, color: AppThemeV3.accent),
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
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CircleOfHealthPageV3()),
        );
      },
      child: Container(
        width: 320,
        height: 320,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 0.8,
              colors: [
                AppThemeV3.accent.withValues(alpha: 0.05),
                AppThemeV3.accent.withValues(alpha: 0.01),
                Colors.transparent,
              ],
          ),
          boxShadow: [
            BoxShadow(
              color: AppThemeV3.accent.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
              spreadRadius: 5,
            ),
          ],
        ),
        child: Stack(
          children: [
            // Circle painting
            CustomPaint(
              painter: CircleOfHealthPainter(
                mealPlan: _currentMealPlan,
                accentColor: AppThemeV3.accent,
                backgroundColor: AppThemeV3.background,
                textColor: AppThemeV3.textPrimary,
              ),
              child: Container(),
            ),
            
            // Curved text using a simpler approach
            Positioned.fill(
              child: CustomPaint(
                painter: SimpleCurvedTextPainter(
                  text: '${_todayStats['calories']} cal • ${_todayStats['protein']}g protein • $_mostEatenMealType',
                  color: AppThemeV3.accent,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressesSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppThemeV3.surface,
            AppThemeV3.surface.withValues(alpha: 0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppThemeV3.accent.withValues(alpha: 0.2),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppThemeV3.accent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.location_on,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Your Addresses',
                    style: AppThemeV3.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppThemeV3.accent.withValues(alpha: 0.1),
                      AppThemeV3.accent.withValues(alpha: 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppThemeV3.accent.withValues(alpha: 0.3),
                    width: 1,
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
                      color: AppThemeV3.accent,
                      fontWeight: FontWeight.w700,
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
                  child: CircularProgressIndicator(color: AppThemeV3.accent, strokeWidth: 3),
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
                color: AppThemeV3.accent.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppThemeV3.accent.withValues(alpha: 0.2)),
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
                      style: ElevatedButton.styleFrom(backgroundColor: AppThemeV3.accent),
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
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppThemeV3.accent.withValues(alpha: 0.05),
                  AppThemeV3.accent.withValues(alpha: 0.02),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppThemeV3.accent.withValues(alpha: 0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppThemeV3.accent.withValues(alpha: 0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppThemeV3.accent,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppThemeV3.accent.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    address.label.toLowerCase() == 'home' 
                        ? Icons.home 
                        : Icons.work,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            address.label,
                            style: AppThemeV3.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppThemeV3.textPrimary,
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
                        address.fullAddress,
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppThemeV3.surface,
            AppThemeV3.surface.withValues(alpha: 0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppThemeV3.accent.withValues(alpha: 0.2),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppThemeV3.accent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
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
          const SizedBox(height: 16),
          
          // Next order card
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const UpcomingOrdersPageV3()),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppThemeV3.accent.withValues(alpha: 0.05),
                    AppThemeV3.accent.withValues(alpha: 0.02),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppThemeV3.accent.withValues(alpha: 0.3),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppThemeV3.accent.withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _nextOrder == null
                  ? Text(
                      'No upcoming orders',
                      style: AppThemeV3.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppThemeV3.textSecondary,
                      ),
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Meal thumbnail (with graceful fallback)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            width: 64,
                            height: 64,
                            child: AppImage(
                              (_nextOrder!['imageUrl'] ?? '').toString(),
                              width: 64,
                              height: 64,
                              borderRadius: BorderRadius.circular(12),
                              fallbackIcon: Icons.fastfood,
                              fallbackBg: AppThemeV3.accent.withValues(alpha: 0.1),
                              fallbackIconColor: AppThemeV3.accent,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Meal name (or type)
                              Text(
                                (_nextOrder!['mealName'] ?? _nextOrder!['mealType'] ?? 'Upcoming meal').toString(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppThemeV3.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppThemeV3.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              // Time
                              Row(
                                children: [
                                  Icon(Icons.access_time, size: 18, color: AppThemeV3.textSecondary),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      (_nextOrder!['deliveryTime'] ?? 'Time not set').toString(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppThemeV3.textTheme.bodyMedium?.copyWith(
                                        color: AppThemeV3.textSecondary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              // Place (default address) — label + full address on two lines
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.place, size: 18, color: AppThemeV3.textSecondary),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Builder(
                                      builder: (context) {
                                        if (_userAddresses.isEmpty) {
                                          return Text(
                                            'Add delivery address',
                                            style: AppThemeV3.textTheme.bodyMedium?.copyWith(
                                              color: AppThemeV3.textSecondary,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          );
                                        }
                                        final a = _userAddresses.first;
                                        return Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              a.label.isNotEmpty ? a.label : 'Address',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: AppThemeV3.textTheme.bodyMedium?.copyWith(
                                                color: AppThemeV3.textSecondary,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              a.fullAddress,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: AppThemeV3.textTheme.bodySmall?.copyWith(
                                                color: AppThemeV3.textSecondary,
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper removed: address display is now built inline to allow two-line layout.

  Widget _buildPastOrdersSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppThemeV3.surface,
            AppThemeV3.surface.withValues(alpha: 0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppThemeV3.accent.withValues(alpha: 0.2),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppThemeV3.accent,
                  borderRadius: BorderRadius.circular(8),
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
          
          // Past orders responsive list: center when fits, scroll when needed
          LayoutBuilder(
            builder: (context, constraints) {
              const double cardWidth = 96;
              const double cardSpacing = 10;
              final int count = _recentOrders.length;
              final double needed = count * cardWidth + (count - 1) * cardSpacing;

              Widget buildCard(Map<String, dynamic> order) {
                return Container(
                  width: cardWidth,
                  decoration: BoxDecoration(
                    color: AppThemeV3.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppThemeV3.border),
                    boxShadow: AppThemeV3.cardShadow,
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
