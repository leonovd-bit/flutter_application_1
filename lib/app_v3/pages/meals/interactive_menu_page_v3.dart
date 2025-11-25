import 'package:flutter/material.dart';
import '../../theme/app_theme_v3.dart';
import '../../models/meal_model_v3.dart';
import '../../services/meals/meal_service_v3.dart';
import '../../widgets/app_image.dart';
import 'customize_meal_page_v3.dart';
import '../../widgets/swipeable_page.dart';

class InteractiveMenuPageV3 extends StatefulWidget {
  final String menuType;
  final String day; // Which day we're selecting meals for
  final Function(MealModelV3) onMealSelected;
  final MealModelV3? selectedMeal; // Currently selected meal for this day/type
  final String? menuCategory; // 'premade' or 'custom' (optional filter)
  
  const InteractiveMenuPageV3({
    super.key, 
    required this.menuType,
    required this.day,
    required this.onMealSelected,
    this.selectedMeal,
    this.menuCategory,
  });

  @override
  State<InteractiveMenuPageV3> createState() => _InteractiveMenuPageV3State();
}

class _InteractiveMenuPageV3State extends State<InteractiveMenuPageV3> {
  String _selectedMealType = 'Breakfast';
  List<MealModelV3> _meals = [];
  bool _isLoading = true;
  // Track which meal descriptions are expanded (by meal id)
  final Set<String> _expandedDescriptions = <String>{};
  // Category toggle: 'premade' or 'custom'
  String _selectedCategory = 'premade';
  
  Widget _buildCategoryPill(String label, String value) {
    final isSelected = _selectedCategory == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_selectedCategory == value) return;
          setState(() {
            _selectedCategory = value;
            _isLoading = true;
          });
          _loadMeals();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppThemeV3.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSelected ? AppThemeV3.accent : AppThemeV3.border),
          ),
          child: Text(
            label,
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
  
  @override
  void initState() {
    super.initState();
    _selectedMealType = widget.menuType.capitalizeFirst();
    // Initialize category from caller if provided
    _selectedCategory = (widget.menuCategory == 'custom') ? 'custom' : 'premade';
    _loadMeals();
  }
  
  Future<void> _loadMeals() async {
    setState(() => _isLoading = true);
    
    try {
      debugPrint('[InteractiveMenu] Loading meals for ${_selectedMealType.toLowerCase()}, category: ${_selectedCategory}');
      
      final meals = await MealServiceV3.getMeals(
        mealType: _selectedMealType.toLowerCase(),
        menuCategory: _selectedCategory,
        limit: 50,
      );
      
      debugPrint('[InteractiveMenu] Loaded ${meals.length} meals from Firestore');
      
      // If Firestore returns empty, try local JSON as fallback
      List<MealModelV3> filtered = meals;
      if (filtered.isEmpty) {
        debugPrint('[InteractiveMenu] No meals from Firestore, trying local JSON');
        final local = await MealServiceV3.getMealsFromLocal(
          mealType: _selectedMealType.toLowerCase(),
          menuCategory: _selectedCategory,
          limit: 50,
        );
        if (local.isNotEmpty) {
          filtered = local;
          debugPrint('[InteractiveMenu] Loaded ${local.length} meals from local JSON');
        }
      }
      
      setState(() {
        _meals = filtered;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[InteractiveMenu] Error loading meals: $e');
      setState(() {
        _meals = [];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SwipeablePage(
      child: Scaffold(
        backgroundColor: AppThemeV3.background,
        appBar: AppBar(
          backgroundColor: AppThemeV3.surface,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        title: Text(
          '${_selectedCategory == 'custom' ? 'Customize' : 'Select'} ${widget.menuType.capitalizeFirst()} for ${widget.day}',
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

          // Category selector (Premade vs Custom)
          Container(
            color: AppThemeV3.surface,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                _buildCategoryPill('Premade', 'premade'),
                const SizedBox(width: 8),
                _buildCategoryPill('Custom', 'custom'),
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
                  _selectedCategory == 'custom'
                      ? '${_selectedMealType.toUpperCase()} • CUSTOMIZE'
                      : '${_selectedMealType.toUpperCase()} MENU',
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
                // Meal image
                AppImage(
                  meal.imagePath,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  borderRadius: BorderRadius.circular(12),
                  fallbackIcon: meal.icon,
                ),
                
                const SizedBox(width: 16),
                
                // Meal name, restaurant, and description
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
                      if ((meal.restaurant ?? '').isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.storefront, size: 14, color: AppThemeV3.textSecondary),
                            const SizedBox(width: 6),
                            Text(
                              meal.restaurant!,
                              style: AppThemeV3.textTheme.bodySmall?.copyWith(
                                color: AppThemeV3.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 4),
                      // Tappable description that expands/collapses
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
                
                // Price + Add/Check icon
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (meal.price > 0)
                      Text(
                        '\$${meal.price.toStringAsFixed(2)}',
                        style: AppThemeV3.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () async {
                        // If this is a custom base, open the customizer first.
                        final isCustom = (_selectedCategory == 'custom') || ((meal.menuCategory ?? '').toLowerCase() == 'custom');
                        if (isCustom) {
                          final result = await Navigator.push<MealModelV3>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CustomizeMealPageV3(baseMeal: meal),
                            ),
                          );
                          if (result != null) {
                            widget.onMealSelected(result);
                          }
                        } else {
                          // Premade: report selection directly
                          widget.onMealSelected(meal);
                        }
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
      isScrollControlled: true,
      backgroundColor: AppThemeV3.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final priceLine = meal.price > 0
            ? 'Price: \$${meal.price.toStringAsFixed(2)}'
            : '';
        final nutritionText =
            'Calories: ${meal.calories > 0 ? meal.calories : '-'}\n'
            'Protein: ${meal.protein > 0 ? meal.protein : '-'}g\n'
            'Carbs: ${meal.carbs > 0 ? meal.carbs : '-'}g\n'
            'Fat: ${meal.fat > 0 ? meal.fat : '-'}g\n'
            '$priceLine';
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
                    'Nutrition & Price',
                    style: AppThemeV3.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(nutritionText, style: AppThemeV3.textTheme.bodyMedium),
                  const SizedBox(height: 16),
                  if ((meal.restaurant ?? '').isNotEmpty) ...[
                    Text(
                      'Restaurant',
                      style: AppThemeV3.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(meal.restaurant!, style: AppThemeV3.textTheme.bodyMedium),
                    const SizedBox(height: 16),
                  ],
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
                    meal.allergens.isNotEmpty
                        ? meal.allergens.join(', ')
                        : 'No known allergens',
                    style: AppThemeV3.textTheme.bodyMedium?.copyWith(
                      color: meal.allergens.isNotEmpty
                          ? AppThemeV3.warning
                          : AppThemeV3.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
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
