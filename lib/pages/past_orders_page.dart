import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/meal.dart';

class PastOrdersPage extends StatefulWidget {
  const PastOrdersPage({super.key});

  @override
  State<PastOrdersPage> createState() => _PastOrdersPageState();
}

class _PastOrdersPageState extends State<PastOrdersPage> {
  List<OrderHistory> _orderHistory = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOrderHistory();
  }

  Future<void> _loadOrderHistory() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // TODO: Load actual order history from Firebase
      // For now, using mock data
      _orderHistory = await _getMockOrderHistory();
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading order history: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<List<OrderHistory>> _getMockOrderHistory() async {
    // Mock data - in production this would come from Firebase
    return [
      OrderHistory(
        id: 'order1',
        meal: Meal(
          id: 'meal1',
          name: 'Grilled Salmon Bowl',
          description: 'Atlantic salmon with quinoa, roasted vegetables, and lemon herb sauce',
          imageUrl: 'https://example.com/salmon-bowl.jpg',
          mealType: MealType.dinner,
          price: 16.99,
          ingredients: ['Atlantic Salmon', 'Quinoa', 'Broccoli', 'Carrots', 'Lemon Herb Sauce'],
          allergyWarnings: ['Fish'],
          nutrition: NutritionInfo(
            calories: 520,
            protein: 38,
            carbohydrates: 42,
            fat: 22,
            fiber: 8,
            sugar: 6,
            sodium: 680,
          ),
          isAvailable: true,
          isPopular: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        orderDate: DateTime.now().subtract(const Duration(days: 1)),
        deliveryStatus: 'Delivered',
      ),
      OrderHistory(
        id: 'order2',
        meal: Meal(
          id: 'meal2',
          name: 'Mediterranean Chicken Wrap',
          description: 'Grilled chicken with hummus, cucumber, tomatoes, and feta in a whole wheat wrap',
          imageUrl: 'https://example.com/chicken-wrap.jpg',
          mealType: MealType.lunch,
          price: 12.99,
          ingredients: ['Grilled Chicken', 'Whole Wheat Wrap', 'Hummus', 'Cucumber', 'Tomatoes', 'Feta Cheese'],
          allergyWarnings: ['Gluten', 'Dairy'],
          nutrition: NutritionInfo(
            calories: 420,
            protein: 32,
            carbohydrates: 38,
            fat: 18,
            fiber: 6,
            sugar: 4,
            sodium: 890,
          ),
          isAvailable: true,
          isPopular: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        orderDate: DateTime.now().subtract(const Duration(days: 2)),
        deliveryStatus: 'Delivered',
      ),
      OrderHistory(
        id: 'order3',
        meal: Meal(
          id: 'meal3',
          name: 'Berry Protein Smoothie Bowl',
          description: 'Mixed berries, banana, protein powder, topped with granola and coconut flakes',
          imageUrl: 'https://example.com/smoothie-bowl.jpg',
          mealType: MealType.breakfast,
          price: 9.99,
          ingredients: ['Mixed Berries', 'Banana', 'Protein Powder', 'Granola', 'Coconut Flakes', 'Almond Milk'],
          allergyWarnings: ['Nuts'],
          nutrition: NutritionInfo(
            calories: 310,
            protein: 20,
            carbohydrates: 45,
            fat: 8,
            fiber: 12,
            sugar: 28,
            sodium: 150,
          ),
          isAvailable: true,
          isPopular: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        orderDate: DateTime.now().subtract(const Duration(days: 3)),
        deliveryStatus: 'Delivered',
      ),
      OrderHistory(
        id: 'order4',
        meal: Meal(
          id: 'meal4',
          name: 'Asian Stir-Fry Bowl',
          description: 'Colorful vegetables stir-fried with teriyaki sauce over brown rice',
          imageUrl: 'https://example.com/stir-fry.jpg',
          mealType: MealType.dinner,
          price: 14.99,
          ingredients: ['Brown Rice', 'Bell Peppers', 'Snap Peas', 'Carrots', 'Teriyaki Sauce', 'Sesame Seeds'],
          allergyWarnings: ['Soy', 'Sesame'],
          nutrition: NutritionInfo(
            calories: 380,
            protein: 12,
            carbohydrates: 65,
            fat: 10,
            fiber: 8,
            sugar: 15,
            sodium: 920,
          ),
          isAvailable: true,
          isPopular: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        orderDate: DateTime.now().subtract(const Duration(days: 5)),
        deliveryStatus: 'Delivered',
      ),
      OrderHistory(
        id: 'order5',
        meal: Meal(
          id: 'meal5',
          name: 'Turkey Club Sandwich',
          description: 'Sliced turkey breast with bacon, lettuce, tomato, and avocado on sourdough',
          imageUrl: 'https://example.com/turkey-club.jpg',
          mealType: MealType.lunch,
          price: 11.99,
          ingredients: ['Sourdough Bread', 'Turkey Breast', 'Bacon', 'Lettuce', 'Tomato', 'Avocado'],
          allergyWarnings: ['Gluten'],
          nutrition: NutritionInfo(
            calories: 450,
            protein: 28,
            carbohydrates: 35,
            fat: 24,
            fiber: 6,
            sugar: 4,
            sodium: 1120,
          ),
          isAvailable: true,
          isPopular: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        orderDate: DateTime.now().subtract(const Duration(days: 7)),
        deliveryStatus: 'Delivered',
      ),
    ];
  }

  String _formatOrderDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;
    
    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Yesterday';
    } else if (difference < 7) {
      return '$difference days ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
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
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1F2937)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Past Orders',
          style: TextStyle(
            color: Color(0xFF1F2937),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF6366F1),
              ),
            )
          : _orderHistory.isEmpty
              ? _buildEmptyState()
              : _buildOrdersList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.restaurant_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No Past Orders',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'When you order meals, they\'ll appear here',
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

  Widget _buildOrdersList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _orderHistory.length,
      itemBuilder: (context, index) {
        final orderItem = _orderHistory[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildOrderCard(orderItem),
        );
      },
    );
  }

  Widget _buildOrderCard(OrderHistory orderItem) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main order info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Meal image
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.restaurant,
                    color: Color(0xFF6366F1),
                    size: 40,
                  ),
                ),
                const SizedBox(width: 16),
                // Meal details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  orderItem.meal.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1F2937),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  orderItem.meal.description,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF6B7280),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatOrderDate(orderItem.orderDate),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF9CA3AF),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getMealTypeColor(orderItem.meal.mealType).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          orderItem.meal.mealType.displayName.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: _getMealTypeColor(orderItem.meal.mealType),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Meal info section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Meal Info',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 12),
                _buildNutritionInfo(orderItem.meal.nutrition),
                if (orderItem.meal.allergyWarnings.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildAllergyWarnings(orderItem.meal.allergyWarnings),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionInfo(NutritionInfo nutrition) {
    return Row(
      children: [
        Expanded(
          child: _buildNutritionItem('Calories', '${nutrition.calories}'),
        ),
        Expanded(
          child: _buildNutritionItem('Protein', '${nutrition.protein.toInt()}g'),
        ),
        Expanded(
          child: _buildNutritionItem('Carbs', '${nutrition.carbohydrates.toInt()}g'),
        ),
        Expanded(
          child: _buildNutritionItem('Fat', '${nutrition.fat.toInt()}g'),
        ),
      ],
    );
  }

  Widget _buildNutritionItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }

  Widget _buildAllergyWarnings(List<String> allergyWarnings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Allergy Warnings',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: allergyWarnings.map((allergy) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.2)),
              ),
              child: Text(
                allergy,
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFFEF4444),
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Color _getMealTypeColor(MealType mealType) {
    switch (mealType) {
      case MealType.breakfast:
        return const Color(0xFFF59E0B);
      case MealType.lunch:
        return const Color(0xFF10B981);
      case MealType.dinner:
        return const Color(0xFF6366F1);
    }
  }
}

// Order History model
class OrderHistory {
  final String id;
  final Meal meal;
  final DateTime orderDate;
  final String deliveryStatus;

  OrderHistory({
    required this.id,
    required this.meal,
    required this.orderDate,
    required this.deliveryStatus,
  });
}
