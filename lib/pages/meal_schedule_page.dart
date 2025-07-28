import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/meal_schedule.dart';
import '../models/meal.dart';
import '../models/user_profile.dart';
import '../models/subscription.dart';
import '../services/meal_schedule_service.dart';
import '../services/meal_service.dart';
import '../services/user_service.dart';
import '../services/subscription_service.dart';
import '../theme/app_theme.dart';
import 'subscription_payment_page.dart';

class MealSchedulePage extends StatefulWidget {
  final bool isSignupFlow;
  
  const MealSchedulePage({
    super.key,
    this.isSignupFlow = false,
  });

  @override
  State<MealSchedulePage> createState() => _MealSchedulePageState();
}

class _MealSchedulePageState extends State<MealSchedulePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Data
  UserProfile? _userProfile;
  Subscription? _userSubscription;
  List<MealSchedule> _userSchedules = [];
  MealSchedule? _selectedSchedule;
  List<Meal> _breakfastMeals = [];
  List<Meal> _lunchMeals = [];
  List<Meal> _dinnerMeals = [];
  
  // State
  bool _isLoading = true;
  MealType _selectedMealType = MealType.breakfast;
  bool _autoSelectDay = false;
  bool _autoSelectWeek = false;
  bool _isCustomizingWeek = false;
  String _selectedDate = '';
  List<String> _weekDates = [];
  int _currentWeekDayIndex = 0;
  
  // Selected meals for current view
  DailyMeals _currentDailyMeals = DailyMeals();
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _selectedDate = MealScheduleService.formatDateForStorage(DateTime.now());
    _generateWeekDates();
    _loadInitialData();
    
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _selectedMealType = MealType.values[_tabController.index];
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _generateWeekDates() {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    _weekDates = List.generate(7, (index) {
      final date = startOfWeek.add(Duration(days: index));
      return MealScheduleService.formatDateForStorage(date);
    });
  }

  Future<void> _loadInitialData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Load user profile
      _userProfile = await UserService.getUserProfile(user.uid);
      
      // Check if user has active subscription
      _userSubscription = await SubscriptionService.getUserSubscription(user.uid);
      
      if (_userSubscription == null) {
        // No active subscription - redirect to subscription setup
        if (mounted) {
          _showSubscriptionRequiredDialog();
        }
        return;
      }
      
      // Load user schedules
      _userSchedules = await MealScheduleService.getUserMealSchedules(user.uid);
      
      // Set selected schedule (active or first available)
      if (_userSchedules.isNotEmpty) {
        _selectedSchedule = _userSchedules.firstWhere(
          (schedule) => schedule.isActive,
          orElse: () => _userSchedules.first,
        );
        
        // Load current daily meals
        _currentDailyMeals = _selectedSchedule!.weeklyMeals[_selectedDate] ?? DailyMeals();
      }
      
      // Load meals by type
      await _loadMealsByType();
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Failed to load data: $e');
    }
  }

  Future<void> _loadMealsByType() async {
    try {
      final futures = await Future.wait([
        MealService.getMealsByType(MealType.breakfast),
        MealService.getMealsByType(MealType.lunch),
        MealService.getMealsByType(MealType.dinner),
      ]);
      
      _breakfastMeals = futures[0];
      _lunchMeals = futures[1];
      _dinnerMeals = futures[2];
    } catch (e) {
      _showErrorSnackBar('Failed to load meals: $e');
    }
  }

  List<Meal> _getCurrentMealList() {
    switch (_selectedMealType) {
      case MealType.breakfast:
        return _breakfastMeals;
      case MealType.lunch:
        return _lunchMeals;
      case MealType.dinner:
        return _dinnerMeals;
    }
  }

  List<String> _getCurrentSelectedMealIds() {
    return _currentDailyMeals.getMealsByType(_selectedMealType);
  }

  int get _maxMealsAllowed {
    if (_userProfile?.subscriptionPlan == '1-meal') return 1;
    if (_userProfile?.subscriptionPlan == '2-meal') return 2;
    return 2; // Default to 2-meal plan
  }

  Future<void> _autoSelectMeals(bool forWeek) async {
    try {
      final randomMeals = await MealService.getRandomMealsByType(
        _selectedMealType, 
        _maxMealsAllowed,
      );
      
      final selectedMealIds = randomMeals.map((meal) => meal.id).toList();
      
      if (forWeek) {
        // Apply to entire week
        final newDailyMeals = _updateDailyMealsForType(_currentDailyMeals, _selectedMealType, selectedMealIds);
        await MealScheduleService.applyMealsToWeek(
          _selectedSchedule!.id,
          newDailyMeals,
          _weekDates,
        );
      } else {
        // Apply to current day only
        await _updateMealsForCurrentDate(selectedMealIds);
      }
      
      _showSuccessSnackBar('Meals auto-selected successfully!');
    } catch (e) {
      _showErrorSnackBar('Failed to auto-select meals: $e');
    }
  }

  DailyMeals _updateDailyMealsForType(DailyMeals dailyMeals, MealType mealType, List<String> mealIds) {
    switch (mealType) {
      case MealType.breakfast:
        return dailyMeals.copyWith(breakfastMealIds: mealIds);
      case MealType.lunch:
        return dailyMeals.copyWith(lunchMealIds: mealIds);
      case MealType.dinner:
        return dailyMeals.copyWith(dinnerMealIds: mealIds);
    }
  }

  Future<void> _updateMealsForCurrentDate(List<String> mealIds) async {
    if (_selectedSchedule == null) return;
    
    try {
      await MealScheduleService.updateMealsForDate(
        _selectedSchedule!.id,
        _isCustomizingWeek ? _weekDates[_currentWeekDayIndex] : _selectedDate,
        _selectedMealType,
        mealIds,
      );
      
      // Update local state
      setState(() {
        _currentDailyMeals = _updateDailyMealsForType(_currentDailyMeals, _selectedMealType, mealIds);
      });
    } catch (e) {
      _showErrorSnackBar('Failed to update meals: $e');
    }
  }

  Future<void> _confirmMealsForToday() async {
    if (_selectedSchedule == null) return;
    
    try {
      await MealScheduleService.updateDailyMeals(
        _selectedSchedule!.id,
        _selectedDate,
        _currentDailyMeals,
      );
      _showSuccessSnackBar('Meals confirmed for today!');
    } catch (e) {
      _showErrorSnackBar('Failed to confirm meals: $e');
    }
  }

  Future<void> _saveForWholeWeek() async {
    if (_selectedSchedule == null) return;
    
    try {
      await MealScheduleService.applyMealsToWeek(
        _selectedSchedule!.id,
        _currentDailyMeals,
        _weekDates,
      );
      _showSuccessSnackBar('Meals saved for the whole week!');
    } catch (e) {
      _showErrorSnackBar('Failed to save meals for week: $e');
    }
  }

  void _toggleCustomizeWeek() {
    setState(() {
      _isCustomizingWeek = !_isCustomizingWeek;
      if (_isCustomizingWeek) {
        _currentWeekDayIndex = 0;
        _loadMealsForWeekDay(0);
      } else {
        _loadMealsForCurrentDate();
      }
    });
  }

  Future<void> _loadMealsForWeekDay(int dayIndex) async {
    if (_selectedSchedule == null) return;
    
    try {
      final dateString = _weekDates[dayIndex];
      final dailyMeals = await MealScheduleService.getMealsForDate(_selectedSchedule!.id, dateString);
      
      setState(() {
        _currentWeekDayIndex = dayIndex;
        _currentDailyMeals = dailyMeals ?? DailyMeals();
      });
    } catch (e) {
      _showErrorSnackBar('Failed to load meals for selected day: $e');
    }
  }

  Future<void> _loadMealsForCurrentDate() async {
    if (_selectedSchedule == null) return;
    
    try {
      final dailyMeals = await MealScheduleService.getMealsForDate(_selectedSchedule!.id, _selectedDate);
      setState(() {
        _currentDailyMeals = dailyMeals ?? DailyMeals();
      });
    } catch (e) {
      _showErrorSnackBar('Failed to load meals for current date: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showSubscriptionRequiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.payment, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Text('Subscription Required'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('You need an active subscription to access meal scheduling.'),
            SizedBox(height: 16),
            Text('Choose a subscription plan to continue:'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.pop(context); // Go back to portal
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SubscriptionPaymentPage(
                    selectedPlan: SubscriptionPlan.oneMeal,
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('1 Meal Plan - \$89.99/month'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SubscriptionPaymentPage(
                    selectedPlan: SubscriptionPlan.twoMeal,
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('2 Meal Plan - \$159.99/month'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: Text(
            'MEAL SCHEDULE',
            style: AppTheme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: AppTheme.textPrimary,
            ),
          ),
          backgroundColor: AppTheme.background,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: AppLoadingIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'FRESHPUNK MEAL SCHEDULE',
          style: AppTheme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
            color: AppTheme.textPrimary,
          ),
        ),
        backgroundColor: AppTheme.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.5,
            colors: [
              AppTheme.background,
              AppTheme.surface.withValues(alpha: 0.2),
              AppTheme.background,
            ],
          ),
        ),
        child: Column(
          children: [
            // Schedule Selection Section
            _buildScheduleSelection(),
            
            // Meal Type Tabs
            _buildMealTypeTabs(),
            
            // Day Selection (when customizing week)
            if (_isCustomizingWeek) _buildWeekDaySelector(),
            
            // Auto Selection Switches
            _buildAutoSelectionSwitches(),
            
            // Meals List
            Expanded(
              child: _buildMealsList(),
            ),
            
            // Action Buttons
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleSelection() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Delivery Schedule',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<MealSchedule>(
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            value: _selectedSchedule,
            hint: const Text('Select delivery schedule'),
            items: [
              ..._userSchedules.map((schedule) => DropdownMenuItem(
                value: schedule,
                child: Text(schedule.scheduleName),
              )),
              const DropdownMenuItem(
                value: null,
                child: Text('+ Add new schedule'),
              ),
            ],
            onChanged: (schedule) {
              if (schedule == null) {
                // TODO: Navigate to create new schedule page
                _showErrorSnackBar('Create new schedule feature coming soon!');
              } else {
                setState(() {
                  _selectedSchedule = schedule;
                });
                _loadMealsForCurrentDate();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMealTypeTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: Theme.of(context).primaryColor,
          borderRadius: BorderRadius.circular(8),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.black54,
        tabs: const [
          Tab(text: 'Breakfast'),
          Tab(text: 'Lunch'),
          Tab(text: 'Dinner'),
        ],
      ),
    );
  }

  Widget _buildWeekDaySelector() {
    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Day',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(7, (index) {
              final isSelected = index == _currentWeekDayIndex;
              return GestureDetector(
                onTap: () => _loadMealsForWeekDay(index),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? Theme.of(context).primaryColor : Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    dayNames[index],
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.black54,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildAutoSelectionSwitches() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: SwitchListTile(
              title: const Text('Auto-select for the day'),
              value: _autoSelectDay,
              onChanged: (value) {
                setState(() {
                  _autoSelectDay = value;
                });
                if (value) {
                  _autoSelectMeals(false);
                }
              },
            ),
          ),
          Expanded(
            child: SwitchListTile(
              title: const Text('Auto-select for the week'),
              value: _autoSelectWeek,
              onChanged: (value) {
                setState(() {
                  _autoSelectWeek = value;
                });
                if (value) {
                  _autoSelectMeals(true);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealsList() {
    final meals = _getCurrentMealList();
    final selectedMealIds = _getCurrentSelectedMealIds().toSet();
    
    if (meals.isEmpty) {
      return const Center(
        child: Text('No meals available for this meal type'),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: meals.length,
      itemBuilder: (context, index) {
        final meal = meals[index];
        final isSelected = selectedMealIds.contains(meal.id);
        final canSelect = !isSelected && selectedMealIds.length < _maxMealsAllowed;
        
        return _buildMealCard(meal, isSelected, canSelect);
      },
    );
  }

  Widget _buildMealCard(Meal meal, bool isSelected, bool canSelect) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: ExpansionTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            meal.imageUrl,
            width: 60,
            height: 60,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: 60,
                height: 60,
                color: Colors.grey[300],
                child: const Icon(Icons.fastfood),
              );
            },
          ),
        ),
        title: Text(
          meal.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          meal.description,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected)
              IconButton(
                icon: const Icon(Icons.remove_circle, color: Colors.red),
                onPressed: () => _toggleMealSelection(meal.id, false),
              )
            else if (canSelect)
              IconButton(
                icon: const Icon(Icons.add_circle, color: Colors.green),
                onPressed: () => _toggleMealSelection(meal.id, true),
              )
            else
              IconButton(
                icon: const Icon(Icons.add_circle, color: Colors.grey),
                onPressed: null,
              ),
            IconButton(
              icon: const Icon(Icons.restaurant_menu),
              onPressed: () => _showMealMenu(meal),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Nutrition Information',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text('Calories: ${meal.nutrition.calories}'),
                Text('Protein: ${meal.nutrition.protein}g'),
                Text('Carbs: ${meal.nutrition.carbohydrates}g'),
                Text('Fat: ${meal.nutrition.fat}g'),
                const SizedBox(height: 16),
                const Text(
                  'Ingredients',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(meal.ingredients.join(', ')),
                if (meal.allergyWarnings.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Allergy Warnings',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    meal.allergyWarnings.join(', '),
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _toggleMealSelection(String mealId, bool add) {
    final currentMealIds = _getCurrentSelectedMealIds().toList();
    
    if (add) {
      if (currentMealIds.length < _maxMealsAllowed) {
        currentMealIds.add(mealId);
      }
    } else {
      currentMealIds.remove(mealId);
    }
    
    _updateMealsForCurrentDate(currentMealIds);
  }

  void _showMealMenu(Meal meal) {
    // TODO: Show meal selection menu/dialog
    _showErrorSnackBar('Meal menu feature coming soon!');
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (!_isCustomizingWeek) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _confirmMealsForToday,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Confirm for Today'),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saveForWholeWeek,
                    child: const Text('Save for the Week'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _toggleCustomizeWeek,
                    child: const Text('Customize for the Week'),
                  ),
                ),
              ],
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _toggleCustomizeWeek,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Done Customizing'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
