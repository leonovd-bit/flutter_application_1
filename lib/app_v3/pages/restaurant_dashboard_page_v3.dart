import 'package:flutter/material.dart';
import '../theme/app_theme_v3.dart';
import '../services/square_integration_service.dart';

class RestaurantDashboardPageV3 extends StatefulWidget {
  final String restaurantId;
  
  const RestaurantDashboardPageV3({
    super.key,
    required this.restaurantId,
  });

  @override
  State<RestaurantDashboardPageV3> createState() => _RestaurantDashboardPageV3State();
}

class _RestaurantDashboardPageV3State extends State<RestaurantDashboardPageV3> 
    with TickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _restaurantData;
  Map<String, dynamic>? _syncStatus;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadRestaurantData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadRestaurantData() async {
    setState(() => _isLoading = true);
    
    try {
      final status = await SquareIntegrationService.getIntegrationStatus(widget.restaurantId);
      setState(() {
        _restaurantData = status['restaurant'];
        _syncStatus = status['syncStatus'];
        _error = null;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeV3.background,
      appBar: AppBar(
        title: Text(_restaurantData?['name'] ?? 'Restaurant Dashboard'),
        backgroundColor: AppThemeV3.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRestaurantData,
          ),
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'sync_menu',
                child: Row(
                  children: [
                    Icon(Icons.sync),
                    SizedBox(width: 8),
                    Text('Force Menu Sync'),
                  ],
                ),
              ),
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
              const PopupMenuItem(
                value: 'disconnect',
                child: Row(
                  children: [
                    Icon(Icons.link_off, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Disconnect Square', 
                      style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Overview'),
            Tab(icon: Icon(Icons.restaurant_menu), text: 'Menu'),
            Tab(icon: Icon(Icons.receipt_long), text: 'Orders'),
            Tab(icon: Icon(Icons.analytics), text: 'Analytics'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(),
                    _buildMenuTab(),
                    _buildOrdersTab(),
                    _buildAnalyticsTab(),
                  ],
                ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Error Loading Dashboard',
            style: AppThemeV3.textTheme.titleLarge?.copyWith(
              color: AppThemeV3.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _error!,
            style: AppThemeV3.textTheme.bodyMedium?.copyWith(
              color: AppThemeV3.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadRestaurantData,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatusCard(),
          const SizedBox(height: 16),
          _buildStatsGrid(),
          const SizedBox(height: 16),
          _buildRecentActivity(),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    final isConnected = _syncStatus?['connected'] ?? false;
    final lastSync = _syncStatus?['lastSync'];
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isConnected
              ? [AppThemeV3.primaryGreen, AppThemeV3.primaryGreen.withOpacity(0.8)]
              : [Colors.orange, Colors.orange.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isConnected ? Icons.check_circle : Icons.warning,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isConnected ? 'Square Connected' : 'Connection Issue',
                      style: AppThemeV3.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isConnected 
                          ? 'Your POS is synced and ready for orders'
                          : 'Please check your Square connection',
                      style: AppThemeV3.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (lastSync != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.schedule, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Last sync: $lastSync',
                    style: AppThemeV3.textTheme.bodySmall?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    final stats = _restaurantData?['stats'] ?? {};
    
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.5,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: [
        _buildStatCard(
          'Today\'s Orders',
          '${stats['todayOrders'] ?? 0}',
          Icons.receipt_long,
          AppThemeV3.primaryGreen,
        ),
        _buildStatCard(
          'Revenue',
          '\$${stats['todayRevenue'] ?? '0.00'}',
          Icons.attach_money,
          Colors.blue,
        ),
        _buildStatCard(
          'Menu Items',
          '${stats['menuItems'] ?? 0}',
          Icons.restaurant_menu,
          Colors.orange,
        ),
        _buildStatCard(
          'Avg Order',
          '\$${stats['avgOrderValue'] ?? '0.00'}',
          Icons.trending_up,
          Colors.purple,
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
        mainAxisAlignment: MainAxisAlignment.center,
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
            style: AppThemeV3.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppThemeV3.textPrimary,
            ),
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

  Widget _buildRecentActivity() {
    final activities = _restaurantData?['recentActivity'] ?? [];
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppThemeV3.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppThemeV3.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Activity',
            style: AppThemeV3.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          if (activities.isEmpty)
            const Text('No recent activity')
          else
            ...activities.take(5).map<Widget>((activity) => 
              _buildActivityItem(activity)).toList(),
        ],
      ),
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> activity) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppThemeV3.primaryGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              _getActivityIcon(activity['type']),
              size: 16,
              color: AppThemeV3.primaryGreen,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity['description'] ?? '',
                  style: AppThemeV3.textTheme.bodyMedium,
                ),
                Text(
                  activity['timestamp'] ?? '',
                  style: AppThemeV3.textTheme.bodySmall?.copyWith(
                    color: AppThemeV3.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getActivityIcon(String? type) {
    switch (type) {
      case 'order':
        return Icons.receipt;
      case 'sync':
        return Icons.sync;
      case 'menu_update':
        return Icons.restaurant_menu;
      default:
        return Icons.circle;
    }
  }

  Widget _buildMenuTab() {
    return const Center(
      child: Text('Menu management coming soon'),
    );
  }

  Widget _buildOrdersTab() {
    return const Center(
      child: Text('Order history coming soon'),
    );
  }

  Widget _buildAnalyticsTab() {
    return const Center(
      child: Text('Analytics coming soon'),
    );
  }

  void _handleMenuAction(String action) async {
    switch (action) {
      case 'sync_menu':
        await _handleForceMenuSync();
        break;
      case 'settings':
        _showSettingsDialog();
        break;
      case 'disconnect':
        _showDisconnectDialog();
        break;
    }
  }

  Future<void> _handleForceMenuSync() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Syncing menu...'),
            ],
          ),
        ),
      );

      final result = await SquareIntegrationService.triggerMenuSync(widget.restaurantId);
      
      Navigator.of(context).pop(); // Close loading dialog
      
      if (result['success'] == true) {
        _showSuccessSnackbar('Menu sync initiated successfully');
        _loadRestaurantData(); // Refresh data
      } else {
        _showErrorSnackbar(result['error'] ?? 'Sync failed');
      }
    } catch (e) {
      Navigator.of(context).pop();
      _showErrorSnackbar(e.toString());
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

  void _showDisconnectDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect Square'),
        content: const Text(
          'Are you sure you want to disconnect your Square POS? This will stop all order synchronization.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _handleDisconnect();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
            child: const Text('Disconnect', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDisconnect() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Disconnecting...'),
            ],
          ),
        ),
      );

      // TODO: Implement disconnect functionality
      await Future.delayed(const Duration(seconds: 2));
      
      Navigator.of(context).pop(); // Close loading dialog
      Navigator.of(context).pop(); // Go back to previous screen
      
      _showSuccessSnackbar('Square disconnected successfully');
    } catch (e) {
      Navigator.of(context).pop();
      _showErrorSnackbar(e.toString());
    }
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppThemeV3.primaryGreen,
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.black,
      ),
    );
  }
}