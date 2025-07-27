import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/meal.dart';
import 'meal_schedule_page.dart';

class CircleOfHealthPage extends StatefulWidget {
  const CircleOfHealthPage({super.key});

  @override
  State<CircleOfHealthPage> createState() => _CircleOfHealthPageState();
}

class _CircleOfHealthPageState extends State<CircleOfHealthPage> {
  DateTime _selectedDate = DateTime.now();
  Map<String, dynamic> _dailyProgress = {};
  List<Meal> _consumedMeals = [];
  bool _isLoading = true;

  // Fixed standard daily nutrition goals
  static const Map<String, double> _dailyGoals = {
    'calories': 2000.0,
    'protein': 50.0, // grams
    'fat': 65.0, // grams
    'carbs': 300.0, // grams
    'fiber': 25.0, // grams
    'sugar': 50.0, // grams
    'vitaminE': 15.0, // mg
  };

  @override
  void initState() {
    super.initState();
    _loadDailyProgress();
  }

  Future<void> _loadDailyProgress() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // TODO: Load actual consumed meals for selected date from Firebase
      // For now, using mock data based on selected date
      _consumedMeals = await _getMockConsumedMeals(_selectedDate);
      _dailyProgress = _calculateDailyProgress(_consumedMeals);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading daily progress: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<List<Meal>> _getMockConsumedMeals(DateTime date) async {
    // Mock data - varies based on selected date
    final daysSinceToday = DateTime.now().difference(date).inDays;
    
    if (daysSinceToday < 0) {
      // Future dates - no consumed meals
      return [];
    }
    
    // Past dates - mock consumed meals (fewer for older dates)
    final mealsCount = daysSinceToday == 0 ? 2 : (daysSinceToday == 1 ? 3 : 1);
    
    final allMockMeals = [
      Meal(
        id: 'breakfast1',
        name: 'Protein Smoothie Bowl',
        description: 'Berry smoothie with protein powder',
        imageUrl: 'https://example.com/smoothie.jpg',
        mealType: MealType.breakfast,
        price: 9.99,
        ingredients: ['Berries', 'Protein Powder', 'Banana'],
        allergyWarnings: [],
        nutrition: NutritionInfo(
          calories: 320,
          protein: 25,
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
      Meal(
        id: 'lunch1',
        name: 'Quinoa Power Bowl',
        description: 'Quinoa with grilled chicken and vegetables',
        imageUrl: 'https://example.com/quinoa-bowl.jpg',
        mealType: MealType.lunch,
        price: 13.99,
        ingredients: ['Quinoa', 'Grilled Chicken', 'Mixed Vegetables'],
        allergyWarnings: [],
        nutrition: NutritionInfo(
          calories: 480,
          protein: 35,
          carbohydrates: 52,
          fat: 15,
          fiber: 8,
          sugar: 6,
          sodium: 420,
        ),
        isAvailable: true,
        isPopular: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Meal(
        id: 'dinner1',
        name: 'Salmon & Sweet Potato',
        description: 'Grilled salmon with roasted sweet potato',
        imageUrl: 'https://example.com/salmon-dinner.jpg',
        mealType: MealType.dinner,
        price: 17.99,
        ingredients: ['Atlantic Salmon', 'Sweet Potato', 'Asparagus'],
        allergyWarnings: ['Fish'],
        nutrition: NutritionInfo(
          calories: 540,
          protein: 42,
          carbohydrates: 35,
          fat: 24,
          fiber: 6,
          sugar: 8,
          sodium: 380,
        ),
        isAvailable: true,
        isPopular: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];

    return allMockMeals.take(mealsCount).toList();
  }

  Map<String, dynamic> _calculateDailyProgress(List<Meal> meals) {
    double totalCalories = 0;
    double totalProtein = 0;
    double totalFat = 0;
    double totalCarbs = 0;
    double totalFiber = 0;
    double totalSugar = 0;
    double totalVitaminE = 5.0; // Mock vitamin E value

    for (final meal in meals) {
      totalCalories += meal.nutrition.calories;
      totalProtein += meal.nutrition.protein;
      totalFat += meal.nutrition.fat;
      totalCarbs += meal.nutrition.carbohydrates;
      totalFiber += meal.nutrition.fiber;
      totalSugar += meal.nutrition.sugar;
    }

    return {
      'calories': totalCalories,
      'protein': totalProtein,
      'fat': totalFat,
      'carbs': totalCarbs,
      'fiber': totalFiber,
      'sugar': totalSugar,
      'vitaminE': totalVitaminE,
    };
  }

  void _changeDate(int days) {
    final newDate = _selectedDate.add(Duration(days: days));
    final today = DateTime.now();
    final oneWeekAgo = today.subtract(const Duration(days: 7));
    final oneWeekAhead = today.add(const Duration(days: 7));

    if (newDate.isBefore(oneWeekAgo) || newDate.isAfter(oneWeekAhead)) {
      return; // Don't allow navigation beyond 1 week range
    }

    setState(() {
      _selectedDate = newDate;
    });
    _loadDailyProgress();
  }

  void _goToToday() {
    setState(() {
      _selectedDate = DateTime.now();
    });
    _loadDailyProgress();
  }

  String _formatSelectedDate() {
    final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final weekday = weekdays[_selectedDate.weekday - 1];
    
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));
    final tomorrow = today.add(const Duration(days: 1));
    
    if (_selectedDate.day == today.day && _selectedDate.month == today.month) {
      return 'Today ($weekday)';
    } else if (_selectedDate.day == yesterday.day && _selectedDate.month == yesterday.month) {
      return 'Yesterday ($weekday)';
    } else if (_selectedDate.day == tomorrow.day && _selectedDate.month == tomorrow.month) {
      return 'Tomorrow ($weekday)';
    } else {
      return weekday;
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
          'Circle of Health',
          style: TextStyle(
            color: Color(0xFF1F2937),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _goToToday,
            child: const Text(
              'Today',
              style: TextStyle(
                color: Color(0xFF6366F1),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF6366F1),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDateSelector(),
                  const SizedBox(height: 24),
                  _buildMealIcons(),
                  const SizedBox(height: 32),
                  _buildDailyTracker(),
                ],
              ),
            ),
    );
  }

  Widget _buildDateSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF6366F1).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Color(0xFF6366F1)),
            onPressed: () => _changeDate(-1),
          ),
          Expanded(
            child: Text(
              _formatSelectedDate(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: Color(0xFF6366F1)),
            onPressed: () => _changeDate(1),
          ),
        ],
      ),
    );
  }

  Widget _buildMealIcons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildMealIcon(
          icon: Icons.free_breakfast,
          label: 'Breakfast',
          mealType: MealType.breakfast,
          color: const Color(0xFFF59E0B),
        ),
        _buildMealIcon(
          icon: Icons.lunch_dining,
          label: 'Lunch',
          mealType: MealType.lunch,
          color: const Color(0xFF10B981),
        ),
        _buildMealIcon(
          icon: Icons.dinner_dining,
          label: 'Dinner',
          mealType: MealType.dinner,
          color: const Color(0xFF6366F1),
        ),
      ],
    );
  }

  Widget _buildMealIcon({
    required IconData icon,
    required String label,
    required MealType mealType,
    required Color color,
  }) {
    final isConsumed = _consumedMeals.any((meal) => meal.mealType == mealType);
    
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const MealSchedulePage(),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isConsumed ? color.withOpacity(0.15) : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isConsumed ? color : Colors.grey[300]!,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: isConsumed ? color : Colors.grey[400],
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isConsumed ? color : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyTracker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Daily Tracker',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 20),
        _buildProgressItem(
          'Calories',
          _dailyProgress['calories'] ?? 0,
          _dailyGoals['calories']!,
          Icons.local_fire_department,
          const Color(0xFFEF4444),
          'cal',
        ),
        _buildProgressItem(
          'Protein',
          _dailyProgress['protein'] ?? 0,
          _dailyGoals['protein']!,
          Icons.fitness_center,
          const Color(0xFF6366F1),
          'g',
        ),
        _buildProgressItem(
          'Fats',
          _dailyProgress['fat'] ?? 0,
          _dailyGoals['fat']!,
          Icons.opacity,
          const Color(0xFFF59E0B),
          'g',
        ),
        _buildProgressItem(
          'Carbs',
          _dailyProgress['carbs'] ?? 0,
          _dailyGoals['carbs']!,
          Icons.grass,
          const Color(0xFF10B981),
          'g',
        ),
        _buildProgressItem(
          'Fiber',
          _dailyProgress['fiber'] ?? 0,
          _dailyGoals['fiber']!,
          Icons.eco,
          const Color(0xFF84CC16),
          'g',
        ),
        _buildProgressItem(
          'Sugar',
          _dailyProgress['sugar'] ?? 0,
          _dailyGoals['sugar']!,
          Icons.grain,
          const Color(0xFFEC4899),
          'g',
        ),
        _buildProgressItem(
          'Vitamin E',
          _dailyProgress['vitaminE'] ?? 0,
          _dailyGoals['vitaminE']!,
          Icons.star,
          const Color(0xFF8B5CF6),
          'mg',
        ),
      ],
    );
  }

  Widget _buildProgressItem(
    String title,
    double current,
    double goal,
    IconData icon,
    Color color,
    String unit,
  ) {
    final progress = (current / goal).clamp(0.0, 1.0);
    final percentage = (progress * 100).round();
    final isExceeded = current > goal;
    final isCompleted = current >= goal;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF374151),
                ),
              ),
              const Spacer(),
              Text(
                '${current.toInt()}/${goal.toInt()} $unit',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isExceeded ? const Color(0xFFEF4444) : const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Stack(
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              FractionallySizedBox(
                widthFactor: progress > 1.0 ? 1.0 : progress,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: isCompleted ? const Color(0xFF10B981) : color.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              if (isExceeded)
                Positioned(
                  right: 0,
                  child: Container(
                    height: 8,
                    width: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$percentage%${isExceeded ? ' (Exceeded)' : ''}',
            style: TextStyle(
              fontSize: 12,
              color: isExceeded ? const Color(0xFFEF4444) : const Color(0xFF9CA3AF),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
