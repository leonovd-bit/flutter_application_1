import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme_v3.dart';
import 'meal_schedule_page_v3.dart';

class MealScheduleOverviewPageV1 extends StatefulWidget {
  const MealScheduleOverviewPageV1({super.key});

  @override
  State<MealScheduleOverviewPageV1> createState() => _MealScheduleOverviewPageV1State();
}

class _MealScheduleOverviewPageV1State extends State<MealScheduleOverviewPageV1> {
  List<String> _schedules = [];
  String? _selected;
  Map<String, Map<String, dynamic>> _weekly = {};
  List<String> _mealTypes = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('saved_schedules') ?? [];
    setState(() {
      _schedules = saved;
      _selected = saved.isNotEmpty ? saved.first : null;
    });
    if (_selected != null) await _loadWeekly(_selected!);
  }

  Future<void> _loadWeekly(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final rawSched = prefs.getString('delivery_schedule_$name');
    final rawMeals = prefs.getString('meal_selections_$name');
    Map<String, Map<String, dynamic>> weekly = {};
    List<String> types = [];
    if (rawSched != null) {
      try {
        final data = json.decode(rawSched) as Map<String, dynamic>;
        final ws = data['weeklySchedule'] as Map<String, dynamic>?;
        if (ws != null) {
          ws.forEach((day, val) {
            weekly[day] = Map<String, dynamic>.from(val as Map<String, dynamic>);
          });
        }
        types = List<String>.from(data['selectedMealTypes'] ?? const <String>[]);
      } catch (_) {}
    }
    if (rawMeals != null) {
      try {
        final data = json.decode(rawMeals) as Map<String, dynamic>;
        // Attach selected meal names where available
        data.forEach((day, mtMap) {
          final mealsForDay = Map<String, dynamic>.from(mtMap as Map<String, dynamic>);
          mealsForDay.forEach((mt, mealJson) {
            final meal = Map<String, dynamic>.from(mealJson as Map<String, dynamic>);
            weekly[day] ??= {};
            weekly[day]![mt] ??= {};
            weekly[day]![mt]['mealName'] = (meal['name'] ?? '').toString();
          });
        });
      } catch (_) {}
    }
    setState(() {
      _weekly = weekly;
      _mealTypes = types;
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
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const MealSchedulePageV3()));
              if (!mounted) return;
              await _load();
            },
            child: const Text('Edit'),
          )
        ],
      ),
      body: Padding(
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
              Expanded(
                child: _weekly.isEmpty
                    ? const Center(child: Text('No schedule details to show.'))
                    : ListView(
                        children: _buildWeeklyCards(),
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTime(String raw) {
    // Expecting HH:mm; return h:mm AM/PM; else return raw
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
            ..._mealTypes.map((mt) {
              final info = mtMap[mt] as Map<String, dynamic>?;
              final time = () {
                final val = info?['time']?.toString() ?? '-';
                if (val == '-' || val.isEmpty) return val;
                return _formatTime(val);
              }();
              final addr = info?['address']?.toString() ?? '-';
              final mealName = info?['mealName']?.toString() ?? '—';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(width: 100, child: Text(mt, style: const TextStyle(fontWeight: FontWeight.w600))),
                    Expanded(child: Text('Time: $time')),
                    Expanded(child: Text('Address: $addr')),
                    Expanded(child: Text('Meal: $mealName')),
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
