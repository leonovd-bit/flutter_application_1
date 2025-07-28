import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/delivery_address.dart';
import '../models/meal.dart';
import '../models/subscription.dart';
import '../services/address_service.dart';
import '../services/subscription_service.dart';
import '../widgets/circular_progress_widget.dart';
import '../theme/app_theme.dart';
import 'past_orders_page.dart';
import 'circle_of_health_page.dart';
import 'upcoming_order_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<DeliveryAddress> _addresses = [];
  Map<String, dynamic> _trackingData = {};
  Subscription? _currentSubscription;
  Meal? _upcomingMeal;
  List<Meal> _recentOrders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHomeData();
  }

  Future<void> _loadHomeData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Load addresses
      _addresses = await AddressService.getUserAddresses(user.uid);
      
      // Load current subscription
      _currentSubscription = await SubscriptionService.getUserSubscription(user.uid);
      
      // Load tracking data from completed orders
      _trackingData = await _calculateTrackingData(user.uid);
      
      // Load upcoming meal (mock for now)
      _upcomingMeal = await _getUpcomingMeal();
      
      // Load recent orders (mock for now)
      _recentOrders = await _getRecentOrders();
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading home data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<Map<String, dynamic>> _calculateTrackingData(String userId) async {
    // TODO: Calculate from completed orders
    // For now, return mock data
    return {
      'totalCalories': 1847,
      'totalProtein': 89,
      'mostCommonMealType': 'Lunch',
      'caloriesGoal': 2000,
      'proteinGoal': 100,
    };
  }

  Future<Meal?> _getUpcomingMeal() async {
    // TODO: Get actual upcoming meal from schedule
    // For now, return mock data
    return Meal(
      id: 'upcoming1',
      name: 'Chicken Quinoa Bowl',
      description: 'Grilled chicken with quinoa and vegetables',
      imageUrl: 'https://example.com/chicken-quinoa.jpg',
      mealType: MealType.lunch,
      price: 12.99,
      ingredients: ['Chicken', 'Quinoa', 'Broccoli'],
      allergyWarnings: [],
      nutrition: NutritionInfo(
        calories: 550,
        protein: 35,
        carbohydrates: 45,
        fat: 18,
        fiber: 8,
        sugar: 5,
        sodium: 650,
      ),
      isAvailable: true,
      isPopular: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  Future<List<Meal>> _getRecentOrders() async {
    // TODO: Get actual recent orders
    // For now, return mock data
    return [
      Meal(
        id: 'recent1',
        name: 'Salmon Bowl',
        description: 'Fresh salmon with rice',
        imageUrl: 'https://example.com/salmon.jpg',
        mealType: MealType.dinner,
        price: 14.99,
        ingredients: ['Salmon', 'Rice'],
        allergyWarnings: [],
        nutrition: NutritionInfo(
          calories: 480,
          protein: 32,
          carbohydrates: 35,
          fat: 20,
          fiber: 3,
          sugar: 2,
          sodium: 580,
        ),
        isAvailable: true,
        isPopular: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Meal(
        id: 'recent2',
        name: 'Veggie Wrap',
        description: 'Fresh vegetable wrap',
        imageUrl: 'https://example.com/veggie-wrap.jpg',
        mealType: MealType.lunch,
        price: 9.99,
        ingredients: ['Tortilla', 'Vegetables'],
        allergyWarnings: [],
        nutrition: NutritionInfo(
          calories: 320,
          protein: 12,
          carbohydrates: 45,
          fat: 10,
          fiber: 6,
          sugar: 8,
          sodium: 420,
        ),
        isAvailable: true,
        isPopular: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Meal(
        id: 'recent3',
        name: 'Berry Smoothie',
        description: 'Mixed berry smoothie bowl',
        imageUrl: 'https://example.com/smoothie.jpg',
        mealType: MealType.breakfast,
        price: 7.99,
        ingredients: ['Berries', 'Yogurt'],
        allergyWarnings: [],
        nutrition: NutritionInfo(
          calories: 250,
          protein: 8,
          carbohydrates: 35,
          fat: 5,
          fiber: 4,
          sugar: 25,
          sodium: 120,
        ),
        isAvailable: true,
        isPopular: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];
  }

  String _getSubscriptionDisplayName() {
    if (_currentSubscription == null) return 'LeanFreak';
    
    switch (_currentSubscription!.plan.mealsPerDay) {
      case 3:
        return 'LeanFreak';
      case 2:
        return 'DietKnight';
      case 1:
        return 'NutrientJr';
      default:
        return 'LeanFreak';
    }
  }

  String _formatDeliveryTime() {
    // TODO: Get actual delivery time from upcoming order
    final now = DateTime.now();
    final deliveryTime = now.add(const Duration(hours: 2));
    final hour = deliveryTime.hour;
    final minute = deliveryTime.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    
    return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(
          child: AppLoadingIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.5,
            colors: [
              AppTheme.background,
              AppTheme.surface.withValues(alpha: 0.2),
              AppTheme.background,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTopBar(),
                const SizedBox(height: 30),
                _buildTrackingCircle(),
                const SizedBox(height: 30),
                _buildAddressSection(),
                const SizedBox(height: 30),
                _buildUpcomingOrder(),
                const SizedBox(height: 30),
                _buildPastOrders(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Icon(
          Icons.location_on,
          color: AppTheme.accent,
          size: 28,
        ),
        Text(
          'FRESHPUNK',
          style: AppTheme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
            color: AppTheme.textPrimary,
          ),
        ),
        IconButton(
          icon: const Icon(
            Icons.settings,
            color: AppTheme.textPrimary,
            size: 28,
          ),
          onPressed: () {
            Navigator.pushNamed(context, '/settings');
          },
        ),
      ],
    );
  }

  Widget _buildTrackingCircle() {
    return Center(
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CircleOfHealthPage()),
          );
        },
        child: SizedBox(
          width: 280,
          height: 280,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer circle with tracking data
              CircularProgressWidget(
                trackingData: _trackingData,
              ),
              // Inner circle with subscription name
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.accent.withValues(alpha: 0.3),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accent.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    _getSubscriptionDisplayName(),
                    style: AppTheme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.accent,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddressSection() {
    final primaryAddress = _addresses.isNotEmpty 
        ? _addresses.firstWhere((addr) => addr.isDefault, orElse: () => _addresses.first)
        : null;
    final secondaryAddress = _addresses.length > 1
        ? _addresses.firstWhere((addr) => !addr.isDefault, orElse: () => _addresses[1])
        : null;

    return Column(
      children: [
        if (primaryAddress != null)
          _buildAddressCard(
            icon: Icons.home,
            label: 'Home Address',
            address: primaryAddress.fullAddress,
            onTap: () {
              // TODO: Navigate to addresses page
            },
          ),
        if (secondaryAddress != null) ...[
          const SizedBox(height: 12),
          _buildAddressCard(
            icon: Icons.business,
            label: 'Office Address',
            address: secondaryAddress.fullAddress,
            onTap: () {
              // TODO: Navigate to addresses page
            },
          ),
        ],
      ],
    );
  }

  Widget _buildAddressCard({
    required IconData icon,
    required String label,
    required String address,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AppCard(
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: AppTheme.accent,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label.toUpperCase(),
                    style: AppTheme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.accent,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    address,
                    style: AppTheme.textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textPrimary.withValues(alpha: 0.7),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: AppTheme.textPrimary.withValues(alpha: 0.3),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingOrder() {
    if (_upcomingMeal == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'UPCOMING ORDER',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF374151),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const UpcomingOrderPage()),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Meal image placeholder
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.restaurant,
                    color: Color(0xFF6366F1),
                    size: 30,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _upcomingMeal!.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _upcomingMeal!.description,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _upcomingMeal!.mealType.displayName.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF6366F1),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatDeliveryTime(),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF374151),
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
    );
  }

  Widget _buildPastOrders() {
    if (_recentOrders.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'PAST ORDERS',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF374151),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: _recentOrders.take(3).map((meal) => 
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const PastOrdersPage()),
                    );
                  },
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        height: 80,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.restaurant,
                          color: Color(0xFF6366F1),
                          size: 30,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        meal.name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF374151),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ).toList(),
        ),
      ],
    );
  }
}
