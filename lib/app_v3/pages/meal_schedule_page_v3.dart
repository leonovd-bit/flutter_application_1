import 'package:flutter/material.dart';
import '../theme/app_theme_v3.dart';
import '../models/meal_model_v3.dart';
import 'menu_page_v3.dart';
import 'payment_page_v3.dart';

class MealSchedulePageV3 extends StatefulWidget {
  final MealPlanModelV3 mealPlan;
  final Map<String, Map<String, dynamic>> weeklySchedule;
  
  const MealSchedulePageV3({
    super.key,
    required this.mealPlan,
    required this.weeklySchedule,
  });

  @override
  State<MealSchedulePageV3> createState() => _MealSchedulePageV3State();
}

class _MealSchedulePageV3State extends State<MealSchedulePageV3> {
  String _selectedSchedule = 'Schedule 1';
  String _selectedDay = 'Monday';
  String _selectedMealType = 'Breakfast';
  
  // Track selected meals for each day and meal type
  Map<String, Map<String, MealModelV3?>> _selectedMeals = {};
  
  final List<String> _daysOfWeek = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];

  @override
  void initState() {
    super.initState();
    _initializeSelectedMeals();
    _selectedMealType = _getAvailableMealTypes().first;
  }

  void _initializeSelectedMeals() {
    for (String day in _daysOfWeek) {
      _selectedMeals[day] = {};
      for (String mealType in _getAvailableMealTypes()) {
        _selectedMeals[day]![mealType] = null;
      }
    }
  }

  List<String> _getAvailableMealTypes() {
    switch (widget.mealPlan.mealsPerDay) {
      case 1:
        return ['Breakfast']; // Could be configurable to any meal
      case 2:
        return ['Breakfast', 'Lunch'];
      case 3:
        return ['Breakfast', 'Lunch', 'Dinner'];
      default:
        return ['Breakfast'];
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _getAvailableMealTypes().length,
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
            'Meal Schedule',
            style: AppThemeV3.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      body: Column(
        children: [
          // Schedule selector at top
          Container(
            color: AppThemeV3.surface,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedSchedule,
                    decoration: const InputDecoration(
                      hintText: 'Select Schedule',
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: ['Schedule 1', 'Schedule 2', 'Add Another Schedule']
                        .map((schedule) => DropdownMenuItem(
                              value: schedule,
                              child: Text(schedule),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedSchedule = value!;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          
          // Meal type tabs
          Container(
            color: AppThemeV3.surface,
            child: TabBar(
              tabs: _getAvailableMealTypes()
                  .map((mealType) => Tab(text: mealType))
                  .toList(),
              onTap: (index) {
                setState(() {
                  _selectedMealType = _getAvailableMealTypes()[index];
                });
              },
              labelColor: AppThemeV3.accent,
              unselectedLabelColor: AppThemeV3.textSecondary,
              indicatorColor: AppThemeV3.accent,
            ),
          ),
          
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Days of week for current meal type
                  Text(
                    'Select meals for $_selectedMealType',
                    style: AppThemeV3.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Days grid
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 3,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: _daysOfWeek.length,
                    itemBuilder: (context, index) {
                      final day = _daysOfWeek[index];
                      return _buildDayCard(day);
                    },
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Automatic selection options
                  Container(
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
                          'Quick Selection',
                          style: AppThemeV3.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _randomlySelectMealsForDay(_selectedDay),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppThemeV3.accent,
                                  side: const BorderSide(color: AppThemeV3.accent),
                                ),
                                child: const Text('Random Day'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _randomlySelectMealsForWeek(),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppThemeV3.accent,
                                  side: const BorderSide(color: AppThemeV3.accent),
                                ),
                                child: const Text('Random Week'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Selected meals display
                  if (_hasSelectedMealsForCurrentMealType()) ...[
                    Text(
                      'Selected ${_selectedMealType} Meals',
                      style: AppThemeV3.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._buildSelectedMealsList(),
                    const SizedBox(height: 24),
                  ],
                  
                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _saveMealsForDay,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppThemeV3.accent,
                            side: const BorderSide(color: AppThemeV3.accent),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('Save for Day'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _saveMealsForWeek,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppThemeV3.accent,
                            side: const BorderSide(color: AppThemeV3.accent),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('Save for Week'),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Fully customize meals button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _fullyCustomizeMeals,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppThemeV3.textSecondary,
                        side: const BorderSide(color: AppThemeV3.border),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Fully Customize Meals for Week'),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Proceed to payment button (show when week is complete)
                  if (_isWeekComplete()) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _proceedToPayment,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppThemeV3.accent,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Proceed to Payment',
                          style: AppThemeV3.textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildDayCard(String day) {
    final meal = _selectedMeals[day]![_selectedMealType];
    final hasSchedule = widget.weeklySchedule[day]?[_selectedMealType]?['time'] != null;
    
    return GestureDetector(
      onTap: hasSchedule ? () => _selectMealForDay(day) : null,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: meal != null 
              ? AppThemeV3.accent.withOpacity(0.1)
              : hasSchedule 
                  ? AppThemeV3.surface 
                  : AppThemeV3.surfaceElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: meal != null 
                ? AppThemeV3.accent 
                : hasSchedule 
                    ? AppThemeV3.border 
                    : AppThemeV3.borderLight,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                day.substring(0, 3), // Mon, Tue, etc.
                style: AppThemeV3.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: hasSchedule ? AppThemeV3.textPrimary : AppThemeV3.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 4),
            if (meal != null)
              Icon(
                Icons.check_circle,
                color: AppThemeV3.accent,
                size: 16,
              )
            else if (hasSchedule)
              Icon(
                Icons.restaurant_menu,
                color: AppThemeV3.textSecondary,
                size: 16,
              )
            else
              Icon(
                Icons.block,
                color: AppThemeV3.textSecondary,
                size: 16,
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSelectedMealsList() {
    List<Widget> widgets = [];
    
    for (String day in _daysOfWeek) {
      final meal = _selectedMeals[day]![_selectedMealType];
      if (meal != null) {
        widgets.add(
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppThemeV3.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppThemeV3.border),
            ),
            child: Row(
              children: [
                Text(
                  '$day: ',
                  style: AppThemeV3.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Expanded(
                  child: Text(
                    meal.name,
                    style: AppThemeV3.textTheme.bodyMedium,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: () => _removeMealForDay(day),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        );
      }
    }
    
    return widgets;
  }

  bool _hasSelectedMealsForCurrentMealType() {
    return _selectedMeals.values.any((dayMeals) => 
        dayMeals[_selectedMealType] != null);
  }

  bool _isWeekComplete() {
    // Check if all required meal slots are filled
    for (String day in _daysOfWeek) {
      for (String mealType in _getAvailableMealTypes()) {
        final hasSchedule = widget.weeklySchedule[day]?[mealType]?['time'] != null;
        final hasMeal = _selectedMeals[day]![mealType] != null;
        
        if (hasSchedule && !hasMeal) {
          return false;
        }
      }
    }
    return true;
  }

  void _selectMealForDay(String day) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MenuPageV3(menuType: _selectedMealType.toLowerCase()),
      ),
    ).then((selectedMeal) {
      if (selectedMeal != null && selectedMeal is MealModelV3) {
        setState(() {
          _selectedMeals[day]![_selectedMealType] = selectedMeal;
        });
      }
    });
  }

  void _removeMealForDay(String day) {
    setState(() {
      _selectedMeals[day]![_selectedMealType] = null;
    });
  }

  void _randomlySelectMealsForDay(String day) {
    final meals = _getSampleMealsForType(_selectedMealType);
    if (meals.isNotEmpty) {
      setState(() {
        _selectedMeals[day]![_selectedMealType] = meals.first;
      });
    }
  }

  void _randomlySelectMealsForWeek() {
    final meals = _getSampleMealsForType(_selectedMealType);
    
    for (String day in _daysOfWeek) {
      final hasSchedule = widget.weeklySchedule[day]?[_selectedMealType]?['time'] != null;
      if (hasSchedule && meals.isNotEmpty) {
        setState(() {
          _selectedMeals[day]![_selectedMealType] = meals[day.hashCode % meals.length];
        });
      }
    }
  }

  List<MealModelV3> _getSampleMealsForType(String mealType) {
    // Return sample meals for the meal type
    switch (mealType.toLowerCase()) {
      case 'breakfast':
        return [
          MealModelV3(
            id: '1',
            name: 'Avocado Toast',
            description: 'Healthy breakfast option',
            calories: 320,
            protein: 12,
            carbs: 35,
            fat: 18,
            ingredients: ['Avocado', 'Bread'],
            allergens: ['Gluten'],
            icon: Icons.breakfast_dining,
          ),
        ];
      case 'lunch':
        return [
          MealModelV3(
            id: '2',
            name: 'Quinoa Bowl',
            description: 'Nutritious lunch',
            calories: 420,
            protein: 16,
            carbs: 58,
            fat: 15,
            ingredients: ['Quinoa', 'Vegetables'],
            allergens: [],
            icon: Icons.lunch_dining,
          ),
        ];
      case 'dinner':
        return [
          MealModelV3(
            id: '3',
            name: 'Salmon Dinner',
            description: 'Protein-rich dinner',
            calories: 480,
            protein: 40,
            carbs: 18,
            fat: 28,
            ingredients: ['Salmon', 'Vegetables'],
            allergens: ['Fish'],
            icon: Icons.dinner_dining,
          ),
        ];
      default:
        return [];
    }
  }

  void _saveMealsForDay() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Meals saved for the day')),
    );
  }

  void _saveMealsForWeek() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Meals saved for the week')),
    );
  }

  void _fullyCustomizeMeals() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Full customization mode')),
    );
  }

  void _proceedToPayment() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentPageV3(
          mealPlan: widget.mealPlan,
          weeklySchedule: widget.weeklySchedule,
          selectedMeals: _selectedMeals,
        ),
      ),
    );
  }
}
