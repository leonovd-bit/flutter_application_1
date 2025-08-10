import 'package:flutter/material.dart';
import '../theme/app_theme_v3.dart';
import '../models/meal_model_v3.dart';
import '../services/firestore_service_v3.dart';
import 'reorder_history_page_v3.dart';

class PastOrdersPageV3Optimized extends StatefulWidget {
  const PastOrdersPageV3Optimized({super.key});

  @override
  State<PastOrdersPageV3Optimized> createState() => _PastOrdersPageV3OptimizedState();
}

class _PastOrdersPageV3OptimizedState extends State<PastOrdersPageV3Optimized> {
  // Optimized pagination - only load 10 orders at a time
  static const int _pageSize = 10;
  bool _hasMoreData = true;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  
  List<OrderModelV3> _pastOrders = [];
  String _selectedFilter = 'All';
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadPastOrders();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadMoreOrders();
    }
  }

  Future<void> _loadPastOrders({bool refresh = false}) async {
    if (refresh) {
      _pastOrders.clear();
      _hasMoreData = true;
    }
    
    setState(() {
      _isLoading = refresh || _pastOrders.isEmpty;
    });

    try {
      final userId = FirestoreServiceV3.getCurrentUserId();
      if (userId != null) {
        // Load with pagination to save memory
        final ordersData = await FirestoreServiceV3.getUserOrders(
          userId, 
          limit: _pageSize,
        );
        final orders = ordersData.map((data) => OrderModelV3.fromJson(data)).toList();
        
        setState(() {
          if (refresh) {
            _pastOrders = orders;
          } else {
            _pastOrders.addAll(orders);
          }
          _hasMoreData = orders.length == _pageSize;
          _isLoading = false;
        });
      } else {
        _loadSampleOrders();
      }
    } catch (e) {
      _loadSampleOrders();
    }
  }

  Future<void> _loadMoreOrders() async {
    if (_isLoadingMore || !_hasMoreData) return;
    
    setState(() {
      _isLoadingMore = true;
    });
    await _loadPastOrders();
    
    setState(() {
      _isLoadingMore = false;
    });
  }

  void _loadSampleOrders() {
    // Only load minimal sample data to save memory
    setState(() {
      _pastOrders = [
        OrderModelV3(
          id: 'order_past_1',
          userId: 'user123',
          mealPlanType: MealPlanType.nutritious,
          meals: [],
          deliveryAddress: 'Home',
          orderDate: DateTime.now().subtract(const Duration(days: 7)),
          deliveryDate: DateTime.now().subtract(const Duration(days: 7)),
          status: OrderStatus.delivered,
          totalAmount: 24.99,
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
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadPastOrders(refresh: true),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  _buildFilterTabs(),
                  Expanded(
                    child: _filteredOrders.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(16),
                            itemCount: _filteredOrders.length + (_isLoadingMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index >= _filteredOrders.length) {
                                return const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(16),
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }
                              return _buildOptimizedOrderCard(_filteredOrders[index]);
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }

  List<OrderModelV3> get _filteredOrders {
    // Memory-efficient filtering
    if (_selectedFilter == 'All') {
      return _pastOrders;
    }
    
    return _pastOrders.where((order) {
      switch (_selectedFilter) {
        case 'Delivered':
          return order.status == OrderStatus.delivered;
        case 'Cancelled':
          return order.status == OrderStatus.cancelled;
        default:
          return true;
      }
    }).toList();
  }

  Widget _buildFilterTabs() {
    final filters = ['All', 'Delivered', 'Cancelled'];
    
    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: filters.map((filter) {
          final isSelected = _selectedFilter == filter;
          return Flexible(
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

  Widget _buildOptimizedOrderCard(OrderModelV3 order) {
    // Simplified card to reduce memory usage
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getStatusColor(order.status),
          child: Icon(
            _getStatusIcon(order.status),
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          _orderTitleFromMeals(order),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
  subtitle: Text(_formatDate(order.orderDate)),
        trailing: order.status == OrderStatus.cancelled
            ? IconButton(
                icon: const Icon(Icons.refresh, color: AppThemeV3.primaryGreen),
                onPressed: () => _reorderMeal(order),
              )
            : null,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            _selectedFilter == 'All' ? 'No Past Orders' : 'No $_selectedFilter Orders',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.delivered:
        return Colors.green;
      case OrderStatus.cancelled:
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  IconData _getStatusIcon(OrderStatus status) {
    switch (status) {
      case OrderStatus.delivered:
        return Icons.check;
      case OrderStatus.cancelled:
        return Icons.close;
      default:
        return Icons.schedule;
    }
  }

  String _getMealPlanDisplayName(MealPlanType type) {
    switch (type) {
      case MealPlanType.nutritious:
        return 'Nutritious Plan';
      case MealPlanType.dietKnight:
        return 'DietKnight Plan';
      case MealPlanType.leanFreak:
        return 'LeanFreak Plan';
    }
  }

  String _orderTitleFromMeals(OrderModelV3 order) {
    if (order.meals.isEmpty) return _getMealPlanDisplayName(order.mealPlanType);
    final names = order.meals.map((m) => m.name).where((n) => n.isNotEmpty).toList();
    if (names.isEmpty) return _getMealPlanDisplayName(order.mealPlanType);
    if (names.length == 1) return names.first;
    return '${names.first} +${names.length - 1} more';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _reorderMeal(OrderModelV3 order) async {
    final userId = FirestoreServiceV3.getCurrentUserId();
    if (userId == null || order.meals.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sign in required or no meal to reorder.')),
        );
      }
      return;
    }

    final newMeal = order.meals.first;
    final mealType = newMeal.mealType;
    try {
      final replaced = await FirestoreServiceV3.replaceNextUpcomingOrderMealOfType(
        userId: userId,
        mealType: mealType,
        newMeal: newMeal,
      );
      if (!mounted) return;
      if (replaced) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Next $mealType order updated to ${newMeal.name}.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No upcoming $mealType order to replace or it is locked.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to replace next order: $e')),
        );
      }
    }
  }
}
