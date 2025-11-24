import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../utils/cloud_functions_helper.dart';

class SquareRestaurantDashboardV3 extends StatefulWidget {
  final String restaurantId;
  
  const SquareRestaurantDashboardV3({
    Key? key,
    required this.restaurantId,
  }) : super(key: key);

  @override
  _SquareRestaurantDashboardV3State createState() => _SquareRestaurantDashboardV3State();
}

class _SquareRestaurantDashboardV3State extends State<SquareRestaurantDashboardV3> {
  Map<String, dynamic>? _restaurantData;
  List<Map<String, dynamic>> _recentOrders = [];
  bool _isLoading = true;
  bool _isMenuSyncing = false;
  static const _region = 'us-central1';
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: _region);

  HttpsCallable _callable(String name) {
    return callableForPlatform(
      functions: _functions,
      functionName: name,
      region: _region,
    );
  }

  @override
  void initState() {
    super.initState();
    _loadRestaurantData();
  }

  Future<void> _loadRestaurantData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load restaurant data and recent orders
      // This would typically come from Firestore
      await Future.delayed(const Duration(seconds: 1)); // Placeholder
      
      setState(() {
        _restaurantData = {
          'name': 'Mario\'s Italian Kitchen',
          'email': 'mario@italiankitchen.com',
          'phone': '+1 (555) 123-4567',
          'squareConnected': true,
          'lastMenuSync': DateTime.now().subtract(const Duration(hours: 2)),
          'totalOrders': 127,
          'totalRevenue': 4250.75,
          'averageOrderValue': 33.47,
        };
        
        _recentOrders = [
          {
            'id': 'FP_20250923_001',
            'customerName': 'Sarah Johnson',
            'items': ['2× Chicken Parmigiana', '1× Caesar Salad'],
            'total': 45.97,
            'status': 'new',
            'deliveryTime': DateTime.now().add(const Duration(hours: 1)),
            'customerPhone': '+1 (555) 987-6543',
          },
          {
            'id': 'FP_20250923_002',
            'customerName': 'Mike Chen',
            'items': ['1× Margherita Pizza', '1× Garlic Bread'],
            'total': 28.50,
            'status': 'preparing',
            'deliveryTime': DateTime.now().add(const Duration(minutes: 45)),
            'customerPhone': '+1 (555) 456-7890',
          },
        ];
        
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading restaurant data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Square Dashboard',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRestaurantData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Restaurant Status Card
                  _buildStatusCard(),
                  
                  const SizedBox(height: 24),
                  
                  // Statistics Row
                  _buildStatisticsRow(),
                  
                  const SizedBox(height: 24),
                  
                  // Menu Sync Section
                  _buildMenuSyncSection(),
                  
                  const SizedBox(height: 24),
                  
                  // Recent Orders Section
                  _buildRecentOrdersSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildStatusCard() {
    final isConnected = _restaurantData?['squareConnected'] ?? false;
    
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isConnected 
              ? [Colors.green[600]!, Colors.green[400]!]
              : [Colors.red[600]!, Colors.red[400]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isConnected ? Icons.check_circle : Icons.error,
                color: Colors.white,
                size: 32,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _restaurantData?['name'] ?? 'Unknown Restaurant',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      isConnected ? 'Square Connected' : 'Square Disconnected',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (isConnected) ...[
            const SizedBox(height: 16),
            Text(
              'Last menu sync: ${_formatLastSync(_restaurantData?['lastMenuSync'])}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatisticsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total Orders',
            '${_restaurantData?['totalOrders'] ?? 0}',
            Icons.receipt_long,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Revenue',
            '\$${(_restaurantData?['totalRevenue'] ?? 0).toStringAsFixed(2)}',
            Icons.attach_money,
            Colors.green,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Avg Order',
            '\$${(_restaurantData?['averageOrderValue'] ?? 0).toStringAsFixed(2)}',
            Icons.trending_up,
            Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSyncSection() {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.sync, color: Colors.black, size: 24),
              SizedBox(width: 12),
              Text(
                'Menu Synchronization',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Your Square menu items are automatically synced with FreshPunk. '
            'Changes in Square inventory will update availability in real-time.',
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isMenuSyncing ? null : _syncMenu,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              child: _isMenuSyncing
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        SizedBox(width: 8),
                        Text('Syncing Menu...'),
                      ],
                    )
                  : const Text('Sync Menu Now'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentOrdersSection() {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.restaurant_menu, color: Colors.black, size: 24),
              SizedBox(width: 12),
              Text(
                'Recent FreshPunk Orders',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Orders from FreshPunk customers also appear in your Square POS dashboard.',
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          
          ..._recentOrders.map((order) => _buildOrderCard(order)).toList(),
          
          if (_recentOrders.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  children: [
                    Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'No recent orders',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
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

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final status = order['status'] as String;
    final statusColor = status == 'new' ? Colors.orange : 
                       status == 'preparing' ? Colors.blue : Colors.green;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Order ${order['id']}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Customer: ${order['customerName']}',
            style: const TextStyle(fontSize: 14),
          ),
          Text(
            'Phone: ${order['customerPhone']}',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Items: ${(order['items'] as List).join(', ')}',
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Delivery: ${_formatDeliveryTime(order['deliveryTime'])}',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ),
              Text(
                '\$${order['total'].toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _syncMenu() async {
    setState(() {
      _isMenuSyncing = true;
    });

    try {
  final callable = _callable('syncSquareMenu');
      await callable.call({
        'restaurantId': widget.restaurantId,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Menu synced successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      // Update last sync time
      setState(() {
        _restaurantData?['lastMenuSync'] = DateTime.now();
      });
    } catch (e) {
      print('Error syncing menu: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to sync menu. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isMenuSyncing = false;
      });
    }
  }

  String _formatLastSync(DateTime? lastSync) {
    if (lastSync == null) return 'Never';
    
    final now = DateTime.now();
    final difference = now.difference(lastSync);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} hours ago';
    } else {
      return '${difference.inDays} days ago';
    }
  }

  String _formatDeliveryTime(DateTime deliveryTime) {
    final now = DateTime.now();
    final difference = deliveryTime.difference(now);
    
    if (difference.inMinutes < 60) {
      return 'in ${difference.inMinutes} minutes';
    } else {
      return 'at ${deliveryTime.hour}:${deliveryTime.minute.toString().padLeft(2, '0')}';
    }
  }
}