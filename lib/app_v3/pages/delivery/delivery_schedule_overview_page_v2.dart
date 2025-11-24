import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme_v3.dart';
import '../../models/meal_model_v3.dart';
import 'delivery_schedule_page_v5.dart';

class DeliveryScheduleOverviewPageV2 extends StatefulWidget {
  const DeliveryScheduleOverviewPageV2({super.key});

  @override
  State<DeliveryScheduleOverviewPageV2> createState() => _DeliveryScheduleOverviewPageV2State();
}

class _DeliveryScheduleOverviewPageV2State extends State<DeliveryScheduleOverviewPageV2> {
  List<String> _schedules = [];
  String? _selected;
  Map<String, dynamic>? _summary;
  Map<String, dynamic>? _mealSelections;
  String? _uid;

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser?.uid;
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
  final userKey = _uid == null ? 'saved_schedules' : 'saved_schedules_${_uid}';
  final List<String> saved = prefs.getStringList(userKey) ?? [];
    setState(() {
      _schedules = saved;
      _selected = saved.isNotEmpty ? saved.first : null;
    });
    if (_selected != null) await _loadSummary(_selected!);
  }

  Future<void> _loadSummary(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _uid == null
        ? 'delivery_schedule_$name'
        : 'delivery_schedule_${_uid}_$name';
    final raw = prefs.getString(key);
    if (raw == null) {
      debugPrint('[ScheduleOverview] No schedule found for key: $key');
      setState(() {
        _summary = null;
        _mealSelections = null;
      });
      return;
    }
    try {
      final data = json.decode(raw) as Map<String, dynamic>;
      debugPrint('[ScheduleOverview] Loaded schedule with ${(data['weeklySchedule'] as Map?)?.keys.length ?? 0} days');
      
      // Also load meal selections
      final mealKey = _uid == null
          ? 'meal_selections_$name'
          : 'meal_selections_${_uid}_$name';
      final mealRaw = prefs.getString(mealKey);
      Map<String, dynamic>? meals;
      if (mealRaw != null) {
        try {
          meals = json.decode(mealRaw) as Map<String, dynamic>;
          debugPrint('[ScheduleOverview] Loaded meal selections for ${meals.keys.length} days: ${meals.keys.join(', ')}');
          // Debug: print first meal to see structure
          if (meals.isNotEmpty) {
            final firstDay = meals.keys.first;
            final firstDayMeals = meals[firstDay];
            debugPrint('[ScheduleOverview] Sample day "$firstDay" meals: $firstDayMeals');
          }
        } catch (e) {
          debugPrint('[ScheduleOverview] Error parsing meal selections: $e');
          meals = null;
        }
      } else {
        debugPrint('[ScheduleOverview] No meal selections found for key: $mealKey');
      }
      
      setState(() {
        _summary = data;
        _mealSelections = meals;
      });
    } catch (e) {
      debugPrint('[ScheduleOverview] Error parsing schedule: $e');
      setState(() {
        _summary = null;
        _mealSelections = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeV3.background,
      appBar: AppBar(
        backgroundColor: AppThemeV3.surface,
        title: const Text('Delivery Schedule Overview'),
        actions: [
          TextButton(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DeliverySchedulePageV5(
                    initialScheduleName: _selected,
                  ),
                ),
              );
              if (!mounted) return;
              await _load();
            },
            child: const Text('Edit'),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_schedules.isEmpty)
              const Text('No saved schedules yet.')
            else ...[
              DropdownButton<String>(
                value: _selected,
                isExpanded: true,
                items: _schedules.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (v) async {
                  if (v == null) return;
                  setState(() => _selected = v);
                  await _loadSummary(v);
                },
              ),
              const SizedBox(height: 12),
              if (_summary != null) _buildSummaryCard(_summary!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(Map<String, dynamic> data) {
    final weekly = (data['weeklySchedule'] as Map<String, dynamic>? ?? {});
    final days = weekly.keys.toList()..sort((a, b) => _dayIndex(a).compareTo(_dayIndex(b)));
    final mealTypes = List<String>.from(data['selectedMealTypes'] ?? const <String>[]);
    String planName = (data['mealPlanDisplayName'] ?? data['mealPlanName'] ?? '').toString();
    final planId = (data['mealPlanId'] ?? '').toString();
    if (planName.trim().isEmpty && planId.isNotEmpty) {
      try {
        final plans = MealPlanModelV3.getAvailablePlans();
        final match = plans.firstWhere((p) => p.id == planId);
        planName = match.displayName.isNotEmpty ? match.displayName : match.name;
      } catch (_) {
        planName = planId;
      }
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppThemeV3.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppThemeV3.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Plan name - keep as is since it's the title
          Text('Plan: $planName', style: AppThemeV3.textTheme.titleLarge),
          const SizedBox(height: 12),
          
          // Meal types in a row format
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 100,
                child: Text(
                  'Meal Types:',
                  style: TextStyle(
                    color: AppThemeV3.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  mealTypes.join(', '),
                  style: TextStyle(color: AppThemeV3.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...days.map((day) {
            final mtMap = Map<String, dynamic>.from(weekly[day] as Map<String, dynamic>? ?? {});
            
            // Only get meal types that are actually scheduled for this day
            final scheduledMeals = mtMap.keys.where((key) => mtMap[key] != null).toList();
            
            // Skip days with no meals scheduled
            if (scheduledMeals.isEmpty) {
              return const SizedBox.shrink();
            }
            
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppThemeV3.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(day, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  ...scheduledMeals.map((mt) {
                    final info = Map<String, dynamic>.from(mtMap[mt] as Map<String, dynamic>? ?? {});
                    final time = _formatTime(info['time']?.toString() ?? '-');
                    final addr = (info['address'] ?? '-').toString();
                    
                    // Get meal name from meal selections
                    String mealName = '—';
                    if (_mealSelections != null) {
                      // Try to find the day in meal selections (case-insensitive)
                      String? matchingDay;
                      for (final selectionDay in _mealSelections!.keys) {
                        if (selectionDay.toString().toLowerCase() == day.toLowerCase()) {
                          matchingDay = selectionDay;
                          break;
                        }
                      }
                      
                      if (matchingDay != null && _mealSelections![matchingDay] != null) {
                        final dayMeals = _mealSelections![matchingDay] as Map<String, dynamic>?;
                        if (dayMeals != null) {
                          // Try to find the meal type (case-insensitive)
                          String? matchingMealType;
                          for (final mealTypeKey in dayMeals.keys) {
                            if (mealTypeKey.toString().toLowerCase() == mt.toLowerCase()) {
                              matchingMealType = mealTypeKey;
                              break;
                            }
                          }
                          
                          if (matchingMealType != null && dayMeals[matchingMealType] != null) {
                            final mealData = dayMeals[matchingMealType] as Map<String, dynamic>?;
                            mealName = mealData?['name'] ?? '—';
                          }
                        }
                      }
                    }
                    
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Meal type header
                          Text(
                            mt,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Time row
                          Row(
                            children: [
                              Icon(Icons.access_time, size: 14, color: AppThemeV3.textSecondary),
                              const SizedBox(width: 6),
                              Text(
                                'Time:',
                                style: TextStyle(
                                  color: AppThemeV3.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(time, style: const TextStyle(fontSize: 13)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          // Meal name row
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.restaurant, size: 14, color: AppThemeV3.textSecondary),
                              const SizedBox(width: 6),
                              Text(
                                'Meal:',
                                style: TextStyle(
                                  color: AppThemeV3.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  mealName,
                                  style: const TextStyle(fontSize: 13),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          // Address row
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.location_on, size: 14, color: AppThemeV3.textSecondary),
                              const SizedBox(width: 6),
                              Text(
                                'Address:',
                                style: TextStyle(
                                  color: AppThemeV3.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  addr,
                                  style: const TextStyle(fontSize: 13),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  String _formatTime(String raw) {
    try {
      final parts = raw.split(':');
      if (parts.length != 2) return raw;
      final h = int.parse(parts[0]);
      final m = int.parse(parts[1]);
      final period = h >= 12 ? 'PM' : 'AM';
      final hour12 = ((h % 12) == 0) ? 12 : (h % 12);
      final mm = m.toString().padLeft(2, '0');
      return '$hour12:$mm $period';
    } catch (_) {
      return raw;
    }
  }

  int _dayIndex(String day) {
    const order = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final index = order.indexOf(day);
    return index == -1 ? 999 : index;
  }
}
