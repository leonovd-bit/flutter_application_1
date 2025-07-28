import 'package:flutter/material.dart';
import '../theme/app_theme_v3.dart';
import '../models/meal_model_v3.dart';
import 'address_page_v3.dart';
import 'meal_schedule_page_v3.dart';

class DeliverySchedulePageV3 extends StatefulWidget {
  const DeliverySchedulePageV3({super.key});

  @override
  State<DeliverySchedulePageV3> createState() => _DeliverySchedulePageV3State();
}

class _DeliverySchedulePageV3State extends State<DeliverySchedulePageV3> {
  MealPlanModelV3? _selectedMealPlan;
  final List<MealPlanModelV3> _mealPlans = MealPlanModelV3.getAvailablePlans();
  
  // Schedule data
  Map<String, Map<String, dynamic>> _weeklySchedule = {};
  final List<String> _daysOfWeek = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];
  final List<String> _mealTypes = ['Breakfast', 'Lunch', 'Dinner'];

  @override
  void initState() {
    super.initState();
    _initializeSchedule();
  }

  void _initializeSchedule() {
    for (String day in _daysOfWeek) {
      _weeklySchedule[day] = {};
      for (String mealType in _mealTypes) {
        _weeklySchedule[day]![mealType] = {
          'time': null,
          'address': null,
          'enabled': false,
        };
      }
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
          'Subscription Setup',
          style: AppThemeV3.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Select Meal Plan Section
            Text(
              'Select Meal Plan',
              style: AppThemeV3.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            
            // Meal Plan Options
            Row(
              children: _mealPlans.map((plan) => Expanded(
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: _buildMealPlanCard(plan),
                ),
              )).toList(),
            ),
            
            const SizedBox(height: 32),
            
            // Delivery Schedule Section (only show if meal plan is selected)
            if (_selectedMealPlan != null) ...[
              Text(
                'Customize weekly delivery schedule',
                style: AppThemeV3.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              
              // Schedule Configuration
              ..._buildScheduleConfiguration(),
              
              const SizedBox(height: 32),
              
              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saveSchedule,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppThemeV3.accent,
                        side: const BorderSide(color: AppThemeV3.accent),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Save',
                        style: AppThemeV3.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _addAnotherSchedule,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppThemeV3.textSecondary,
                        side: const BorderSide(color: AppThemeV3.border),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Add Another',
                        style: AppThemeV3.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Go to Meal Schedule Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isScheduleComplete() ? _goToMealSchedule : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppThemeV3.accent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Go to Meal Schedule',
                    style: AppThemeV3.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Skip for Now Button (Development Bypass)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _skipDeliverySchedule,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: AppThemeV3.accent),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Skip for Now (Auto-fill Default)',
                    style: AppThemeV3.textTheme.titleMedium?.copyWith(
                      color: AppThemeV3.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMealPlanCard(MealPlanModelV3 plan) {
    final isSelected = _selectedMealPlan?.id == plan.id;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedMealPlan = plan;
          _updateScheduleForMealPlan(plan);
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppThemeV3.accent.withOpacity(0.1) : AppThemeV3.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppThemeV3.accent : AppThemeV3.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected ? AppThemeV3.accent : AppThemeV3.surfaceElevated,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  plan.mealsPerDay.toString(),
                  style: AppThemeV3.textTheme.headlineSmall?.copyWith(
                    color: isSelected ? Colors.white : AppThemeV3.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'meal/day',
              style: AppThemeV3.textTheme.bodySmall?.copyWith(
                color: AppThemeV3.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildScheduleConfiguration() {
    List<Widget> widgets = [];
    
    for (String day in _daysOfWeek) {
      widgets.add(_buildDayConfiguration(day));
      widgets.add(const SizedBox(height: 16));
    }
    
    return widgets;
  }

  Widget _buildDayConfiguration(String day) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppThemeV3.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppThemeV3.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day header with expand/collapse
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                day,
                style: AppThemeV3.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down,
                color: AppThemeV3.textSecondary,
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Meal configurations for this day
          ...(_getAvailableMealTypes().map((mealType) => 
            _buildMealConfiguration(day, mealType)
          ).toList()),
        ],
      ),
    );
  }

  Widget _buildMealConfiguration(String day, String mealType) {
    final mealData = _weeklySchedule[day]![mealType];
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppThemeV3.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppThemeV3.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$mealType of the day',
            style: AppThemeV3.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          
          // Time selection
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _selectTime(day, mealType),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppThemeV3.border),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          mealData['time'] != null 
                              ? mealData['time'].format(context)
                              : 'Time',
                          style: AppThemeV3.textTheme.bodyMedium?.copyWith(
                            color: mealData['time'] != null 
                                ? AppThemeV3.textPrimary 
                                : AppThemeV3.textSecondary,
                          ),
                        ),
                        Icon(
                          Icons.access_time,
                          size: 16,
                          color: AppThemeV3.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // Address selection
          GestureDetector(
            onTap: () => _selectAddress(day, mealType),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: AppThemeV3.border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      mealData['address'] != null 
                          ? mealData['address']
                          : 'Place/Address',
                      style: AppThemeV3.textTheme.bodyMedium?.copyWith(
                        color: mealData['address'] != null 
                            ? AppThemeV3.textPrimary 
                            : AppThemeV3.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    Icons.location_on,
                    size: 16,
                    color: AppThemeV3.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _getAvailableMealTypes() {
    if (_selectedMealPlan == null) return [];
    
    switch (_selectedMealPlan!.mealsPerDay) {
      case 1:
        return ['Breakfast']; // User can choose which meal they want
      case 2:
        return ['Breakfast', 'Lunch']; // User can choose which 2 meals
      case 3:
        return ['Breakfast', 'Lunch', 'Dinner'];
      default:
        return [];
    }
  }

  void _updateScheduleForMealPlan(MealPlanModelV3 plan) {
    // Reset schedule when meal plan changes
    _initializeSchedule();
  }

  Future<void> _selectTime(String day, String mealType) async {
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    
    if (time != null) {
      setState(() {
        _weeklySchedule[day]![mealType]['time'] = time;
        _weeklySchedule[day]![mealType]['enabled'] = true;
      });
    }
  }

  Future<void> _selectAddress(String day, String mealType) async {
    final String? address = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => const AddressPageV3(),
      ),
    );
    
    if (address != null) {
      setState(() {
        _weeklySchedule[day]![mealType]['address'] = address;
      });
    }
  }

  void _saveSchedule() {
    // Save current schedule
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Schedule saved successfully'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _addAnotherSchedule() {
    // Add another schedule configuration
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Add another schedule functionality'),
      ),
    );
  }

  bool _isScheduleComplete() {
    if (_selectedMealPlan == null) return false;
    
    // Check if at least one meal is configured for at least one day
    for (String day in _daysOfWeek) {
      for (String mealType in _getAvailableMealTypes()) {
        final mealData = _weeklySchedule[day]![mealType];
        if (mealData['time'] != null && mealData['address'] != null) {
          return true;
        }
      }
    }
    return false;
  }

  void _goToMealSchedule() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MealSchedulePageV3(
          mealPlan: _selectedMealPlan!,
          weeklySchedule: _weeklySchedule,
        ),
      ),
    );
  }

  void _skipDeliverySchedule() {
    // Auto-fill with default schedule for bypass
    setState(() {
      // Set default to NutritiousJr plan (first available plan)
      _selectedMealPlan = _mealPlans.isNotEmpty ? _mealPlans.first : null;
      
      // Set default schedule for Monday-Friday lunch
      for (String day in ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday']) {
        _weeklySchedule[day]!['lunch'] = {
          'time': const TimeOfDay(hour: 12, minute: 0), // Default 12:00 PM
          'address': '123 Main Street, New York, NY 10001', // Default address
          'enabled': true,
        };
      }
    });

    // Navigate to meal schedule immediately
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MealSchedulePageV3(
          mealPlan: _selectedMealPlan!,
          weeklySchedule: _weeklySchedule,
        ),
      ),
    );
  }
}
