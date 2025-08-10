import 'package:flutter/material.dart';
// import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme_v3.dart';
import '../models/meal_model_v3.dart';
import '../services/firestore_service_v3.dart';
import '../services/reorder_service.dart';
import 'reorder_history_page_v3.dart';

class PastOrdersPageV3 extends StatefulWidget {
  const PastOrdersPageV3({super.key});

  @override
  State<PastOrdersPageV3> createState() => _PastOrdersPageV3State();
}

class _PastOrdersPageV3State extends State<PastOrdersPageV3> {
  List<OrderModelV3> _pastOrders = [];
  bool _isLoading = true;
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _loadPastOrders();
  }

  Future<void> _loadPastOrders() async {
    try {
      // Get current user ID
      final userId = FirestoreServiceV3.getCurrentUserId();
      if (userId != null) {
        // Load past orders from Firebase
        final ordersData = await FirestoreServiceV3.getPastOrders(userId);
        final orders = ordersData.map((data) => OrderModelV3.fromJson(data)).toList();
        setState(() {
          _pastOrders = orders;
          _isLoading = false;
        });
      } else {
        // User not logged in, use sample data
        _loadSampleOrders();
      }
    } catch (e) {
      // Use sample data if Firebase fails
      _loadSampleOrders();
    }
  }

  void _loadSampleOrders() {
    setState(() {
      _pastOrders = [
        OrderModelV3(
          id: 'order_past_1',
          userId: 'user123',
          mealPlanType: MealPlanType.nutritious,
          meals: [
            MealModelV3(
              id: 'b1',
              name: 'Avocado Toast & Eggs',
              description: 'Whole grain toast with avocado and scrambled eggs',
              calories: 420,
              protein: 18,
              carbs: 35,
              fat: 24,
              ingredients: const [],
              allergens: const [],
              icon: Icons.breakfast_dining,
              imageUrl: '',
              mealType: 'breakfast',
              price: 12.99,
            ),
          ],
          deliveryAddress: 'Home',
          orderDate: DateTime.now().subtract(const Duration(days: 7)),
          deliveryDate: DateTime.now().subtract(const Duration(days: 7)),
          status: OrderStatus.delivered,
          totalAmount: 24.99,
          estimatedDeliveryTime: DateTime.now().subtract(const Duration(days: 7)),
        ),
        OrderModelV3(
          id: 'order_past_2',
          userId: 'user123',
          mealPlanType: MealPlanType.leanFreak,
          meals: [
            MealModelV3(
              id: 'l1',
              name: 'Grilled Chicken Power Bowl',
              description: 'Chicken, quinoa, greens, and roasted veggies',
              calories: 550,
              protein: 42,
              carbs: 45,
              fat: 16,
              ingredients: const [],
              allergens: const [],
              icon: Icons.lunch_dining,
              imageUrl: '',
              mealType: 'lunch',
              price: 13.99,
            ),
          ],
          deliveryAddress: 'Work',
          orderDate: DateTime.now().subtract(const Duration(days: 14)),
          deliveryDate: DateTime.now().subtract(const Duration(days: 14)),
          status: OrderStatus.delivered,
          totalAmount: 29.99,
          estimatedDeliveryTime: DateTime.now().subtract(const Duration(days: 14)),
        ),
        OrderModelV3(
          id: 'order_past_3',
          userId: 'user123',
          mealPlanType: MealPlanType.dietKnight,
          meals: [
            MealModelV3(
              id: 'd1',
              name: 'Salmon & Veggie Plate',
              description: 'Roasted salmon with seasonal vegetables',
              calories: 480,
              protein: 34,
              carbs: 28,
              fat: 22,
              ingredients: const [],
              allergens: const [],
              icon: Icons.dinner_dining,
              imageUrl: '',
              mealType: 'dinner',
              price: 14.99,
            ),
          ],
          deliveryAddress: 'Office',
          orderDate: DateTime.now().subtract(const Duration(days: 21)),
          deliveryDate: DateTime.now().subtract(const Duration(days: 21)),
          status: OrderStatus.delivered,
          totalAmount: 27.99,
          estimatedDeliveryTime: DateTime.now().subtract(const Duration(days: 21)),
        ),
        OrderModelV3(
          id: 'order_past_4',
          userId: 'user123',
          mealPlanType: MealPlanType.nutritious,
          meals: [
            MealModelV3(
              id: 'b2',
              name: 'Greek Yogurt Bowl',
              description: 'Greek yogurt with berries and granola',
              calories: 320,
              protein: 20,
              carbs: 42,
              fat: 8,
              ingredients: const [],
              allergens: const [],
              icon: Icons.breakfast_dining,
              imageUrl: '',
              mealType: 'breakfast',
              price: 9.99,
            ),
          ],
          deliveryAddress: 'Home',
          orderDate: DateTime.now().subtract(const Duration(days: 30)),
          deliveryDate: DateTime.now().subtract(const Duration(days: 30)),
          status: OrderStatus.cancelled,
          totalAmount: 24.99,
          estimatedDeliveryTime: DateTime.now().subtract(const Duration(days: 30)),
        ),
      ];
      _isLoading = false;
    });
  }

  List<OrderModelV3> get _filteredOrders {
    if (_selectedFilter == 'All') {
      return _pastOrders;
    } else if (_selectedFilter == 'Delivered') {
      return _pastOrders.where((order) => order.status == OrderStatus.delivered).toList();
    } else if (_selectedFilter == 'Cancelled') {
      return _pastOrders.where((order) => order.status == OrderStatus.cancelled).toList();
    }
    return _pastOrders;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Past Orders',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: Colors.black87),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ReorderHistoryPageV3(),
                ),
              );
            },
            tooltip: 'Reorder History',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppThemeV3.primaryGreen),
              ),
            )
          : Column(
              children: [
                // Filter Tabs
                _buildFilterTabs(),
                
                // Orders List
                Expanded(
                  child: _filteredOrders.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: _loadPastOrders,
                          color: AppThemeV3.primaryGreen,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _filteredOrders.length,
                            itemBuilder: (context, index) {
                              final order = _filteredOrders[index];
                              return _buildOrderCard(order);
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildFilterTabs() {
    final filters = ['All', 'Delivered', 'Cancelled'];
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: filters.map((filter) {
          final isSelected = _selectedFilter == filter;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedFilter = filter;
                });
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? AppThemeV3.primaryGreen : Colors.grey[100],
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Text(
                  filter,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey[600],
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            _selectedFilter == 'All' 
                ? 'No Past Orders'
                : 'No $_selectedFilter Orders',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedFilter == 'All'
                ? 'Your order history will appear here'
                : 'No orders found for the selected filter',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(OrderModelV3 order) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: order.status == OrderStatus.cancelled 
            ? Border.all(color: AppThemeV3.primaryGreen.withOpacity(0.3), width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Special reorder banner for cancelled orders
          if (order.status == OrderStatus.cancelled)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppThemeV3.primaryGreen.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.refresh,
                    color: AppThemeV3.primaryGreen,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Available for Reorder',
                    style: TextStyle(
                      color: AppThemeV3.primaryGreen,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  FutureBuilder<bool>(
                    future: ReorderService.hasBeenReordered(order.id),
                    builder: (context, snapshot) {
                      if (snapshot.data == true) {
                        return Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: AppThemeV3.primaryGreen,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Previously Reordered',
                              style: TextStyle(
                                color: AppThemeV3.primaryGreen,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ],
              ),
            ),
          
          // Order Header
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _getStatusColor(order.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getStatusIcon(order.status),
                    color: _getStatusColor(order.status),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _orderTitleFromMeals(order),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Order #${order.id.substring(order.id.length - 6).toUpperCase()}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(order.status),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _getStatusText(order.status),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Order Details
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                _buildInfoRow(
                  Icons.calendar_today,
                  'Order Date',
                  _formatDate(order.orderDate),
                ),
                const SizedBox(height: 8),
                _buildInfoRow(
                  Icons.location_on,
                  'Delivery Address',
                  _addressDisplayName(order.deliveryAddress),
                ),
                const SizedBox(height: 8),
                // Price removed per request
              ],
            ),
          ),

          // Action Buttons
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _reorderMeal(order),
                    icon: Icon(
                      order.status == OrderStatus.cancelled ? Icons.refresh : Icons.refresh,
                      color: order.status == OrderStatus.cancelled 
                          ? AppThemeV3.primaryGreen 
                          : AppThemeV3.primaryGreen,
                    ),
                    label: Text(
                      order.status == OrderStatus.cancelled ? 'Reorder Now' : 'Reorder',
                      style: TextStyle(
                        fontWeight: order.status == OrderStatus.cancelled 
                            ? FontWeight.w600 
                            : FontWeight.normal,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppThemeV3.primaryGreen,
                      side: BorderSide(
                        color: AppThemeV3.primaryGreen,
                        width: order.status == OrderStatus.cancelled ? 2 : 1,
                      ),
                    ),
                  ),
                ),
                // Receipt button removed per request
                if (order.status == OrderStatus.delivered) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _leaveFeedback(order),
                      icon: const Icon(Icons.star_outline),
                      label: const Text('Rate'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange,
                        side: const BorderSide(color: Colors.orange),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: Colors.grey[600],
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.delivered:
        return Colors.green;
      case OrderStatus.cancelled:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(OrderStatus status) {
    switch (status) {
      case OrderStatus.delivered:
        return Icons.check_circle;
      case OrderStatus.cancelled:
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }

  String _getStatusText(OrderStatus status) {
    switch (status) {
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.cancelled:
        return 'Cancelled';
      default:
        return 'Unknown';
    }
  }

  String _getMealPlanDisplayName(MealPlanType type) {
    switch (type) {
      case MealPlanType.nutritious:
        return 'NutritiousJr Plan';
      case MealPlanType.dietKnight:
        return 'DietKnight Plan';
      case MealPlanType.leanFreak:
        return 'LeanFreak Plan';
    }
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _orderTitleFromMeals(OrderModelV3 order) {
    if (order.meals.isEmpty) return _getMealPlanDisplayName(order.mealPlanType);
    final names = order.meals.map((m) => m.name).where((n) => n.isNotEmpty).toList();
    if (names.isEmpty) return _getMealPlanDisplayName(order.mealPlanType);
    if (names.length == 1) return names.first;
    return '${names.first} +${names.length - 1} more';
  }

  String _addressDisplayName(String fullAddress) {
    final lower = fullAddress.toLowerCase();
    if (lower.contains('home')) return 'Home';
    if (lower.contains('work')) return 'Work';
    if (lower.contains('office')) return 'Office';
    return fullAddress.isNotEmpty ? fullAddress : 'Address';
  }

  void _reorderMeal(OrderModelV3 order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.refresh,
              color: AppThemeV3.primaryGreen,
              size: 24,
            ),
            const SizedBox(width: 8),
            const Text('Reorder Meal'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reorder "${_orderTitleFromMeals(order)}"?',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.restaurant_menu, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Text(
                        'Original order details:',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('• Meal: ${_orderTitleFromMeals(order)}'),
                  Text('• Address: ${_addressDisplayName(order.deliveryAddress)}'),
                  if (order.notes != null && order.notes!.isNotEmpty)
                    Text('• Notes: ${order.notes}'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'This will create a new order with the same meal plan and preferences.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _processReorder(order);
            },
            icon: const Icon(Icons.add_shopping_cart),
            label: const Text('Reorder Now'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppThemeV3.primaryGreen,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _processReorder(OrderModelV3 order) async {
    final userId = FirestoreServiceV3.getCurrentUserId();
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to reorder.')),
      );
      return;
    }

    if (order.meals.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This order has no meal details to reorder.')),
      );
      return;
    }

    final newMeal = order.meals.first;
    final mealType = newMeal.mealType;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final replaced = await FirestoreServiceV3.replaceNextUpcomingOrderMealOfType(
        userId: userId,
        mealType: mealType,
        newMeal: newMeal,
      );

      if (mounted) Navigator.pop(context);

      if (replaced) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Replaced Next Order'),
            content: Text('Your next $mealType order has been updated to "${newMeal.name}".'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/upcoming-orders-v3');
                },
                child: const Text('View Upcoming'),
              ),
            ],
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No upcoming $mealType order available to replace, or it is locked.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to replace next order: $e')),
      );
    }
  }

  // Removed legacy success dialog for reorder cart flow

  // Removed unused navigation helper

  // _viewOrderDetails removed (receipt UI disabled)

  void _leaveFeedback(OrderModelV3 order) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Opening feedback form...'),
        backgroundColor: Colors.orange,
      ),
    );
  }
}
