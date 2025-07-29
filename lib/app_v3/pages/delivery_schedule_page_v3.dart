import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
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
  
  // Schedule management
  String _scheduleName = '';
  final TextEditingController _scheduleNameController = TextEditingController();
  
  // Available options
  final List<String> _daysOfWeek = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];
  final List<String> _allMealTypes = ['Breakfast', 'Lunch', 'Dinner'];
  
  // Mock saved addresses - in real app, load from storage
  List<Map<String, String>> _savedAddresses = [
    {'name': 'Home', 'address': '123 Main St, New York, NY 10001'},
    {'name': 'Work', 'address': '456 Business Ave, New York, NY 10002'},
  ];
  
  // For meal type selection (when plan has fewer than 3 meals)
  Set<String> _selectedMealTypes = {};
  
  // Complete weekly schedule: Map<Day, Map<MealType, {time, address}>>
  Map<String, Map<String, Map<String, dynamic>>> _weeklySchedule = {};
  
  // New UI state for multi-select dropdown and inline expansion
  Set<String> _selectedDaysForCustomization = {};
  bool _showDayCustomization = false;
  String _selectedMealTypeTab = 'Breakfast';
  
  Set<String> _unconfiguredDays = {};
  
  @override
  void initState() {
    super.initState();
    _initializeDefaults();
  }
  
  @override
  void dispose() {
    _scheduleNameController.dispose();
    super.dispose();
  }
  
  void _initializeDefaults() {
    // Set default schedule name
    _scheduleName = 'Schedule ${DateTime.now().millisecondsSinceEpoch % 1000}';
    _scheduleNameController.text = _scheduleName;
    
    // Initialize all days as unconfigured
    _unconfiguredDays = _daysOfWeek.toSet();
    
    // Set default meal type tab to first available meal type
    if (_allMealTypes.isNotEmpty) {
      _selectedMealTypeTab = _allMealTypes.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeV3.background,
      appBar: AppBar(
        backgroundColor: AppThemeV3.surface,
        elevation: 8,
        shadowColor: Colors.black.withOpacity(0.1),
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppThemeV3.accent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: Icon(Icons.arrow_back, color: AppThemeV3.accent),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: Text(
          'Delivery Schedule',
          style: AppThemeV3.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: AppThemeV3.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppThemeV3.background,
              AppThemeV3.background.withOpacity(0.95),
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Select Meal Plan Section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppThemeV3.accent.withOpacity(0.05),
                      AppThemeV3.accent.withOpacity(0.02),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppThemeV3.accent.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppThemeV3.accent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.restaurant_menu,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Select Meal Plan',
                          style: AppThemeV3.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppThemeV3.textPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Choose how many meals you want delivered per day',
                      style: AppThemeV3.textTheme.bodyMedium?.copyWith(
                        color: AppThemeV3.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
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
            
            // Schedule Name Section
            if (_selectedMealPlan != null) ...[
              Text(
                'Schedule Name',
                style: AppThemeV3.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              
              TextField(
                controller: _scheduleNameController,
                decoration: InputDecoration(
                  hintText: 'Enter schedule name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppThemeV3.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppThemeV3.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppThemeV3.accent),
                  ),
                ),
                onChanged: (value) {
                  _scheduleName = value;
                },
              ),
              
              const SizedBox(height: 32),
              
              // Meal Type Selection (for plans with fewer than 3 meals)
              if (_selectedMealPlan!.mealsPerDay < 3) ...[
                Text(
                  'Select Meal Types (${_selectedMealPlan!.mealsPerDay} meal${_selectedMealPlan!.mealsPerDay > 1 ? 's' : ''})',
                  style: AppThemeV3.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                
                _buildMealTypeSelection(),
                
                const SizedBox(height: 32),
              ],
              
              // Day Selection Section with Multi-Select Dropdown
              Text(
                'Weekly Schedule Setup',
                style: AppThemeV3.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              
              _buildMultiSelectDaysDropdown(),
              
              const SizedBox(height: 16),
              
              // Show configured days as tags
              if (_getConfiguredDays().isNotEmpty) ...[
                Text(
                  'Configured Days',
                  style: AppThemeV3.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                _buildConfiguredDaysTags(),
                const SizedBox(height: 16),
              ],
              
              // Inline expansion for day customization
              if (_showDayCustomization && _selectedDaysForCustomization.isNotEmpty) ...[
                _buildInlineCustomization(),
                const SizedBox(height: 16),
              ],
              
              const SizedBox(height: 32),
              
              // Action Buttons
              if (_selectedMealPlan != null && 
                  (_selectedMealPlan!.mealsPerDay >= 3 || _selectedMealTypes.isNotEmpty)) ...[
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppThemeV3.surface,
                        AppThemeV3.surface.withOpacity(0.95),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppThemeV3.border.withOpacity(0.5),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: _canContinueToMeals() ? [
                                  BoxShadow(
                                    color: AppThemeV3.accent.withOpacity(0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ] : [],
                              ),
                              child: ElevatedButton(
                                onPressed: _canContinueToMeals() ? _saveSchedule : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _canContinueToMeals() ? AppThemeV3.accent : Colors.grey.shade300,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 18),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: _canContinueToMeals() ? 8 : 0,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.save,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Save Schedule',
                                      style: AppThemeV3.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: _canContinueToMeals() ? [
                                  BoxShadow(
                                    color: AppThemeV3.accent.withOpacity(0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ] : [],
                              ),
                              child: OutlinedButton(
                                onPressed: _canContinueToMeals() ? _continueToMealSelection : null,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _canContinueToMeals() ? AppThemeV3.accent : Colors.grey,
                                  side: BorderSide(
                                    color: _canContinueToMeals() ? AppThemeV3.accent : Colors.grey,
                                    width: 2,
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 18),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.arrow_forward,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Continue',
                                      style: AppThemeV3.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Add New Schedule button (only show when current schedule is complete)
                      if (_canContinueToMeals()) ...[
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppThemeV3.accent.withOpacity(0.1),
                                AppThemeV3.accent.withOpacity(0.05),
                              ],
                            ),
                          ),
                          child: SizedBox(
                            width: double.infinity,
                            child: TextButton(
                              onPressed: _addNewSchedule,
                              style: TextButton.styleFrom(
                                foregroundColor: AppThemeV3.accent,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_circle_outline,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Add New Schedule',
                                    style: AppThemeV3.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                
                // Validation message
                if (!_canContinueToMeals()) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.orange.withOpacity(0.1),
                          Colors.orange.withOpacity(0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.orange.withOpacity(0.4),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.warning_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Configuration Required',
                                style: TextStyle(
                                  color: Colors.orange.shade800,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Please configure all 7 days before continuing.\nMissing: ${_unconfiguredDays.join(', ')}',
                                style: TextStyle(
                                  color: Colors.orange.shade700,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ],
          ],
        ),
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? AppThemeV3.accent.withOpacity(0.1) : AppThemeV3.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppThemeV3.accent : AppThemeV3.border,
            width: isSelected ? 3 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected 
                  ? AppThemeV3.accent.withOpacity(0.2) 
                  : Colors.black.withOpacity(0.05),
              blurRadius: isSelected ? 12 : 8,
              offset: const Offset(0, 4),
              spreadRadius: isSelected ? 2 : 0,
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isSelected 
                      ? [AppThemeV3.accent, AppThemeV3.accent.withOpacity(0.8)]
                      : [AppThemeV3.surfaceElevated, AppThemeV3.surfaceElevated.withOpacity(0.9)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: isSelected 
                        ? AppThemeV3.accent.withOpacity(0.3) 
                        : Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  plan.mealsPerDay.toString(),
                  style: AppThemeV3.textTheme.headlineSmall?.copyWith(
                    color: isSelected ? Colors.white : AppThemeV3.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 24,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'meal/day',
              style: AppThemeV3.textTheme.bodyMedium?.copyWith(
                color: isSelected ? AppThemeV3.accent : AppThemeV3.textSecondary,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppThemeV3.accent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'SELECTED',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _updateScheduleForMealPlan(MealPlanModelV3 plan) {
    // Reset all schedule data when meal plan changes
    _weeklySchedule.clear();
    _selectedMealTypes.clear();
    _unconfiguredDays = _daysOfWeek.toSet();
    _selectedDaysForCustomization.clear();
    _showDayCustomization = false;
    _tempTime = null;
    _tempAddress = null;
    
    // Auto-select meal types if plan has 3 meals
    if (plan.mealsPerDay >= 3) {
      _selectedMealTypes = _allMealTypes.toSet();
    }
    
    // Set default meal type tab
    if (_selectedMealTypes.isNotEmpty) {
      _selectedMealTypeTab = _selectedMealTypes.first;
    } else if (_allMealTypes.isNotEmpty) {
      _selectedMealTypeTab = _allMealTypes.first;
    }
  }

  Widget _buildMealTypeSelection() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: _allMealTypes.map((mealType) {
        final isSelected = _selectedMealTypes.contains(mealType);
        return FilterChip(
          label: Text(mealType),
          selected: isSelected,
          onSelected: _selectedMealTypes.length < _selectedMealPlan!.mealsPerDay || isSelected
              ? (selected) {
                  setState(() {
                    if (selected) {
                      if (_selectedMealTypes.length < _selectedMealPlan!.mealsPerDay) {
                        _selectedMealTypes.add(mealType);
                      }
                    } else {
                      _selectedMealTypes.remove(mealType);
                    }
                    
                    // Update the selected tab if necessary
                    if (_selectedMealTypes.isNotEmpty && !_selectedMealTypes.contains(_selectedMealTypeTab)) {
                      _selectedMealTypeTab = _selectedMealTypes.first;
                    }
                  });
                }
              : null,
          selectedColor: AppThemeV3.accent.withOpacity(0.2),
          checkmarkColor: AppThemeV3.accent,
          labelStyle: TextStyle(
            color: isSelected ? AppThemeV3.accent : AppThemeV3.textPrimary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMultiSelectDaysDropdown() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppThemeV3.surface,
            AppThemeV3.surface.withOpacity(0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppThemeV3.accent.withOpacity(0.2),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppThemeV3.accent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.calendar_today,
                      color: AppThemeV3.accent,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Select days to customize:',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: AppThemeV3.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _showDayCustomization 
                      ? AppThemeV3.accent 
                      : AppThemeV3.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppThemeV3.accent,
                    width: 2,
                  ),
                ),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _showDayCustomization = !_showDayCustomization;
                    });
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _showDayCustomization ? Icons.expand_less : Icons.expand_more,
                        color: _showDayCustomization ? Colors.white : AppThemeV3.accent,
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _showDayCustomization ? 'Hide' : 'Customize',
                        style: TextStyle(
                          color: _showDayCustomization ? Colors.white : AppThemeV3.accent,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _daysOfWeek.map((day) {
              final isSelected = _selectedDaysForCustomization.contains(day);
              final isConfigured = _weeklySchedule.containsKey(day);
              
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: isSelected 
                          ? AppThemeV3.accent.withOpacity(0.3)
                          : Colors.black.withOpacity(0.05),
                      blurRadius: isSelected ? 8 : 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: FilterChip(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        day.substring(0, 3),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      if (isConfigured) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: AppThemeV3.accent,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.check,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ],
                  ),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedDaysForCustomization.add(day);
                      } else {
                        _selectedDaysForCustomization.remove(day);
                      }
                    });
                  },
                  selectedColor: AppThemeV3.accent.withOpacity(0.2),
                  backgroundColor: isConfigured 
                      ? AppThemeV3.accent.withOpacity(0.1) 
                      : AppThemeV3.background,
                  checkmarkColor: AppThemeV3.accent,
                  side: BorderSide(
                    color: isSelected 
                        ? AppThemeV3.accent 
                        : (isConfigured ? AppThemeV3.accent.withOpacity(0.3) : AppThemeV3.border),
                    width: isSelected ? 2 : 1,
                  ),
                  labelStyle: TextStyle(
                    color: isSelected ? AppThemeV3.accent : AppThemeV3.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  List<String> _getConfiguredDays() {
    return _weeklySchedule.keys.toList()..sort((a, b) {
      return _daysOfWeek.indexOf(a).compareTo(_daysOfWeek.indexOf(b));
    });
  }

  Widget _buildConfiguredDaysTags() {
    final configuredDays = _getConfiguredDays();
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppThemeV3.accent.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppThemeV3.accent.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppThemeV3.accent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.check_circle,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Configured Days',
                style: AppThemeV3.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppThemeV3.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: configuredDays.map((day) {
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: AppThemeV3.accent.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppThemeV3.accent.withOpacity(0.15),
                        AppThemeV3.accent.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: AppThemeV3.accent.withOpacity(0.4),
                      width: 2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        day,
                        style: TextStyle(
                          color: AppThemeV3.accent,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppThemeV3.accent.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: GestureDetector(
                          onTap: () => _editDay(day),
                          child: Icon(
                            Icons.edit,
                            size: 16,
                            color: AppThemeV3.accent,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: GestureDetector(
                          onTap: () => _removeDay(day),
                          child: Icon(
                            Icons.close,
                            size: 16,
                            color: Colors.red.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineCustomization() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppThemeV3.surfaceElevated,
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
                'Customize Selected Days',
                style: AppThemeV3.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _showDayCustomization = false;
                  });
                },
                child: Text(
                  'Done',
                  style: TextStyle(color: AppThemeV3.accent),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Horizontal tabs for meal types
          _buildMealTypeTabs(),
          
          const SizedBox(height: 16),
          
          // Configuration for selected meal type
          _buildMealTypeConfiguration(),
          
          const SizedBox(height: 16),
          
          // Apply configuration button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _applyConfigurationToSelectedDays,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppThemeV3.accent,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(
                'Apply to ${_selectedDaysForCustomization.length} day${_selectedDaysForCustomization.length != 1 ? 's' : ''}',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealTypeTabs() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: AppThemeV3.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppThemeV3.border),
      ),
      child: Row(
        children: _selectedMealTypes.map((mealType) {
          final isSelected = _selectedMealTypeTab == mealType;
          
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedMealTypeTab = mealType;
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected ? AppThemeV3.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    mealType,
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppThemeV3.textPrimary,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMealTypeConfiguration() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Time Selection
        Text(
          'Delivery Time',
          style: AppThemeV3.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _selectTimeForMealType(_selectedMealTypeTab),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: AppThemeV3.border),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _getSelectedTimeForMealType(_selectedMealTypeTab) != null 
                      ? _getSelectedTimeForMealType(_selectedMealTypeTab)!.format(context)
                      : 'Select time',
                  style: AppThemeV3.textTheme.bodyMedium?.copyWith(
                    color: _getSelectedTimeForMealType(_selectedMealTypeTab) != null 
                        ? AppThemeV3.textPrimary 
                        : AppThemeV3.textSecondary,
                  ),
                ),
                const Icon(
                  Icons.access_time,
                  size: 18,
                  color: AppThemeV3.textSecondary,
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Address Selection
        Text(
          'Delivery Address',
          style: AppThemeV3.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        _buildAddressDropdownForMealType(_selectedMealTypeTab),
      ],
    );
  }

  // Temporary storage for inline customization
  TimeOfDay? _tempTime;
  String? _tempAddress;

  void _editDay(String day) {
    setState(() {
      _selectedDaysForCustomization.clear();
      _selectedDaysForCustomization.add(day);
      _showDayCustomization = true;
      // Load existing configuration for this day
      _loadExistingConfigForDay(day);
    });
  }

  void _removeDay(String day) {
    setState(() {
      _weeklySchedule.remove(day);
      _unconfiguredDays.add(day);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Removed configuration for $day')),
    );
  }

  void _loadExistingConfigForDay(String day) {
    final dayConfig = _weeklySchedule[day];
    if (dayConfig != null && dayConfig.containsKey(_selectedMealTypeTab)) {
      _tempTime = dayConfig[_selectedMealTypeTab]?['time'];
      _tempAddress = dayConfig[_selectedMealTypeTab]?['address'];
    } else {
      _tempTime = null;
      _tempAddress = null;
    }
  }

  TimeOfDay? _getSelectedTimeForMealType(String mealType) {
    return _tempTime;
  }

  void _selectTimeForMealType(String mealType) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        height: 300,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Select $mealType time',
              style: AppThemeV3.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                initialDateTime: DateTime.now(),
                onDateTimeChanged: (DateTime newTime) {
                  setState(() {
                    _tempTime = TimeOfDay.fromDateTime(newTime);
                  });
                },
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppThemeV3.accent,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text(
                  'Done',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressDropdownForMealType(String mealType) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        border: Border.all(color: AppThemeV3.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _tempAddress,
          hint: const Text('Select address'),
          isExpanded: true,
          items: [
            // Saved addresses
            ..._savedAddresses.map((address) => DropdownMenuItem<String>(
              value: address['name'],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    address['name']!,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  Text(
                    address['address']!,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppThemeV3.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            )),
            // Add new address option
            const DropdownMenuItem<String>(
              value: 'add_new',
              child: Row(
                children: [
                  Icon(Icons.add, color: AppThemeV3.accent, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Add New Address',
                    style: TextStyle(
                      color: AppThemeV3.accent,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
          onChanged: (value) {
            if (value == 'add_new') {
              _navigateToAddAddress();
            } else if (value != null) {
              setState(() {
                _tempAddress = value;
              });
            }
          },
        ),
      ),
    );
  }

  void _applyConfigurationToSelectedDays() {
    if (_tempTime == null || _tempAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both time and address')),
      );
      return;
    }

    setState(() {
      for (String day in _selectedDaysForCustomization) {
        if (!_weeklySchedule.containsKey(day)) {
          _weeklySchedule[day] = {};
        }
        if (!_weeklySchedule[day]!.containsKey(_selectedMealTypeTab)) {
          _weeklySchedule[day]![_selectedMealTypeTab] = {};
        }
        _weeklySchedule[day]![_selectedMealTypeTab]!['time'] = _tempTime;
        _weeklySchedule[day]![_selectedMealTypeTab]!['address'] = _tempAddress;
        
        // Check if this day is now fully configured
        if (_isDayFullyConfigured(day)) {
          _unconfiguredDays.remove(day);
        }
      }
      
      // Clear temporary data
      _tempTime = null;
      _tempAddress = null;
      _selectedDaysForCustomization.clear();
      _showDayCustomization = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Configuration applied to selected days!')),
    );
  }

  bool _isDayFullyConfigured(String day) {
    final dayConfig = _weeklySchedule[day];
    if (dayConfig == null) return false;
    
    for (String mealType in _selectedMealTypes) {
      final mealConfig = dayConfig[mealType];
      if (mealConfig == null || 
          mealConfig['time'] == null || 
          mealConfig['address'] == null) {
        return false;
      }
    }
    return true;
  }

  void _navigateToAddAddress() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddressPageV3()),
    );
    
    // In a real app, you'd get the new address from the result
    // For now, we'll simulate adding a new address
    if (result != null) {
      setState(() {
        _savedAddresses.add({
          'name': 'New Address ${_savedAddresses.length + 1}',
          'address': '789 New St, New York, NY 10003',
        });
      });
    }
  }

  bool _canContinueToMeals() {
    return _unconfiguredDays.isEmpty && _weeklySchedule.length == 7;
  }

  void _saveSchedule() async {
    if (_scheduleName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a schedule name')),
      );
      return;
    }

    if (!_canContinueToMeals()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please configure all 7 days before saving. Missing: ${_unconfiguredDays.join(', ')}')),
      );
      return;
    }

    // Save schedule data using SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final scheduleData = {
      'name': _scheduleName,
      'mealPlanId': _selectedMealPlan!.id,
      'mealPlanName': _selectedMealPlan!.name,
      'selectedMealTypes': _selectedMealTypes.toList(),
      'weeklySchedule': _weeklySchedule.map((day, daySchedule) => MapEntry(
        day,
        daySchedule.map((mealType, config) => MapEntry(
          mealType,
          {
            'time': (config['time'] as TimeOfDay?)?.toString(),
            'address': config['address'] as String?,
          },
        )),
      )),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    
    // Store the schedule
    await prefs.setString('delivery_schedule_${_scheduleName}', json.encode(scheduleData));
    
    // Add to list of saved schedules
    final savedSchedules = prefs.getStringList('saved_schedules') ?? [];
    if (!savedSchedules.contains(_scheduleName)) {
      savedSchedules.add(_scheduleName);
      await prefs.setStringList('saved_schedules', savedSchedules);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Schedule "$_scheduleName" saved successfully!')),
    );
  }

  void _addNewSchedule() {
    setState(() {
      // Reset form for new schedule
      _weeklySchedule.clear();
      _selectedMealTypes.clear();
      _unconfiguredDays = _daysOfWeek.toSet();
      _selectedDaysForCustomization.clear();
      _showDayCustomization = false;
      _tempTime = null;
      _tempAddress = null;
      
      // Generate new schedule name
      _scheduleName = 'Schedule ${DateTime.now().millisecondsSinceEpoch % 1000}';
      _scheduleNameController.text = _scheduleName;
      
      // Reset meal plan selection
      _selectedMealPlan = null;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ready to create a new schedule!')),
    );
  }

  void _continueToMealSelection() {
    if (_selectedMealPlan == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a meal plan')),
      );
      return;
    }

    if (!_canContinueToMeals()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please configure all 7 days before continuing. Missing: ${_unconfiguredDays.join(', ')}')),
      );
      return;
    }

    // Convert to the expected format for MealSchedulePageV3
    Map<String, Map<String, dynamic>> weeklySchedule = {};
    
    for (String day in _weeklySchedule.keys) {
      weeklySchedule[day] = {};
      for (String mealType in _selectedMealTypes) {
        final mealConfig = _weeklySchedule[day]?[mealType];
        if (mealConfig != null) {
          weeklySchedule[day]![mealType] = {
            'time': mealConfig['time'],
            'address': mealConfig['address'],
            'enabled': true,
          };
        }
      }
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MealSchedulePageV3(
          mealPlan: _selectedMealPlan!,
          weeklySchedule: weeklySchedule,
        ),
      ),
    );
  }
}
