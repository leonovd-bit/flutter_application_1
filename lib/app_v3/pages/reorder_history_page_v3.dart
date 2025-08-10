import 'package:flutter/material.dart';
import '../theme/app_theme_v3.dart';
import '../services/reorder_service.dart';

class ReorderHistoryPageV3 extends StatefulWidget {
  const ReorderHistoryPageV3({super.key});

  @override
  State<ReorderHistoryPageV3> createState() => _ReorderHistoryPageV3State();
}

class _ReorderHistoryPageV3State extends State<ReorderHistoryPageV3> {
  List<Map<String, dynamic>> _reorderHistory = [];
  Map<String, dynamic> _reorderStats = {};
  bool _isLoading = true;
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _loadReorderData();
  }

  Future<void> _loadReorderData() async {
    setState(() => _isLoading = true);
    
    try {
      final history = await ReorderService.getReorderHistory();
      final stats = await ReorderService.getReorderStats();
      
      setState(() {
        _reorderHistory = history;
        _reorderStats = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load reorder history: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  List<Map<String, dynamic>> get _filteredReorders {
    if (_selectedFilter == 'All') {
      return _reorderHistory;
    } else if (_selectedFilter == 'Favorites') {
      return _reorderHistory.where((reorder) => reorder['isFavorite'] == true).toList();
    } else {
      // Filter by meal plan type
      return _reorderHistory.where((reorder) => 
        reorder['mealPlanType'] == _selectedFilter.toLowerCase()).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Reorder History',
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
            icon: const Icon(Icons.refresh, color: Colors.black87),
            onPressed: _loadReorderData,
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
                // Stats Card
                if (_reorderStats['totalReorders'] > 0) _buildStatsCard(),
                
                // Filter Tabs
                _buildFilterTabs(),
                
                // Reorder List
                Expanded(
                  child: _filteredReorders.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: _loadReorderData,
                          color: AppThemeV3.primaryGreen,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _filteredReorders.length,
                            itemBuilder: (context, index) {
                              final reorder = _filteredReorders[index];
                              return _buildReorderCard(reorder);
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatsCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppThemeV3.primaryGreen,
            AppThemeV3.primaryGreen.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppThemeV3.primaryGreen.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
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
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.analytics,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Your Reorder Stats',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Total Reorders',
                  '${_reorderStats['totalReorders']}',
                  Icons.refresh,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Total Spent',
                  '\$${(_reorderStats['totalSpent'] ?? 0.0).toStringAsFixed(2)}',
                  Icons.attach_money,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Avg Order',
                  '\$${(_reorderStats['averageOrderValue'] ?? 0.0).toStringAsFixed(2)}',
                  Icons.trending_up,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Favorite Plan',
                  _getMealPlanDisplayName(_reorderStats['mostReorderedPlan'] ?? 'nutritious'),
                  Icons.favorite,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white, size: 16),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs() {
    final filters = ['All', 'Favorites', 'Nutritious', 'DietKnight', 'LeanFreak'];
    
    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = _selectedFilter == filter;
          
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedFilter = filter;
              });
            },
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? AppThemeV3.primaryGreen : Colors.grey[200],
                borderRadius: BorderRadius.circular(25),
              ),
              child: Center(
                child: Text(
                  filter,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey[600],
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.refresh,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            _selectedFilter == 'All' 
                ? 'No Reorder History'
                : 'No $_selectedFilter Reorders',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedFilter == 'All'
                ? 'Your reordered meals will appear here'
                : 'No reorders found for the selected filter',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.restaurant_menu),
            label: const Text('Browse Past Orders'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppThemeV3.primaryGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReorderCard(Map<String, dynamic> reorder) {
    final reorderDate = DateTime.fromMillisecondsSinceEpoch(reorder['reorderDate']);
    final isFavorite = reorder['isFavorite'] ?? false;
    
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
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppThemeV3.primaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.refresh,
                    color: AppThemeV3.primaryGreen,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getMealPlanDisplayName(reorder['mealPlanType']),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Reordered on ${_formatDate(reorderDate)}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _toggleFavorite(reorder['id']),
                  icon: Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: isFavorite ? Colors.red : Colors.grey[400],
                  ),
                ),
              ],
            ),
          ),
          
          // Details
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                _buildInfoRow(
                  Icons.attach_money,
                  'Amount',
                  '\$${(reorder['totalAmount'] ?? 0.0).toStringAsFixed(2)}',
                ),
                const SizedBox(height: 8),
                _buildInfoRow(
                  Icons.location_on,
                  'Address',
                  reorder['deliveryAddress'] ?? 'Not specified',
                ),
                if (reorder['notes'] != null && reorder['notes'].isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    Icons.note,
                    'Notes',
                    reorder['notes'],
                  ),
                ],
              ],
            ),
          ),
          
          // Actions
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _reorderAgain(reorder),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reorder Again'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppThemeV3.primaryGreen,
                      side: const BorderSide(color: AppThemeV3.primaryGreen),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _viewOriginalOrder(reorder['originalOrderId']),
                    icon: const Icon(Icons.receipt),
                    label: const Text('View Original'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppThemeV3.primaryGreen,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
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
        Flexible(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  String _getMealPlanDisplayName(String type) {
    switch (type.toLowerCase()) {
      case 'nutritious':
        return 'NutritiousJr Plan';
      case 'dietknight':
        return 'DietKnight Plan';
      case 'leanfreak':
        return 'LeanFreak Plan';
      default:
        return 'Unknown Plan';
    }
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Future<void> _toggleFavorite(String reorderId) async {
    await ReorderService.toggleFavoriteReorder(reorderId);
    _loadReorderData(); // Refresh the list
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Favorite status updated'),
        backgroundColor: AppThemeV3.primaryGreen,
      ),
    );
  }

  void _reorderAgain(Map<String, dynamic> reorder) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reorder Again'),
        content: Text('Reorder "${_getMealPlanDisplayName(reorder['mealPlanType'])}" again?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement reorder logic
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Starting reorder process...'),
                  backgroundColor: AppThemeV3.primaryGreen,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppThemeV3.primaryGreen,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reorder'),
          ),
        ],
      ),
    );
  }

  void _viewOriginalOrder(String originalOrderId) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Viewing original order #${originalOrderId.substring(originalOrderId.length - 6).toUpperCase()}'),
        backgroundColor: AppThemeV3.primaryGreen,
      ),
    );
  }
}
