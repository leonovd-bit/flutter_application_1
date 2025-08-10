import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../theme/app_theme_v3.dart';
import '../models/meal_model_v3.dart';
import '../services/progress_manager.dart';
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
  
  // Optimized address storage - lazy load from preferences
  List<Map<String, String>> _savedAddresses = [];
  
  // State management
  Set<String> _selectedMealTypes = {};
  Map<String, Map<String, Map<String, dynamic>>> _weeklySchedule = {};
  Set<String> _selectedDaysForCustomization = {};
  Set<String> _unconfiguredDays = {};
  
  // UI state
  bool _showDayCustomization = false;
  String _selectedMealTypeTab = 'Breakfast';
  // ignore: unused_field
  int _currentMealTypeStep = 0; // Track which meal type we're configuring (0=Breakfast, 1=Lunch, 2=Dinner)
  // Track if user has edited temp values in the current selection session
  bool _hasTempEditsThisSession = false;
  
  // Debug mode - set to false for production
  final bool _debugMode = false;
  
  @override
  void initState() {
    super.initState();
    _initializeDefaults();
    _loadExistingProgress();
    _loadSavedAddresses();
    // Removed _loadTimeConfiguration() to prevent auto-filling from saved configurations
  }

  Future<void> _loadSavedAddresses() async {
    // Load only user-created addresses from SharedPreferences - no defaults
    final prefs = await SharedPreferences.getInstance();
    final addressList = prefs.getStringList('user_addresses') ?? [];
    
    _savedAddresses.clear();
    for (String addressJson in addressList) {
      try {
        final addressData = json.decode(addressJson);
        _savedAddresses.add({
          'name': addressData['label'],
          'address': '${addressData['streetAddress']}${addressData['apartment'].isEmpty ? '' : ', ${addressData['apartment']}'}, ${addressData['city']}, ${addressData['state']} ${addressData['zipCode']}',
        });
      } catch (e) {
        print('Error parsing address: $e');
      }
    }
    
    setState(() {});
  }

  Future<void> _loadExistingProgress() async {
    // Set current step to delivery schedule
    await ProgressManager.saveCurrentStep(OnboardingStep.deliverySchedule);
    
    // Check if this is a reorder flow
    final prefs = await SharedPreferences.getInstance();
    final isReordering = prefs.getBool('is_reordering') ?? false;
    
    if (isReordering) {
      await _loadReorderData(prefs);
    } else {
      // Load any existing schedule progress
      final scheduleData = await ProgressManager.getScheduleProgress();
      if (scheduleData != null) {
        await _loadScheduleProgress(scheduleData);
      }
    }
  }

  Future<void> _loadReorderData(SharedPreferences prefs) async {
    setState(() {
      // Load reorder data
      final reorderMealPlanType = prefs.getString('reorder_meal_plan_type');
      if (reorderMealPlanType != null) {
        // Find matching meal plan
        for (var plan in _mealPlans) {
          if (plan.id.toLowerCase() == reorderMealPlanType.toLowerCase() ||
              plan.name.toLowerCase().contains(reorderMealPlanType.toLowerCase())) {
            _selectedMealPlan = plan;
            break;
          }
        }
        
        // If not found, use first plan as fallback
        if (_selectedMealPlan == null && _mealPlans.isNotEmpty) {
          _selectedMealPlan = _mealPlans.first;
        }
      }
      
      // Set schedule name based on reorder
      final sourceOrderId = prefs.getString('reorder_source_order_id') ?? '';
      _scheduleName = 'Reorder from ${sourceOrderId.substring(sourceOrderId.length - 6).toUpperCase()}';
      _scheduleNameController.text = _scheduleName;
      
      // Auto-select meal types based on plan
      if (_selectedMealPlan != null) {
        if (_selectedMealPlan!.mealsPerDay >= 3) {
          _selectedMealTypes = _allMealTypes.toSet();
        } else {
          // For reorders, start with breakfast for partial plans
          _selectedMealTypes = {'Breakfast'};
        }
        
        // Set default meal type tab
        if (_selectedMealTypes.isNotEmpty) {
          _selectedMealTypeTab = _selectedMealTypes.first;
        }
      }
    });
    
    // Clear reorder flag
    await prefs.setBool('is_reordering', false);
    
    // Show reorder notification
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.refresh, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Reordering previous meal plan. Customize your schedule below.'),
              ),
            ],
          ),
          backgroundColor: AppThemeV3.accent,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Got it',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    }
  }

  Future<void> _loadScheduleProgress(Map<String, dynamic> scheduleData) async {
    setState(() {
      if (scheduleData['selectedMealPlanId'] != null) {
        _selectedMealPlan = _mealPlans.firstWhere(
          (plan) => plan.id == scheduleData['selectedMealPlanId'],
          orElse: () => _mealPlans.first,
        );
      }
      if (scheduleData['scheduleName'] != null) {
        _scheduleName = scheduleData['scheduleName'];
        _scheduleNameController.text = _scheduleName;
      }
      if (scheduleData['selectedMealTypes'] != null) {
        _selectedMealTypes = (scheduleData['selectedMealTypes'] as List<dynamic>)
            .cast<String>()
            .toSet();
      }
      if (scheduleData['weeklySchedule'] != null) {
        _weeklySchedule = Map<String, Map<String, Map<String, dynamic>>>.from(
          (scheduleData['weeklySchedule'] as Map<String, dynamic>).map(
            (key, value) => MapEntry(
              key,
              Map<String, Map<String, dynamic>>.from(
                (value as Map<String, dynamic>).map(
                  (k, v) => MapEntry(k, Map<String, dynamic>.from(v)),
                ),
              ),
            ),
          ),
        );
        
        // Update unconfigured days - only show days with NO meal types configured
        _unconfiguredDays = _daysOfWeek.toSet();
        for (String day in _weeklySchedule.keys) {
          if (_isDayPartiallyConfigured(day)) {
            _unconfiguredDays.remove(day);
          }
        }
      }
    });
  }
  
  @override
  void dispose() {
    _scheduleNameController.dispose();
    super.dispose();
  }
  
  void _initializeDefaults() {
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
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'Delivery Schedule',
          style: AppThemeV3.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppThemeV3.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Step 1: Meal Plan Selection
            _buildStepHeader('1', 'Choose Your Meal Plan'),
            const SizedBox(height: 20),
            _buildMealPlanGrid(),
            
            if (_selectedMealPlan != null) ...[
              const SizedBox(height: 40),
              
              // Step 2: Schedule Name
              _buildStepHeader('2', 'Name Your Schedule'),
              const SizedBox(height: 20),
              _buildScheduleNameInput(),
              
              const SizedBox(height: 40),
              
              // Step 3: Meal Type Selection (if needed)
              if (_selectedMealPlan!.mealsPerDay < 3) ...[
                _buildStepHeader('3', 'Select Meal Types'),
                const SizedBox(height: 16),
                Text(
                  'Choose ${_selectedMealPlan!.mealsPerDay} meal${_selectedMealPlan!.mealsPerDay > 1 ? 's' : ''} for your plan',
                  style: AppThemeV3.textTheme.bodyMedium?.copyWith(
                    color: AppThemeV3.textSecondary,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 20),
                _buildMealTypeGrid(),
                const SizedBox(height: 40),
              ],
              
              // Step 4: Weekly Schedule
              if (_selectedMealPlan!.mealsPerDay >= 3 || _selectedMealTypes.isNotEmpty) ...[
                _buildStepHeader(
                  _selectedMealPlan!.mealsPerDay < 3 ? '4' : '3', 
                  'Set Up Weekly Schedule'
                ),
                const SizedBox(height: 16),
                Text(
                  'Configure delivery times and addresses for each day',
                  style: AppThemeV3.textTheme.bodyMedium?.copyWith(
                    color: AppThemeV3.textSecondary,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 20),
                _buildWeeklyScheduleSetup(),
                
                const SizedBox(height: 40),
                
                // Continue Button
                _buildContinueButton(),
              ],
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
          ],
        ),
      ),
    );
  }

  Widget _buildStepHeader(String stepNumber, String title) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppThemeV3.accent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              stepNumber,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Text(
          title,
          style: AppThemeV3.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppThemeV3.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildMealPlanGrid() {
    return Row(
      children: _mealPlans.map((plan) => Expanded(
        child: Container(
          margin: EdgeInsets.only(
            right: plan != _mealPlans.last ? 12 : 0,
          ),
          child: _buildMealPlanCard(plan),
        ),
      )).toList(),
    );
  }

  Widget _buildScheduleNameInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Give your schedule a memorable name',
          style: AppThemeV3.textTheme.bodyMedium?.copyWith(
            color: AppThemeV3.textSecondary,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _scheduleNameController,
          decoration: InputDecoration(
            hintText: 'e.g., "Weekly Family Meals"',
            filled: true,
            fillColor: AppThemeV3.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppThemeV3.border.withOpacity(0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppThemeV3.accent, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          onChanged: (value) {
            _scheduleName = value;
          },
        ),
      ],
    );
  }

  Widget _buildMealTypeGrid() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: _allMealTypes.map((mealType) {
        final isSelected = _selectedMealTypes.contains(mealType);
        final canSelect = _selectedMealTypes.length < _selectedMealPlan!.mealsPerDay || isSelected;
        
        return GestureDetector(
          onTap: canSelect ? () {
            setState(() {
              if (isSelected) {
                _selectedMealTypes.remove(mealType);
              } else {
                if (_selectedMealTypes.length < _selectedMealPlan!.mealsPerDay) {
                  _selectedMealTypes.add(mealType);
                }
              }
              
              if (_selectedMealTypes.isNotEmpty && !_selectedMealTypes.contains(_selectedMealTypeTab)) {
                _selectedMealTypeTab = _selectedMealTypes.first;
              }
            });
          } : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: isSelected ? AppThemeV3.accent : AppThemeV3.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AppThemeV3.accent : AppThemeV3.border.withOpacity(0.3),
                width: 2,
              ),
              boxShadow: isSelected ? [
                BoxShadow(
                  color: AppThemeV3.accent.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ] : [],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getMealTypeIcon(mealType),
                  color: isSelected ? Colors.white : AppThemeV3.textPrimary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  mealType,
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppThemeV3.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  IconData _getMealTypeIcon(String mealType) {
    switch (mealType.toLowerCase()) {
      case 'breakfast':
        return Icons.wb_sunny_outlined;
      case 'lunch':
        return Icons.wb_sunny;
      case 'dinner':
        return Icons.nightlight_round;
      default:
        return Icons.restaurant_menu;
    }
  }

  Widget _buildWeeklyScheduleSetup() {
    return Column(
      children: [
        // Days grid
        _buildDaysGrid(),
        
        const SizedBox(height: 20),
        
        // Configuration panel
        if (_selectedDaysForCustomization.isNotEmpty) ...[
          _buildConfigurationPanel(),
        ],
        
        const SizedBox(height: 20),
        
        // Progress indicator
        _buildProgressIndicator(),
      ],
    );
  }

  Widget _buildDaysGrid() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppThemeV3.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppThemeV3.border.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select days to configure',
            style: AppThemeV3.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppThemeV3.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _daysOfWeek.map((day) {
              final isSelected = _selectedDaysForCustomization.contains(day);
              final isConfigured = _isDayPartiallyConfigured(day);
              
              return GestureDetector(
                onTap: () {
                  if (isConfigured) {
                    // Show details dialog for configured days
                    _showDayConfigurationDialog(day);
                  } else {
                    // Normal selection behavior for unconfigured days
                    setState(() {
                      if (isSelected) {
                        _selectedDaysForCustomization.remove(day);
                      } else {
                        _selectedDaysForCustomization.add(day);
                      }
                      // Load existing configuration when selecting configured days
                      // Do not auto-load from other days; keep configs independent
                      _tempTimes.clear();
                      _tempAddresses.clear();
                      _hasTempEditsThisSession = false;
                    });
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? AppThemeV3.accent 
                        : isConfigured 
                            ? AppThemeV3.accent.withOpacity(0.1)
                            : AppThemeV3.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected 
                          ? AppThemeV3.accent 
                          : isConfigured 
                              ? AppThemeV3.accent.withOpacity(0.3)
                              : AppThemeV3.border,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        day.substring(0, 3),
                        style: TextStyle(
                          color: isSelected 
                              ? Colors.white 
                              : AppThemeV3.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      if (isConfigured) ...[
                        const SizedBox(width: 8),
                        Icon(
                          Icons.check_circle,
                          size: 16,
                          color: isSelected ? Colors.white : AppThemeV3.accent,
                        ),
                      ],
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

  Widget _buildConfigurationPanel() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppThemeV3.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppThemeV3.accent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Configure ${_selectedDaysForCustomization.length} selected day${_selectedDaysForCustomization.length != 1 ? 's' : ''}',
            style: AppThemeV3.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppThemeV3.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          
          // Meal type tabs
          if (_selectedMealTypes.length > 1) ...[
            _buildMealTypeTabs(),
            const SizedBox(height: 20),
          ],
          
          // Time and address configuration
          _buildTimeAndAddressConfig(),
          
          const SizedBox(height: 20),
          
          // Apply button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _applyConfigurationToSelectedDays,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppThemeV3.accent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Apply Configuration',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeAndAddressConfig() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Optional: Load from a configured day (explicit action, no auto-fill)
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _hasConfiguredDaysForMealType(_selectedMealTypeTab) ? _showLoadFromDayPicker : null,
            icon: Icon(
              Icons.file_download,
              color: _hasConfiguredDaysForMealType(_selectedMealTypeTab)
                  ? AppThemeV3.accent
                  : AppThemeV3.textSecondary,
              size: 18,
            ),
            label: Text(
              'Load ${_selectedMealTypeTab} from day',
              style: TextStyle(
                color: _hasConfiguredDaysForMealType(_selectedMealTypeTab)
                    ? AppThemeV3.accent
                    : AppThemeV3.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        if (!_hasConfiguredDaysForMealType(_selectedMealTypeTab)) ...[
          const SizedBox(height: 4),
          Text(
            'No days have ${_selectedMealTypeTab} configured yet.',
            style: AppThemeV3.textTheme.bodySmall?.copyWith(
              color: AppThemeV3.textSecondary,
            ),
            textAlign: TextAlign.right,
          ),
        ],
        const SizedBox(height: 4),
        // Time selection
        Text(
          'Delivery Time',
          style: AppThemeV3.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppThemeV3.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _selectTimeForMealType(_selectedMealTypeTab),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppThemeV3.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppThemeV3.border.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _hasTempEditsThisSession && _tempTimes[_selectedMealTypeTab] != null
                      ? _tempTimes[_selectedMealTypeTab]!.format(context)
                      : 'Select time',
                  style: AppThemeV3.textTheme.bodyMedium?.copyWith(
                    color: _tempTimes[_selectedMealTypeTab] != null 
                        ? AppThemeV3.textPrimary 
                        : AppThemeV3.textSecondary,
                    fontSize: 16,
                  ),
                ),
                Icon(
                  Icons.access_time,
                  color: AppThemeV3.textSecondary,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Address selection
        Text(
          'Delivery Address',
          style: AppThemeV3.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppThemeV3.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        _buildAddressDropdown(),
      ],
    );
  }

  Widget _buildAddressDropdown() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: AppThemeV3.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppThemeV3.border.withOpacity(0.3)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _hasTempEditsThisSession ? _tempAddresses[_selectedMealTypeTab] : null,
          hint: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'Select address',
              style: TextStyle(
                color: AppThemeV3.textSecondary,
                fontSize: 16,
              ),
            ),
          ),
          isExpanded: true,
          itemHeight: 60, // Set consistent item height
          items: [
            ..._savedAddresses.map((address) => DropdownMenuItem<String>(
              value: address['name'],
              child: Container(
                height: 56, // Fixed height to prevent overflow
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            address['name']!,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          Text(
                            address['address']!,
                            style: TextStyle(
                              color: AppThemeV3.textSecondary,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )),
            DropdownMenuItem<String>(
              value: 'add_new',
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    Icon(Icons.add, color: AppThemeV3.accent, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Add new address',
                      style: TextStyle(
                        color: AppThemeV3.accent,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          onChanged: (value) {
            if (value == 'add_new') {
              _navigateToAddAddress();
            } else if (value != null) {
              setState(() {
                _tempAddresses[_selectedMealTypeTab] = value;
              });
            }
          },
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    final totalDays = _daysOfWeek.length;
    final configuredDays = totalDays - _unconfiguredDays.length;
    final progress = configuredDays / totalDays;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppThemeV3.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppThemeV3.border.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Setup Progress',
                style: AppThemeV3.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppThemeV3.textPrimary,
                ),
              ),
              Text(
                '$configuredDays/$totalDays days',
                style: AppThemeV3.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppThemeV3.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: AppThemeV3.background,
            valueColor: AlwaysStoppedAnimation<Color>(AppThemeV3.accent),
            minHeight: 8,
          ),
          if (_unconfiguredDays.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Remaining: ${_unconfiguredDays.join(', ')}',
              style: AppThemeV3.textTheme.bodySmall?.copyWith(
                color: AppThemeV3.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContinueButton() {
    // Count actual saved configurations in _weeklySchedule, not just temp configurations
    int savedMealSlots = 0;
    for (String day in _daysOfWeek) {
      for (String mealType in _selectedMealTypes) {
        if (_weeklySchedule[day]?[mealType] != null && 
            _weeklySchedule[day]![mealType]!['time'] != null) {
          savedMealSlots++;
        }
      }
    }
    
    // Also count current temp configurations for current meal type
    final tempConfiguredCount = _tempTimes.values.where((time) => time != null).length;
    
    // For continue button: count both saved and temp
    final totalConfiguredCount = savedMealSlots + tempConfiguredCount;
    
    // For status display: only count saved meals (not temp)
    final statusMealCount = savedMealSlots;
    
    // Debug logging if enabled
    if (_debugMode) {
      print('DEBUG: Meal count - Saved: $savedMealSlots, Temp: $tempConfiguredCount, Total: $totalConfiguredCount');
      print('DEBUG: Temp times: $_tempTimes');
      print('DEBUG: Selected meal types: $_selectedMealTypes');
    }
    
    final canContinue = totalConfiguredCount > 0 && _scheduleName.isNotEmpty;
    
    return Column(
      children: [
        // Status Display - Only show if we have saved configurations
        if (statusMealCount > 0)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 24),
                const SizedBox(width: 12),
                Text(
                  '$statusMealCount meal${statusMealCount != 1 ? 's' : ''} scheduled',
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        
        // Main Continue Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: canContinue ? _continueToMealSelection : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: canContinue ? AppThemeV3.accent : Colors.grey.shade300,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: canContinue ? 4 : 0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  canContinue ? Icons.check_circle : Icons.schedule,
                  color: canContinue ? Colors.white : Colors.grey.shade600,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  canContinue 
                    ? 'Continue to Meal Selection' 
                    : 'Set meal times to continue',
                  style: TextStyle(
                    color: canContinue ? Colors.white : Colors.grey.shade600,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Skip Button - Only show in debug mode
        if (_debugMode) ...[
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _bypassDeliverySchedule,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                side: BorderSide(color: AppThemeV3.accent.withOpacity(0.6)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.skip_next,
                    color: AppThemeV3.accent,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Skip for Now',
                    style: TextStyle(
                      color: AppThemeV3.accent,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        
        const SizedBox(height: 8),
        
        // Helper text for bypass
        Text(
          'You can set up delivery schedule later in settings',
          style: TextStyle(
            color: AppThemeV3.textSecondary,
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  void _updateScheduleForMealPlan(MealPlanModelV3 plan) async {
    // Reset all schedule data when meal plan changes
    _weeklySchedule.clear();
    _selectedMealTypes.clear();
    _unconfiguredDays = _daysOfWeek.toSet();
    _selectedDaysForCustomization.clear();
    _tempTimes.clear();
    _tempAddresses.clear();
    
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
    
    // Save the selected meal plan to storage for home page
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_meal_plan_display_name', plan.displayName);
      await prefs.setString('selected_meal_plan_id', plan.id);
      await prefs.setString('selected_meal_plan_name', plan.name);
      
      // Save schedule progress
      await ProgressManager.saveScheduleProgress(
        selectedMealPlanId: plan.id,
        selectedMealPlanName: plan.displayName,
        scheduleName: _scheduleName,
        selectedMealTypes: _selectedMealTypes.toList(),
        configuredDaysCount: 7 - _unconfiguredDays.length,
      );
    } catch (e) {
      print('Error saving meal plan selection: $e');
    }
  }

  // ignore: unused_element
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

  // ignore: unused_element
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

  // ignore: unused_element
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
                  // Ensure fresh state per meal tab; no carry-over between sessions
                  _tempTimes.remove(mealType);
                  _tempAddresses.remove(mealType);
                  _hasTempEditsThisSession = false;
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

  // Temporary storage for inline customization - per meal type
  Map<String, TimeOfDay?> _tempTimes = {};
  Map<String, String?> _tempAddresses = {};

  TimeOfDay? _getSelectedTimeForMealType(String mealType) {
    return _tempTimes[mealType];
  }

  // ignore: unused_element
  String? _getSelectedAddressForMealType(String mealType) {
    return _tempAddresses[mealType];
  }

  void _selectTimeForMealType(String mealType) {
    // Get current time, no default fallback to prevent auto-filling from other days
    final currentTime = _tempTimes[mealType];
    int selectedHour = currentTime?.hour ?? TimeOfDay.now().hour;
    int selectedMinute = currentTime?.minute ?? TimeOfDay.now().minute;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: 400,
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Select $mealType Time',
                    style: AppThemeV3.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppThemeV3.textPrimary,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: AppThemeV3.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              // Current Time Display
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppThemeV3.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppThemeV3.accent.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.access_time,
                      color: AppThemeV3.accent,
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      TimeOfDay(hour: selectedHour, minute: selectedMinute).format(context),
                      style: AppThemeV3.textTheme.headlineSmall?.copyWith(
                        color: AppThemeV3.accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Scroll Wheel Time Picker
              Expanded(
                child: Row(
                  children: [
                    // Hour Picker
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            'Hour',
                            style: AppThemeV3.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppThemeV3.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: CupertinoPicker(
                              scrollController: FixedExtentScrollController(
                                initialItem: selectedHour,
                              ),
                              itemExtent: 40,
                              onSelectedItemChanged: (int index) {
                                setModalState(() {
                                  selectedHour = index;
                                });
                              },
                              children: List.generate(24, (index) => Center(
                                child: Text(
                                  index.toString().padLeft(2, '0'),
                                  style: AppThemeV3.textTheme.titleLarge?.copyWith(
                                    color: AppThemeV3.textPrimary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              )),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(width: 16),
                    
                    // Separator
                    Container(
                      height: 40,
                      child: Center(
                        child: Text(
                          ':',
                          style: AppThemeV3.textTheme.headlineMedium?.copyWith(
                            color: AppThemeV3.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 16),
                    
                    // Minute Picker
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            'Minute',
                            style: AppThemeV3.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppThemeV3.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: CupertinoPicker(
                              scrollController: FixedExtentScrollController(
                                initialItem: selectedMinute,
                              ),
                              itemExtent: 40,
                              onSelectedItemChanged: (int index) {
                                setModalState(() {
                                  selectedMinute = index;
                                });
                              },
                              children: List.generate(60, (index) => Center(
                                child: Text(
                                  index.toString().padLeft(2, '0'),
                                  style: AppThemeV3.textTheme.titleLarge?.copyWith(
                                    color: AppThemeV3.textPrimary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              )),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Confirm Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    // Save the selected time
                    final selectedTime = TimeOfDay(hour: selectedHour, minute: selectedMinute);
                    setState(() {
                      _tempTimes[mealType] = selectedTime;
                      _hasTempEditsThisSession = true;
                    });
                    
                    // Save configuration immediately
                    await _saveTimeConfiguration();
                    
                    // Show confirmation snackbar
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('✅ $mealType time set to ${selectedTime.format(context)}'),
                          backgroundColor: Colors.green,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                    
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppThemeV3.accent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Confirm Time',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
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
          value: _tempAddresses[mealType],
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
                    maxLines: 1,
                    softWrap: false,
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
                _tempAddresses[mealType] = value;
                _hasTempEditsThisSession = true;
              });
            }
          },
        ),
      ),
    );
  }

  void _applyConfigurationToSelectedDays() {
    final currentTime = _tempTimes[_selectedMealTypeTab];
    final currentAddress = _tempAddresses[_selectedMealTypeTab];
    
    // Debug information
    print('DEBUG: === APPLYING CONFIGURATION ===');
    print('DEBUG: Selected meal type: $_selectedMealTypeTab');
    print('DEBUG: Current time: $currentTime');
    print('DEBUG: Current address: $currentAddress');
    print('DEBUG: Selected days for customization: $_selectedDaysForCustomization');
    print('DEBUG: All selected meal types: $_selectedMealTypes');
    print('DEBUG: Current weekly schedule before: $_weeklySchedule');
    
    if (currentTime == null || currentAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select both time and address for $_selectedMealTypeTab'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    if (_selectedDaysForCustomization.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one day to configure'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // Store the count before clearing
    final dayCount = _selectedDaysForCustomization.length;

    setState(() {
      for (String day in _selectedDaysForCustomization) {
        // Initialize day structure if it doesn't exist
        if (!_weeklySchedule.containsKey(day)) {
          _weeklySchedule[day] = {};
          print('DEBUG: Created new day entry for $day');
        }
        if (!_weeklySchedule[day]!.containsKey(_selectedMealTypeTab)) {
          _weeklySchedule[day]![_selectedMealTypeTab] = {};
          print('DEBUG: Created new meal type entry for $day $_selectedMealTypeTab');
        }
        
        // Apply configuration ONLY to the selected meal type
        // Convert TimeOfDay to string format for storage
        String timeString = '${currentTime.hour.toString().padLeft(2, '0')}:${currentTime.minute.toString().padLeft(2, '0')}';
        _weeklySchedule[day]![_selectedMealTypeTab]!['time'] = timeString;
        _weeklySchedule[day]![_selectedMealTypeTab]!['address'] = currentAddress;
        
        print('DEBUG: Applied to $day $_selectedMealTypeTab - time: $timeString, address: $currentAddress');
        
        // Remove from unconfigured days if it now has at least one meal type configured
        if (_isDayPartiallyConfigured(day)) {
          _unconfiguredDays.remove(day);
          print('DEBUG: $day now has meal types configured');
        } else {
          print('DEBUG: $day still has no meal types configured');
        }
      }
      
      print('DEBUG: Current weekly schedule after: $_weeklySchedule');
      
      // Clear temporary data for current meal type only after successful save
  _tempTimes.remove(_selectedMealTypeTab);
  _tempAddresses.remove(_selectedMealTypeTab);
  // Also clear any other temp values to ensure next session starts blank
  _tempTimes.clear();
  _tempAddresses.clear();
  _hasTempEditsThisSession = false;
      _selectedDaysForCustomization.clear();
      _showDayCustomization = false;
    });

    // Save progress after configuration changes
    _saveScheduleProgress();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ $_selectedMealTypeTab configuration applied to $dayCount day${dayCount != 1 ? 's' : ''}!'),
        backgroundColor: AppThemeV3.accent,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _saveScheduleProgress() async {
    if (_selectedMealPlan != null) {
      // Convert TimeOfDay objects to serializable format
      Map<String, Map<String, Map<String, dynamic>>> serializableSchedule = {};
      
      _weeklySchedule.forEach((day, dayData) {
        serializableSchedule[day] = {};
        dayData.forEach((mealType, mealData) {
          serializableSchedule[day]![mealType] = {};
          mealData.forEach((key, value) {
            if (value is TimeOfDay) {
              // Convert TimeOfDay to string format
              serializableSchedule[day]![mealType]![key] = '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
            } else {
              serializableSchedule[day]![mealType]![key] = value;
            }
          });
        });
      });
      
      await ProgressManager.saveScheduleProgress(
        selectedMealPlanId: _selectedMealPlan!.id,
        selectedMealPlanName: _selectedMealPlan!.displayName,
        scheduleName: _scheduleName,
        selectedMealTypes: _selectedMealTypes.toList(),
        weeklySchedule: serializableSchedule,
        configuredDaysCount: 7 - _unconfiguredDays.length,
      );
    }
  }

  // ignore: unused_element
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

  // Check if a day has ANY meal types configured (for progress tracking)
  bool _isDayPartiallyConfigured(String day) {
    final dayConfig = _weeklySchedule[day];
    if (dayConfig == null) return false;
    
    for (String mealType in _selectedMealTypes) {
      final mealConfig = dayConfig[mealType];
      if (mealConfig != null && 
          mealConfig['time'] != null && 
          mealConfig['address'] != null) {
        return true; // At least one meal type is configured
      }
    }
    return false;
  }

  // ignore: unused_element
  String _getDayConfigurationSummary(String day) {
    final dayConfig = _weeklySchedule[day];
    if (dayConfig == null) return "";
    
    List<String> configuredMeals = [];
    for (String mealType in _selectedMealTypes) {
      final mealConfig = dayConfig[mealType];
      if (mealConfig != null && 
          mealConfig['time'] != null && 
          mealConfig['address'] != null) {
        // Handle both TimeOfDay and String types for time
        String time;
        if (mealConfig['time'] is TimeOfDay) {
          final timeOfDay = mealConfig['time'] as TimeOfDay;
          time = '${timeOfDay.hour.toString().padLeft(2, '0')}:${timeOfDay.minute.toString().padLeft(2, '0')}';
        } else {
          time = mealConfig['time'] as String;
        }
        String mealShort = mealType.substring(0, 1).toUpperCase(); // B, L, D
        configuredMeals.add('$mealShort: $time');
      }
    }
    
    return configuredMeals.join('\n');
  }

  // ignore: unused_element
  void _loadExistingConfigurationForSelectedDays() {
  // No-op by design: keep each configuration session independent and fresh.
  }

  // Returns true if at least one day has a complete configuration (time + address)
  // for the given meal type. Used to enable/disable the "Load from day" affordance.
  bool _hasConfiguredDaysForMealType(String mealType) {
    for (final day in _daysOfWeek) {
      final dayCfg = _weeklySchedule[day];
      final mealCfg = dayCfg?[mealType];
      if (mealCfg != null && mealCfg['time'] != null && mealCfg['address'] != null) {
        return true;
      }
    }
    return false;
  }

  void _showLoadFromDayPicker() {
    // Build list of days that have current meal type configured
    final options = _daysOfWeek.where((day) {
      final dayCfg = _weeklySchedule[day];
      final mealCfg = dayCfg?[_selectedMealTypeTab];
      return mealCfg != null && mealCfg['time'] != null && mealCfg['address'] != null;
    }).toList();

    if (options.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No days have ${_selectedMealTypeTab} configured yet.')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Text('Load ${_selectedMealTypeTab} from day', style: AppThemeV3.textTheme.titleMedium),
              const Divider(),
              ...options.map((day) => ListTile(
                    leading: const Icon(Icons.calendar_today),
                    title: Text(day),
                    subtitle: Builder(builder: (context) {
                      final cfg = _weeklySchedule[day]![_selectedMealTypeTab]!;
                      final time = cfg['time'] as String?;
                      final address = cfg['address'];
                      final addressName = address is Map<String, dynamic> ? address['name'] as String? : (address?.toString());
                      return Text('${time ?? '-'} • ${addressName ?? '-'}');
                    }),
                    onTap: () {
                      final cfg = _weeklySchedule[day]![_selectedMealTypeTab]!;
                      // Time is stored as HH:mm string in schedule; parse to TimeOfDay for temp
                      final timeStr = cfg['time'] as String?;
                      if (timeStr != null) {
                        final parts = timeStr.split(':');
                        if (parts.length == 2) {
                          final h = int.tryParse(parts[0]);
                          final m = int.tryParse(parts[1]);
                          if (h != null && m != null) {
                            _tempTimes[_selectedMealTypeTab] = TimeOfDay(hour: h, minute: m);
                          }
                        }
                      }
                      // Address: keep only the name in temp selection dropdown
                      final address = cfg['address'];
                      if (address is Map<String, dynamic>) {
                        _tempAddresses[_selectedMealTypeTab] = address['name'] as String?;
                      } else if (address is String) {
                        _tempAddresses[_selectedMealTypeTab] = address;
                      }

                      setState(() {});
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Loaded ${_selectedMealTypeTab} from $day')),
                      );
                      _hasTempEditsThisSession = true;
                    },
                  )),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _showDayConfigurationDialog(String day) {
    // Prepare fresh temp state for editing a single day
    _tempTimes.clear();
    _tempAddresses.clear();

    // If the tapped day already has configuration, load ONLY that day's values
    final existingDayCfg = _weeklySchedule[day];
    if (existingDayCfg != null) {
      for (final mealType in _selectedMealTypes) {
        final mealCfg = existingDayCfg[mealType];
        if (mealCfg == null) continue;

        // Load time (stored as HH:mm string)
        final timeStr = mealCfg['time'];
        if (timeStr is String) {
          final parts = timeStr.split(':');
          if (parts.length == 2) {
            final h = int.tryParse(parts[0]);
            final m = int.tryParse(parts[1]);
            if (h != null && m != null) {
              _tempTimes[mealType] = TimeOfDay(hour: h, minute: m);
            }
          }
        }

        // Load address (Map with name or plain string)
        final addr = mealCfg['address'];
        if (addr is Map<String, dynamic>) {
          _tempAddresses[mealType] = addr['name'] as String?;
        } else if (addr is String) {
          _tempAddresses[mealType] = addr;
        }
      }
      // Show loaded values in the UI
      _hasTempEditsThisSession = true;
    } else {
      // New day edit session: start blank, hide values until user sets them
      _hasTempEditsThisSession = false;
    }

    // Set the editing mode and selected day
    setState(() {
      _selectedDaysForCustomization.clear();
      _selectedDaysForCustomization.add(day);
      _showDayCustomization = true;
      // Prefer a meal tab that has data loaded; otherwise first selected
      final loadedTab = _selectedMealTypes.firstWhere(
        (mt) => _tempTimes.containsKey(mt) || _tempAddresses.containsKey(mt),
        orElse: () => _selectedMealTypes.isNotEmpty ? _selectedMealTypes.first : 'Breakfast',
      );
      _selectedMealTypeTab = loadedTab;
    });
  }

  // ignore: unused_element
  Widget _buildModalConfigurationContent(String day, Map<String, dynamic>? dayConfig, List<String> mealTypesToShow, String initialMealTypeTab, StateSetter setModalState) {
    // Use a local variable for the modal's selected meal type tab
    String modalSelectedMealTypeTab = initialMealTypeTab;
    
    return Column(
      children: [
        // Show the day and selected meal types (same as original interface)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppThemeV3.accent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.calendar_today, color: AppThemeV3.accent, size: 20),
              const SizedBox(width: 8),
              Text(
                'Configure ${mealTypesToShow.length} meal type${mealTypesToShow.length != 1 ? 's' : ''} for $day',
                style: TextStyle(
                  color: AppThemeV3.accent,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Meal type tabs (use mealTypesToShow instead of _selectedMealTypes)
        Container(
          height: 50,
          decoration: BoxDecoration(
            color: AppThemeV3.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppThemeV3.border),
          ),
          child: Row(
            children: mealTypesToShow.map((mealType) {
              final isActive = modalSelectedMealTypeTab == mealType;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setModalState(() {
                      modalSelectedMealTypeTab = mealType;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isActive ? AppThemeV3.accent : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        mealType,
                        style: TextStyle(
                          color: isActive ? Colors.white : AppThemeV3.textSecondary,
                          fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        
        const SizedBox(height: 20),
        
        // Configuration for selected meal type
        Expanded(
          child: _buildModalMealConfiguration(day, modalSelectedMealTypeTab, dayConfig, setModalState),
        ),
      ],
    );
  }

  Widget _buildModalMealConfiguration(String day, String mealType, Map<String, dynamic>? dayConfig, StateSetter setModalState) {
    final mealConfigData = dayConfig?[mealType];
    final mealConfig = mealConfigData is Map<String, dynamic> ? mealConfigData : null;
    final currentTime = mealConfig?['time'] as String?;
    final currentAddressData = mealConfig?['address'];
    final currentAddress = currentAddressData is Map<String, dynamic> ? currentAddressData : null;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$mealType Configuration',
          style: AppThemeV3.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppThemeV3.accent,
          ),
        ),
        const SizedBox(height: 16),
        
        // Time selection
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppThemeV3.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppThemeV3.border),
          ),
          child: Row(
            children: [
              Icon(Icons.access_time, color: AppThemeV3.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Delivery Time',
                      style: AppThemeV3.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      currentTime ?? 'Not set',
                      style: AppThemeV3.textTheme.bodySmall?.copyWith(
                        color: currentTime != null ? AppThemeV3.textPrimary : AppThemeV3.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => _selectTimeForModalMealType(mealType, day, setModalState),
                child: Text(
                  currentTime != null ? 'Change' : 'Select',
                  style: TextStyle(color: AppThemeV3.accent),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Address selection  
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppThemeV3.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppThemeV3.border),
          ),
          child: Row(
            children: [
              Icon(Icons.location_on, color: AppThemeV3.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Delivery Address',
                      style: AppThemeV3.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      currentAddress?['name'] as String? ?? 'Not set',
                      style: AppThemeV3.textTheme.bodySmall?.copyWith(
                        color: currentAddress != null ? AppThemeV3.textPrimary : AppThemeV3.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => _selectAddressForModalMealType(mealType, day, setModalState),
                child: Text(
                  currentAddress != null ? 'Change' : 'Select',
                  style: TextStyle(color: AppThemeV3.accent),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _selectTimeForModalMealType(String mealType, String day, StateSetter setModalState) {
    // Simple time picker - in real app you'd use the full time picker modal
    showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    ).then((selectedTime) {
      if (selectedTime != null) {
        // Update the weekly schedule directly
        if (_weeklySchedule[day] == null) _weeklySchedule[day] = {};
        
        // Ensure the meal type entry exists and is a Map
        final daySchedule = _weeklySchedule[day]!;
        if (daySchedule[mealType] == null || daySchedule[mealType] is! Map<String, dynamic>) {
          daySchedule[mealType] = <String, dynamic>{};
        }
        
        String timeString = '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}';
        (daySchedule[mealType] as Map<String, dynamic>)['time'] = timeString;
        
        setModalState(() {}); // Update the modal
      }
    });
  }

  void _selectAddressForModalMealType(String mealType, String day, StateSetter setModalState) {
    // For now, just set a dummy address
    if (_weeklySchedule[day] == null) _weeklySchedule[day] = {};
    
    // Ensure the meal type entry exists and is a Map
    final daySchedule = _weeklySchedule[day]!;
    if (daySchedule[mealType] == null || daySchedule[mealType] is! Map<String, dynamic>) {
      daySchedule[mealType] = <String, dynamic>{};
    }
    
    (daySchedule[mealType] as Map<String, dynamic>)['address'] = {
      'name': 'Home Address',
      'street': '123 Main St', 
      'city': 'City',
      'state': 'State',
    };
    
    setModalState(() {});
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
    // Check for actual saved configurations in _weeklySchedule
    int savedMealSlots = 0;
    for (String day in _daysOfWeek) {
      for (String mealType in _selectedMealTypes) {
        if (_weeklySchedule[day]?[mealType] != null && 
            _weeklySchedule[day]![mealType]!['time'] != null) {
          savedMealSlots++;
        }
      }
    }
    
    // Also count current temp configurations
    final tempConfiguredCount = _tempTimes.values.where((time) => time != null).length;
    
    return (savedMealSlots + tempConfiguredCount) > 0;
  }

  // ignore: unused_element
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
    
    // Save selected meal plan for home page display
    await prefs.setString('selected_meal_plan_display_name', _selectedMealPlan!.displayName);
    
    // Add to list of saved schedules
    final savedSchedules = prefs.getStringList('saved_schedules') ?? [];
    if (!savedSchedules.contains(_scheduleName)) {
      savedSchedules.add(_scheduleName);
      await prefs.setStringList('saved_schedules', savedSchedules);
    }

    // Save progress - schedule is completed, ready for payment
    await ProgressManager.saveCurrentStep(OnboardingStep.paymentSetup);
    await _saveScheduleProgress();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Schedule "$_scheduleName" saved successfully!')),
    );
  }

  // ignore: unused_element
  void _addNewSchedule() {
    setState(() {
      // Reset form for new schedule
      _weeklySchedule.clear();
      _selectedMealTypes.clear();
      _unconfiguredDays = _daysOfWeek.toSet();
      _selectedDaysForCustomization.clear();
      _showDayCustomization = false;
      _tempTimes.clear();
      _tempAddresses.clear();
      
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

  void _continueToMealSelection() async {
    if (_scheduleName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a schedule name')),
      );
      return;
    }

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
    
    print('DeliverySchedulePage: Converting schedule for ${_weeklySchedule.keys.length} days');
    print('DeliverySchedulePage: Selected meal types: ${_selectedMealTypes.join(", ")}');
    
    for (String day in _weeklySchedule.keys) {
      weeklySchedule[day] = {};
      print('DeliverySchedulePage: Processing day $day with meal types: ${_weeklySchedule[day]?.keys.join(", ")}');
      
      for (String mealType in _selectedMealTypes) {
        final mealConfig = _weeklySchedule[day]?[mealType];
        print('DeliverySchedulePage: $day $mealType config: $mealConfig');
        if (mealConfig != null) {
          weeklySchedule[day]![mealType] = {
            'time': mealConfig['time'],
            'address': mealConfig['address'],
            'enabled': true,
          };
          print('DeliverySchedulePage: Added $day $mealType - time: ${mealConfig['time']}, address: ${mealConfig['address']}');
        }
      }
    }

    // Save progress before navigating to meal selection
    await ProgressManager.saveCurrentStep(OnboardingStep.paymentSetup);
    await _saveScheduleProgress();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MealSchedulePageV3(
          mealPlan: _selectedMealPlan!,
          weeklySchedule: weeklySchedule,
          initialScheduleName: _scheduleName,
        ),
      ),
    );
  }

  void _bypassDeliverySchedule() async {
    if (_selectedMealPlan == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a meal plan first')),
      );
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Skip Delivery Schedule'),
        content: const Text(
          'Are you sure you want to skip setting up the delivery schedule? '
          'You can configure it later in settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppThemeV3.accent,
            ),
            child: const Text('Skip for Now', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Create empty schedule for bypass
    Map<String, Map<String, dynamic>> emptySchedule = {};
    
    // Save progress to skip this step
    await ProgressManager.saveCurrentStep(OnboardingStep.paymentSetup);

    // Navigate to meal selection with minimal schedule
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MealSchedulePageV3(
          mealPlan: _selectedMealPlan!,
          weeklySchedule: emptySchedule,
          initialScheduleName: _scheduleName,
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildIndependentMealCustomization() {
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
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppThemeV3.accent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.restaurant,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Customize Meals',
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
            'Set delivery times and locations for each meal independently',
            style: AppThemeV3.textTheme.bodyMedium?.copyWith(
              color: AppThemeV3.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),
          
          // Individual meal type cards
          ...(_selectedMealPlan!.mealsPerDay >= 3 ? _allMealTypes : _selectedMealTypes.toList()).map((mealType) {
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              child: _buildMealTypeCard(mealType),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildMealTypeCard(String mealType) {
    // Get icon for meal type
    IconData mealIcon;
    Color mealColor;
    switch (mealType.toLowerCase()) {
      case 'breakfast':
        mealIcon = Icons.wb_sunny_outlined;
        mealColor = Colors.orange;
        break;
      case 'lunch':
        mealIcon = Icons.wb_sunny;
        mealColor = Colors.amber;
        break;
      case 'dinner':
        mealIcon = Icons.nightlight_round;
        mealColor = Colors.indigo;
        break;
      default:
        mealIcon = Icons.restaurant_menu;
        mealColor = AppThemeV3.accent;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppThemeV3.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppThemeV3.border,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
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
                      color: mealColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      mealIcon,
                      color: mealColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    mealType,
                    style: AppThemeV3.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppThemeV3.textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppThemeV3.accent.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: () => _showMealCustomizationDialog(mealType),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppThemeV3.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                  ),
                  icon: Icon(Icons.settings, size: 16),
                  label: Text(
                    'Customize',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Show current configuration if any
          _buildMealTypeScheduleSummary(mealType),
        ],
      ),
    );
  }

  Widget _buildMealTypeScheduleSummary(String mealType) {
    final configuredDays = _weeklySchedule.entries
        .where((entry) => entry.value.containsKey(mealType))
        .map((entry) => entry.key)
        .toList();

    if (configuredDays.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(
              Icons.info_outline,
              color: Colors.grey.shade600,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Not configured yet',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    configuredDays.sort((a, b) => _daysOfWeek.indexOf(a).compareTo(_daysOfWeek.indexOf(b)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              'Configured for ${configuredDays.length} day${configuredDays.length != 1 ? 's' : ''}',
              style: TextStyle(
                color: Colors.green.shade700,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: configuredDays.map((day) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppThemeV3.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppThemeV3.accent.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    day.substring(0, 3),
                    style: TextStyle(
                      color: AppThemeV3.accent,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.edit,
                    color: AppThemeV3.accent,
                    size: 12,
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  void _showMealCustomizationDialog(String mealType) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Customize $mealType'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select days and set delivery details for $mealType',
                      style: AppThemeV3.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    
                    // Day selection
                    Text(
                      'Select Days:',
                      style: AppThemeV3.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: _daysOfWeek.map((day) {
                        final isConfigured = _weeklySchedule[day]?.containsKey(mealType) ?? false;
                        return FilterChip(
                          label: Text(day.substring(0, 3)),
                          selected: isConfigured,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                // Add basic configuration
                                if (!_weeklySchedule.containsKey(day)) {
                                  _weeklySchedule[day] = {};
                                }
                                _weeklySchedule[day]![mealType] = {
                                  'time': '8:30 AM',
                                  'address': 'Home',
                                };
                                _unconfiguredDays.remove(day);
                              } else {
                                // Remove configuration
                                _weeklySchedule[day]?.remove(mealType);
                                if (_weeklySchedule[day]?.isEmpty ?? false) {
                                  _weeklySchedule.remove(day);
                                  _unconfiguredDays.add(day);
                                }
                              }
                            });
                          },
                          selectedColor: AppThemeV3.accent.withOpacity(0.2),
                          checkmarkColor: AppThemeV3.accent,
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    this.setState(() {}); // Refresh the main page
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppThemeV3.accent,
                  ),
                  child: Text(
                    'Save',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Time configuration save/load methods
  Future<void> _saveTimeConfiguration() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final Map<String, String> timeConfig = {};
      
      _tempTimes.forEach((mealType, time) {
        if (time != null) {
          timeConfig[mealType] = '${time.hour}:${time.minute}';
        }
      });
      
      await prefs.setString('meal_times_config', json.encode(timeConfig));
      print('Time configuration saved: $timeConfig'); // Debug logging
    } catch (e) {
      print('Error saving time configuration: $e');
    }
  }

}
