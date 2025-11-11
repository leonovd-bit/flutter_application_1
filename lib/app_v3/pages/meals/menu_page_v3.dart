import 'package:flutter/material.dart';
import '../../theme/app_theme_v3.dart';
import '../../models/meal_model_v3.dart';
import '../../services/meals/meal_service_v3.dart';
import '../../widgets/app_image.dart';

class MenuPageV3 extends StatefulWidget {
  final String menuType;
  
  const MenuPageV3({super.key, required this.menuType});

  @override
  State<MenuPageV3> createState() => _MenuPageV3State();
}

class _MenuPageV3State extends State<MenuPageV3> {
  String _selectedMealType = 'Breakfast';
  String _selectedCategory = 'Premade'; // New: category selector
  late Future<List<MealModelV3>> _mealsFuture;
  final Set<String> _expandedDescriptions = {};
  
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
          
          // Category selector (Premade, Custom)
          Container(
            color: AppThemeV3.surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildCategoryTab('Premade'),
                _buildCategoryTab('Custom'),
              ],
            ),
          ),
          
          // Victus Menu Header
          Container(
            color: AppThemeV3.surface,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  'Victus',
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
                // Filter by selected category
                final allMeals = (snapshot.data ?? []);
                final list = allMeals.where((m) {
                  final category = (m.menuCategory ?? 'premade').toLowerCase();
                  return category == _selectedCategory.toLowerCase();
                }).toList();
                if (list.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text(
                        'No $_selectedCategory meals found for ${_selectedMealType}.',
                        style: AppThemeV3.textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
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
            color: isSelected ? Colors.black : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? Colors.black : AppThemeV3.borderLight,
              width: 2,
            ),
          ),
          child: Text(
            mealType,
            textAlign: TextAlign.center,
            style: AppThemeV3.textTheme.titleMedium?.copyWith(
              color: isSelected ? Colors.white : AppThemeV3.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryTab(String category) {
    final isSelected = category == _selectedCategory;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedCategory = category;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? Colors.black : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? Colors.black : AppThemeV3.borderLight,
              width: 2,
            ),
          ),
          child: Text(
            category,
            textAlign: TextAlign.center,
            style: AppThemeV3.textTheme.titleMedium?.copyWith(
              color: isSelected ? Colors.white : AppThemeV3.textSecondary,
              fontWeight: FontWeight.w700,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Column(
        children: [
          // Main meal info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Meal image (asset or network) with graceful fallback
                Builder(
                  builder: (context) {
                    // Debug meal image loading in menu page
                    print('🍽️ MenuPage - Meal: ${meal.name}');
                    print('🔗 MenuPage - ImagePath: "${meal.imagePath}"');
                    print('🔗 MenuPage - ImageUrl: "${meal.imageUrl}"');
                    print('📏 MenuPage - Path Empty? ${meal.imagePath.isEmpty}');
                    
                    return AppImage(
                      meal.imagePath,
                      width: 80,
                      height: 80,
                      borderRadius: BorderRadius.circular(12),
                      fallbackIcon: meal.icon,
                      fallbackBg: AppThemeV3.surfaceElevated,
                      fallbackIconColor: Colors.black,
                    );
                  },
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
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            if (_expandedDescriptions.contains(meal.id)) {
                              _expandedDescriptions.remove(meal.id);
                            } else {
                              _expandedDescriptions.add(meal.id);
                            }
                          });
                        },
                        child: AnimatedCrossFade(
                          firstChild: Text(
                            meal.description,
                            style: AppThemeV3.textTheme.bodyMedium?.copyWith(
                              color: AppThemeV3.textSecondary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          secondChild: Text(
                            meal.description,
                            style: AppThemeV3.textTheme.bodyMedium?.copyWith(
                              color: AppThemeV3.textSecondary,
                            ),
                            softWrap: true,
                          ),
                          crossFadeState: _expandedDescriptions.contains(meal.id)
                              ? CrossFadeState.showSecond
                              : CrossFadeState.showFirst,
                          duration: const Duration(milliseconds: 200),
                        ),
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
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.black,
                      width: 2,
                    ),
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
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _showMealInfo(meal),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black,
                  side: const BorderSide(color: Colors.black, width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(
                  'Meal Info',
                  style: AppThemeV3.textTheme.titleMedium?.copyWith(
                    color: Colors.black,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showMealInfo(MealModelV3 meal) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppThemeV3.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    meal.name,
                    style: AppThemeV3.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
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
            ),
          ),
        );
      },
    );
  }
}

extension StringExtension on String {
  String capitalizeFirst() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1).toLowerCase()}';
  }
}
