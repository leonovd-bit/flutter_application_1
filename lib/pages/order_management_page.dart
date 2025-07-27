import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/order.dart' as app_models;
import '../services/order_service.dart';
import '../services/notification_service.dart';

class OrderManagementPage extends StatefulWidget {
  const OrderManagementPage({super.key});

  @override
  State<OrderManagementPage> createState() => _OrderManagementPageState();
}

class _OrderManagementPageState extends State<OrderManagementPage> {
  List<app_models.Order> _orders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // For demo purposes, we'll just show orders for the current user
        final upcomingOrder = await OrderService.getUpcomingOrder(user.uid);
        final activeOrder = await OrderService.getActiveOrder(user.uid);
        
        _orders = [
          if (upcomingOrder != null) upcomingOrder,
          if (activeOrder != null) activeOrder,
        ];
      }
    } catch (e) {
      debugPrint('Error loading orders: $e');
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _updateOrderStatus(app_models.Order order, app_models.OrderStatus newStatus) async {
    final success = await OrderService.updateOrderStatus(order.id, newStatus);
    
    if (success) {
      // Send notification about status update
      final updatedOrder = order.copyWith(status: newStatus);
      await NotificationService.notifyOrderStatusUpdate(updatedOrder);
      
      // Reload orders
      await _loadOrders();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order status updated to ${newStatus.name}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Order Management',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _orders.isEmpty
              ? const Center(
                  child: Text(
                    'No orders found',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _orders.length,
                  itemBuilder: (context, index) {
                    final order = _orders[index];
                    return _buildOrderCard(order);
                  },
                ),
    );
  }

  Widget _buildOrderCard(app_models.Order order) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.mealName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Order #${order.id.substring(0, 8)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(order.status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    order.status.name.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _getStatusColor(order.status),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Order Details
            Text(
              order.mealDescription,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  'Delivery: ${_formatDeliveryTime(order.scheduledDeliveryTime)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Status Update Buttons
            if (order.status != app_models.OrderStatus.delivered && 
                order.status != app_models.OrderStatus.cancelled)
              _buildStatusButtons(order),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusButtons(app_models.Order order) {
    final availableStatuses = _getNextStatuses(order.status);
    
    if (availableStatuses.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Wrap(
      spacing: 8,
      children: availableStatuses.map((status) {
        return ElevatedButton(
          onPressed: () => _updateOrderStatus(order, status),
          style: ElevatedButton.styleFrom(
            backgroundColor: _getStatusColor(status),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            _getStatusButtonText(status),
            style: const TextStyle(fontSize: 12),
          ),
        );
      }).toList(),
    );
  }

  List<app_models.OrderStatus> _getNextStatuses(app_models.OrderStatus currentStatus) {
    switch (currentStatus) {
      case app_models.OrderStatus.scheduled:
        return [app_models.OrderStatus.confirmed];
      case app_models.OrderStatus.confirmed:
        return [app_models.OrderStatus.ready];
      case app_models.OrderStatus.ready:
        return [app_models.OrderStatus.pickedUp];
      case app_models.OrderStatus.pickedUp:
        return [app_models.OrderStatus.outForDelivery];
      case app_models.OrderStatus.outForDelivery:
        return [app_models.OrderStatus.delivered];
      default:
        return [];
    }
  }

  Color _getStatusColor(app_models.OrderStatus status) {
    switch (status) {
      case app_models.OrderStatus.scheduled:
        return Colors.grey;
      case app_models.OrderStatus.confirmed:
        return Colors.blue;
      case app_models.OrderStatus.ready:
        return Colors.orange;
      case app_models.OrderStatus.pickedUp:
        return Colors.purple;
      case app_models.OrderStatus.outForDelivery:
        return Colors.indigo;
      case app_models.OrderStatus.delivered:
        return Colors.green;
      case app_models.OrderStatus.cancelled:
        return Colors.red;
    }
  }

  String _getStatusButtonText(app_models.OrderStatus status) {
    switch (status) {
      case app_models.OrderStatus.confirmed:
        return 'Confirm';
      case app_models.OrderStatus.ready:
        return 'Mark Ready';
      case app_models.OrderStatus.pickedUp:
        return 'Mark Picked Up';
      case app_models.OrderStatus.outForDelivery:
        return 'Out for Delivery';
      case app_models.OrderStatus.delivered:
        return 'Mark Delivered';
      default:
        return status.name;
    }
  }

  String _formatDeliveryTime(DateTime time) {
    return '${time.day}/${time.month} at ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
