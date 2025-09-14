import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/meal_model_v3.dart';
import '../services/firestore_service_v3.dart';
import '../services/ai_meal_recommendation_service.dart';
import 'payment_page_v3.dart';

/// Schedule review page for AI meal planning workflow
class AIScheduleReviewPageV3 extends StatefulWidget {
  final AIMealPlan mealPlan;
  final AddressModelV3 deliveryAddress;
  
  const AIScheduleReviewPageV3({
    super.key,
    required this.mealPlan,
    required this.deliveryAddress,
  });

  @override
  State<AIScheduleReviewPageV3> createState() => _AIScheduleReviewPageV3State();
}

class _AIScheduleReviewPageV3State extends State<AIScheduleReviewPageV3> {
  bool _isLoading = false;
  List<String> _selectedDeliveryDays = [];
  List<String> _selectedMealTimes = [];
  final Map<String, List<MealModelV3>> _weeklyMeals = {};

  @override
  void initState() {
    super.initState();
    _initializeSchedule();
  }

  void _initializeSchedule() {
    final schedule = widget.mealPlan.schedule;
    _selectedDeliveryDays = List.from(schedule.deliveryDays);
    _selectedMealTimes = List.from(schedule.mealTimes);
    _weeklyMeals.addAll(schedule.weeklyMeals);
  }

  double get _totalWeeklyPrice {
    double total = 0;
    for (final dayMeals in _weeklyMeals.values) {
      for (final meal in dayMeals) {
        total += meal.price;
      }
    }
    return total > 0 ? total : widget.mealPlan.meals.length * 12.99; // Fallback pricing
  }

  Future<void> _proceedToPayment() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to continue')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Save the AI meal plan to user profile
      await FirestoreServiceV3.updateUserProfile(user.uid, {
        'activeMealPlan': widget.mealPlan.toJson(),
        'selectedDeliveryDays': _selectedDeliveryDays,
        'selectedMealTimes': _selectedMealTimes,
        'deliveryAddress': widget.deliveryAddress.toJson(),
        'lastAIPlanUpdate': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        // Create a MealPlanModelV3 for the AI plan
        final aiMealPlan = MealPlanModelV3(
          id: 'ai_plan_${DateTime.now().millisecondsSinceEpoch}',
          userId: FirebaseAuth.instance.currentUser?.uid ?? '',
          name: 'AI Generated Plan',
          displayName: 'AI Optimized ${widget.mealPlan.goal}',
          mealsPerDay: widget.mealPlan.mealsPerDay,
          pricePerWeek: _totalWeeklyPrice,
          description: 'AI-optimized meal plan based on your preferences',
        );
        
        // Convert weekly meals to the format expected by PaymentPageV3
        final selectedMeals = <String, Map<String, MealModelV3?>>{};
        for (final entry in _weeklyMeals.entries) {
          final dayMeals = <String, MealModelV3?>{};
          for (int i = 0; i < entry.value.length; i++) {
            dayMeals['meal_$i'] = entry.value[i];
          }
          selectedMeals[entry.key] = dayMeals;
        }
        
        // Convert delivery schedule to expected format
        final weeklySchedule = <String, Map<String, dynamic>>{};
        for (final day in _selectedDeliveryDays) {
          weeklySchedule[day] = {
            'isDeliveryDay': true,
            'meals': _weeklyMeals[day]?.map((m) => m.toJson()).toList() ?? [],
            'mealTimes': _selectedMealTimes,
          };
        }
        
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PaymentPageV3(
              mealPlan: aiMealPlan,
              weeklySchedule: weeklySchedule,
              selectedMeals: selectedMeals,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving meal plan: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _updateDeliveryDays(String day, bool selected) {
    setState(() {
      if (selected) {
        if (!_selectedDeliveryDays.contains(day)) {
          _selectedDeliveryDays.add(day);
        }
      } else {
        _selectedDeliveryDays.remove(day);
      }
    });
  }

  void _updateMealTime(int index, String newTime) {
    setState(() {
      if (index < _selectedMealTimes.length) {
        _selectedMealTimes[index] = newTime;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Your Schedule'),
        backgroundColor: Colors.green[600],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // AI Plan Summary Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.smart_toy, color: Colors.green[600], size: 24),
                        const SizedBox(width: 8),
                        Text(
                          'AI-Optimized Plan',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.green[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildStatChip('${widget.mealPlan.meals.length} Meals', Icons.restaurant),
                        const SizedBox(width: 8),
                        _buildStatChip('${widget.mealPlan.mealsPerDay}/day', Icons.schedule),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildStatChip('${widget.mealPlan.nutritionSummary['calories']?.toInt() ?? 0} cal', Icons.local_fire_department),
                        const SizedBox(width: 8),
                        _buildStatChip('${widget.mealPlan.nutritionSummary['protein']?.toInt() ?? 0}g protein', Icons.fitness_center),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Goal: ${widget.mealPlan.goal}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Delivery Schedule Section
            Text(
              'Delivery Schedule',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Delivery Days',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']
                          .map((day) => FilterChip(
                                label: Text(day.substring(0, 3)),
                                selected: _selectedDeliveryDays.contains(day),
                                onSelected: (selected) => _updateDeliveryDays(day, selected),
                                selectedColor: Colors.green[100],
                                checkmarkColor: Colors.green[700],
                              ))
                          .toList(),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Meal Times Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Meal Times',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._selectedMealTimes.asMap().entries.map((entry) {
                      final index = entry.key;
                      final time = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text('Meal ${index + 1}:'),
                            ),
                            SizedBox(
                              width: 120,
                              child: DropdownButtonFormField<String>(
                                value: time,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                items: [
                                  '7:00 AM', '8:00 AM', '9:00 AM', '10:00 AM',
                                  '11:00 AM', '12:00 PM', '1:00 PM', '2:00 PM',
                                  '3:00 PM', '4:00 PM', '5:00 PM', '6:00 PM',
                                  '7:00 PM', '8:00 PM', '9:00 PM'
                                ].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                                onChanged: (newTime) {
                                  if (newTime != null) {
                                    _updateMealTime(index, newTime);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Weekly Meal Preview
            Text(
              'Weekly Meal Preview',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            
            ..._weeklyMeals.entries.map((entry) {
              final day = entry.key;
              final meals = entry.value;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ExpansionTile(
                  title: Text(
                    day,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('${meals.length} meals'),
                  children: meals.map((meal) => ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      backgroundColor: Colors.green[100],
                      child: Icon(meal.icon, color: Colors.green[700], size: 16),
                    ),
                    title: Text(meal.name, style: const TextStyle(fontSize: 14)),
                    subtitle: Text('${meal.calories} cal • ${meal.protein}g protein'),
                    trailing: Text(
                      '\$${meal.price > 0 ? meal.price.toStringAsFixed(2) : '12.99'}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                      ),
                    ),
                  )).toList(),
                ),
              );
            }),
            
            const SizedBox(height: 24),
            
            // Delivery Address
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Delivery Address',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          widget.deliveryAddress.type == 'home' ? Icons.home : Icons.work,
                          color: Colors.green[600],
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.deliveryAddress.displayAddress,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                    if (widget.deliveryAddress.specialInstructions.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Instructions: ${widget.deliveryAddress.specialInstructions}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Price Summary
            Card(
              color: Colors.green[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Weekly Total',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '\$${_totalWeeklyPrice.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Includes ${widget.mealPlan.meals.length} meals • Free delivery',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Proceed to Payment Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading || _selectedDeliveryDays.isEmpty ? null : _proceedToPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Proceed to Payment',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.payment, size: 24),
                        ],
                      ),
              ),
            ),
            
            if (_selectedDeliveryDays.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Please select at least one delivery day',
                  style: TextStyle(
                    color: Colors.red[600],
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.green[100],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.green[700]),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.green[700],
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
