import 'package:flutter/material.dart';
import 'add_address_page.dart';
import 'subscription_payment_page.dart';
import '../models/subscription.dart';
import '../theme/app_theme.dart';

class SubscriptionSetupPage extends StatefulWidget {
  const SubscriptionSetupPage({super.key});

  @override
  State<SubscriptionSetupPage> createState() => _SubscriptionSetupPageState();
}

class _SubscriptionSetupPageState extends State<SubscriptionSetupPage> {
  int? selectedMealPlan;
  List<Map<String, dynamic>> savedAddresses = [];
  Map<String, List<Map<String, dynamic>>> weeklySchedule = {};
  
  final List<String> daysOfWeek = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];
  
  final List<String> mealTypes = ['Breakfast', 'Lunch', 'Dinner'];
  
  // Sample time slots (would be dynamic based on kitchen hours)
  final List<String> timeSlots = [
    '7:00 AM', '7:30 AM', '8:00 AM', '8:30 AM', '9:00 AM',
    '12:00 PM', '12:30 PM', '1:00 PM', '1:30 PM', '2:00 PM',
    '6:00 PM', '6:30 PM', '7:00 PM', '7:30 PM', '8:00 PM',
  ];

  @override
  void initState() {
    super.initState();
    // Initialize empty schedule for all days
    for (String day in daysOfWeek) {
      weeklySchedule[day] = [];
    }
  }

  bool get _canProceed {
    if (selectedMealPlan == null) return false;
    
    // Check if all selected days have the required number of meals
    for (String day in daysOfWeek) {
      final dayMeals = weeklySchedule[day] ?? [];
      if (dayMeals.isNotEmpty && dayMeals.length != selectedMealPlan) {
        return false;
      }
    }
    
    // At least one day must be configured
    return weeklySchedule.values.any((meals) => meals.isNotEmpty);
  }

  void _addMealSlot() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String? selectedDay;
        String? selectedMealType;
        String? selectedTime;
        String? selectedAddress;
        
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Meal Delivery'),
              content: SizedBox(
                width: 300,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Day selection
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Day of the week',
                        border: OutlineInputBorder(),
                      ),
                      value: selectedDay,
                      items: daysOfWeek.map((day) {
                        final currentMeals = weeklySchedule[day]?.length ?? 0;
                        final canAdd = selectedMealPlan == null || currentMeals < selectedMealPlan!;
                        
                        return DropdownMenuItem(
                          value: day,
                          enabled: canAdd,
                          child: Text(
                            '$day ($currentMeals/${selectedMealPlan ?? 0} meals)',
                            style: TextStyle(
                              color: canAdd ? Colors.black : Colors.grey,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          selectedDay = value;
                        });
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Meal type selection
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Meal of the day',
                        border: OutlineInputBorder(),
                      ),
                      value: selectedMealType,
                      items: mealTypes.map((meal) {
                        return DropdownMenuItem(
                          value: meal,
                          child: Text(meal),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          selectedMealType = value;
                        });
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Time selection
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Delivery time',
                        border: OutlineInputBorder(),
                      ),
                      value: selectedTime,
                      items: timeSlots.map((time) {
                        return DropdownMenuItem(
                          value: time,
                          child: Text(time),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          selectedTime = value;
                        });
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Address selection
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            decoration: const InputDecoration(
                              labelText: 'Delivery address',
                              border: OutlineInputBorder(),
                            ),
                            value: selectedAddress,
                            items: [
                              ...savedAddresses.map((address) {
                                return DropdownMenuItem(
                                  value: address['id'],
                                  child: Text(address['label']),
                                );
                              }),
                              const DropdownMenuItem(
                                value: 'add_new',
                                child: Text('+ Add New Address'),
                              ),
                            ],
                            onChanged: (value) async {
                              if (value == 'add_new') {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const AddAddressPage(),
                                  ),
                                );
                                if (result != null) {
                                  setState(() {
                                    savedAddresses.add(result);
                                  });
                                  setDialogState(() {
                                    selectedAddress = result['id'];
                                  });
                                }
                              } else {
                                setDialogState(() {
                                  selectedAddress = value;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: (selectedDay != null && 
                              selectedMealType != null && 
                              selectedTime != null && 
                              selectedAddress != null)
                      ? () {
                          setState(() {
                            weeklySchedule[selectedDay!]?.add({
                              'mealType': selectedMealType,
                              'time': selectedTime,
                              'address': selectedAddress,
                            });
                          });
                          Navigator.pop(context);
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D5A2D),
                  ),
                  child: const Text('Save', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _proceedToMealSchedule() {
    // Navigate to subscription payment page
    final selectedPlan = selectedMealPlan == 1 
        ? SubscriptionPlan.oneMeal 
        : SubscriptionPlan.twoMeal;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SubscriptionPaymentPage(
          selectedPlan: selectedPlan,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Text(
                'SELECT MEAL PLAN',
                style: AppTheme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: AppTheme.textPrimary,
                ),
              ),
              
              const SizedBox(height: 30),
              
              // Meal plan options
              Row(
                children: [
                  Expanded(child: _buildMealPlanCard(1)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildMealPlanCard(2)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildMealPlanCard(3)),
                ],
              ),
              
              if (selectedMealPlan != null) ...[
                const SizedBox(height: 40),
                
                // Customization section
                Text(
                  'CUSTOMIZE WEEKLY DELIVERY SCHEDULE',
                  style: AppTheme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                    color: AppTheme.textPrimary,
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Current schedule display
                Expanded(
                  child: Column(
                    children: [
                      // Schedule list
                      Expanded(
                        child: weeklySchedule.values.any((meals) => meals.isNotEmpty)
                            ? ListView.builder(
                                itemCount: daysOfWeek.length,
                                itemBuilder: (context, index) {
                                  final day = daysOfWeek[index];
                                  final dayMeals = weeklySchedule[day] ?? [];
                                  
                                  if (dayMeals.isEmpty) return const SizedBox();
                                  
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: AppTheme.surface,
                                      border: Border.all(color: AppTheme.border),
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: AppTheme.cardShadow,
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              day,
                                              style: AppTheme.textTheme.titleMedium?.copyWith(
                                                fontWeight: FontWeight.w600,
                                                color: AppTheme.textPrimary,
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: dayMeals.length == selectedMealPlan 
                                                    ? AppTheme.success.withValues(alpha: 0.2) 
                                                    : AppTheme.warning.withValues(alpha: 0.2),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                '${dayMeals.length}/$selectedMealPlan meals',
                                                style: AppTheme.textTheme.bodySmall?.copyWith(
                                                  fontWeight: FontWeight.w500,
                                                  color: dayMeals.length == selectedMealPlan 
                                                      ? AppTheme.success 
                                                      : AppTheme.warning,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        ...dayMeals.map((meal) {
                                          final address = savedAddresses.firstWhere(
                                            (addr) => addr['id'] == meal['address'],
                                            orElse: () => {'label': 'Unknown Address'},
                                          );
                                          return Padding(
                                            padding: const EdgeInsets.only(bottom: 4),
                                            child: Text(
                                              '${meal['mealType']} at ${meal['time']} → ${address['label']}',
                                              style: AppTheme.textTheme.bodyMedium?.copyWith(
                                                color: AppTheme.textSecondary,
                                              ),
                                            ),
                                          );
                                        }),
                                      ],
                                    ),
                                  );
                                },
                              )
                            : Center(
                                child: Text(
                                  'No meals scheduled yet.\nTap "Add another" to start.',
                                  textAlign: TextAlign.center,
                                  style: AppTheme.textTheme.bodyLarge?.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                      ),
                      
                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _addMealSlot,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.accent,
                                side: BorderSide(color: AppTheme.accent),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'ADD ANOTHER',
                                style: AppTheme.textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _canProceed ? _proceedToMealSchedule : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.accent,
                                foregroundColor: AppTheme.textPrimary,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 8,
                                shadowColor: AppTheme.accent.withValues(alpha: 0.3),
                              ),
                              child: Text(
                                'GO TO MEAL SCHEDULE',
                                style: AppTheme.textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMealPlanCard(int mealsPerDay) {
    final isSelected = selectedMealPlan == mealsPerDay;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedMealPlan = mealsPerDay;
          // Reset schedule when changing plan
          for (String day in daysOfWeek) {
            weeklySchedule[day] = [];
          }
        });
      },
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? AppTheme.accent : AppTheme.border,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isSelected ? AppTheme.accent.withValues(alpha: 0.2) : AppTheme.surface,
          boxShadow: isSelected ? AppTheme.cardShadow : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$mealsPerDay',
              style: AppTheme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: isSelected ? AppTheme.accent : AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'meal${mealsPerDay > 1 ? 's' : ''}/day',
              style: AppTheme.textTheme.bodyMedium?.copyWith(
                color: isSelected ? AppTheme.accent : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
