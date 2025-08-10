import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/meal_model_v3.dart';
import '../services/firestore_service_v3.dart';
import '../theme/app_theme_v3.dart';

class PlanSubscriptionPageV3 extends StatefulWidget {
  const PlanSubscriptionPageV3({super.key});

  @override
  State<PlanSubscriptionPageV3> createState() => _PlanSubscriptionPageV3State();
}

class _PlanSubscriptionPageV3State extends State<PlanSubscriptionPageV3> {
  final _auth = FirebaseAuth.instance;
  final _plans = MealPlanModelV3.getAvailablePlans();
  String? _selectedPlanId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadCurrent();
  }

  Future<void> _loadCurrent() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      final current = await FirestoreServiceV3.getCurrentMealPlan(uid);
      if (mounted) {
        setState(() {
          _selectedPlanId = current?.id;
        });
      }
    } catch (_) {}
  }

  Future<void> _save() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || _selectedPlanId == null) return;
    final plan = _plans.firstWhere((p) => p.id == _selectedPlanId);
    setState(() => _saving = true);
    try {
      await FirestoreServiceV3.setActiveMealPlan(uid, plan);
      await FirestoreServiceV3.updateActiveSubscriptionPlan(uid, plan);
      // Persist local fallbacks for display
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('selected_meal_plan_id', plan.id);
        await prefs.setString('selected_meal_plan_name', plan.name);
        await prefs.setString('selected_meal_plan_display_name', plan.displayName);
      } catch (_) {}
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Meal plan updated')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meal Plan Subscription'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      backgroundColor: Colors.white,
      body: Column(
        children: [
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: _plans.length,
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) {
                final plan = _plans[index];
                final selected = plan.id == _selectedPlanId;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: selected ? AppThemeV3.primaryGreen : Colors.grey.shade200, width: selected ? 2 : 1),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: Radio<String>(
                      value: plan.id,
                      groupValue: _selectedPlanId,
                      activeColor: AppThemeV3.primaryGreen,
                      onChanged: (val) => setState(() => _selectedPlanId = val),
                    ),
                    title: Text(plan.displayName, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('${plan.mealsPerDay} meal(s) per day • ~\$${plan.monthlyPrice.toStringAsFixed(0)}/mo'),
                    onTap: () => setState(() => _selectedPlanId = plan.id),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppThemeV3.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(_saving ? 'Saving...' : 'Save Changes'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
