import 'package:flutter/material.dart';
import '../theme/app_theme_v3.dart';
import '../models/meal_model_v3.dart';
import '../services/firestore_service_v3.dart';

class MealScheduleScreen extends StatefulWidget {
  final int mealsPerDay;
  final List<Map<String, dynamic>> selectedMeals;
  final String deliveryAddress;

  const MealScheduleScreen({
    super.key,
    required this.mealsPerDay,
    required this.selectedMeals,
    required this.deliveryAddress,
  });

  @override
  State<MealScheduleScreen> createState() => _MealScheduleScreenState();
}

class _MealScheduleScreenState extends State<MealScheduleScreen> {
  final List<String> _weekDays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];
  
  Map<String, List<Map<String, dynamic>>> _weeklySchedule = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeSchedule();
  }

  void _initializeSchedule() {
    for (String day in _weekDays) {
      _weeklySchedule[day] = List.generate(
        widget.mealsPerDay,
        (index) => Map<String, dynamic>.from(widget.selectedMeals[index % widget.selectedMeals.length]),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeV3.background,
      appBar: AppBar(
        backgroundColor: AppThemeV3.surface,
        elevation: 0,
        title: Text(
          'Meal Schedule',
          style: AppThemeV3.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Schedule summary
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
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
                  'Schedule Summary',
                  style: AppThemeV3.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text('${widget.mealsPerDay} meals per day'),
                Text('Delivery: ${widget.deliveryAddress}'),
              ],
            ),
          ),
          
          // Weekly schedule
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _weekDays.length,
              itemBuilder: (context, index) {
                final day = _weekDays[index];
                final dayMeals = _weeklySchedule[day] ?? [];
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          day,
                          style: AppThemeV3.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...dayMeals.asMap().entries.map((entry) {
                          final mealIndex = entry.key;
                          final meal = entry.value;
                          final mealType = _getMealType(mealIndex);
                          
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                // Meal image
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: meal['image'].toString().startsWith('assets/')
                                      ? Image.asset(
                                          meal['image'],
                                          width: 60,
                                          height: 60,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return Container(
                                              width: 60,
                                              height: 60,
                                              color: AppThemeV3.surface,
                                              child: Icon(
                                                Icons.fastfood,
                                                color: AppThemeV3.accent,
                                              ),
                                            );
                                          },
                                        )
                                      : Image.network(
                                          meal['image'],
                                          width: 60,
                                          height: 60,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return Container(
                                              width: 60,
                                              height: 60,
                                              color: AppThemeV3.surface,
                                              child: Icon(
                                                Icons.fastfood,
                                                color: AppThemeV3.accent,
                                              ),
                                            );
                                          },
                                        ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '$mealType: ${meal['name']}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        meal['description'] ?? '',
                                        style: TextStyle(
                                          color: AppThemeV3.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                      Text(
                                        '\$${meal['price'].toStringAsFixed(2)}',
                                        style: TextStyle(
                                          color: AppThemeV3.accent,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Confirm button
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _confirmSchedule,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppThemeV3.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'Confirm Schedule',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  String _getMealType(int index) {
    switch (widget.mealsPerDay) {
      case 1:
        return 'Breakfast';
      case 2:
        return index == 0 ? 'Breakfast' : 'Dinner';
      case 3:
        return ['Breakfast', 'Lunch', 'Dinner'][index];
      default:
        return 'Meal ${index + 1}';
    }
  }

  Future<void> _confirmSchedule() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userId = FirestoreServiceV3.getCurrentUserId();
      if (userId != null) {
        // Save user's meal schedule and selections
        await FirestoreServiceV3.saveUserMealSchedule(
          userId,
          _weeklySchedule,
          widget.deliveryAddress,
          widget.mealsPerDay,
        );

        // Update Circle of Health with actual meal names
        await _updateCircleOfHealth(userId);
        
        // Create upcoming orders based on this schedule
        await _createUpcomingOrders(userId);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Schedule confirmed! Your meals are now set up.'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Navigate back to home or wherever appropriate
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving schedule: $e'),
            backgroundColor: Colors.red,
          ),
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

  Future<void> _updateCircleOfHealth(String userId) async {
    try {
      // Extract unique meal names from the schedule
      final Set<String> uniqueMealNames = {};
      for (final dayMeals in _weeklySchedule.values) {
        for (final meal in dayMeals) {
          uniqueMealNames.add(meal['name']);
        }
      }

      // Save meal names to user profile for Circle of Health display
      await FirestoreServiceV3.saveUserPreference(
        userId,
        'selectedMealNames',
        uniqueMealNames.toList(),
      );
    } catch (e) {
      print('Error updating Circle of Health: $e');
    }
  }

  Future<void> _createUpcomingOrders(String userId) async {
    try {
      // Create upcoming orders for the next week based on the schedule
      final now = DateTime.now();
      final List<Map<String, dynamic>> upcomingOrders = [];

      for (int i = 0; i < 7; i++) {
        final deliveryDate = now.add(Duration(days: i + 1));
        final dayName = _weekDays[deliveryDate.weekday - 1];
        final dayMeals = _weeklySchedule[dayName] ?? [];

        for (int mealIndex = 0; mealIndex < dayMeals.length; mealIndex++) {
          final meal = dayMeals[mealIndex];
          final mealType = _getMealType(mealIndex);
          
          upcomingOrders.add({
            'id': 'order_${deliveryDate.millisecondsSinceEpoch}_$mealIndex',
            'userId': userId,
            'mealName': meal['name'],
            'mealType': mealType,
            'deliveryAddress': widget.deliveryAddress,
            'deliveryDate': deliveryDate,
            'price': meal['price'],
            'status': 'scheduled',
            'createdAt': now,
          });
        }
      }

      // Save upcoming orders to Firestore
      await FirestoreServiceV3.saveUpcomingOrders(userId, upcomingOrders);
    } catch (e) {
      print('Error creating upcoming orders: $e');
    }
  }
}