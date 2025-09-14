import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/meal_model_v3.dart';
import '../theme/app_theme_v3.dart';
import 'delivery_schedule_page_v4.dart';

class DeliveryScheduleOverviewPageV1 extends StatefulWidget {
  const DeliveryScheduleOverviewPageV1({super.key});

  @override
  State<DeliveryScheduleOverviewPageV1> createState() => _DeliveryScheduleOverviewPageV1State();
}

class _DeliveryScheduleOverviewPageV1State extends State<DeliveryScheduleOverviewPageV1> {
  List<String> _schedules = [];
  String? _selected;
  Map<String, dynamic>? _summary;

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
    if (_selected != null) await _loadSummary(_selected!);
  }

  Future<void> _loadSummary(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('delivery_schedule_$name');
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
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const DeliverySchedulePageV4()));
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
    final days = (data['weeklySchedule'] as Map<String, dynamic>? ?? {}).keys.toList()..sort();
    final mealTypes = List<String>.from(data['selectedMealTypes'] ?? const <String>[]);
    String planName = (
      data['mealPlanDisplayName'] ?? data['mealPlanName'] ?? ''
    ).toString();
    final planId = (data['mealPlanId'] ?? '').toString();
    if (planName.trim().isEmpty && planId.isNotEmpty) {
      try {
        final plans = MealPlanModelV3.getAvailablePlans();
        final match = plans.firstWhere((p) => p.id == planId);
        planName = match.displayName.isNotEmpty ? match.displayName : match.name;
      } catch (_) {
        planName = planId; // fallback to ID
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
        ],
      ),
    );
  }
}
