import 'package:flutter/material.dart';

class MenuPage extends StatefulWidget {
  final String mealType;
  
  const MenuPage({
    super.key,
    required this.mealType,
  });

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  // Sample meal data
  List<Map<String, dynamic>> get _meals {
    switch (widget.mealType) {
      case 'breakfast':
        return [
          {
            'name': 'Avocado Toast Supreme',
            'description': 'Multigrain bread with smashed avocado, poached egg, and microgreens',
            'image': 'assets/images/avocado_toast.jpg',
            'nutrients': {
              'calories': 350,
              'protein': '14g',
              'carbs': '32g',
              'fat': '18g',
            },
            'ingredients': ['Multigrain bread', 'Avocado', 'Egg', 'Microgreens', 'Olive oil', 'Sea salt'],
            'allergens': ['Gluten', 'Eggs'],
          },
          {
            'name': 'Greek Yogurt Parfait',
            'description': 'Creamy Greek yogurt layered with fresh berries and granola',
            'image': 'assets/images/yogurt_parfait.jpg',
            'nutrients': {
              'calories': 280,
              'protein': '20g',
              'carbs': '25g',
              'fat': '8g',
            },
            'ingredients': ['Greek yogurt', 'Mixed berries', 'Homemade granola', 'Honey'],
            'allergens': ['Dairy', 'Nuts'],
          },
          {
            'name': 'Veggie Scramble Bowl',
            'description': 'Scrambled eggs with seasonal vegetables and herbs',
            'image': 'assets/images/veggie_scramble.jpg',
            'nutrients': {
              'calories': 320,
              'protein': '18g',
              'carbs': '12g',
              'fat': '22g',
            },
            'ingredients': ['Eggs', 'Bell peppers', 'Spinach', 'Mushrooms', 'Onions', 'Fresh herbs'],
            'allergens': ['Eggs'],
          },
        ];
      case 'lunch':
        return [
          {
            'name': 'Mediterranean Bowl',
            'description': 'Quinoa bowl with grilled chicken, vegetables, and tahini dressing',
            'image': 'assets/images/mediterranean_bowl.jpg',
            'nutrients': {
              'calories': 520,
              'protein': '32g',
              'carbs': '45g',
              'fat': '22g',
            },
            'ingredients': ['Quinoa', 'Grilled chicken', 'Cucumber', 'Tomatoes', 'Red onion', 'Feta cheese', 'Tahini'],
            'allergens': ['Dairy', 'Sesame'],
          },
          {
            'name': 'Asian Fusion Salad',
            'description': 'Mixed greens with sesame-crusted tofu and ginger dressing',
            'image': 'assets/images/asian_salad.jpg',
            'nutrients': {
              'calories': 420,
              'protein': '22g',
              'carbs': '28g',
              'fat': '26g',
            },
            'ingredients': ['Mixed greens', 'Tofu', 'Edamame', 'Carrots', 'Sesame seeds', 'Ginger dressing'],
            'allergens': ['Soy', 'Sesame'],
          },
        ];
      case 'dinner':
        return [
          {
            'name': 'Herb-Crusted Salmon',
            'description': 'Fresh Atlantic salmon with roasted vegetables and quinoa',
            'image': 'assets/images/salmon_dinner.jpg',
            'nutrients': {
              'calories': 580,
              'protein': '42g',
              'carbs': '35g',
              'fat': '28g',
            },
            'ingredients': ['Atlantic salmon', 'Quinoa', 'Broccoli', 'Carrots', 'Herbs', 'Lemon'],
            'allergens': ['Fish'],
          },
          {
            'name': 'Plant-Based Power Bowl',
            'description': 'Lentils, roasted vegetables, and tahini drizzle over brown rice',
            'image': 'assets/images/power_bowl.jpg',
            'nutrients': {
              'calories': 480,
              'protein': '24g',
              'carbs': '52g',
              'fat': '18g',
            },
            'ingredients': ['Brown rice', 'Lentils', 'Sweet potato', 'Kale', 'Chickpeas', 'Tahini'],
            'allergens': ['Sesame'],
          },
        ];
      default:
        return [];
    }
  }

  String get _pageTitle {
    switch (widget.mealType) {
      case 'breakfast':
        return 'FreshPunk Breakfast Menu';
      case 'lunch':
        return 'FreshPunk Lunch Menu';
      case 'dinner':
        return 'FreshPunk Dinner Menu';
      default:
        return 'FreshPunk Menu';
    }
  }

  void _showMealInfo(Map<String, dynamic> meal) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with close button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        meal['name'],
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Nutrition Info
                const Text(
                  'Nutrition Information',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2D5A2D),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      _buildNutritionRow('Calories', '${meal['nutrients']['calories']}'),
                      _buildNutritionRow('Protein', meal['nutrients']['protein']),
                      _buildNutritionRow('Carbs', meal['nutrients']['carbs']),
                      _buildNutritionRow('Fat', meal['nutrients']['fat']),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Ingredients
                const Text(
                  'Ingredients',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2D5A2D),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: (meal['ingredients'] as List<String>).map((ingredient) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        ingredient,
                        style: const TextStyle(fontSize: 12),
                      ),
                    );
                  }).toList(),
                ),
                
                const SizedBox(height: 16),
                
                // Allergens
                const Text(
                  'Allergen Information',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: (meal['allergens'] as List<String>).map((allergen) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange[300]!),
                      ),
                      child: Text(
                        allergen,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange[800],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNutritionRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
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
          'Menu',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page title
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                _pageTitle,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
            
            // Meal list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: _meals.length,
                itemBuilder: (context, index) {
                  final meal = _meals[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          // Meal image placeholder
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.restaurant_menu,
                              size: 40,
                              color: Colors.grey[400],
                            ),
                          ),
                          
                          const SizedBox(width: 16),
                          
                          // Meal info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  meal['name'],
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  meal['description'],
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                
                                // Meal Info button
                                SizedBox(
                                  height: 32,
                                  child: OutlinedButton(
                                    onPressed: () => _showMealInfo(meal),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF2D5A2D),
                                      side: const BorderSide(color: Color(0xFF2D5A2D)),
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                    ),
                                    child: const Text(
                                      'Meal Info',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // Action buttons (for registered users only)
                          // For now, these are hidden as per requirements
                          const SizedBox(width: 16),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
