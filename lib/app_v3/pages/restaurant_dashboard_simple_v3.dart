import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme_v3.dart';
import '../services/restaurant_notification_service.dart';

class RestaurantDashboardSimpleV3 extends StatefulWidget {
  final String restaurantId;
  final String restaurantName;
  
  const RestaurantDashboardSimpleV3({
    super.key,
    required this.restaurantId,
    required this.restaurantName,
  });

  @override
  State<RestaurantDashboardSimpleV3> createState() => _RestaurantDashboardSimpleV3State();
}

class _RestaurantDashboardSimpleV3State extends State<RestaurantDashboardSimpleV3> {
  Map<String, dynamic>? _restaurantData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRestaurantData();
  }

  Future<void> _loadRestaurantData() async {
    setState(() => _isLoading = true);
    
    try {
      final data = await RestaurantNotificationService.getRestaurantProfile(widget.restaurantId);
      setState(() {
        _restaurantData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeV3.background,
      appBar: AppBar(
        title: Text(widget.restaurantName),
        backgroundColor: AppThemeV3.primaryGreen,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRestaurantData,
          ),
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings),
                    SizedBox(width: 8),
                    Text('Settings'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadRestaurantData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatsSection(),
                    const SizedBox(height: 24),
                    _buildNotificationsSection(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatsSection() {
    final stats = _restaurantData?['stats'] ?? {};
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Today\'s Overview',
          style: AppThemeV3.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Total Orders',
                '${stats['totalOrders'] ?? 0}',
                Icons.receipt_long,
                AppThemeV3.primaryGreen,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                'Total Revenue',
                '\$${(stats['totalRevenue'] ?? 0).toStringAsFixed(2)}',
                Icons.attach_money,
                Colors.blue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Avg Order',
                '\$${(stats['averageOrderValue'] ?? 0).toStringAsFixed(2)}',
                Icons.trending_up,
                Colors.orange,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                'Last Order',
                _formatLastOrder(stats['lastOrderDate']),
                Icons.schedule,
                Colors.purple,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppThemeV3.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppThemeV3.border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppThemeV3.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppThemeV3.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            title,
            style: AppThemeV3.textTheme.bodySmall?.copyWith(
              color: AppThemeV3.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Order Notifications',
              style: AppThemeV3.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton.icon(
              onPressed: () => _showAllNotifications(),
              icon: const Icon(Icons.history),
              label: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot>(
          stream: RestaurantNotificationService.streamRestaurantNotifications(widget.restaurantId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return _buildErrorCard('Error loading notifications: ${snapshot.error}');
            }

            final notifications = snapshot.data?.docs ?? [];

            if (notifications.isEmpty) {
              return _buildEmptyNotifications();
            }

            return Column(
              children: notifications.take(5).map((doc) {
                final notification = {
                  'id': doc.id,
                  ...doc.data() as Map<String, dynamic>,
                };
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildNotificationCard(notification),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification) {
    final isUnread = notification['status'] == 'pending';
    final meals = notification['meals'] as List? ?? [];
    final totalAmount = notification['totalAmount'] ?? 0.0;

    return Card(
      elevation: isUnread ? 4 : 1,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => _showNotificationDetails(notification),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: isUnread 
                ? Border.all(color: AppThemeV3.primaryGreen, width: 2)
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isUnread 
                          ? AppThemeV3.primaryGreen.withOpacity(0.1)
                          : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      isUnread ? Icons.notifications_active : Icons.notifications,
                      size: 16,
                      color: isUnread ? AppThemeV3.primaryGreen : Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Order from ${notification['customerName'] ?? 'Customer'}',
                          style: AppThemeV3.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Delivery: ${notification['deliveryDate']} at ${notification['deliveryTime']}',
                          style: AppThemeV3.textTheme.bodySmall?.copyWith(
                            color: AppThemeV3.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '\$${totalAmount.toStringAsFixed(2)}',
                        style: AppThemeV3.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppThemeV3.primaryGreen,
                        ),
                      ),
                      Text(
                        RestaurantNotificationService.getTimeAgo(notification['createdAt'] ?? ''),
                        style: AppThemeV3.textTheme.bodySmall?.copyWith(
                          color: AppThemeV3.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '${meals.length} items: ${_getMealsSummary(meals)}',
                style: AppThemeV3.textTheme.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyNotifications() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppThemeV3.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppThemeV3.border),
      ),
      child: Column(
        children: [
          Icon(
            Icons.notifications_none,
            size: 64,
            color: AppThemeV3.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            'No Orders Yet',
            style: AppThemeV3.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Order notifications will appear here when customers schedule meals from your restaurant.',
            style: AppThemeV3.textTheme.bodyMedium?.copyWith(
              color: AppThemeV3.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String error) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              error,
              style: TextStyle(color: Colors.red.shade600),
            ),
          ),
        ],
      ),
    );
  }

  String _getMealsSummary(List meals) {
    if (meals.isEmpty) return 'No items';
    
    return meals.take(3).map((meal) {
      final quantity = meal['quantity'] ?? 1;
      final name = meal['name'] ?? 'Unknown item';
      return quantity > 1 ? '$quantity× $name' : name;
    }).join(', ') + (meals.length > 3 ? '...' : '');
  }

  String _formatLastOrder(String? lastOrderDate) {
    if (lastOrderDate == null) return 'Never';
    
    try {
      final date = DateTime.parse(lastOrderDate);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        return 'Today';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return '${(difference.inDays / 7).floor()}w ago';
      }
    } catch (e) {
      return 'Unknown';
    }
  }

  void _showNotificationDetails(Map<String, dynamic> notification) {
    // Mark as read when opened
    if (notification['status'] == 'pending') {
      RestaurantNotificationService.markNotificationAsRead(notification['id']);
    }

    showDialog(
      context: context,
      builder: (context) => _NotificationDetailsDialog(notification: notification),
    );
  }

  void _showAllNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _AllNotificationsPage(
          restaurantId: widget.restaurantId,
          restaurantName: widget.restaurantName,
        ),
      ),
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'settings':
        _showSettingsDialog();
        break;
    }
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restaurant Settings'),
        content: const Text('Settings panel coming soon'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _NotificationDetailsDialog extends StatelessWidget {
  final Map<String, dynamic> notification;

  const _NotificationDetailsDialog({required this.notification});

  @override
  Widget build(BuildContext context) {
    final meals = notification['meals'] as List? ?? [];
    final totalAmount = notification['totalAmount'] ?? 0.0;

    return AlertDialog(
      title: Text('Order Details'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDetailRow('Customer', notification['customerName'] ?? 'Unknown'),
            if (notification['customerPhone'] != null)
              _buildDetailRow('Phone', RestaurantNotificationService.formatPhoneNumber(notification['customerPhone'])),
            if (notification['customerEmail'] != null)
              _buildDetailRow('Email', notification['customerEmail']),
            _buildDetailRow('Delivery Date', notification['deliveryDate'] ?? 'TBD'),
            _buildDetailRow('Delivery Time', notification['deliveryTime'] ?? 'TBD'),
            if (notification['deliveryAddress'] != null)
              _buildDetailRow('Address', notification['deliveryAddress']),
            const SizedBox(height: 16),
            Text(
              'Order Items:',
              style: AppThemeV3.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...meals.map((meal) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text('${meal['quantity'] ?? 1}× ${meal['name'] ?? 'Unknown'}'),
                  ),
                  Text('\$${(meal['price'] ?? 0).toString()}'),
                ],
              ),
            )),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total:',
                  style: AppThemeV3.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  '\$${totalAmount.toStringAsFixed(2)}',
                  style: AppThemeV3.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppThemeV3.primaryGreen,
                  ),
                ),
              ],
            ),
            if (notification['specialInstructions'] != null) ...[
              const SizedBox(height: 16),
              Text(
                'Special Instructions:',
                style: AppThemeV3.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(notification['specialInstructions']),
            ],
            const SizedBox(height: 16),
            _buildDetailRow('Order ID', notification['orderId'] ?? 'Unknown'),
          ],
        ),
      ),
      actions: [
        if (notification['status'] != 'acknowledged')
          TextButton(
            onPressed: () {
              RestaurantNotificationService.acknowledgeNotification(notification['id']);
              Navigator.of(context).pop();
            },
            child: const Text('Acknowledge'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: AppThemeV3.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppThemeV3.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _AllNotificationsPage extends StatelessWidget {
  final String restaurantId;
  final String restaurantName;

  const _AllNotificationsPage({
    required this.restaurantId,
    required this.restaurantName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$restaurantName - All Orders'),
        backgroundColor: AppThemeV3.primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: RestaurantNotificationService.streamRestaurantNotifications(restaurantId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          final notifications = snapshot.data?.docs ?? [];

          if (notifications.isEmpty) {
            return const Center(
              child: Text('No notifications yet'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = {
                'id': notifications[index].id,
                ...notifications[index].data() as Map<String, dynamic>,
              };

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  child: ListTile(
                    title: Text('Order from ${notification['customerName'] ?? 'Customer'}'),
                    subtitle: Text('${notification['deliveryDate']} at ${notification['deliveryTime']}'),
                    trailing: Text('\$${(notification['totalAmount'] ?? 0).toStringAsFixed(2)}'),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => _NotificationDetailsDialog(notification: notification),
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}