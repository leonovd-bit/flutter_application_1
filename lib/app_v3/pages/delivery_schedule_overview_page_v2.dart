import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme_v3.dart';
import '../models/meal_model_v3.dart';
import 'delivery_schedule_page_v4.dart';

class DeliveryScheduleOverviewPageV2 extends StatefulWidget {
  const DeliveryScheduleOverviewPageV2({super.key});

  @override
  State<DeliveryScheduleOverviewPageV2> createState() => _DeliveryScheduleOverviewPageV2State();
}

class _DeliveryScheduleOverviewPageV2State extends State<DeliveryScheduleOverviewPageV2> {
  List<String> _schedules = [];
  String? _selected;
  Map<String, dynamic>? _summary;
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
      setState(() => _summary = null);
      return;
    }
    try {
      final data = json.decode(raw) as Map<String, dynamic>;
      setState(() => _summary = data);
    } catch (_) {
      setState(() => _summary = null);
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
                  builder: (_) => DeliverySchedulePageV4(
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
    final days = weekly.keys.toList()..sort();
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
          Text('Plan: $planName', style: AppThemeV3.textTheme.titleLarge),
          const SizedBox(height: 6),
          Text('Days: ${days.join(', ')}', style: TextStyle(color: AppThemeV3.textSecondary)),
          const SizedBox(height: 6),
          Text('Meal Types: ${mealTypes.join(', ')}', style: TextStyle(color: AppThemeV3.textSecondary)),
          const SizedBox(height: 12),
          ...days.map((day) {
            final mtMap = Map<String, dynamic>.from(weekly[day] as Map<String, dynamic>? ?? {});
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
                  ...mealTypes.map((mt) {
                    final info = Map<String, dynamic>.from(mtMap[mt] as Map<String, dynamic>? ?? {});
                    final time = _formatTime(info['time']?.toString() ?? '-');
                    final addr = (info['address'] ?? '-').toString();
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          SizedBox(width: 100, child: Text(mt, style: const TextStyle(fontWeight: FontWeight.w600))),
                          Expanded(child: Text('Time: $time')),
                          Expanded(child: Text('Address: $addr')),
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
}
