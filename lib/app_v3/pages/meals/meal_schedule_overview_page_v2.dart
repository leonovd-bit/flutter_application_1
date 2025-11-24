import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../theme/app_theme_v3.dart';
import 'meal_schedule_page_v3_fixed.dart';

class MealScheduleOverviewPageV2 extends StatefulWidget {
  const MealScheduleOverviewPageV2({super.key});

  @override
  State<MealScheduleOverviewPageV2> createState() => _MealScheduleOverviewPageV2State();
}

class _MealScheduleOverviewPageV2State extends State<MealScheduleOverviewPageV2> {
  List<String> _schedules = [];
  String? _selected;
  Map<String, Map<String, dynamic>> _weekly = {};
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
    if (_selected != null) await _loadWeekly(_selected!);
  }

  Future<void> _loadWeekly(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final schedKey = _uid == null ? 'delivery_schedule_$name' : 'delivery_schedule_${_uid}_$name';
    final mealsKey = _uid == null ? 'meal_selections_$name' : 'meal_selections_${_uid}_$name';
    final rawSched = prefs.getString(schedKey);
    final rawMeals = prefs.getString(mealsKey);
    
    debugPrint('[Overview] Loading schedule: $name');
    debugPrint('[Overview] Schedule key: $schedKey');
    debugPrint('[Overview] Meals key: $mealsKey');
    debugPrint('[Overview] Raw schedule found: ${rawSched != null}');
    debugPrint('[Overview] Raw meals found: ${rawMeals != null}');
    
    Map<String, Map<String, dynamic>> weekly = {};
    List<String> types = [];
    
    // Load delivery schedule (times and addresses)
    if (rawSched != null) {
      try {
        debugPrint('[Overview] Raw schedule JSON: ${rawSched.substring(0, rawSched.length > 500 ? 500 : rawSched.length)}');
        final data = json.decode(rawSched) as Map<String, dynamic>;
        final ws = data['weeklySchedule'] as Map<String, dynamic>?;
        debugPrint('[Overview] Weekly schedule keys: ${ws?.keys.toList()}');
        if (ws != null) {
          ws.forEach((day, val) {
            // Normalize day name to title case
            final normalizedDay = day.toString()[0].toUpperCase() + day.toString().substring(1).toLowerCase();
            debugPrint('[Overview] Schedule day: $day -> $normalizedDay, val type: ${val.runtimeType}');
            
            // Normalize meal type keys within the day
            final dayData = Map<String, dynamic>.from(val as Map<String, dynamic>);
            final normalizedDayData = <String, dynamic>{};
            dayData.forEach((mt, info) {
              final normalizedMt = mt.toString()[0].toUpperCase() + mt.toString().substring(1).toLowerCase();
              normalizedDayData[normalizedMt] = info;
            });
            
            weekly[normalizedDay] = normalizedDayData;
            debugPrint('[Overview] Loaded schedule for $normalizedDay: ${weekly[normalizedDay]!.keys.toList()}');
          });
          debugPrint('[Overview] Loaded ${weekly.length} days from schedule');
        }
        types = List<String>.from(data['selectedMealTypes'] ?? const <String>[]);
        debugPrint('[Overview] Meal types: $types');
      } catch (e) {
        debugPrint('[Overview] Error parsing schedule: $e');
      }
    }
    
    // Load meal selections (meal names)
    if (rawMeals != null) {
      try {
        debugPrint('[Overview] Raw meals JSON: ${rawMeals.substring(0, rawMeals.length > 500 ? 500 : rawMeals.length)}');
        final data = json.decode(rawMeals) as Map<String, dynamic>;
        debugPrint('[Overview] Parsed meals data keys: ${data.keys.toList()}');
        data.forEach((day, mtMap) {
          // Normalize day name to title case
          final normalizedDay = day.toString()[0].toUpperCase() + day.toString().substring(1).toLowerCase();
          debugPrint('[Overview] Processing day: $day -> $normalizedDay, mtMap type: ${mtMap.runtimeType}');
          final mealsForDay = Map<String, dynamic>.from(mtMap as Map<String, dynamic>);
          debugPrint('[Overview] Meals for $normalizedDay: ${mealsForDay.keys.toList()}');
          mealsForDay.forEach((mt, mealJson) {
            // Normalize meal type to title case
            final normalizedMt = mt.toString()[0].toUpperCase() + mt.toString().substring(1).toLowerCase();
            debugPrint('[Overview] Processing $normalizedDay/$mt -> $normalizedMt, mealJson type: ${mealJson.runtimeType}');
            final meal = Map<String, dynamic>.from(mealJson as Map<String, dynamic>);
            debugPrint('[Overview] Meal data for $normalizedDay/$normalizedMt: ${meal.keys.toList()}');
            weekly[normalizedDay] ??= {};
            weekly[normalizedDay]![normalizedMt] ??= {};
            weekly[normalizedDay]![normalizedMt]['mealName'] = (meal['name'] ?? '').toString();
            debugPrint('[Overview] Added meal for $normalizedDay/$normalizedMt: ${meal['name']} (weekly[$normalizedDay][$normalizedMt] = ${weekly[normalizedDay]![normalizedMt]})');
          });
        });
      } catch (e) {
        debugPrint('[Overview] Error parsing meals: $e');
      }
    }
    
    // If no meal types found in schedule, derive from weekly data
    if (types.isEmpty && weekly.isNotEmpty) {
      final Set<String> foundTypes = {};
      for (final dayData in weekly.values) {
        foundTypes.addAll(dayData.keys);
      }
      types = foundTypes.toList()..sort();
      debugPrint('[Overview] Derived meal types from data: $types');
    }
    
    setState(() {
      _weekly = weekly;
      debugPrint('[Overview] Final _weekly state: ${_weekly.keys.toList()}');
      _weekly.forEach((day, mtMap) {
        debugPrint('[Overview] _weekly[$day]: ${mtMap.keys.toList()}');
        mtMap.forEach((mt, info) {
          debugPrint('[Overview] _weekly[$day][$mt]: $info');
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeV3.background,
      appBar: AppBar(
        backgroundColor: AppThemeV3.surface,
        title: const Text('Meal Schedule Overview'),
        actions: [
          TextButton(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MealSchedulePageV3(
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
                  await _loadWeekly(v);
                },
              ),
              const SizedBox(height: 12),
              if (_weekly.isEmpty)
                const Center(child: Text('No schedule details to show.'))
              else
                ..._buildWeeklyCards(),
            ],
          ],
        ),
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

  List<Widget> _buildWeeklyCards() {
    final days = _weekly.keys.toList()
      ..sort((a, b) => _dayIndex(a).compareTo(_dayIndex(b)));
    return days.map((day) {
      final mtMap = _weekly[day] ?? {};
      
      // Only show meal types that are actually configured for this day
      final configuredMealTypes = mtMap.keys.where((mt) {
        final info = mtMap[mt];
        if (info == null) return false;
        if (info is! Map) return false;
        return info['time'] != null || info['address'] != null || info['mealName'] != null;
      }).toList();
      
      // Skip days with no configured meals
      if (configuredMealTypes.isEmpty) {
        return const SizedBox.shrink();
      }
      
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppThemeV3.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppThemeV3.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(day, style: AppThemeV3.textTheme.titleLarge),
            const SizedBox(height: 8),
            ...configuredMealTypes.map((mt) {
              final info = mtMap[mt];
              if (info == null || info is! Map) {
                debugPrint('[Overview] Skipping $day/$mt - info is null or not a Map (type: ${info.runtimeType})');
                return const SizedBox.shrink();
              }
              
              final time = () {
                final val = info['time']?.toString() ?? '-';
                if (val == '-' || val.isEmpty) return val;
                return _formatTime(val);
              }();
              final addr = info['address']?.toString() ?? '-';
              final mealName = info['mealName']?.toString() ?? '—';
              
              debugPrint('[Overview] Displaying $day/$mt - time: $time, addr: $addr, meal: $mealName');
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
                  ],
                ),
              );
            }),
          ],
        ),
      );
    }).toList();
  }

  int _dayIndex(String day) {
    const order = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
    final i = order.indexOf(day);
    return i < 0 ? 7 : i;
  }
}
