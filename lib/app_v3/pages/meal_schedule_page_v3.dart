import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../theme/app_theme_v3.dart';
import '../models/meal_model_v3.dart';
import 'menu_page_v3.dart';
import 'payment_page_v3.dart';
import 'delivery_schedule_page_v3.dart';

class MealSchedulePageV3 extends StatefulWidget {
  final MealPlanModelV3? mealPlan;
  final Map<String, Map<String, dynamic>>? weeklySchedule;
  final String? initialScheduleName;
  
  const MealSchedulePageV3({
    super.key,
    this.mealPlan,
    this.weeklySchedule,
    this.initialScheduleName,
  });

  @override
  State<MealSchedulePageV3> createState() => _MealSchedulePageV3State();
}

class _MealSchedulePageV3State extends State<MealSchedulePageV3> {
  String? _selectedSchedule;
  String _selectedMealType = 'Breakfast';
  List<String> _availableSchedules = [];
  
  // Current schedule data
  MealPlanModelV3? _currentMealPlan;
  Map<String, Map<String, dynamic>> _currentWeeklySchedule = {};
  List<String> _currentMealTypes = [];
  
  // Track selected meals for each day and meal type
  Map<String, Map<String, MealModelV3?>> _selectedMeals = {};
  
  // Get configured days from the current weekly schedule
  List<String> get _configuredDays => _currentWeeklySchedule.keys.toList()..sort();

  @override
  void initState() {
    super.initState();
    _loadAvailableSchedules();
    
    // Initialize with provided data if available
    if (widget.mealPlan != null && widget.weeklySchedule != null) {
      _currentMealPlan = widget.mealPlan;
      _currentWeeklySchedule = widget.weeklySchedule!;
      _currentMealTypes = _getAvailableMealTypes();
      _selectedSchedule = widget.initialScheduleName;
      
      _initializeSelectedMeals();
      if (_currentMealTypes.isNotEmpty) {
        _selectedMealType = _currentMealTypes.first;
      }
    }
  }

  Future<void> _loadAvailableSchedules() async {
    final prefs = await SharedPreferences.getInstance();
    final savedSchedules = prefs.getStringList('saved_schedules') ?? [];
    setState(() {
      _availableSchedules = savedSchedules;
      if (_selectedSchedule == null && _availableSchedules.isNotEmpty) {
        _selectedSchedule = _availableSchedules.first;
        _loadScheduleData(_selectedSchedule!);
      }
    });
  }

  Future<void> _loadScheduleData(String scheduleName) async {
    final prefs = await SharedPreferences.getInstance();
    final scheduleJson = prefs.getString('delivery_schedule_$scheduleName');
    
    if (scheduleJson != null) {
      final scheduleData = json.decode(scheduleJson);
      
      // Find the meal plan
      final mealPlanId = scheduleData['mealPlanId'] as String;
      final availablePlans = MealPlanModelV3.getAvailablePlans();
      _currentMealPlan = availablePlans.firstWhere((plan) => plan.id == mealPlanId);
      
      // Load meal types
      _currentMealTypes = List<String>.from(scheduleData['selectedMealTypes']);
      
      // Parse weekly schedule
      _currentWeeklySchedule = {};
      final weeklyScheduleData = scheduleData['weeklySchedule'] as Map<String, dynamic>;
      for (String day in weeklyScheduleData.keys) {
        _currentWeeklySchedule[day] = {};
        final dayData = weeklyScheduleData[day] as Map<String, dynamic>;
        for (String mealType in dayData.keys) {
          _currentWeeklySchedule[day]![mealType] = {
            'time': dayData[mealType]['time'],
            'address': dayData[mealType]['address'],
            'enabled': true,
          };
        }
      }
      
      _initializeSelectedMeals();
      if (_currentMealTypes.isNotEmpty) {
        _selectedMealType = _currentMealTypes.first;
      }
      
      setState(() {});
    }
  }

  void _initializeSelectedMeals() {
    _selectedMeals.clear();
    for (String day in _configuredDays) {
      _selectedMeals[day] = {};
      for (String mealType in _currentMealTypes) {
        _selectedMeals[day]![mealType] = null;
      }
    }
  }

  List<String> _getAvailableMealTypes() {
    if (_currentMealPlan == null) return [];
    
    switch (_currentMealPlan!.mealsPerDay) {
      case 1:
        return _currentMealTypes.isNotEmpty ? _currentMealTypes : ['Breakfast'];
      case 2:
        return _currentMealTypes.isNotEmpty ? _currentMealTypes : ['Breakfast', 'Lunch'];
      case 3:
        return _currentMealTypes.isNotEmpty ? _currentMealTypes : ['Breakfast', 'Lunch', 'Dinner'];
      default:
        return _currentMealTypes.isNotEmpty ? _currentMealTypes : ['Breakfast'];
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
                    items: [
                      ..._availableSchedules.map((schedule) => DropdownMenuItem(
                        value: schedule,
                        child: Text(schedule),
                      )),
                      const DropdownMenuItem(
                        value: 'add_another',
                        child: Text('Add Another Schedule'),
                      ),
                    ],
                    onChanged: (value) async {
                      if (value == 'add_another') {
                        Navigator.push(
                          context, 
                          MaterialPageRoute(
                            builder: (context) => const DeliverySchedulePageV3(),
                          ),
                        );
                      } else if (value != null) {
                        setState(() {
                          _selectedSchedule = value;
                        });
                        await _loadScheduleData(value);
                      }
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
                  // Show configured days for current meal type
                  Text(
                    'Select meals for $_selectedMealType',
                    style: AppThemeV3.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Show configured days info
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppThemeV3.accent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppThemeV3.accent.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Configured days: ${_configuredDays.join(', ')}',
                          style: TextStyle(
                            color: AppThemeV3.accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Select meals for each day below:',
                          style: TextStyle(
                            color: AppThemeV3.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Configured days list for meal selection
                  ..._configuredDays.map((day) => _buildDayMealSelector(day)),
                  
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
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => _randomlySelectMealsForMealType(_selectedMealType),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppThemeV3.accent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text('Random $_selectedMealType Meals for All Days'),
                          ),
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

  List<Widget> _buildSelectedMealsList() {
    List<Widget> widgets = [];
    
    for (String day in _configuredDays) {
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
    for (String day in _configuredDays) {
      for (String mealType in _getAvailableMealTypes()) {
        final hasSchedule = _currentWeeklySchedule[day]?[mealType]?['time'] != null;
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
          mealPlan: _currentMealPlan!,
          weeklySchedule: _currentWeeklySchedule,
          selectedMeals: _selectedMeals,
        ),
      ),
    );
  }

  Widget _buildDayMealSelector(String day) {
    final selectedMeal = _selectedMeals[day]?[_selectedMealType];
    final scheduleInfo = _currentWeeklySchedule[day]?[_selectedMealType];
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppThemeV3.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppThemeV3.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                day,
                style: AppThemeV3.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (scheduleInfo != null) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Time: ${(scheduleInfo['time'] as TimeOfDay?)?.format(context) ?? 'Not set'}',
                      style: AppThemeV3.textTheme.bodySmall?.copyWith(
                        color: AppThemeV3.textSecondary,
                      ),
                    ),
                    Text(
                      'Address: ${scheduleInfo['address'] ?? 'Not set'}',
                      style: AppThemeV3.textTheme.bodySmall?.copyWith(
                        color: AppThemeV3.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          
          // Meal selection for this day
          if (selectedMeal != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppThemeV3.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppThemeV3.accent.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      selectedMeal.imageUrl,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selectedMeal.name,
                          style: AppThemeV3.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          selectedMeal.description,
                          style: AppThemeV3.textTheme.bodySmall?.copyWith(
                            color: AppThemeV3.textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _clearMealForDay(day),
                    icon: const Icon(Icons.close, color: Colors.red),
                  ),
                ],
              ),
            ),
          ] else ...[
            OutlinedButton(
              onPressed: () => _selectMealForDay(day),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppThemeV3.accent,
                side: const BorderSide(color: AppThemeV3.accent),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add),
                  const SizedBox(width: 8),
                  Text('Select $_selectedMealType'),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _clearMealForDay(String day) {
    setState(() {
      _selectedMeals[day]![_selectedMealType] = null;
    });
  }

  void _randomlySelectMealsForMealType(String mealType) {
    final availableMeals = _getSampleMealsForType(mealType);
    if (availableMeals.isEmpty) return;

    setState(() {
      for (String day in _configuredDays) {
        final randomIndex = DateTime.now().millisecondsSinceEpoch % availableMeals.length;
        final randomMeal = availableMeals[randomIndex];
        _selectedMeals[day]![mealType] = randomMeal;
        // Add small delay to get different random selections
        Future.delayed(const Duration(milliseconds: 10));
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Random $mealType meals selected for all configured days!')),
    );
  }

}
