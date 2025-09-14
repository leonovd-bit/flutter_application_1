import 'package:flutter/material.dart';
import '../theme/app_theme_v3.dart';
import '../models/meal_model_v3.dart';
import '../services/meal_service_v3.dart';

class InteractiveMenuPageV3 extends StatefulWidget {
  final String menuType;
  final String day; // Which day we're selecting meals for
  final Function(MealModelV3) onMealSelected;
  final MealModelV3? selectedMeal; // Currently selected meal for this day/type
  
  const InteractiveMenuPageV3({
    super.key, 
    required this.menuType,
    required this.day,
    required this.onMealSelected,
    this.selectedMeal,
  });

  @override
  State<InteractiveMenuPageV3> createState() => _InteractiveMenuPageV3State();
}

class _InteractiveMenuPageV3State extends State<InteractiveMenuPageV3> {
  String _selectedMealType = 'Breakfast';
  List<MealModelV3> _meals = [];
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _selectedMealType = widget.menuType.capitalizeFirst();
    _loadMeals();
  }
  
  Future<void> _loadMeals() async {
    try {
      final meals = await MealServiceV3.getMeals(
        mealType: _selectedMealType.toLowerCase(),
        limit: 50,
      );
      setState(() {
        _meals = meals;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading meals: $e');
      setState(() {
        _meals = [];
        _isLoading = false;
      });
    }
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
          'Select ${widget.menuType.capitalizeFirst()} for ${widget.day}',
          style: AppThemeV3.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
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
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _meals.isEmpty
                    ? const Center(
                        child: Text(
                          'No meals available for this type',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _meals.length,
                        itemBuilder: (context, index) {
                          final meal = _meals[index];
                          final isSelected = widget.selectedMeal?.id == meal.id;
                          return _buildInteractiveMealCard(meal, isSelected);
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
            _isLoading = true;
          });
          _loadMeals();
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

  Widget _buildInteractiveMealCard(MealModelV3 meal, bool isSelected) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppThemeV3.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? AppThemeV3.accent : AppThemeV3.border,
          width: isSelected ? 2 : 1,
        ),
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
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppThemeV3.surfaceElevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppThemeV3.border),
                  ),
                  child: Icon(
                    meal.icon,
                    size: 40,
                    color: AppThemeV3.accent,
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
                
                // Add/Check icon
                GestureDetector(
                  onTap: () {
                    // Report selection to the parent; the parent decides when/if to pop.
                    widget.onMealSelected(meal);
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.green : AppThemeV3.accent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isSelected ? Icons.check : Icons.add,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Meal Info button
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
                meal.allergens.isNotEmpty 
                    ? meal.allergens.join(', ')
                    : 'No known allergens',
                style: AppThemeV3.textTheme.bodyMedium?.copyWith(
                  color: meal.allergens.isNotEmpty ? AppThemeV3.warning : AppThemeV3.textSecondary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }


}

// Extension to capitalize first letter
extension StringExtension on String {
  String capitalizeFirst() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1).toLowerCase()}';
  }
}
