import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../models/order.dart' as app_models;
import '../services/order_service.dart';
import '../services/review_service.dart';
import 'menu_page.dart';
import 'home_page.dart';

class UpcomingOrderPage extends StatefulWidget {
  const UpcomingOrderPage({super.key});

  @override
  State<UpcomingOrderPage> createState() => _UpcomingOrderPageState();
}

class _UpcomingOrderPageState extends State<UpcomingOrderPage> {
  app_models.Order? _order;
  bool _isLoading = true;
  bool _isSubmittingReview = false;
  StreamSubscription<app_models.Order?>? _orderSubscription;
  
  // Review form controllers
  final _reviewController = TextEditingController();
  int _selectedRating = 5;

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  @override
  void dispose() {
    _orderSubscription?.cancel();
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _loadOrder() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // First check for active order (confirmed, ready, etc.)
      app_models.Order? order = await OrderService.getActiveOrder(user.uid);
      
      // If no active order, check for upcoming order
      order ??= await OrderService.getUpcomingOrder(user.uid);
      
      // If still no order, create a mock one for testing
      if (order == null) {
        final orderId = await OrderService.createMockOrder(user.uid);
        if (orderId != null) {
          // Wait a moment then fetch the created order
          await Future.delayed(const Duration(milliseconds: 500));
          order = await OrderService.getUpcomingOrder(user.uid);
        }
      }

      if (order != null) {
        setState(() {
          _order = order;
          _isLoading = false;
        });

        // Start listening for real-time updates
        _startOrderStream(order.id);
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
            debugPrint('Error loading upcoming order: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _startOrderStream(String orderId) {
    _orderSubscription = OrderService.streamOrderUpdates(orderId).listen((order) {
      if (order != null && mounted) {
        setState(() {
          _order = order;
        });
      }
    });
  }

  Future<void> _confirmOrder() async {
    if (_order == null) return;

    final success = await OrderService.confirmOrder(_order!.id);
    
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order confirmed successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _cancelOrder() async {
    if (_order == null) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Order'),
        content: const Text('Are you sure you want to cancel this order?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await OrderService.cancelOrder(_order!.id);
      
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order cancelled successfully'),
            backgroundColor: Colors.orange,
          ),
        );
        
        // Navigate back to home
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      }
    }
  }

  Future<void> _replaceOrder() async {
    if (_order == null) return;

    // Navigate to menu to select new meal
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const MenuPage(mealType: 'lunch'), // Could be dynamic
      ),
    );

    // Handle the result if meal was selected
    if (result != null && mounted) {
      // TODO: Update order with new meal
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Meal replaced successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _submitReview() async {
    if (_order == null || _reviewController.text.trim().isEmpty) return;

    setState(() {
      _isSubmittingReview = true;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final success = await ReviewService.submitReview(
        orderId: _order!.id,
        userId: user.uid,
        rating: _selectedRating,
        comment: _reviewController.text.trim(),
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Review submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        _reviewController.clear();
      }
    }

    setState(() {
      _isSubmittingReview = false;
    });
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
          'FreshPunk',
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
          : _order == null
              ? _buildNoOrderView()
              : _buildOrderView(),
    );
  }

  Widget _buildNoOrderView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.no_meals,
            size: 80,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            'No upcoming orders',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderView() {
    final order = _order!;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          const Text(
            'Upcoming Order',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 24),
          
          // Meal Info Card
          _buildMealInfoCard(order),
          const SizedBox(height: 24),
          
          // Action Buttons (only show if order can be modified)
          if (order.status == app_models.OrderStatus.scheduled && order.canBeModified)
            _buildActionButtons(),
          
          // Order Tracking
          if (order.status != app_models.OrderStatus.cancelled)
            _buildOrderTracking(order),
          
          // Review Section (only show after delivered)
          if (order.status == app_models.OrderStatus.delivered)
            _buildReviewSection(),
        ],
      ),
    );
  }

  Widget _buildMealInfoCard(app_models.Order order) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Meal Image
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[300],
                ),
                child: const Icon(
                  Icons.restaurant,
                  size: 40,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(width: 16),
              
              // Meal Details
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
                    const SizedBox(height: 4),
                    Text(
                      order.mealDescription,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Delivery Time
              Column(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 20,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${order.scheduledDeliveryTime.hour.toString().padLeft(2, '0')}:${order.scheduledDeliveryTime.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Delivery Address
          Row(
            children: [
              Icon(
                Icons.location_on,
                size: 20,
                color: Colors.grey[600],
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  order.deliveryAddressText,
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
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _replaceOrder,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: Color(0xFF2D5A2D)),
                ),
                child: const Text(
                  'Replace',
                  style: TextStyle(color: Color(0xFF2D5A2D)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: _cancelOrder,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: Colors.red),
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _confirmOrder,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2D5A2D),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Confirm',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildOrderTracking(app_models.Order order) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Order Status',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: _buildTrackingSteps(order),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildTrackingSteps(app_models.Order order) {
    final steps = [
      {
        'title': 'Order Confirmed',
        'icon': Icons.check_circle,
        'status': app_models.OrderStatus.confirmed,
        'time': order.confirmedAt,
      },
      {
        'title': 'Order Ready',
        'icon': Icons.restaurant,
        'status': app_models.OrderStatus.ready,
        'time': order.readyAt,
      },
      {
        'title': 'Order Picked Up',
        'icon': Icons.person,
        'status': app_models.OrderStatus.pickedUp,
        'time': order.pickedUpAt,
      },
      {
        'title': 'Out for Delivery',
        'icon': Icons.directions_car,
        'status': app_models.OrderStatus.outForDelivery,
        'time': order.outForDeliveryAt,
      },
      {
        'title': 'Order Delivered',
        'icon': Icons.home,
        'status': app_models.OrderStatus.delivered,
        'time': order.deliveredAt,
      },
    ];

    return Column(
      children: steps.asMap().entries.map((entry) {
        final index = entry.key;
        final step = entry.value;
        final isCompleted = _isStepCompleted(order.status, step['status'] as app_models.OrderStatus);
        final isActive = order.status == step['status'];
        
        return Column(
          children: [
            Row(
              children: [
                // Step Icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isCompleted || isActive 
                        ? const Color(0xFF2D5A2D) 
                        : Colors.grey[300],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    step['icon'] as IconData,
                    color: isCompleted || isActive ? Colors.white : Colors.grey[600],
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                
                // Step Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        step['title'] as String,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: isCompleted || isActive ? FontWeight.w600 : FontWeight.normal,
                          color: isCompleted || isActive ? Colors.black : Colors.grey[600],
                        ),
                      ),
                      if (step['time'] != null)
                        Text(
                          _formatTime(step['time'] as DateTime),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            
            // Connector Line (except for last item)
            if (index < steps.length - 1)
              Container(
                margin: const EdgeInsets.only(left: 20, top: 8, bottom: 8),
                height: 30,
                width: 2,
                color: isCompleted ? const Color(0xFF2D5A2D) : Colors.grey[300],
              ),
          ],
        );
      }).toList(),
    );
  }

  bool _isStepCompleted(app_models.OrderStatus currentStatus, app_models.OrderStatus stepStatus) {
    const statusOrder = [
      app_models.OrderStatus.confirmed,
      app_models.OrderStatus.ready,
      app_models.OrderStatus.pickedUp,
      app_models.OrderStatus.outForDelivery,
      app_models.OrderStatus.delivered,
    ];
    
    final currentIndex = statusOrder.indexOf(currentStatus);
    final stepIndex = statusOrder.indexOf(stepStatus);
    
    return currentIndex >= stepIndex && currentIndex != -1 && stepIndex != -1;
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildReviewSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Leave a Review',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Rating Stars
              Row(
                children: [
                  const Text(
                    'Rating: ',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  ...List.generate(5, (index) {
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedRating = index + 1;
                        });
                      },
                      child: Icon(
                        Icons.star,
                        color: index < _selectedRating 
                            ? Colors.amber 
                            : Colors.grey[300],
                        size: 30,
                      ),
                    );
                  }),
                ],
              ),
              const SizedBox(height: 16),
              
              // Comment TextField
              TextField(
                controller: _reviewController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Tell us about your experience...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF2D5A2D)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Send Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmittingReview ? null : _submitReview,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D5A2D),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isSubmittingReview
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Send',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
