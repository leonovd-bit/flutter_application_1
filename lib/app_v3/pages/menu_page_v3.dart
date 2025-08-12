import 'package:flutter/material.dart';
import '../theme/app_theme_v3.dart';
import '../models/meal_model_v3.dart';
import '../services/meal_service_v3.dart';
import '../services/token_service_v3.dart';

class MenuPageV3 extends StatefulWidget {
  final String menuType;
  
  const MenuPageV3({super.key, required this.menuType});

  @override
  State<MenuPageV3> createState() => _MenuPageV3State();
}

class _MenuPageV3State extends State<MenuPageV3> {
  String _selectedMealType = 'Breakfast';
  late Future<List<MealModelV3>> _mealsFuture;
  
  @override
  void initState() {
    super.initState();
    _selectedMealType = widget.menuType.capitalizeFirst();
  _mealsFuture = MealServiceV3.getMeals(mealType: _selectedMealType.toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeV3.background,
      appBar: AppBar(
        backgroundColor: AppThemeV3.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Menu',
          style: AppThemeV3.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          // User icon (sign up view)
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () {
              // Navigate to sign up
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Token balance banner
          StreamBuilder<int>(
            stream: TokenServiceV3.balanceStream(),
            builder: (context, snapshot) {
              final tokens = snapshot.data ?? 0;
              return Container(
                color: Colors.orange.shade50,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.toll, color: Colors.orange),
                    const SizedBox(width: 8),
                    Text('$tokens tokens available', style: AppThemeV3.textTheme.bodyMedium),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Go to Plans to buy more tokens')),
                        );
                      },
                      child: const Text('Buy tokens'),
                    ),
                  ],
                ),
              );
            },
          ),
          // Meal type selector (Breakfast, Lunch, Dinner)
          Container(
            color: AppThemeV3.surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildMealTypeTab('Breakfast'),
                _buildMealTypeTab('Lunch'),
                _buildMealTypeTab('Dinner'),
              ],
            ),
          ),
          
          // FreshPunk Menu Header
          Container(
            color: AppThemeV3.surface,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  'FreshPunk',
                  style: AppThemeV3.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${_selectedMealType.toUpperCase()} MENU',
                  style: AppThemeV3.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppThemeV3.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          
          // Menu items list
          Expanded(
            child: FutureBuilder<List<MealModelV3>>(
              future: _mealsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = (snapshot.data ?? []);
                final list = items.isNotEmpty ? items : _getSampleMeals();
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final meal = list[index];
                    return _buildMealCard(meal);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealTypeTab(String mealType) {
    final isSelected = mealType == _selectedMealType;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedMealType = mealType;
            _mealsFuture = MealServiceV3.getMeals(mealType: _selectedMealType.toLowerCase());
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? AppThemeV3.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            mealType,
            textAlign: TextAlign.center,
            style: AppThemeV3.textTheme.titleMedium?.copyWith(
              color: isSelected ? Colors.white : AppThemeV3.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMealCard(MealModelV3 meal) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppThemeV3.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppThemeV3.border),
        boxShadow: AppThemeV3.cardShadow,
      ),
      child: Column(
        children: [
          // Main meal info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Meal image placeholder
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 80,
                    height: 80,
                    child: meal.imageUrl.isNotEmpty
                        ? Image.network(
                            meal.imageUrl,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            color: AppThemeV3.surfaceElevated,
                            child: Icon(
                              meal.icon,
                              size: 40,
                              color: AppThemeV3.accent,
                            ),
                          ),
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // Meal name and description
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        meal.name,
                        style: AppThemeV3.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        meal.description,
                        style: AppThemeV3.textTheme.bodyMedium?.copyWith(
                          color: AppThemeV3.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // View/Add icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppThemeV3.accent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.visibility,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
          
          // Meal Info button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _showMealInfo(meal),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppThemeV3.accent,
                      side: const BorderSide(color: AppThemeV3.accent),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      'Meal Info',
                      style: AppThemeV3.textTheme.titleMedium?.copyWith(
                        color: AppThemeV3.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final balance = await TokenServiceV3.getBalance();
                      if (balance <= 0) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('No tokens left. Buy more from Plans.')),
                        );
                        return;
                      }
                      final ok = await TokenServiceV3.useTokens(
                        orderId: 'order_${DateTime.now().millisecondsSinceEpoch}',
                        tokens: 1,
                      );
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(ok ? 'Meal ordered with 1 token' : 'Failed to use token')),
                      );
                    },
                    icon: const Icon(Icons.toll),
                    label: const Text('Use 1 Token'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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

  void _showMealInfo(MealModelV3 meal) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppThemeV3.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                meal.name,
                style: AppThemeV3.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              
              // Nutrients
              Text(
                'Nutrition Information',
                style: AppThemeV3.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Calories: ${meal.calories}\nProtein: ${meal.protein}g\nCarbs: ${meal.carbs}g\nFat: ${meal.fat}g',
                style: AppThemeV3.textTheme.bodyMedium,
              ),
              
              const SizedBox(height: 16),
              
              // Ingredients
              Text(
                'Ingredients',
                style: AppThemeV3.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                meal.ingredients.join(', '),
                style: AppThemeV3.textTheme.bodyMedium,
              ),
              
              const SizedBox(height: 16),
              
              // Allergy warnings
              Text(
                'Allergy Warnings',
                style: AppThemeV3.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppThemeV3.warning,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                meal.allergens.isNotEmpty ? meal.allergens.join(', ') : 'None',
                style: AppThemeV3.textTheme.bodyMedium?.copyWith(
                  color: meal.allergens.isNotEmpty ? AppThemeV3.warning : AppThemeV3.success,
                ),
              ),
              
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  List<MealModelV3> _getSampleMeals() {
    switch (_selectedMealType.toLowerCase()) {
      case 'breakfast':
        return [
          MealModelV3(
            id: '1',
            name: 'Avocado Toast',
            description: 'Whole grain bread topped with fresh avocado, cherry tomatoes, and a sprinkle of seeds',
            calories: 320,
            protein: 12,
            carbs: 35,
            fat: 18,
            ingredients: ['Whole grain bread', 'Avocado', 'Cherry tomatoes', 'Pumpkin seeds', 'Olive oil'],
            allergens: ['Gluten'],
            icon: Icons.breakfast_dining,
            imageUrl: '',
          ),
          MealModelV3(
            id: '2',
            name: 'Greek Yogurt Parfait',
            description: 'Creamy Greek yogurt layered with fresh berries and granola',
            calories: 280,
            protein: 20,
            carbs: 32,
            fat: 8,
            ingredients: ['Greek yogurt', 'Mixed berries', 'Granola', 'Honey'],
            allergens: ['Dairy', 'Nuts'],
            icon: Icons.icecream,
            imageUrl: '',
          ),
          MealModelV3(
            id: '3',
            name: 'Almond Butter Pancakes',
            description: 'Fluffy pancakes made with almond flour and topped with fresh fruit',
            calories: 450,
            protein: 15,
            carbs: 42,
            fat: 25,
            ingredients: ['Almond flour', 'Eggs', 'Banana', 'Blueberries', 'Maple syrup'],
            allergens: ['Nuts', 'Eggs'],
            icon: Icons.cake,
            imageUrl: '',
          ),
        ];
      case 'lunch':
        return [
          MealModelV3(
            id: '4',
            name: 'Quinoa Buddha Bowl',
            description: 'Nutritious bowl with quinoa, roasted vegetables, and tahini dressing',
            calories: 420,
            protein: 16,
            carbs: 58,
            fat: 15,
            ingredients: ['Quinoa', 'Sweet potato', 'Broccoli', 'Chickpeas', 'Tahini'],
            allergens: ['Sesame'],
            icon: Icons.rice_bowl,
            imageUrl: '',
          ),
          MealModelV3(
            id: '5',
            name: 'Grilled Chicken Salad',
            description: 'Fresh mixed greens with grilled chicken, avocado, and balsamic vinaigrette',
            calories: 380,
            protein: 35,
            carbs: 12,
            fat: 22,
            ingredients: ['Chicken breast', 'Mixed greens', 'Avocado', 'Cherry tomatoes', 'Balsamic vinegar'],
            allergens: [],
            icon: Icons.lunch_dining,
            imageUrl: '',
          ),
        ];
      case 'dinner':
        return [
          MealModelV3(
            id: '6',
            name: 'Salmon with Vegetables',
            description: 'Baked salmon with roasted seasonal vegetables and herbs',
            calories: 480,
            protein: 40,
            carbs: 18,
            fat: 28,
            ingredients: ['Salmon fillet', 'Asparagus', 'Bell peppers', 'Olive oil', 'Herbs'],
            allergens: ['Fish'],
            icon: Icons.dinner_dining,
            imageUrl: '',
          ),
          MealModelV3(
            id: '7',
            name: 'Lentil Curry',
            description: 'Hearty red lentil curry with coconut milk and spices, served with rice',
            calories: 390,
            protein: 18,
            carbs: 65,
            fat: 8,
            ingredients: ['Red lentils', 'Coconut milk', 'Brown rice', 'Onions', 'Spices'],
            allergens: [],
            icon: Icons.dinner_dining,
            imageUrl: '',
          ),
        ];
      default:
        return [];
    }
  }
}

extension StringExtension on String {
  String capitalizeFirst() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1).toLowerCase()}';
  }
}
