import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service_v3.dart';
import '../theme/app_theme_v3.dart';
import '../models/meal_model_v3.dart';
import 'meal_schedule_page_v3.dart';
import 'address_page_v3.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'plan_subscription_page_v3.dart';

class DeliverySchedulePageV4 extends StatefulWidget {
  const DeliverySchedulePageV4({super.key});

  @override
  State<DeliverySchedulePageV4> createState() => _DeliverySchedulePageV4State();
}

class _DeliverySchedulePageV4State extends State<DeliverySchedulePageV4> {
  // Basic setup
  MealPlanModelV3? _selectedMealPlan;
  String _scheduleName = '';
  final TextEditingController _scheduleNameController = TextEditingController();
  // Meal type selection (for plans with 1 or 2 meals/day)
  final List<String> _mealOptions = const ['Breakfast', 'Lunch', 'Dinner'];
  final Set<String> _selectedMealTypes = <String>{};
  
  // Days and meal types
  final List<String> _daysOfWeek = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];
  
  // Selected days for configuration
  Set<String> _selectedDays = {};
  
  // Day configurations: Map<Day, Map<MealType, {time, address}>>
  Map<String, Map<String, Map<String, dynamic>>> _dayConfigurations = {};
  
  // Saved addresses - start empty; only user-created addresses will appear
  // Each entry: { 'name': <label>, 'address': <full address> }
  List<Map<String, String>> _savedAddresses = [];
  
  // Currently editing day (for individual day configuration)
  String? _editingDay;
  Map<String, TimeOfDay?> _tempMealTimes = {};
  // Temporary per-meal-type address selections while configuring (store full address value)
  Map<String, String?> _tempAddresses = {};

  @override
  void initState() {
    super.initState();
  // No default schedule name; require user input
  _scheduleName = '';
  _scheduleNameController.text = '';
  _loadUserAddresses();
  _loadCurrentPlan();
  }

  @override
  void dispose() {
    _scheduleNameController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentPlan() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      // 1) Try the user's current active plan document
      MealPlanModelV3? plan = await FirestoreServiceV3.getCurrentMealPlan(uid);

      // 2) Fallback: resolve from active subscription (set up during payment)
      if (plan == null) {
        try {
          final sub = await FirestoreServiceV3.getActiveSubscription(uid);
          final subPlanId = (sub?['mealPlanId'] ?? '').toString().trim();
          final subPlanName = (sub?['planName'] ?? '').toString().trim();
          if (subPlanId.isNotEmpty || subPlanName.isNotEmpty) {
            final available = MealPlanModelV3.getAvailablePlans();
            // Prefer ID match, else match by displayName/name (case-insensitive)
            plan = available.firstWhere(
              (p) => p.id == subPlanId,
              orElse: () {
                final lname = subPlanName.toLowerCase();
                return available.firstWhere(
                  (p) => p.displayName.toLowerCase() == lname || p.name.toLowerCase() == lname,
                  orElse: () => plan ?? available.first,
                );
              },
            );
          }
        } catch (_) {
          // ignore: avoid_print
          print('[DeliverySchedule] Could not resolve plan from subscription');
        }
      }

      if (!mounted) return;
      setState(() {
        _selectedMealPlan = plan;
        _selectedMealTypes.clear();
        if (plan != null && plan.mealsPerDay >= 3) {
          _selectedMealTypes.addAll(_mealOptions);
        }
      });
    } catch (_) {
      // Keep silent; plan UI will display a neutral summary without prompting.
    }
  }

  Future<void> _loadUserAddresses() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      // Not signed in; try local fallback
      try {
        final prefs = await SharedPreferences.getInstance();
        final list = prefs.getStringList('user_addresses') ?? [];
        final deduped = <Map<String, String>>[];
        final seen = <String>{};
        for (final jsonStr in list) {
          try {
            final data = json.decode(jsonStr) as Map<String, dynamic>;
            final label = (data['label'] ?? 'Address').toString().trim();
            final street = (data['streetAddress'] ?? '').toString().trim();
            final apt = (data['apartment'] ?? '').toString().trim();
            final city = (data['city'] ?? '').toString().trim();
            final state = (data['state'] ?? '').toString().trim();
            final zip = (data['zipCode'] ?? '').toString().trim();
            final full = [
              street,
              if (apt.isNotEmpty) apt,
              if (city.isNotEmpty || state.isNotEmpty || zip.isNotEmpty)
                [city, state].where((s) => s.isNotEmpty).join(', ') + (zip.isNotEmpty ? ' $zip' : ''),
            ].where((s) => s.toString().trim().isNotEmpty).join(', ');
            final addr = full.trim();
            if (addr.isEmpty || seen.contains(addr)) continue;
            seen.add(addr);
            deduped.add({'name': label, 'address': addr});
          } catch (_) {}
        }
        if (mounted) {
          setState(() {
            _savedAddresses = deduped;
          });
        }
        // ignore: avoid_print
        print('[DeliverySchedule] Loaded ${_savedAddresses.length} addresses from local (not signed in)');
      } catch (_) {
        // No local addresses available
      }
      return;
    }
    try {
      // 1) Attempt lightweight name/address pairs first
      final pairs = await FirestoreServiceV3.getUserAddressPairs(uid);
      final seen = <String>{};
      final deduped = <Map<String, String>>[];
      for (final p in pairs) {
        final addr = (p['address'] ?? '').trim();
        if (addr.isEmpty || seen.contains(addr)) continue;
        seen.add(addr);
        deduped.add({
          'name': (p['name'] ?? 'Address').trim(),
          'address': addr,
        });
      }

      if (deduped.isEmpty) {
        // 2) If no pairs exist yet, read the richer address docs and map to pairs
        try {
          final models = await FirestoreServiceV3.getUserAddresses(uid);
          final seen2 = <String>{};
          final mapped = <Map<String, String>>[];
          for (final a in models) {
            final addr = a.fullAddress.trim();
            if (addr.isEmpty || seen2.contains(addr)) continue;
            seen2.add(addr);
            mapped.add({'name': a.label.trim().isNotEmpty ? a.label.trim() : 'Address', 'address': addr});
          }
          if (mounted) {
            setState(() {
              _savedAddresses = mapped;
            });
          }
          // ignore: avoid_print
          print('[DeliverySchedule] Loaded ${_savedAddresses.length} addresses from Firestore (mapped from models)');
        } catch (e2) {
          // ignore: avoid_print
          print('[DeliverySchedule] Model fetch failed after empty pairs, falling back to local. Error: $e2');
          throw e2; // fall into the catch to use local
        }
      } else {
        if (mounted) {
          setState(() {
            _savedAddresses = deduped;
          });
        }
        // ignore: avoid_print
        print('[DeliverySchedule] Loaded ${_savedAddresses.length} addresses from Firestore (pairs)');
      }
    } catch (e) {
      // Firestore may be blocked by security rules; fall back to local addresses.
      try {
        final prefs = await SharedPreferences.getInstance();
        final list = prefs.getStringList('user_addresses') ?? [];
        final deduped = <Map<String, String>>[];
        final seen = <String>{};
        for (final jsonStr in list) {
          try {
            final data = json.decode(jsonStr) as Map<String, dynamic>;
            final label = (data['label'] ?? 'Address').toString().trim();
            final street = (data['streetAddress'] ?? '').toString().trim();
            final apt = (data['apartment'] ?? '').toString().trim();
            final city = (data['city'] ?? '').toString().trim();
            final state = (data['state'] ?? '').toString().trim();
            final zip = (data['zipCode'] ?? '').toString().trim();
            final full = [
              street,
              if (apt.isNotEmpty) apt,
              if (city.isNotEmpty || state.isNotEmpty || zip.isNotEmpty)
                [city, state].where((s) => s.isNotEmpty).join(', ') + (zip.isNotEmpty ? ' $zip' : ''),
            ].where((s) => s.toString().trim().isNotEmpty).join(', ');
            final addr = full.trim();
            if (addr.isEmpty || seen.contains(addr)) continue;
            seen.add(addr);
            deduped.add({'name': label, 'address': addr});
          } catch (_) {}
        }
        if (mounted) {
          setState(() {
            _savedAddresses = deduped;
          });
        }
        // ignore: avoid_print
        print('[DeliverySchedule] Loaded ${_savedAddresses.length} addresses from local (fallback). Error: $e');
      } catch (_) {
        // Keep silent; no local addresses available.
      }
    }
  }

  List<String> _getMealTypesForPlan() {
    if (_selectedMealPlan == null) return [];
    final count = _selectedMealPlan!.mealsPerDay;
    if (count >= 3) {
      // All meals when plan has 3 per day
      return List<String>.from(_mealOptions);
    }
    // Use the user's chosen meals (for 1 or 2 per day)
    return _mealOptions.where((m) => _selectedMealTypes.contains(m)).toList();
  }

  bool _isDayConfigured(String day) {
    if (!_dayConfigurations.containsKey(day)) return false;
    
    final dayConfig = _dayConfigurations[day]!;
    final expectedMealTypes = _getMealTypesForPlan();
    
    // Check if all expected meal types have both time and address
    for (String mealType in expectedMealTypes) {
      if (!dayConfig.containsKey(mealType) ||
          dayConfig[mealType]!['time'] == null ||
          dayConfig[mealType]!['address'] == null) {
        return false;
      }
    }
    return true;
  }

  void _startEditingDay(String day) {
    setState(() {
      _editingDay = day;
      _tempMealTimes.clear();
  _tempAddresses.clear();
      
      // Load existing configuration if available
      if (_dayConfigurations.containsKey(day)) {
        final dayConfig = _dayConfigurations[day]!;
        for (String mealType in _getMealTypesForPlan()) {
          if (dayConfig.containsKey(mealType)) {
            _tempMealTimes[mealType] = dayConfig[mealType]!['time'] as TimeOfDay?;
    _tempAddresses[mealType] = dayConfig[mealType]!['address'] as String?;
          }
        }
      }
    });
  }

  void _cancelEditing() {
    setState(() {
      _editingDay = null;
      _tempMealTimes.clear();
  _tempAddresses.clear();
    });
  }

  void _saveCurrentDayConfiguration() {
    if (_editingDay == null) return;
    
    final mealTypes = _getMealTypesForPlan();
    
    // Validate that all meal types have both time and address
    for (String mealType in mealTypes) {
      if (_tempMealTimes[mealType] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please set time for $mealType')),
        );
        return;
      }
      if (_tempAddresses[mealType] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please select delivery address for $mealType')),
        );
        return;
      }
    }
    final savedDay = _editingDay!;

    setState(() {
      // Initialize day configuration if not exists
      if (!_dayConfigurations.containsKey(_editingDay!)) {
        _dayConfigurations[_editingDay!] = {};
      }
      
      // Save configuration for each meal type
      for (String mealType in mealTypes) {
        _dayConfigurations[_editingDay!]![mealType] = {
          'time': _tempMealTimes[mealType],
          'address': _tempAddresses[mealType],
        };
      }
      
      _editingDay = null;
      _tempMealTimes.clear();
      _tempAddresses.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Configuration saved for $savedDay!')),
    );
  }

  void _applyToSelectedDays() {
    if (_selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select days to configure')),
      );
      return;
    }
    // Validate meal type selection count for 1 or 2 meals/day plans
    final perDay = _selectedMealPlan?.mealsPerDay ?? 0;
    if (perDay > 0 && perDay < 3 && _selectedMealTypes.length != perDay) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please choose exactly $perDay meal${perDay == 1 ? '' : 's'} above')),
      );
      return;
    }

    final mealTypes = _getMealTypesForPlan();
    
    // Validate that all meal types have both time and address
    for (String mealType in mealTypes) {
      if (_tempMealTimes[mealType] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please set time for $mealType')),
        );
        return;
      }
      if (_tempAddresses[mealType] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please select delivery address for $mealType')),
        );
        return;
      }
    }

    final appliedCount = _selectedDays.length;

    setState(() {
      for (String day in _selectedDays) {
        // Initialize day configuration if not exists
        if (!_dayConfigurations.containsKey(day)) {
          _dayConfigurations[day] = {};
        }
        
        // Save configuration for each meal type
        for (String mealType in mealTypes) {
          _dayConfigurations[day]![mealType] = {
            'time': _tempMealTimes[mealType],
    'address': _tempAddresses[mealType],
          };
        }
      }
      
      _selectedDays.clear();
      _tempMealTimes.clear();
  _tempAddresses.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Configuration applied to $appliedCount day${appliedCount == 1 ? '' : 's'}!')),
    );
  }

  String _formatTimeOfDay(TimeOfDay? time) {
    if (time == null) return 'Not set';
    final hour = time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    final displayHour = hour == 0 ? 12 : hour;
    return '$displayHour:$minute $period';
  }

  // Helpers for address dropdown rendering
  List<Map<String, String>> _getDedupedAddresses() {
    final seen = <String>{};
    final list = <Map<String, String>>[];
    for (final a in _savedAddresses) {
      final addr = (a['address'] ?? '').trim();
      if (addr.isEmpty || seen.contains(addr)) continue;
      seen.add(addr);
      list.add({'name': (a['name'] ?? 'Address').trim(), 'address': addr});
    }
    return list;
  }

  // (No-op) Removed unused name lookup; selectedItemBuilder provides compact display.

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeV3.background,
      appBar: AppBar(
        backgroundColor: AppThemeV3.surface,
        title: const Text('Delivery Schedule'),
        centerTitle: true,
        elevation: 2,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
            // Meal Plan summary (Settings version is read-only; change via dedicated page)
            _buildPlanSummarySection(),
            
            if (_selectedMealPlan != null) ...[
              const SizedBox(height: 24),
              _buildScheduleNameSection(),
              const SizedBox(height: 24),
              _buildMealTypeSelectionSection(),
              
              const SizedBox(height: 24),
              _buildDaySelectionSection(),
              
              const SizedBox(height: 24),
              _buildConfigurationSection(),
              
              if (_dayConfigurations.isNotEmpty) ...[
                const SizedBox(height: 24),
                _buildConfiguredDaysSection(),
              ],
              
              const SizedBox(height: 24),
              _buildProceedButton(),
            ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlanSummarySection() {
    final plan = _selectedMealPlan;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.subscriptions_outlined, color: AppThemeV3.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Meal Plan',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
          plan != null
            ? '${plan.displayName.isNotEmpty ? plan.displayName : plan.name} • ${plan.mealsPerDay} ${plan.mealsPerDay == 1 ? 'meal' : 'meals'}/day'
            : 'Plan unavailable — complete setup in Settings',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            TextButton(
        onPressed: _navigateToPlanSubscription,
        child: const Text('Manage Plan'),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToPlanSubscription() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PlanSubscriptionPageV3()),
    ).then((_) => _loadCurrentPlan());
  }

  Widget _buildScheduleNameSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Text(
                'Schedule Name',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
              TextFormField(
              controller: _scheduleNameController,
                onChanged: (value) => setState(() {
                  _scheduleName = value;
                }),
              decoration: const InputDecoration(
                hintText: 'Enter schedule name',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMealTypeSelectionSection() {
    if (_selectedMealPlan == null) return const SizedBox.shrink();
    final perDay = _selectedMealPlan!.mealsPerDay;
    if (perDay >= 3) {
      // No selection needed; all meals included
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Meals Included',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: _mealOptions.map((m) => Chip(label: Text(m))).toList(),
              ),
            ],
          ),
        ),
      );
    }

    final selectedCount = _selectedMealTypes.length;
    final allowed = perDay;
    final help = 'Select exactly $allowed meal${allowed == 1 ? '' : 's'} per day';
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose Meals',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              '$help  •  $selectedCount/$allowed selected',
              style: TextStyle(color: Colors.grey[700], fontSize: 12),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _mealOptions.map((meal) {
                final isOn = _selectedMealTypes.contains(meal);
                return FilterChip(
                  label: Text(meal),
                  selected: isOn,
                  onSelected: (on) {
                    setState(() {
                      if (on) {
                        if (_selectedMealTypes.length < allowed) {
                          _selectedMealTypes.add(meal);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('You can select only $allowed meal${allowed == 1 ? '' : 's'}')),
                          );
                        }
                      } else {
                        _selectedMealTypes.remove(meal);
                        // Clear temp selections for unselected meal type
                        _tempMealTimes.remove(meal);
                        _tempAddresses.remove(meal);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDaySelectionSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Days to Configure',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                // Responsive columns: 3 on wide, otherwise 2
                final maxW = constraints.maxWidth;
                final cols = maxW >= 480 ? 3 : 2;
                return GridView.count(
                  crossAxisCount: cols,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 3.2, // wider than tall for chip look
                  children: _daysOfWeek.map((day) {
                    final isSelected = _selectedDays.contains(day);
                    final isConfigured = _isDayConfigured(day);
                    return InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selectedDays.remove(day);
                          } else {
                            _selectedDays.add(day);
                          }
                        });
                      },
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isConfigured
                              ? Colors.green.withValues(alpha: 0.08)
                              : (isSelected
                                  ? AppThemeV3.accent.withValues(alpha: 0.12)
                                  : Colors.transparent),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isConfigured
                                ? Colors.green
                                : (isSelected ? AppThemeV3.accent : Colors.grey),
                          ),
                        ),
                        child: Text(
                          day,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: isSelected ? AppThemeV3.accent : Colors.black87,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigurationSection() {
    if (_selectedDays.isEmpty && _editingDay == null) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Select days above to configure delivery times and address',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
        ),
      );
    }

    // Ensure the correct number of meals is selected for 1 or 2 meals/day plans
    final perDay = _selectedMealPlan?.mealsPerDay ?? 0;
    if (perDay > 0 && perDay < 3 && _selectedMealTypes.length != perDay) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Please choose exactly $perDay meal${perDay == 1 ? '' : 's'} (Breakfast, Lunch, or Dinner) above before configuring.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[700],
                ),
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Text(
                _editingDay != null 
                  ? 'Editing $_editingDay'
                  : 'Configure Selected Days (${_selectedDays.length})',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Per-meal-type time and address configuration
            ..._getMealTypesForPlan().map((mealType) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          SizedBox(
                            width: 80,
                            child: Text(
                              '$mealType:',
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _selectTimeForMealType(mealType),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.withValues(alpha: 0.5)),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _formatTimeOfDay(_tempMealTimes[mealType]),
                                  style: TextStyle(
                                    color: _tempMealTimes[mealType] != null
                                        ? Colors.black87
                                        : Colors.grey[600],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        // Guard value: ensure exactly one item matches
                        value: () {
                          final current = _tempAddresses[mealType];
                          if (current == null) return null;
                          final matches = _savedAddresses
                              .where((a) => (a['address'] ?? '').trim() == current)
                              .length;
                          return matches == 1 ? current : null;
                        }(),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Delivery Address',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        isExpanded: true,
                        selectedItemBuilder: (context) {
                          // Build compact selected widgets matching the items order
                          final deduped = _getDedupedAddresses();
                          final widgets = deduped
                              .map((addr) => Text(
                                    (addr['name'] ?? 'Address').trim(),
                                    overflow: TextOverflow.ellipsis,
                                  ))
                              .toList();
                          widgets.add(const Text('Add New Address', overflow: TextOverflow.ellipsis));
                          widgets.add(const Text('Manage Addresses…', overflow: TextOverflow.ellipsis));
                          return widgets;
                        },
                        items: () {
                          // Build a deduped list of DropdownMenuItems
                          final items = <DropdownMenuItem<String>>[];
                          final deduped = _getDedupedAddresses();
                          for (final addr in deduped) {
                            final value = (addr['address'] ?? '').trim();
                            items.add(DropdownMenuItem<String>(
                              value: value,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    (addr['name'] ?? '').trim(),
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                  ),
                                  Text(
                                    value,
                                    style: TextStyle(fontSize: 11, color: AppThemeV3.textSecondary),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                    softWrap: false,
                                  ),
                                ],
                              ),
                            ));
                          }
                          // Trailing "Add New" action
                          items.add(
                            DropdownMenuItem<String>(
                              value: 'add_new',
                              child: Row(
                                children: [
                                  Icon(Icons.add, color: AppThemeV3.accent, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Add New Address',
                                    style: TextStyle(
                                      color: AppThemeV3.accent,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                          // Manage Addresses action
                          items.add(
                            DropdownMenuItem<String>(
                              value: 'manage_addresses',
                              child: Row(
                                children: [
                                  Icon(Icons.edit_location_alt, color: AppThemeV3.accent, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Manage Addresses…',
                                    style: TextStyle(
                                      color: AppThemeV3.accent,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                          return items;
                        }(),
                        onChanged: (value) {
                          if (value == 'add_new') {
                            _navigateToAddAddress(forMealType: mealType);
                            // Do not keep 'add_new' as selected value
                            return;
                          } else if (value == 'manage_addresses') {
                            // Open address page for editing; reload saved addresses on return
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const AddressPageV3()),
                            ).then((_) => _loadUserAddresses());
                            return;
                          } else {
                            setState(() {
                              _tempAddresses[mealType] = value;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                )),
            
            const SizedBox(height: 20),
            
            // Action buttons
            Row(
              children: [
                if (_editingDay != null) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _cancelEditing,
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saveCurrentDayConfiguration,
                      child: const Text('Save Day'),
                    ),
                  ),
                ] else ...[
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _applyToSelectedDays,
                      child: Text('Apply to ${_selectedDays.length} day${_selectedDays.length == 1 ? '' : 's'}'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfiguredDaysSection() {
    final configuredDays = _dayConfigurations.keys.toList()
      ..sort((a, b) => _daysOfWeek.indexOf(a).compareTo(_daysOfWeek.indexOf(b)));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Configured Days',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...configuredDays.map((day) {
              final dayConfig = _dayConfigurations[day]!;
              
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.05),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            day,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          ...dayConfig.entries.map((entry) {
                            final mealType = entry.key;
                            final config = entry.value;
                            return Text(
                              '$mealType: ${_formatTimeOfDay(config['time'])} • ${config['address'] ?? '-'}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            );
                          }),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _startEditingDay(day),
                      icon: const Icon(Icons.edit, size: 20),
                      color: AppThemeV3.accent,
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildProceedButton() {
    final hasConfiguredDays = _dayConfigurations.isNotEmpty;
  final canProceed = hasConfiguredDays && _scheduleName.trim().isNotEmpty;
    
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
    onPressed: canProceed ? _proceedToMealSelection : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppThemeV3.accent,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: const Text(
          'Proceed to Meal Selection',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  void _selectTimeForMealType(String mealType) async {
    final initialTime = _tempMealTimes[mealType] ?? TimeOfDay.now();
    final selectedTime = await _showCupertinoTimePicker(initialTime);
    if (selectedTime != null) {
      setState(() {
        _tempMealTimes[mealType] = selectedTime;
      });
    }
  }

  void _proceedToMealSelection() {
    if (_scheduleName.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a schedule name')),
      );
      return;
    }
    if (_selectedMealPlan == null) {
      // Block gracefully without asking the user to choose a plan
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your plan could not be loaded. Manage your plan in Settings.')),
      );
      return;
    }
    // Convert to the expected format for MealSchedulePageV3
    Map<String, Map<String, dynamic>> weeklySchedule = {};
    
    for (String day in _dayConfigurations.keys) {
      weeklySchedule[day] = {};
      final dayConfig = _dayConfigurations[day]!;
      
      for (String mealType in dayConfig.keys) {
        final config = dayConfig[mealType]!;
        weeklySchedule[day]![mealType] = {
          'time': config['time'],
          'address': config['address'],
          'enabled': true,
        };
      }
    }

    // Persist this schedule locally so it appears in Meal Schedule selector
    _saveScheduleLocally(weeklySchedule);

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

  Future<void> _saveScheduleLocally(Map<String, Map<String, dynamic>> weeklySchedule) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Ensure name is trimmed and unique in the list
      final name = _scheduleName.trim();
      final existing = prefs.getStringList('saved_schedules') ?? [];
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
      await prefs.setStringList('saved_schedules', cleaned);

      // Serialize weekly schedule with time as "HH:mm"
      String _timeToStr(dynamic t) {
        if (t is TimeOfDay) {
          final hh = t.hour.toString().padLeft(2, '0');
          final mm = t.minute.toString().padLeft(2, '0');
          return '$hh:$mm';
        }
        return (t ?? '').toString();
      }

      final Map<String, Map<String, dynamic>> serializable = {};
      weeklySchedule.forEach((day, meals) {
        serializable[day] = {};
        meals.forEach((mealType, cfg) {
          serializable[day]![mealType] = {
            'time': _timeToStr(cfg['time']),
            'address': cfg['address'],
          };
        });
      });

      final data = {
        'mealPlanId': _selectedMealPlan!.id,
        // Prefer the current meal types used in the UI if available
        'selectedMealTypes': _getMealTypesForPlan(),
        'weeklySchedule': serializable,
      };
      await prefs.setString('delivery_schedule_$name', json.encode(data));
      // ignore: avoid_print
      print('[DeliverySchedule] Saved schedule "$name" locally with ${serializable.length} days');
    } catch (e) {
      // ignore: avoid_print
      print('[DeliverySchedule] Failed to save schedule locally: $e');
    }
  }

  // Navigate to the full Address page and return the selected address
  Future<void> _navigateToAddAddress({required String forMealType}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddressPageV3()),
    );
    if (result is Map && result['fullAddress'] is String && (result['fullAddress'] as String).isNotEmpty) {
      final trimmed = (result['fullAddress'] as String).trim();
      final label = (result['label'] as String?)?.trim();
      setState(() {
        _tempAddresses[forMealType] = trimmed;
        // Show it immediately in the dropdown list (UI-first), dedup by address
        final exists = _savedAddresses.any((a) => (a['address'] ?? '').trim() == trimmed);
        if (!exists) {
          _savedAddresses = List.of(_savedAddresses)
            ..add({'name': (label?.isNotEmpty == true ? label! : 'Address'), 'address': trimmed});
        }
      });
      // If not already saved, persist to Firestore (fallback label)
      if (!_savedAddresses.any((a) => (a['address'] ?? '').trim() == trimmed)) {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          try {
            await FirestoreServiceV3.addUserAddressPair(
              userId: uid,
              name: (label?.isNotEmpty == true ? label! : 'Address'),
              address: trimmed,
            );
          } catch (e) {
            // Keep silent but the UI already shows the address in-memory
          }
        }
      }
      await _loadUserAddresses();
    }
  }

  // Cupertino scroll-wheel time picker shown in a bottom sheet
  Future<TimeOfDay?> _showCupertinoTimePicker(TimeOfDay initial) async {
    TimeOfDay temp = initial;
    final result = await showModalBottomSheet<TimeOfDay>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        DateTime initialDateTime = DateTime(0, 1, 1, initial.hour, initial.minute);
        return SafeArea(
          child: SizedBox(
            height: 280,
            child: Column(
              children: [
                // Action bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      Text(
                        'Select Time',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, temp),
                        child: const Text('Done'),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: CupertinoDatePicker(
                    initialDateTime: initialDateTime,
                    mode: CupertinoDatePickerMode.time,
                    use24hFormat: false,
                    onDateTimeChanged: (dt) {
                      temp = TimeOfDay(hour: dt.hour, minute: dt.minute);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    return result;
  }
}
