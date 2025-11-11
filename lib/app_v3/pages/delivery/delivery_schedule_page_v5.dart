import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/mock_user_model.dart';
import '../../services/auth/firestore_service_v3.dart';
import '../../models/meal_model_v3.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../onboarding/choose_meal_plan_page_v3.dart';
import '../meals/meal_schedule_page_v3_fixed.dart';
import '../../services/maps/simple_google_maps_service.dart';

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}

/// DeliverySchedulePageV5 - Flexible per-day meal selection
/// Users can choose different meals for different days within their plan's mealsPerDay limit
class DeliverySchedulePageV5 extends StatefulWidget {
  final String? initialScheduleName;
  final bool isSignupFlow;
  final MockUser? mockUser;
  const DeliverySchedulePageV5({
    super.key,
    this.initialScheduleName,
    this.isSignupFlow = false,
    this.mockUser,
  });

  @override
  State<DeliverySchedulePageV5> createState() => _DeliverySchedulePageV5State();
}

class _DeliverySchedulePageV5State extends State<DeliverySchedulePageV5> {
  MockUser? _mockUser;
  // Basic setup
  MealPlanModelV3? _selectedMealPlan;
  String _scheduleName = '';
  late final TextEditingController _scheduleNameInputController;

  // Controllers for "Apply to All" configuration
  final Map<String, TextEditingController> _allDaysTimeControllers = {}; // mealType -> controller
  final Map<String, TextEditingController> _allDaysAddressControllers = {}; // mealType -> controller

  // Days of week
  final List<String> _daysOfWeek = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday'
  ];

  // Day selection for bulk operations
  Set<String> _selectedDays = {};
  
  // Per-day meal selections: Map<Day, Set<MealType>>
  // Example: {'Monday': {'Breakfast', 'Dinner'}, 'Tuesday': {'Lunch', 'Dinner'}}
  Map<String, Set<String>> _dayMealSelections = {};

  // Day configurations: Map<Day, Map<MealType, {time, address}>>
  Map<String, Map<String, Map<String, dynamic>>> _dayConfigurations = {};

  // Meal type selections (breakfast, lunch, dinner)
  Set<String> _selectedMeals = {}; // Selected meal types for the schedule
  bool _applyToAllDays = false; // Apply same config to all selected days

  // Helpers
  Future<void> _pickTimeForController(TextEditingController controller) async {
    // Parse existing value like "12:30" if present
    int h = 12, m = 30;
    final text = controller.text.trim();
    final parts = text.split(':');
    if (parts.length == 2) {
      final ph = int.tryParse(parts[0]);
      final pm = int.tryParse(parts[1]);
      if (ph != null && pm != null) { h = ph; m = pm; }
    }

    DateTime temp = DateTime(0, 1, 1, h, m);
    await showCupertinoModalPopup(
      context: context,
      builder: (_) => Container(
        height: 300,
        color: Colors.white,
        child: Column(
          children: [
            SizedBox(
              height: 44,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      final hh = temp.hour.toString().padLeft(2, '0');
                      final mm = temp.minute.toString().padLeft(2, '0');
                      controller.text = '$hh:$mm';
                      Navigator.pop(context);
                    },
                    child: const Text('Done'),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                initialDateTime: temp,
                use24hFormat: true,
                onDateTimeChanged: (dt) => temp = dt,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _mockUser = widget.mockUser;
    _scheduleName = widget.initialScheduleName ?? '';
    _scheduleNameInputController = TextEditingController(text: _scheduleName);
    _loadCurrentPlan();
    _initializeDefaultSelections();
  }

  void _initializeDefaultSelections() {
    // Initialize empty selections for all days
    for (final day in _daysOfWeek) {
      _dayMealSelections[day] = {};
      _dayConfigurations[day] = {};
    }
  }

  @override
  void dispose() {
    _scheduleNameInputController.dispose();
    for (var controller in _allDaysTimeControllers.values) {
      controller.dispose();
    }
    for (var controller in _allDaysAddressControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadCurrentPlan() async {
    debugPrint('[DeliveryScheduleV5] Loading current plan...');
  final uid = _mockUser?.uid ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      debugPrint('[DeliveryScheduleV5] No user logged in');
      return;
    }

    try {
      MealPlanModelV3? plan;

      // Check SharedPreferences first
      try {
        final prefs = await SharedPreferences.getInstance();
        final planId = prefs.getString('selected_meal_plan_id');
        debugPrint('[DeliveryScheduleV5] Plan ID from SharedPreferences: $planId');
        if (planId != null && planId.isNotEmpty) {
          final available = MealPlanModelV3.getAvailablePlans();
          plan = available.firstWhere(
            (p) => p.id == planId,
            orElse: () => available.first,
          );
          debugPrint('[DeliveryScheduleV5] Loaded plan from SharedPreferences: ${plan.name}');
        }
      } catch (e) {
        debugPrint('[DeliveryScheduleV5] Error loading from SharedPreferences: $e');
      }

      // Fallback to Firestore
      if (plan == null) {
        debugPrint('[DeliveryScheduleV5] Falling back to Firestore');
        plan = await FirestoreServiceV3.getCurrentMealPlan(uid);
        debugPrint('[DeliveryScheduleV5] Loaded plan from Firestore: ${plan?.name}');
      }

      if (!mounted) return;
      setState(() {
        _selectedMealPlan = plan;
      });
      debugPrint('[DeliveryScheduleV5] Plan updated in UI: ${plan?.name}');
    } catch (e) {
      debugPrint('[DeliveryScheduleV5] Error loading plan: $e');
    }
  }

  /* PROTEIN+ METHODS REMOVED - Commenting out corrupt methods to fix compile errors
  // Build config card for all selected days (Apply to All Days enabled)
  Widget _buildAllDaysConfigCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('≡ƒÆ¬', style: TextStyle(fontSize: 24)),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Select Your Proteins',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_selectedProteins.length}/3 selected',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Choose your preferred protein options for your meals • \$9.99 per serving • Max 3 selections',
          style: TextStyle(
            fontSize: 14,
            color: Colors.black87,
          ),
        ),
        if (_selectedProteins.length >= 3) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Γ£ô Maximum protein selections reached. Deselect a protein to choose a different one.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white,
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        ...availableProteins.map((protein) {
          final isSelected = _selectedProteins.contains(protein.id);
          final isExpanded = _expandedProtein == protein.id;
          final config = _proteinConfigs[protein.id];
          final hasConfig = config != null && config.servingsPerWeek > 0;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  // Protein selection header
                  InkWell(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedProteins.remove(protein.id);
                          _proteinConfigs.remove(protein.id);
                          _expandedProtein = null;
                        } else if (_selectedProteins.length < 3) {
                          _selectedProteins.add(protein.id);
                          _expandedProtein = protein.id;
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.black : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Text(protein.emoji, style: const TextStyle(fontSize: 32)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  protein.name,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected ? Colors.white : Colors.black,
                                  ),
                                ),
                                Text(
                                  '${protein.serving} • ${protein.calories} cal • ${protein.proteinGrams}g protein',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isSelected ? Colors.grey.shade300 : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '\$${protein.price.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected ? Colors.white : Colors.black,
                                ),
                              ),
                              if (isSelected)
                                const Text(
                                  'Γ£ô',
                                  style: TextStyle(fontSize: 14, color: Colors.white),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Config summary (if configured)
                  if (isSelected && hasConfig)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(top: BorderSide(color: Colors.black, width: 2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildConfigRow('Servings:', '${config.servingsPerWeek} per week'),
                          const SizedBox(height: 4),
                          _buildConfigRow('Day:', config.deliveryDay.capitalize()),
                          const SizedBox(height: 4),
                          _buildConfigRow('Time:', config.deliveryTime),
                          if (config.deliveryAddress.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            _buildConfigRow('Location:', config.deliveryAddress, maxLines: 2),
                          ],
                        ],
                      ),
                    ),

                  // Expandable configuration
                  if (isSelected)
                    Container(
                      decoration: const BoxDecoration(
                        color: Colors.grey,
                        border: Border(top: BorderSide(color: Colors.grey, width: 1)),
                      ),
                      child: Column(
                        children: [
                          InkWell(
                            onTap: () {
                              setState(() {
                                _expandedProtein = isExpanded ? null : protein.id;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              color: Colors.grey.shade50,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    hasConfig ? 'Edit Configuration' : 'Configure Delivery',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black,
                                    ),
                                  ),
                                  Icon(
                                    isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                    color: Colors.black,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          if (isExpanded)
                            Container(
                              padding: const EdgeInsets.all(16),
                              color: Colors.white,
                              child: _buildProteinConfigForm(protein),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildConfigRow(String label, String value, {int maxLines = 1}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black87,
            ),
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildProteinConfigForm(ProteinOptionV3 protein) {
    final config = _proteinConfigs[protein.id];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Servings input
        const Text(
          'Number of Servings per Week (Max 21)',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        TextField(
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: 'Enter number of servings',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.grey, width: 2),
            ),
          ),
          onChanged: (value) {
            final servings = int.tryParse(value) ?? 0;
            if (servings > 0 && servings <= 21) {
              setState(() {
                _proteinConfigs[protein.id] = ProteinConfigV3(
                  proteinId: protein.id,
                  servingsPerWeek: servings,
                  deliveryDay: config?.deliveryDay ?? 'monday',
                  deliveryTime: config?.deliveryTime ?? '12:30',
                  deliveryAddress: config?.deliveryAddress ?? '',
                );
              });
            }
          },
        ),

        const SizedBox(height: 16),

        // Day selector
        const Text(
          'Delivery Day (Select One)',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'].map((day) {
            final dayLower = day.toLowerCase();
            final isSelected = config?.deliveryDay == dayLower;

            return InkWell(
              onTap: () {
                setState(() {
                  _proteinConfigs[protein.id] = ProteinConfigV3(
                    proteinId: protein.id,
                    servingsPerWeek: config?.servingsPerWeek ?? 1,
                    deliveryDay: dayLower,
                    deliveryTime: config?.deliveryTime ?? '12:30',
                    deliveryAddress: config?.deliveryAddress ?? '',
                  );
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.black : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? Colors.black : Colors.grey.shade300,
                    width: 2,
                  ),
                ),
                child: Text(
                  day.substring(0, 3),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : Colors.black,
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 16),

        // Time picker
        const Text(
          'Delivery Time',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        TextField(
          decoration: InputDecoration(
            hintText: '12:30',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.grey, width: 2),
            ),
          ),
          onChanged: (value) {
            setState(() {
              _proteinConfigs[protein.id] = ProteinConfigV3(
                proteinId: protein.id,
                servingsPerWeek: config?.servingsPerWeek ?? 1,
                deliveryDay: config?.deliveryDay ?? 'monday',
                deliveryTime: value,
                deliveryAddress: config?.deliveryAddress ?? '',
              );
            });
          },
        ),

        const SizedBox(height: 16),

        // Address input
        const Text(
          'Delivery Address',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        TextField(
          decoration: InputDecoration(
            hintText: '2 6th Ave, 45, New York City, NY 10013',
            prefixIcon: const Icon(Icons.location_on, size: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.grey, width: 2),
            ),
          ),
          onChanged: (value) {
            setState(() {
              _proteinConfigs[protein.id] = ProteinConfigV3(
                proteinId: protein.id,
                servingsPerWeek: config?.servingsPerWeek ?? 1,
                deliveryDay: config?.deliveryDay ?? 'monday',
                deliveryTime: config?.deliveryTime ?? '12:30',
                deliveryAddress: value,
              );
            });
          },
        ),

        const SizedBox(height: 16),

        // Done button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              setState(() {
                _expandedProtein = null;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Done',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  // Build config card for all selected days (Apply to All Days enabled)
  Widget _buildAllDaysConfigCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Configure All Selected Days',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          
          // For each selected meal type
          ..._selectedMeals.map((meal) {
            // Initialize controllers if not exists
            if (!_allDaysTimeControllers.containsKey(meal)) {
              _allDaysTimeControllers[meal] = TextEditingController(text: '12:30');
            }
            if (!_allDaysAddressControllers.containsKey(meal)) {
              _allDaysAddressControllers[meal] = TextEditingController();
            }
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    meal.capitalize(),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Time input
                  TextFormField(
                    controller: _allDaysTimeControllers[meal],
                    readOnly: true,
                    onTap: () => _pickTimeForController(_allDaysTimeControllers[meal]!),
                    decoration: InputDecoration(
                      labelText: 'Time',
                      hintText: 'e.g., 12:30',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.black, width: 2),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade400, width: 2),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.black, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Address input
                  TextFormField(
                    controller: _allDaysAddressControllers[meal],
                    decoration: InputDecoration(
                      labelText: 'Delivery Address',
                      hintText: 'Enter address',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.black, width: 2),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade400, width: 2),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.black, width: 2),
                      ),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
  */ // END PROTEIN+ METHODS REMOVED

  // Build config card for all selected days (Apply to All Days enabled)
  Widget _buildAllDaysConfigCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Configuration for All Days',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          
          // For each selected meal type
          ..._selectedMeals.map((meal) {
            // Get controller for this meal type
            final timeController = _allDaysTimeControllers.putIfAbsent(
              meal,
              () => TextEditingController(),
            );
            final addressController = _allDaysAddressControllers.putIfAbsent(
              meal,
              () => TextEditingController(),
            );

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    meal.capitalize(),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Time input
                  TextFormField(
                    controller: timeController,
                    decoration: InputDecoration(
                      labelText: 'Time',
                      hintText: 'e.g., 12:30',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.black, width: 2),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade400, width: 2),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.black, width: 2),
                      ),
                    ),
                    onTap: () => _pickTimeForController(timeController),
                    readOnly: true,
                  ),
                  const SizedBox(height: 8),
                  
                  // Address input
                  TextFormField(
                    controller: addressController,
                    decoration: InputDecoration(
                      labelText: 'Delivery Address',
                      hintText: 'Enter address',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.black, width: 2),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade400, width: 2),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.black, width: 2),
                      ),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  // Build config card for individual day
  Widget _buildDayConfigCard(String day) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            day.capitalize(),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          
          // For each selected meal type
          ..._selectedMeals.map((meal) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    meal.capitalize(),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Time input
                  TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Time',
                      hintText: 'e.g., 12:30',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.black, width: 2),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade400, width: 2),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.black, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Address input
                  TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Delivery Address',
                      hintText: 'Enter address',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.black, width: 2),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade400, width: 2),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.black, width: 2),
                      ),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  bool _validateSchedule() {
    if (_scheduleName.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a schedule name'),
          backgroundColor: Colors.black,
        ),
      );
      return false;
    }

    // Check if meals are selected
    if (_selectedMeals.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select at least one meal type'),
          backgroundColor: Colors.black,
        ),
      );
      return false;
    }

    // Check if days are selected
    if (_selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select at least one day'),
          backgroundColor: Colors.black,
        ),
      );
      return false;
    }

    return true;
  }

  Future<void> _saveSchedule() async {
    if (!_validateSchedule()) return;

    if (_selectedMealPlan == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Meal plan not loaded. Please try again.'),
          backgroundColor: Colors.black,
        ),
      );
      return;
    }

    // Build weeklySchedule from current simple structure
    // For "Apply to All", all selected days get the same meals with user-entered time/address
    Map<String, Map<String, dynamic>> weeklySchedule = {};
    
    for (final day in _selectedDays) {
      weeklySchedule[day] = {};
      for (final mealType in _selectedMeals) {
        final time = _allDaysTimeControllers[mealType]?.text.trim() ?? '12:30';
        final address = _allDaysAddressControllers[mealType]?.text.trim() ?? '';
        
        weeklySchedule[day]![mealType] = {
          'time': time,
          'address': address,
          'enabled': true,
        };
      }
    }

    debugPrint('[DeliveryScheduleV5] Saving schedule with ${weeklySchedule.length} days');
    for (final day in weeklySchedule.keys) {
      debugPrint('[DeliveryScheduleV5]   $day: ${weeklySchedule[day]!.keys.join(", ")}');
    }

    // Save schedule locally
    await _saveScheduleLocally(weeklySchedule);

    // Navigate to meal selection page
    if (mounted) {
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
  }

  Future<void> _saveScheduleLocally(Map<String, Map<String, dynamic>> weeklySchedule) async {
    try {
      final prefs = await SharedPreferences.getInstance();
  final uid = _mockUser?.uid ?? FirebaseAuth.instance.currentUser?.uid;
      final name = _scheduleName.trim();
      
      if (name.isEmpty) return;

      // Add to saved schedules list
      final listKey = uid == null ? 'saved_schedules' : 'saved_schedules_$uid';
      final existing = prefs.getStringList(listKey) ?? [];
      final seen = <String>{};
      final cleaned = <String>[];
      for (final s in existing) {
        final t = s.trim();
        if (t.isEmpty) continue;
        if (seen.add(t)) cleaned.add(t);
      }
      if (!seen.contains(name)) {
        cleaned.add(name);
      }
      await prefs.setStringList(listKey, cleaned);

      // Helper to convert TimeOfDay to "HH:mm" string format
      String timeToStr(dynamic t) {
        if (t is TimeOfDay) {
          final hh = t.hour.toString().padLeft(2, '0');
          final mm = t.minute.toString().padLeft(2, '0');
          return '$hh:$mm';
        }
        return (t ?? '').toString();
      }

      // Convert to serializable format (matching V4 format)
      final Map<String, Map<String, dynamic>> serializable = {};
      for (final day in weeklySchedule.keys) {
        serializable[day] = {};
        for (final mealType in weeklySchedule[day]!.keys) {
          final mealData = weeklySchedule[day]![mealType]!;
          serializable[day]![mealType] = {
            'time': timeToStr(mealData['time']),
            'address': mealData['address'],
          };
        }
      }

      // Get all unique meal types from the schedule
      final Set<String> allMealTypes = {};
      for (final dayMeals in weeklySchedule.values) {
        allMealTypes.addAll(dayMeals.keys);
      }

      // Create data structure matching V4 format
      final data = {
        'mealPlanId': _selectedMealPlan?.id,
        'selectedMealTypes': allMealTypes.toList(),
        'mealPlanName': _selectedMealPlan?.name,
        'mealPlanDisplayName': _selectedMealPlan?.displayName,
        'weeklySchedule': serializable,
      };

      // Save with schedule name (for loading specific schedules)
      final key = uid == null ? 'delivery_schedule_$name' : 'delivery_schedule_${uid}_$name';
      await prefs.setString(key, json.encode(data));

      // ALSO save to the key that upcoming orders expects (without schedule name)
      final upcomingOrdersKey = uid == null ? 'delivery_schedule' : 'delivery_schedule_$uid';
      await prefs.setString(upcomingOrdersKey, json.encode(serializable));
      
      // Set this as the selected schedule
      if (uid != null) {
        await prefs.setString('selected_schedule_$uid', name);
      }

      // Extract unique addresses from the schedule and save them to user_addresses
      await _saveAddressesFromSchedule(serializable, prefs, uid);

      debugPrint('[DeliveryScheduleV5] Saved schedule "$name" locally with ${serializable.length} days');
      debugPrint('[DeliveryScheduleV5] Also saved to key: $upcomingOrdersKey for upcoming orders');
    } catch (e) {
      debugPrint('[DeliveryScheduleV5] Failed to save schedule locally: $e');
    }
  }

  /// Extract unique addresses from the schedule and save them as address records
  Future<void> _saveAddressesFromSchedule(
    Map<String, Map<String, dynamic>> weeklySchedule,
    SharedPreferences prefs,
    String? uid,
  ) async {
    try {
      debugPrint('[DeliveryScheduleV5] ========== EXTRACTING ADDRESSES ==========');
      // Extract all unique addresses from the schedule
      final Set<String> uniqueAddresses = {};
      for (final dayMeals in weeklySchedule.values) {
        for (final mealData in dayMeals.values) {
          final address = (mealData['address'] ?? '').toString().trim();
          debugPrint('[DeliveryScheduleV5] Found address in schedule: "$address"');
          if (address.isNotEmpty) {
            uniqueAddresses.add(address);
          }
        }
      }

      debugPrint('[DeliveryScheduleV5] Total unique addresses found: ${uniqueAddresses.length}');
      if (uniqueAddresses.isEmpty) {
        debugPrint('[DeliveryScheduleV5] ΓÜá∩╕Å No addresses to save - schedule has no addresses!');
        return;
      }

      // Load existing addresses from both SharedPreferences and Firestore
      final addressList = prefs.getStringList('user_addresses') ?? [];
      final existingAddressStreets = <String>{};
      final Map<String, Map<String, dynamic>> existingAddressMap = {};
      
      // Parse existing addresses to avoid duplicates
      for (final jsonStr in addressList) {
        try {
          final data = json.decode(jsonStr) as Map<String, dynamic>;
          final streetAddress = (data['streetAddress'] ?? '').toString().trim().toLowerCase();
          if (streetAddress.isNotEmpty) {
            existingAddressStreets.add(streetAddress);
            existingAddressMap[streetAddress] = data;
          }
        } catch (e) {
          debugPrint('[DeliveryScheduleV5] Error parsing existing address: $e');
        }
      }

      // Add new addresses (only validated ones)
      final List<String> updatedAddressList = List<String>.from(addressList);
      int validatedCount = 0;
      int skippedCount = 0;
      
      for (final address in uniqueAddresses) {
        final normalizedAddress = address.trim().toLowerCase();
        
        // Skip if already exists
        if (existingAddressStreets.contains(normalizedAddress)) {
          debugPrint('[DeliveryScheduleV5] ΓÅ¡∩╕Å Skipping duplicate address: "$address"');
          skippedCount++;
          continue;
        }
        
        // Validate and complete the address
        final validationResult = await _validateAndCompleteAddress(address);

        // If validation failed to provide a zip (or anything), still save a minimal record
        final bool validated = validationResult['zipCode']!.isNotEmpty;
        final resolvedStreet = validated && validationResult['streetAddress']!.isNotEmpty
            ? validationResult['streetAddress']!
            : address.trim();
        final resolvedCity = validated ? validationResult['city']! : 'New York City';
        final resolvedState = validated ? validationResult['state']! : 'New York';
        final resolvedZip = validationResult['zipCode'] ?? '';

        final addressId = 'addr_${DateTime.now().millisecondsSinceEpoch}_${address.hashCode}';
          final addressData = {
            'id': addressId,
            'userId': uid ?? '',
            'label': 'Delivery Address',
            'streetAddress': resolvedStreet,
            'apartment': validationResult['apartment'] ?? '',
            'city': resolvedCity,
            'state': resolvedState,
            'zipCode': resolvedZip,
            'isDefault': existingAddressStreets.isEmpty && validatedCount == 0, // First address becomes default
            'createdAt': DateTime.now().toIso8601String(),
          };
          
          // Save to SharedPreferences
          updatedAddressList.add(json.encode(addressData));
          existingAddressStreets.add(normalizedAddress);
          validatedCount++;
          
          // Also save to Firestore if user is logged in
          if (uid != null && uid.isNotEmpty) {
            try {
              final addressModel = AddressModelV3(
                id: addressId,
                userId: uid,
                label: 'Delivery Address',
                streetAddress: resolvedStreet,
                apartment: validationResult['apartment'] ?? '',
                city: resolvedCity,
                state: resolvedState,
                zipCode: resolvedZip,
                isDefault: existingAddressStreets.length == 1, // First address is default
              );
              await FirestoreServiceV3.saveAddress(addressModel);
              debugPrint('[DeliveryScheduleV5] Γ£à Saved address to Firestore: $addressId');
            } catch (e) {
              debugPrint('[DeliveryScheduleV5] ΓÜá∩╕Å Failed to save address to Firestore: $e');
            }
          }
          
          debugPrint('[DeliveryScheduleV5] Γ£à Added address: $resolvedStreet, $resolvedCity, $resolvedState $resolvedZip');
      }

      // Save updated address list to SharedPreferences
      await prefs.setStringList('user_addresses', updatedAddressList);
      debugPrint('[DeliveryScheduleV5] ========== SUMMARY ==========');
      debugPrint('[DeliveryScheduleV5] Γ£à Validated and saved: $validatedCount addresses');
      debugPrint('[DeliveryScheduleV5] ΓÅ¡∩╕Å Skipped (duplicates or invalid): $skippedCount addresses');
      debugPrint('[DeliveryScheduleV5] ≡ƒôè Total addresses in storage: ${updatedAddressList.length}');
    } catch (e) {
      debugPrint('[DeliveryScheduleV5] Γ¥î Error saving addresses: $e');
    }
  }

  /// Validate and complete NYC address using Google Places
  Future<Map<String, String>> _validateAndCompleteAddress(String streetAddress) async {
    try {
      debugPrint('[DeliveryScheduleV5] Validating address: "$streetAddress"');
      
      // Add NYC context to the search
      final searchQuery = streetAddress.contains('New York') || streetAddress.contains('NYC')
          ? streetAddress
          : '$streetAddress, New York, NY';
      
      final service = SimpleGoogleMapsService.instance;
      final result = await service.validateAddress(searchQuery);
      
      if (result != null) {
        debugPrint('[DeliveryScheduleV5] Γ£à Address validated: ${result.formattedAddress}');
        
        // Convert state abbreviation to full name for consistency
        String stateName = result.state;
        if (stateName == 'NY') stateName = 'New York';
        else if (stateName == 'NJ') stateName = 'New Jersey';
        else if (stateName == 'CT') stateName = 'Connecticut';
        else if (stateName == 'PA') stateName = 'Pennsylvania';
        else if (stateName == 'MA') stateName = 'Massachusetts';
        
        // Convert city to match dropdown options
        String cityName = result.city;
        if (cityName == 'New York' || cityName == 'NYC' || cityName == 'Manhattan' || 
            cityName == 'Brooklyn' || cityName == 'Queens' || cityName == 'Bronx' || 
            cityName == 'Staten Island') {
          cityName = 'New York City';
        }
        
        return {
          'streetAddress': result.street.isNotEmpty ? result.street : streetAddress,
          'apartment': '', // User can add this manually if needed
          'city': cityName.isNotEmpty ? cityName : 'New York City',
          'state': stateName.isNotEmpty ? stateName : 'New York',
          'zipCode': result.zipCode.isNotEmpty ? result.zipCode : '',
        };
      } else {
        debugPrint('[DeliveryScheduleV5] ΓÜá∩╕Å Address validation failed, using defaults');
        // Return with NYC defaults
        return {
          'streetAddress': streetAddress,
          'apartment': '',
          'city': 'New York City',
          'state': 'New York',
          'zipCode': '',
        };
      }
    } catch (e) {
      debugPrint('[DeliveryScheduleV5] Γ¥î Error validating address: $e');
      // Return with NYC defaults on error
      return {
        'streetAddress': streetAddress,
        'apartment': '',
        'city': 'New York City',
        'state': 'New York',
        'zipCode': '',
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.isSignupFlow, // Prevent back navigation during signup
      onPopInvoked: (bool didPop) {
        // Prevent back navigation during signup flow
        if (widget.isSignupFlow && !didPop) {
          debugPrint('[DeliverySchedule] Back navigation blocked during signup');
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text(
            'Delivery Schedule',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: Colors.black,
            ),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.black),
          automaticallyImplyLeading: !widget.isSignupFlow, // Remove back button during signup
        ),
      body: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Schedule name
                  const Text(
                    'Schedule Name',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _scheduleNameInputController,
                    decoration: InputDecoration(
                      hintText: 'e.g., "Weekly Schedule"',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Colors.black, width: 2),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Colors.black, width: 2),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Colors.black, width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    onChanged: (value) => _scheduleName = value,
                  ),

                  const SizedBox(height: 24),

                  // Select Meal Plan Button
                  const Text(
                    'Select Meal Plan',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      debugPrint('[DeliveryScheduleV5] Opening meal plan selection...');
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ChooseMealPlanPageV3(isSignupFlow: false),
                        ),
                      );
                      // Always reload plan after returning to pick up any changes
                      debugPrint('[DeliveryScheduleV5] Returned from meal plan selection, reloading...');
                      if (mounted) {
                        await _loadCurrentPlan();
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _selectedMealPlan == null ? Colors.grey.shade100 : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.black, width: 2),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.restaurant_menu, color: Colors.black, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedMealPlan?.displayName ?? 'Select Your Meal Plan',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                    color: Colors.black,
                                  ),
                                ),
                                if (_selectedMealPlan != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_selectedMealPlan!.mealsPerDay} meal${_selectedMealPlan!.mealsPerDay > 1 ? 's' : ''} per day',
                                    style: const TextStyle(
                                      color: Colors.black87,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios, color: Colors.black, size: 18),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Only show configuration sections if a meal plan is selected
                  if (_selectedMealPlan != null) ...[
                    // Choose Meals Section
                    const Text(
                      'Choose Meals',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Select your meals • ${_selectedMeals.length}/${_selectedMealPlan?.mealsPerDay ?? 0} selected',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                  Row(
                    children: ['breakfast', 'lunch', 'dinner'].asMap().entries.map((entry) {
                      final index = entry.key;
                      final meal = entry.value;
                      final isSelected = _selectedMeals.contains(meal);
                      final maxMeals = _selectedMealPlan?.mealsPerDay ?? 0;
                      final canSelect = _selectedMeals.length < maxMeals;

                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            left: index == 0 ? 0 : 4,
                            right: index == 2 ? 0 : 4,
                          ),
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedMeals.remove(meal);
                                } else if (canSelect) {
                                  _selectedMeals.add(meal);
                                }
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.black : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.black, width: 2),
                              ),
                              child: Center(
                                child: Text(
                                  isSelected ? '✓ ${meal.capitalize()}' : meal.capitalize(),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected ? Colors.white : Colors.black,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 24),

                  // Select Days Section
                  const Text(
                    'Select Days to Configure',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: _daysOfWeek.map((day) {
                      final dayLower = day.toLowerCase();
                      final isSelected = _selectedDays.contains(dayLower);

                      return InkWell(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedDays.remove(dayLower);
                            } else {
                              _selectedDays.add(dayLower);
                            }
                          });
                        },
                        child: Container(
                          width: (MediaQuery.of(context).size.width - 80) / 2, // Fixed: Better spacing calculation
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.grey.shade50 : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? Colors.black : Colors.grey.shade300,
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              day,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 24),

                  // Configure Times & Locations (if days and meals selected)
                  if (_selectedDays.isNotEmpty && _selectedMeals.isNotEmpty) ...[
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Configure Times & Locations',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () {
                            setState(() {
                              _applyToAllDays = !_applyToAllDays;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: _applyToAllDays ? Colors.black : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.black, width: 2),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_applyToAllDays) ...[
                                  const Icon(Icons.check, size: 16, color: Colors.white),
                                  const SizedBox(width: 6),
                                ],
                                Text(
                                  'Apply to All',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: _applyToAllDays ? Colors.white : Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Configuration cards
                    if (_applyToAllDays)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _buildAllDaysConfigCard(),
                      )
                    else
                      ..._selectedDays.map((day) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _buildDayConfigCard(day),
                      )).toList(),

                    const SizedBox(height: 24),
                  ],

                  const SizedBox(height: 32),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saveSchedule,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: Colors.black, width: 2),
                        ),
                      ),
                      child: const Text(
                        'Save Schedule',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  ], // End of meal plan selected conditional
                ],
              ),
            ),
      ), // End of PopScope child
    );
  }
}

