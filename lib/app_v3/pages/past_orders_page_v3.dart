import 'package:flutter/material.dart';
import '../theme/app_theme_v3.dart';
import '../models/meal_model_v3.dart';
import '../services/firestore_service_v3.dart';

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
          meals: [],
          deliveryAddress: 'Your Address',
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
          meals: [],
          deliveryAddress: 'Your Address',
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
          meals: [],
          deliveryAddress: 'Your Address',
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
          meals: [],
          deliveryAddress: 'Your Address',
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
                        _getMealPlanDisplayName(order.mealPlanType),
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
                  order.deliveryAddress,
                ),
                const SizedBox(height: 8),
                _buildInfoRow(
                  Icons.attach_money,
                  'Total Amount',
                  '\$${order.totalAmount.toStringAsFixed(2)}',
                ),
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
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reorder'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppThemeV3.primaryGreen,
                      side: const BorderSide(color: AppThemeV3.primaryGreen),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _viewOrderDetails(order),
                    icon: const Icon(Icons.receipt),
                    label: const Text('View Receipt'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppThemeV3.primaryGreen,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
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

  void _reorderMeal(OrderModelV3 order) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Reordering ${_getMealPlanDisplayName(order.mealPlanType)}...'),
        backgroundColor: AppThemeV3.primaryGreen,
      ),
    );
  }

  void _viewOrderDetails(OrderModelV3 order) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Viewing receipt for order #${order.id.substring(order.id.length - 6).toUpperCase()}'),
        backgroundColor: AppThemeV3.primaryGreen,
      ),
    );
  }

  void _leaveFeedback(OrderModelV3 order) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Opening feedback form...'),
        backgroundColor: Colors.orange,
      ),
    );
  }
}
