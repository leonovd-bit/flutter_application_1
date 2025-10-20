import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/meal_model_v3.dart';
import '../theme/app_theme_v3.dart';
import '../widgets/app_image.dart';
import 'delivery_schedule_page_v5.dart';
import '../services/meal_service_v3.dart';
import 'interactive_menu_page_v3.dart';
import 'payment_page_v3.dart';

class MealSchedulePageV3 extends StatefulWidget {
  final MealPlanModelV3? mealPlan;
  final Map<String, Map<String, dynamic>>? weeklySchedule;
  final String? initialScheduleName;

  const MealSchedulePageV3({
    super.key,
    this.mealPlan,
    this.weeklySchedule,
    this.initialScheduleName,
  });

  @override
  State<MealSchedulePageV3> createState() => _MealSchedulePageV3State();
}

class _MealSchedulePageV3State extends State<MealSchedulePageV3> {
  // Anchor for custom dropdown
  final LayerLink _scheduleLink = LayerLink();
  OverlayEntry? _scheduleOverlay;
  final GlobalKey _scheduleFieldKey = GlobalKey();
  // Schedules
  String? _selectedSchedule;
  List<String> _availableSchedules = [];

  // Data resolved from schedule
  MealPlanModelV3? _currentMealPlan;
  Map<String, Map<String, dynamic>> _currentWeeklySchedule = {};
  List<String> _currentMealTypes = [];

  // UI state
  String _selectedMealType = 'Breakfast';
  String _customizeMode = 'week_individual'; // week_individual | day_then_apply | multi_day
  String? _dayThenApplySelectedDay; // which single day to show before apply
  bool _dayThenApplyApplied = false; // after apply, reveal all
  final Set<String> _batchDays = <String>{}; // multi-day selection
  MealModelV3? _batchSelectedMeal; // explicit meal for multi-day

  // Selections: day -> mealType -> meal
  final Map<String, Map<String, MealModelV3?>> _selectedMeals = {};

  void _proceedToPayment() {
    if (_currentMealPlan == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentPageV3(
          mealPlan: _currentMealPlan!,
          weeklySchedule: _currentWeeklySchedule,
          selectedMeals: _selectedMeals,
        ),
      ),
    );
  }

  List<String> get _configuredDays {
    const order = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final days = _currentWeeklySchedule.keys.toList();
    days.sort((a, b) => order.indexOf(a).compareTo(order.indexOf(b)));
    return days;
  }

  @override
  void initState() {
    super.initState();
    _loadAvailableSchedules();

    if (widget.mealPlan != null && widget.weeklySchedule != null) {
      debugPrint('[MealSchedule] ========== INIT START ==========');
      debugPrint('[MealSchedule] Meal Plan: ${widget.mealPlan?.name}, mealsPerDay: ${widget.mealPlan?.mealsPerDay}');
      debugPrint('[MealSchedule] WeeklySchedule keys: ${widget.weeklySchedule!.keys.toList()}');
      debugPrint('[MealSchedule] WeeklySchedule: ${ widget.weeklySchedule}');
      
      _currentMealPlan = widget.mealPlan;
      _currentWeeklySchedule = widget.weeklySchedule!;
      _currentMealTypes = _deriveMealTypes();
      _selectedSchedule = widget.initialScheduleName;
      _initSelectedMeals();
      
      debugPrint('[MealSchedule] Current meal types: $_currentMealTypes');
      debugPrint('[MealSchedule] Configured days: $_configuredDays');
      debugPrint('[MealSchedule] Selected meal type: $_selectedMealType');
      
      if (_currentMealTypes.isNotEmpty) _selectedMealType = _currentMealTypes.first;
      _dayThenApplySelectedDay = _configuredDays.isNotEmpty ? _configuredDays.first : null;
      
      debugPrint('[MealSchedule] ========== INIT END ==========');
    }
  }

  // Load saved schedule names (deduped) and optionally load one
  Future<void> _loadAvailableSchedules() async {
    final prefs = await SharedPreferences.getInstance();
  final uid = FirebaseAuth.instance.currentUser?.uid;
  final listKey = uid == null ? 'saved_schedules' : 'saved_schedules_${uid}';
  final saved = prefs.getStringList(listKey) ?? [];
    final seen = <String>{};
    final unique = <String>[];
    for (final s in saved) {
      final t = s.trim();
      if (t.isEmpty) continue;
      if (seen.add(t)) unique.add(t);
    }
    await prefs.setStringList('saved_schedules', unique);

    if (!mounted) return;
    setState(() {
      _availableSchedules = unique;
      if (widget.initialScheduleName != null && unique.contains(widget.initialScheduleName)) {
        _selectedSchedule = widget.initialScheduleName;
        _loadScheduleData(_selectedSchedule!);
      } else if (_selectedSchedule == null && unique.isNotEmpty) {
        _selectedSchedule = unique.first;
        _loadScheduleData(_selectedSchedule!);
      }
    });
  }

  Future<void> _loadScheduleData(String name) async {
    final prefs = await SharedPreferences.getInstance();
  final uid = FirebaseAuth.instance.currentUser?.uid;
  final schedKey = uid == null ? 'delivery_schedule_$name' : 'delivery_schedule_${uid}_$name';
  final raw = prefs.getString(schedKey);
    if (raw == null) return;
    final data = json.decode(raw) as Map<String, dynamic>;

    final mealPlanId = data['mealPlanId'] as String;
    final plans = MealPlanModelV3.getAvailablePlans();
    _currentMealPlan = plans.firstWhere((p) => p.id == mealPlanId);

    _currentMealTypes = List<String>.from(data['selectedMealTypes'] as List);

    _currentWeeklySchedule = {};
    final weekly = data['weeklySchedule'] as Map<String, dynamic>;
    weekly.forEach((day, value) {
      final m = value as Map<String, dynamic>;
      _currentWeeklySchedule[day] = {};
      m.forEach((mealType, v) {
        final mt = v as Map<String, dynamic>;
        _currentWeeklySchedule[day]![mealType] = {
          'time': mt['time'],
          'address': mt['address'],
          'enabled': true,
        };
      });
    });

    _selectedSchedule = name;
    _initSelectedMeals();
    await _loadPersistedMealSelections();
    if (_currentMealTypes.isNotEmpty) _selectedMealType = _currentMealTypes.first;
    _dayThenApplySelectedDay = _configuredDays.isNotEmpty ? _configuredDays.first : null;
    _dayThenApplyApplied = false;

    if (mounted) setState(() {});
  }

  void _initSelectedMeals() {
    _selectedMeals.clear();
    for (final day in _configuredDays) {
      _selectedMeals[day] = {};
      for (final mt in _currentMealTypes) {
        _selectedMeals[day]![mt] = null;
      }
    }
  }

  List<String> _deriveMealTypes() {
    if (_currentMealPlan == null) return [];
    
    // First, try to extract meal types from the weeklySchedule
    if (_currentWeeklySchedule.isNotEmpty) {
      final Set<String> mealTypesFromSchedule = {};
      for (final daySchedule in _currentWeeklySchedule.values) {
        mealTypesFromSchedule.addAll(daySchedule.keys);
      }
      if (mealTypesFromSchedule.isNotEmpty) {
        // Capitalize meal types: 'lunch' -> 'Lunch'
        final capitalizedTypes = mealTypesFromSchedule.map((mt) {
          if (mt.isEmpty) return mt;
          return mt[0].toUpperCase() + mt.substring(1);
        }).toList();
        debugPrint('[MealSchedule] Derived meal types from schedule: $capitalizedTypes');
        return capitalizedTypes;
      }
    }
    
    // Fallback to deriving from mealsPerDay
    return _currentMealTypes.isNotEmpty
        ? _currentMealTypes
        : switch (_currentMealPlan!.mealsPerDay) {
            1 => ['Breakfast'],
            2 => ['Breakfast', 'Lunch'],
            3 => ['Breakfast', 'Lunch', 'Dinner'],
            _ => ['Breakfast'],
          };
  }

  Future<void> _loadPersistedMealSelections() async {
    if (_selectedSchedule == null) return;
    final prefs = await SharedPreferences.getInstance();
  final uid = FirebaseAuth.instance.currentUser?.uid;
  final key = uid == null
    ? 'meal_selections_${_selectedSchedule}'
    : 'meal_selections_${uid}_${_selectedSchedule}';
  final raw = prefs.getString(key);
    if (raw == null) return;
    try {
      final data = json.decode(raw) as Map<String, dynamic>;
      data.forEach((day, mealTypes) {
        if (!_selectedMeals.containsKey(day)) return;
        final mtMap = mealTypes as Map<String, dynamic>;
        mtMap.forEach((mt, val) {
          if (!_selectedMeals[day]!.containsKey(mt)) return;
          final mealJson = val as Map<String, dynamic>;
          _selectedMeals[day]![mt] = MealModelV3.fromJson(mealJson);
        });
      });
    } catch (_) {}
  }

  Future<void> _saveMealSelections() async {
    if (_selectedSchedule == null) return;
    final prefs = await SharedPreferences.getInstance();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final userId = uid ?? 'local_user';
    
    // Save in existing format for meal schedule functionality
    final out = <String, Map<String, Map<String, dynamic>>>{};
    _selectedMeals.forEach((day, mtMap) {
      out[day] = {};
      mtMap.forEach((mt, meal) {
        if (meal != null) out[day]![mt] = meal.toJson();
      });
    });
    final key = uid == null
      ? 'meal_selections_${_selectedSchedule}'
      : 'meal_selections_${uid}_${_selectedSchedule}';
    await prefs.setString(key, json.encode(out));
    
    // ALSO save in format expected by UpcomingOrdersPageV3
    try {
      final selectedMealsList = <Map<String, dynamic>>[];
      final mealTypes = _deriveMealTypes();
      
      // Extract unique meals from the selected meals
      final uniqueMeals = <String, Map<String, dynamic>>{};
      _selectedMeals.forEach((day, mtMap) {
        mtMap.forEach((mt, meal) {
          if (meal != null) {
            try {
              final mealJson = meal.toJson();
              // Test if it can be encoded to JSON
              json.encode(mealJson);
              uniqueMeals[meal.id] = mealJson;
            } catch (e) {
              debugPrint('[MealScheduleFixed] Error serializing meal ${meal.id}: $e');
              debugPrint('[MealScheduleFixed] Meal data: $meal');
              // Create a safe version with only basic properties
              uniqueMeals[meal.id] = {
                'id': meal.id,
                'name': meal.name,
                'description': meal.description,
                'calories': meal.calories,
                'protein': meal.protein,
                'carbs': meal.carbs,
                'fat': meal.fat,
                'ingredients': meal.ingredients,
                'allergens': meal.allergens,
                'imageUrl': meal.imageUrl,
                'mealType': meal.mealType,
                'price': meal.price,
              };
            }
          }
        });
      });
      
      selectedMealsList.addAll(uniqueMeals.values);
      
      // Get a delivery address from the schedule
      String? deliveryAddress;
      final weeklySchedule = widget.weeklySchedule;
      if (weeklySchedule != null && weeklySchedule.isNotEmpty) {
        for (final daySchedule in weeklySchedule.values) {
          for (final mealConfig in daySchedule.values) {
            if (mealConfig['address'] != null && mealConfig['address'].toString().isNotEmpty) {
              deliveryAddress = mealConfig['address'].toString();
              break;
            }
          }
          if (deliveryAddress != null) break;
        }
      }
      
      if (selectedMealsList.isNotEmpty) {
        try {
          // Test if the meals list can be encoded before saving
          json.encode(selectedMealsList);
          
          // Save data in format expected by upcoming orders
          await prefs.setString('user_meal_selections_$userId', json.encode(selectedMealsList));
          debugPrint('[MealScheduleFixed] Successfully saved ${selectedMealsList.length} meal selections');
          
          if (deliveryAddress != null) {
            await prefs.setString('user_delivery_address_$userId', deliveryAddress);
            debugPrint('[MealScheduleFixed] Saved delivery address: $deliveryAddress');
          }
          
          await prefs.setInt('user_meals_per_day_$userId', mealTypes.length);
          debugPrint('[MealScheduleFixed] Saved meals per day: ${mealTypes.length}');
          
        } catch (e) {
          debugPrint('[MealScheduleFixed] Error encoding meals list: $e');
          debugPrint('[MealScheduleFixed] Meals list: $selectedMealsList');
        }
        
        // Save delivery schedule in format expected by upcoming orders
        final weeklySchedule = widget.weeklySchedule;
        if (weeklySchedule != null) {
          try {
            // Convert TimeOfDay objects to strings for JSON serialization
            final serializableSchedule = <String, Map<String, dynamic>>{};
            weeklySchedule.forEach((day, daySchedule) {
              serializableSchedule[day] = <String, dynamic>{};
              daySchedule.forEach((mealType, config) {
                serializableSchedule[day]![mealType] = <String, dynamic>{};
                config.forEach((key, value) {
                  if (value is TimeOfDay) {
                    // Convert TimeOfDay to string format "HH:mm"
                    final hour = value.hour.toString().padLeft(2, '0');
                    final minute = value.minute.toString().padLeft(2, '0');
                    serializableSchedule[day]![mealType]![key] = '$hour:$minute';
                  } else {
                    serializableSchedule[day]![mealType]![key] = value;
                  }
                });
              });
            });
            
            // Test encoding before saving
            json.encode(serializableSchedule);
            
            await prefs.setString('delivery_schedule_$userId', json.encode(serializableSchedule));
            debugPrint('[MealScheduleFixed] Successfully saved delivery schedule for ${serializableSchedule.keys.length} days');
          } catch (e) {
            debugPrint('[MealScheduleFixed] Error saving delivery schedule: $e');
            debugPrint('[MealScheduleFixed] Original schedule: $weeklySchedule');
          }
        }
        
        debugPrint('[MealScheduleFixed] Saved meal selections for upcoming orders: ${selectedMealsList.length} meals');
      }
    } catch (e) {
      debugPrint('[MealScheduleFixed] Error saving for upcoming orders: $e');
    }
  }

  TimeOfDay? _parseTime(dynamic val) {
    if (val == null) return null;
    if (val is TimeOfDay) return val;
    if (val is String) {
      final parts = val.split(':');
      if (parts.length == 2) {
        final h = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        if (h != null && m != null) return TimeOfDay(hour: h, minute: m);
      }
    }
    return null;
  }

  bool _hasAnyForCurrentType() {
    return _selectedMeals.values.any((m) => m[_selectedMealType] != null);
  }

  bool _isWeekComplete() {
    for (final day in _configuredDays) {
      for (final mt in _deriveMealTypes()) {
        final required = _currentWeeklySchedule[day]?[mt]?['time'] != null;
        if (required && _selectedMeals[day]?[mt] == null) return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final mealTypes = _deriveMealTypes();
    return DefaultTabController(
      length: mealTypes.length,
      child: Scaffold(
        backgroundColor: AppThemeV3.background,
        appBar: AppBar(
          backgroundColor: AppThemeV3.surface,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Meal Schedule',
            style: AppThemeV3.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          actions: [
            IconButton(
              tooltip: 'Randomize meals for current type',
              icon: const Icon(Icons.shuffle),
              onPressed: _randomizeCurrentMealType,
            ),
          ],
        ),
        body: Column(
          children: [
            _buildScheduleSelector(),
            Container(
              color: AppThemeV3.surface,
              child: TabBar(
                isScrollable: true,
                tabs: mealTypes.map((e) => Tab(text: e)).toList(),
                onTap: (i) => setState(() => _selectedMealType = mealTypes[i]),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_currentMealPlan != null) _buildScheduleSummary(),
                    _buildModeSelector(),
                    if (_customizeMode == 'day_then_apply') _buildDayThenApplyCard(),
                    if (_customizeMode == 'multi_day') _buildMultiDayBatchCard(),
                    Text(
                      'Select meals for $_selectedMealType',
                      style: AppThemeV3.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    ..._visibleDays().map(_buildDayCard),
                    const SizedBox(height: 16),
                    if (_isWeekComplete()) _buildProceedButton(),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  // Randomly fill any empty selections for the currently selected meal type
  Future<void> _randomizeCurrentMealType() async {
    if (_selectedSchedule == null || _currentMealPlan == null) return;
    // Fetch a pool of meals for the current type from service or use simple samples if empty
    final meals = await _fetchMealsForType(_selectedMealType);
    if (meals.isEmpty) return;
    meals.shuffle();
    int idx = 0;
    for (final day in _configuredDays) {
      final required = _currentWeeklySchedule[day]?[_selectedMealType]?['time'] != null;
      if (!required) continue;
      if (_selectedMeals[day]?[_selectedMealType] == null) {
        _selectedMeals[day]![_selectedMealType] = meals[idx % meals.length];
        idx++;
      }
    }
    await _saveMealSelections();
    if (mounted) setState(() {});
  }

  // Helper to fetch meals by type; tries Firestore via MealServiceV3 first, else falls back to simple defaults
  Future<List<MealModelV3>> _fetchMealsForType(String type) async {
    debugPrint('[MealSchedule] FETCHING meals for type: $type');
    
    try {
      debugPrint('[MealSchedule] Calling MealServiceV3.getMeals(mealType: ${type.toLowerCase()}, limit: 50)');
      final svcMeals = await MealServiceV3.getMeals(mealType: type.toLowerCase(), limit: 50);
      debugPrint('[MealSchedule] MealServiceV3.getMeals returned ${svcMeals.length} meals');
      
      if (svcMeals.isNotEmpty) {
        debugPrint('[MealSchedule] ✅ SUCCESS: Found ${svcMeals.length} database meals for $type');
        // Log first few meal names
        for (int i = 0; i < svcMeals.length && i < 3; i++) {
          debugPrint('[MealSchedule]   - Database meal $i: ${svcMeals[i].name}');
        }
        return svcMeals;
      } else {
        debugPrint('[MealSchedule] ⚠️ MealServiceV3.getMeals returned empty list for $type');
      }
    } catch (e) {
      debugPrint('[MealSchedule] ❌ ERROR fetching meals for $type: $e');
      debugPrint('[MealSchedule] Error type: ${e.runtimeType}');
    }
    
    // Fallback to in-memory samples if service returns nothing
    debugPrint('[MealSchedule] 🔄 FALLING BACK to sample meals for $type');
    try {
      final samples = MealModelV3.getSampleMeals()
          .where((m) => m.mealType.toLowerCase() == type.toLowerCase())
          .toList();
      debugPrint('[MealSchedule] ⚠️ Using ${samples.length} SAMPLE meals for $type as fallback');
      // Log first few sample meal names
      for (int i = 0; i < samples.length && i < 3; i++) {
        debugPrint('[MealSchedule]   - Sample meal $i: ${samples[i].name}');
      }
      return samples;
    } catch (e) {
      debugPrint('[MealSchedule] ❌ Error even getting sample meals: $e');
      return [];
    }
  }

  // Header widgets
  Widget _buildScheduleSelector() {
    return Container(
      color: AppThemeV3.surface,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: CompositedTransformTarget(
              link: _scheduleLink,
              child: Container(
                key: _scheduleFieldKey,
                child: InkWell(
                  onTap: _toggleScheduleDropdown,
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    height: 56,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Schedule',
                        hintText: 'Select Schedule',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        border: OutlineInputBorder(),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _selectedSchedule ?? 'Select Schedule',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Anchored schedule dropdown overlay helpers
  void _toggleScheduleDropdown() {
    if (_scheduleOverlay == null) {
      _showScheduleDropdown();
    } else {
      _hideScheduleDropdown();
    }
  }

  void _hideScheduleDropdown() {
    _scheduleOverlay?.remove();
    _scheduleOverlay = null;
    if (mounted) setState(() {});
  }

  void _showScheduleDropdown() {
  final overlay = Overlay.of(context);
    // Measure the field width so the dropdown aligns perfectly
    double panelWidth = 260;
    final ctx = _scheduleFieldKey.currentContext;
    if (ctx != null) {
      final rb = ctx.findRenderObject();
      if (rb is RenderBox) {
        panelWidth = rb.size.width;
      }
    }
    _scheduleOverlay = OverlayEntry(
      builder: (ctx) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _hideScheduleDropdown,
              ),
            ),
            CompositedTransformFollower(
              link: _scheduleLink,
              showWhenUnlinked: false,
              offset: const Offset(0, 56),
              child: Material(
                elevation: 6,
                borderRadius: BorderRadius.circular(8),
                color: AppThemeV3.surface,
                child: SizedBox(
                  width: panelWidth,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 320),
                    child: _ScheduleDropdownPanel(
                    schedules: _availableSchedules,
                    selected: _selectedSchedule,
                    onSelect: (name) async {
                      _hideScheduleDropdown();
                      setState(() => _selectedSchedule = name);
                      await _loadScheduleData(name);
                    },
                    onDelete: (name) async {
                      await _deleteSchedule(name);
                      if (!mounted) return;
                      if (_availableSchedules.isEmpty) {
                        _hideScheduleDropdown();
                      } else {
                        _scheduleOverlay?.markNeedsBuild();
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Deleted '$name'")),
                      );
                    },
                    onAddNew: () {
                      _hideScheduleDropdown();
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const DeliverySchedulePageV5()));
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
    overlay.insert(_scheduleOverlay!);
    if (mounted) setState(() {});
  }

  Widget _buildScheduleSummary() {
    final plan = _currentMealPlan!;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppThemeV3.surface,
        border: Border.all(color: AppThemeV3.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Delivery Schedule: ${_selectedSchedule ?? "No schedule"}',
            style: AppThemeV3.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Meal Plan: ${plan.name} (${plan.mealsPerDay} meals/day)',
            style: TextStyle(color: AppThemeV3.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            'Days: ${_configuredDays.join(', ')}',
            style: TextStyle(color: AppThemeV3.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            'Meal Types: ${_currentMealTypes.join(', ')}',
            style: TextStyle(color: AppThemeV3.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Iterable<String> _visibleDays() {
    if (_customizeMode == 'day_then_apply' && !_dayThenApplyApplied) {
      final d = _dayThenApplySelectedDay;
      if (d != null) return [d];
      return _configuredDays.take(1);
    }
    return _configuredDays;
  }

  Widget _buildDayCard(String day) {
    final selectedMeal = _selectedMeals[day]?[_selectedMealType];
    final scheduleInfo = _currentWeeklySchedule[day]?[_selectedMealType];
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppThemeV3.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppThemeV3.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_customizeMode == 'day_then_apply' && !_dayThenApplyApplied)
            // Hide day-of-week label; align schedule details to the left for a cleaner look
            if (scheduleInfo != null)
      Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Time: ${_parseTime(scheduleInfo['time'])?.format(context) ?? 'Not set'}',
                    style: AppThemeV3.textTheme.bodySmall?.copyWith(color: AppThemeV3.textSecondary),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
        softWrap: false,
                  ),
                  Text(
                    'Address: ${scheduleInfo['address'] ?? 'Not set'}',
                    style: AppThemeV3.textTheme.bodySmall?.copyWith(color: AppThemeV3.textSecondary),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
        softWrap: false,
                  ),
                ],
              )
            else
              const SizedBox.shrink()
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    day,
                    style: AppThemeV3.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                  ),
                ),
                if (scheduleInfo != null)
                  Flexible(
                    fit: FlexFit.loose,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Time: ${_parseTime(scheduleInfo['time'])?.format(context) ?? 'Not set'}',
                          style: AppThemeV3.textTheme.bodySmall?.copyWith(color: AppThemeV3.textSecondary),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          softWrap: false,
                        ),
                        Text(
                          'Address: ${scheduleInfo['address'] ?? 'Not set'}',
                          style: AppThemeV3.textTheme.bodySmall?.copyWith(color: AppThemeV3.textSecondary),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                          softWrap: true,
                          textAlign: TextAlign.right,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 12),
          if (selectedMeal != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppThemeV3.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppThemeV3.accent.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppThemeV3.surfaceElevated,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppThemeV3.border),
                    ),
                    child: Builder(
                      builder: (context) {
                        print('🍽️ Meal: ${selectedMeal.name}');
                        print('🔗 ImagePath: "${selectedMeal.imagePath}"');
                        print('🔗 ImageUrl: "${selectedMeal.imageUrl}"');
                        print('📏 Path Empty? ${selectedMeal.imagePath.isEmpty}');
                        
                        return (selectedMeal.imagePath.isNotEmpty)
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: AppImage(
                                  selectedMeal.imagePath,
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: AppThemeV3.primaryGreen.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  selectedMeal.icon, 
                                  size: 30, 
                                  color: AppThemeV3.accent
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
                        Text(selectedMeal.name, style: AppThemeV3.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(selectedMeal.description, style: AppThemeV3.textTheme.bodySmall?.copyWith(color: AppThemeV3.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text('${selectedMeal.calories} cal • ${selectedMeal.protein}g protein', style: AppThemeV3.textTheme.bodySmall?.copyWith(color: AppThemeV3.textSecondary, fontSize: 11)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _selectMealForDay(day),
                    icon: const Icon(Icons.edit, color: AppThemeV3.accent),
                    tooltip: 'Change meal',
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints.tightFor(width: 32, height: 32),
                    padding: EdgeInsets.zero,
                  ),
                  IconButton(
                    onPressed: () => _clearMealForDay(day),
                    icon: const Icon(Icons.close, color: Colors.red),
                    tooltip: 'Remove meal',
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints.tightFor(width: 32, height: 32),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ] else ...[
            OutlinedButton(
              onPressed: () => _selectMealForDay(day),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppThemeV3.accent,
                side: const BorderSide(color: AppThemeV3.accent),
                padding: const EdgeInsets.symmetric(vertical: 16),
                minimumSize: const Size.fromHeight(64),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add),
                  const SizedBox(width: 8),
                  Text('Select $_selectedMealType'),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
 

  Widget _buildModeSelector() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppThemeV3.surface,
        border: Border.all(color: AppThemeV3.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Customization mode',
            style: AppThemeV3.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            runAlignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Week (individual)'),
                labelPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                selected: _customizeMode == 'week_individual',
                onSelected: (_) => setState(() => _customizeMode = 'week_individual'),
              ),
              ChoiceChip(
                label: const Text('One day → apply'),
                labelPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                selected: _customizeMode == 'day_then_apply',
                onSelected: (_) => setState(() => _customizeMode = 'day_then_apply'),
              ),
              ChoiceChip(
                label: const Text('Multi-day (batch)'),
                labelPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                selected: _customizeMode == 'multi_day',
                onSelected: (_) => setState(() => _customizeMode = 'multi_day'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _restartCurrentMode,
            icon: const Icon(Icons.restart_alt),
            label: const Text('Restart'),
          ),
        ],
      ),
    );
  }

  // Day-then-apply card: show one selected day until apply, then reveal all
  Widget _buildDayThenApplyCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppThemeV3.surface,
        border: Border.all(color: AppThemeV3.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Customize one day, then apply to the rest.',
            style: AppThemeV3.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
            onPressed: _hasAnyForCurrentType()
                ? () {
                    _applyCurrentTypeToAllDays();
                    setState(() => _dayThenApplyApplied = true);
                  }
                : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppThemeV3.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text('Apply current $_selectedMealType to all scheduled days'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMultiDayBatchCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppThemeV3.surface,
        border: Border.all(color: AppThemeV3.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Select days to batch-apply the same $_selectedMealType.',
            style: AppThemeV3.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            runAlignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: _configuredDays.map((day) {
              final selected = _batchDays.contains(day);
              return FilterChip(
                label: Text(day),
                selected: selected,
                onSelected: (isSel) => setState(() {
                  if (isSel) {
                    _batchDays.add(day);
                  } else {
                    _batchDays.remove(day);
                  }
                }),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _chooseBatchMeal,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppThemeV3.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(_batchSelectedMeal == null ? 'Choose meal' : 'Change meal'),
                ),
              ),
              if (_batchSelectedMeal != null) ...[
                const SizedBox(height: 6),
                Text(
                  _batchSelectedMeal!.name,
                  style: AppThemeV3.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
                TextButton(
                  onPressed: () => setState(() => _batchSelectedMeal = null),
                  child: const Text('Clear'),
                ),
              ]
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _batchDays.isNotEmpty && _batchSelectedMeal != null ? _applyBatch : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppThemeV3.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('Apply selected meal to chosen days'),
            ),
          ),
        ],
      ),
    );
  }
  

  // Removed "Save for Week" and "Customize for Week" buttons as requested.

  Widget _buildProceedButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _proceedToPayment,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppThemeV3.accent,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(
          'Proceed to Payment',
          style: AppThemeV3.textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  // Actions
  void _applyCurrentTypeToAllDays() {
    setState(() {
      MealModelV3? ref;
      for (final d in _configuredDays) {
        final m = _selectedMeals[d]?[_selectedMealType];
        if (m != null) {
          ref = m;
          break;
        }
      }
      if (ref == null) return;
      for (final d in _configuredDays) {
        final hasSchedule = _currentWeeklySchedule[d]?[_selectedMealType] != null;
        if (hasSchedule) _selectedMeals[d]![_selectedMealType] = ref;
      }
    });
    _saveMealSelections();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$_selectedMealType meals applied to all scheduled days'), backgroundColor: Colors.green),
    );
  }

  void _applyBatch() {
    final ref = _batchSelectedMeal;
    if (ref == null) return;
    final appliedCount = _batchDays.length;
    setState(() {
      for (final d in List<String>.from(_batchDays)) {
        final hasSchedule = _currentWeeklySchedule[d]?[_selectedMealType] != null;
        if (hasSchedule) _selectedMeals[d]![_selectedMealType] = ref;
      }
  // Keep previous applications; clear current selection so the user can create another set.
  _batchDays.clear();
  // Keep the chosen meal visible for convenience so user can re-apply to new days or change it.
    });
    _saveMealSelections();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Applied $_selectedMealType to $appliedCount day(s).'), backgroundColor: Colors.green),
    );
  }

  Future<void> _chooseBatchMeal() async {
  // Open the interactive menu; we update selection via callback and pop from here once chosen.
    Navigator.push(
      context,
      MaterialPageRoute(
    builder: (_) => InteractiveMenuPageV3(
          menuType: _selectedMealType.toLowerCase(),
          day: 'Batch',
          selectedMeal: _batchSelectedMeal,
          onMealSelected: (meal) {
            // If days are selected, apply immediately and clear the selection for rapid batching.
            if (_customizeMode == 'multi_day' && _batchDays.isNotEmpty) {
              final appliedDays = List<String>.from(_batchDays);
              setState(() {
                for (final d in appliedDays) {
                  final hasSchedule = _currentWeeklySchedule[d]?[_selectedMealType] != null;
                  if (hasSchedule) {
                    _selectedMeals[d]![_selectedMealType] = meal;
                  }
                }
                _batchDays.clear();
                _batchSelectedMeal = null;
              });
              _saveMealSelections();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Applied $_selectedMealType to ${appliedDays.length} day(s).'), backgroundColor: Colors.green),
              );
            } else {
              setState(() => _batchSelectedMeal = meal);
            }
            // Close the menu and return to the schedule page after choosing.
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  void _selectMealForDay(String day) {
    final selectedMeal = _selectedMeals[day]?[_selectedMealType];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InteractiveMenuPageV3(
          menuType: _selectedMealType.toLowerCase(),
          day: day,
          selectedMeal: selectedMeal,
          onMealSelected: (meal) {
            setState(() => _selectedMeals[day]![_selectedMealType] = meal);
            _saveMealSelections();
            Navigator.pop(context); // return to schedule after choosing
          },
        ),
      ),
    );
  }

  void _clearMealForDay(String day) {
    setState(() => _selectedMeals[day]![_selectedMealType] = null);
    _saveMealSelections();
  }

  // Restart current mode and clear customizations for the current meal type (with confirmation)
  void _restartCurrentMode() {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restart Customizations'),
        content: Text('This will clear all selected meals for $_selectedMealType across the visible days. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Restart', style: TextStyle(color: Colors.red))),
        ],
      ),
  ).then((confirmed) {
      if (confirmed != true) return;
      setState(() {
    // Clear meals for current meal type on ALL configured days
    for (final d in _configuredDays) {
          if (_selectedMeals[d] != null) {
            _selectedMeals[d]![_selectedMealType] = null;
          }
        }
        // Reset mode UI state
        if (_customizeMode == 'day_then_apply') {
          _dayThenApplyApplied = false;
          _dayThenApplySelectedDay = _configuredDays.isNotEmpty ? _configuredDays.first : null;
        } else if (_customizeMode == 'multi_day') {
          _batchDays.clear();
          _batchSelectedMeal = null;
        }
      });
      _saveMealSelections();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cleared $_selectedMealType selections.')),
      );
    });
  }

    // Removed _confirmDeleteSchedule (no longer used after bottom sheet picker was introduced)

  Future<void> _deleteSchedule(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('saved_schedules') ?? [];
    final updated = saved.where((s) => s != name).toList();
    await prefs.setStringList('saved_schedules', updated);
    await prefs.remove('delivery_schedule_$name');
    await prefs.remove('meal_selections_$name');

    if (!mounted) return;
    setState(() {
      _availableSchedules = updated;
      if (_selectedSchedule == name) {
        _selectedSchedule = updated.isNotEmpty ? updated.first : null;
      }
    });
    if (_selectedSchedule != null) {
      await _loadScheduleData(_selectedSchedule!);
    } else {
      // Clear current data if no schedules remain
      setState(() {
        _currentWeeklySchedule.clear();
        _selectedMeals.clear();
        _currentMealTypes = [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All schedules deleted')), 
      );
    }
  }

}

// Panel widget used in the anchored dropdown overlay for schedules
class _ScheduleDropdownPanel extends StatelessWidget {
  final List<String> schedules;
  final String? selected;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onDelete;
  final VoidCallback onAddNew;

  const _ScheduleDropdownPanel({
    required this.schedules,
    required this.selected,
    required this.onSelect,
    required this.onDelete,
    required this.onAddNew,
  });

  @override
  Widget build(BuildContext context) {
    const rowHeight = 48.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (schedules.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('No schedules saved yet.'),
          )
        else
          Flexible(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: schedules.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final name = schedules[index];
                final isSel = name == selected;
                return InkWell(
                  onTap: () => onSelect(name),
                  child: SizedBox(
                    height: rowHeight,
                    child: Row(
                      children: [
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 20,
                          child: isSel
                              ? const Icon(Icons.check, size: 20, color: AppThemeV3.accent)
                              : const SizedBox.shrink(),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          onPressed: () => onDelete(name),
                          icon: const Icon(Icons.close, color: Colors.redAccent, size: 20),
                          tooltip: 'Delete',
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(width: 36, height: 36),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        const Divider(height: 1),
        InkWell(
          onTap: onAddNew,
          child: const SizedBox(
            height: rowHeight,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(Icons.add),
                  SizedBox(width: 12),
                  Expanded(child: Text('Add Another Schedule')),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
