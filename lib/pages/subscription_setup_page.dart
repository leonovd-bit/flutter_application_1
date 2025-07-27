import 'package:flutter/material.dart';
import 'add_address_page.dart';
import 'subscription_payment_page.dart';
import '../models/subscription.dart';

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
                            '$day (${currentMeals}/${selectedMealPlan ?? 0} meals)',
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
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
              const Text(
                'Select Meal Plan',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
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
                const Text(
                  'Customize weekly delivery schedule',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
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
                                      border: Border.all(color: Colors.grey[300]!),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              day,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: dayMeals.length == selectedMealPlan 
                                                    ? Colors.green[100] 
                                                    : Colors.orange[100],
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                '${dayMeals.length}/$selectedMealPlan meals',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                  color: dayMeals.length == selectedMealPlan 
                                                      ? Colors.green[800] 
                                                      : Colors.orange[800],
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
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey[600],
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
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[500],
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
                                foregroundColor: const Color(0xFF2D5A2D),
                                side: const BorderSide(color: Color(0xFF2D5A2D)),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Add another'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _canProceed ? _proceedToMealSchedule : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Go to Meal Schedule'),
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
            color: isSelected ? const Color(0xFF2D5A2D) : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isSelected ? const Color(0xFF2D5A2D).withOpacity(0.1) : Colors.white,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$mealsPerDay',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isSelected ? const Color(0xFF2D5A2D) : Colors.black,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'meal${mealsPerDay > 1 ? 's' : ''}/day',
              style: TextStyle(
                fontSize: 14,
                color: isSelected ? const Color(0xFF2D5A2D) : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
