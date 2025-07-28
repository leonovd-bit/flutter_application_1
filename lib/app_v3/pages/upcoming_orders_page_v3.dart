import 'package:flutter/material.dart';
import '../theme/app_theme_v3.dart';
import '../models/meal_model_v3.dart';
import '../services/firestore_service_v3.dart';

class UpcomingOrdersPageV3 extends StatefulWidget {
  const UpcomingOrdersPageV3({super.key});

  @override
  State<UpcomingOrdersPageV3> createState() => _UpcomingOrdersPageV3State();
}

class _UpcomingOrdersPageV3State extends State<UpcomingOrdersPageV3> {
  List<OrderModelV3> _upcomingOrders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUpcomingOrders();
  }

  Future<void> _loadUpcomingOrders() async {
    try {
      // Get current user ID
      final userId = FirestoreServiceV3.getCurrentUserId();
      if (userId != null) {
        // Load upcoming orders from Firebase
        final ordersData = await FirestoreServiceV3.getUpcomingOrders(userId);
        final orders = ordersData.map((data) => OrderModelV3.fromJson(data)).toList();
        setState(() {
          _upcomingOrders = orders;
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
      _upcomingOrders = [
        OrderModelV3(
          id: 'order_1',
          userId: 'user123',
          mealPlanType: MealPlanType.nutritious,
          meals: [],
          deliveryAddress: 'Your Address',
          orderDate: DateTime.now().subtract(const Duration(hours: 2)),
          deliveryDate: DateTime.now().add(const Duration(hours: 4)),
          status: OrderStatus.preparing,
          totalAmount: 24.99,
          estimatedDeliveryTime: DateTime.now().add(const Duration(hours: 4)),
        ),
        OrderModelV3(
          id: 'order_2',
          userId: 'user123',
          mealPlanType: MealPlanType.leanFreak,
          meals: [],
          deliveryAddress: 'Your Address',
          orderDate: DateTime.now().subtract(const Duration(hours: 1)),
          deliveryDate: DateTime.now().add(const Duration(days: 1, hours: 2)),
          status: OrderStatus.confirmed,
          totalAmount: 29.99,
          estimatedDeliveryTime: DateTime.now().add(const Duration(days: 1, hours: 2)),
        ),
        OrderModelV3(
          id: 'order_3',
          userId: 'user123',
          mealPlanType: MealPlanType.dietKnight,
          meals: [],
          deliveryAddress: 'Your Address',
          orderDate: DateTime.now().subtract(const Duration(minutes: 30)),
          deliveryDate: DateTime.now().add(const Duration(days: 2, hours: 1)),
          status: OrderStatus.outForDelivery,
          totalAmount: 27.99,
          estimatedDeliveryTime: DateTime.now().add(const Duration(minutes: 30)),
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
        title: const Text(
          'Upcoming Orders',
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
          : _upcomingOrders.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadUpcomingOrders,
                  color: AppThemeV3.primaryGreen,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _upcomingOrders.length,
                    itemBuilder: (context, index) {
                      final order = _upcomingOrders[index];
                      return _buildOrderCard(order);
                    },
                  ),
                ),
    );
  }

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

          // Delivery Info
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                _buildInfoRow(
                  Icons.access_time,
                  'Estimated Delivery',
                  _formatDeliveryTime(order.estimatedDeliveryTime),
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

          // Progress Indicator for Active Orders
          if (order.status == OrderStatus.preparing || 
              order.status == OrderStatus.outForDelivery)
            _buildProgressIndicator(order),

          // Action Buttons
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                if (order.status == OrderStatus.outForDelivery)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _trackOrder(order),
                      icon: const Icon(Icons.location_on),
                      label: const Text('Track Order'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppThemeV3.primaryGreen,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                if (order.status == OrderStatus.confirmed)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _cancelOrder(order),
                      icon: const Icon(Icons.cancel),
                      label: const Text('Cancel Order'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                    ),
                  ),
                if (order.status == OrderStatus.preparing ||
                    order.status == OrderStatus.outForDelivery) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _contactSupport(order),
                      icon: const Icon(Icons.support_agent),
                      label: const Text('Support'),
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
                      icon: const Icon(Icons.info),
                      label: const Text('Details'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppThemeV3.primaryGreen,
                        foregroundColor: Colors.white,
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

  Widget _buildProgressIndicator(OrderModelV3 order) {
    double progress = 0.0;
    switch (order.status) {
      case OrderStatus.confirmed:
        progress = 0.25;
        break;
      case OrderStatus.preparing:
        progress = 0.5;
        break;
      case OrderStatus.outForDelivery:
        progress = 0.75;
        break;
      case OrderStatus.delivered:
        progress = 1.0;
        break;
      default:
        progress = 0.0;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order Progress',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(AppThemeV3.primaryGreen),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.confirmed:
        return Colors.blue;
      case OrderStatus.preparing:
        return Colors.orange;
      case OrderStatus.outForDelivery:
        return AppThemeV3.primaryGreen;
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
      case OrderStatus.confirmed:
        return Icons.check_circle;
      case OrderStatus.preparing:
        return Icons.restaurant;
      case OrderStatus.outForDelivery:
        return Icons.local_shipping;
      case OrderStatus.delivered:
        return Icons.done_all;
      case OrderStatus.cancelled:
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }

  String _getStatusText(OrderStatus status) {
    switch (status) {
      case OrderStatus.confirmed:
        return 'Confirmed';
      case OrderStatus.preparing:
        return 'Preparing';
      case OrderStatus.outForDelivery:
        return 'Out for Delivery';
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

  String _formatDeliveryTime(DateTime? deliveryTime) {
    if (deliveryTime == null) return 'Not available';
    
    final now = DateTime.now();
    final difference = deliveryTime.difference(now);
    
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours';
    } else {
      return '${difference.inDays} days';
    }
  }

  void _trackOrder(OrderModelV3 order) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Tracking order #${order.id.substring(order.id.length - 6).toUpperCase()}...'),
        backgroundColor: AppThemeV3.primaryGreen,
      ),
    );
  }

  void _cancelOrder(OrderModelV3 order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Order'),
        content: const Text('Are you sure you want to cancel this order?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Order cancelled successfully'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }

  void _contactSupport(OrderModelV3 order) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Connecting to customer support...'),
        backgroundColor: AppThemeV3.primaryGreen,
      ),
    );
  }

  void _viewOrderDetails(OrderModelV3 order) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Viewing details for order #${order.id.substring(order.id.length - 6).toUpperCase()}'),
        backgroundColor: AppThemeV3.primaryGreen,
      ),
    );
  }
}
