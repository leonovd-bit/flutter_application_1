import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/meal_model_v3.dart';
import '../services/firestore_service_v3.dart';
import '../theme/app_theme_v3.dart';
import 'delivery_schedule_page_v4.dart';
import '../services/auth_wrapper.dart';

class ChooseMealPlanPageV3 extends StatefulWidget {
  const ChooseMealPlanPageV3({super.key});

  @override
  State<ChooseMealPlanPageV3> createState() => _ChooseMealPlanPageV3State();
}

class _ChooseMealPlanPageV3State extends State<ChooseMealPlanPageV3> {
  final _auth = FirebaseAuth.instance;
  final _plans = MealPlanModelV3.getAvailablePlans();
  String? _selectedPlanId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _prefillFromServer();
  }

  Future<void> _prefillFromServer() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      final current = await FirestoreServiceV3.getCurrentMealPlan(uid);
      if (mounted) setState(() => _selectedPlanId = current?.id);
    } catch (_) {}
  }

  Future<void> _continue() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || _selectedPlanId == null) return;
    final plan = _plans.firstWhere((p) => p.id == _selectedPlanId);
    setState(() => _saving = true);
    try {
      // Persist to Firestore as active plan and denormalize to profile/subscription
      await FirestoreServiceV3.setActiveMealPlan(uid, plan);
      await FirestoreServiceV3.updateActiveSubscriptionPlan(uid, plan);

      // Save local fallbacks (also namespaced by uid to avoid cross-account carryover)
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('selected_meal_plan_id', plan.id);
        await prefs.setString('selected_meal_plan_name', plan.name);
        await prefs.setString('selected_meal_plan_display_name', plan.displayName);
        await prefs.setString('selected_meal_plan_id_${uid}', plan.id);
        await prefs.setString('selected_meal_plan_display_name_${uid}', plan.displayName);
        
        // Mark explicit approval so auth bootstrap can safely seed/generate
        if (mounted) {
          try {
            ExplicitSetupApproval.approve(context);
          } catch (_) {}
        }
      } catch (_) {}

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DeliverySchedulePageV4()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save selection: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose your meal plan'),
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
                    border: Border.all(
                      color: selected ? AppThemeV3.primaryGreen : Colors.grey.shade200,
                      width: selected ? 2 : 1,
                    ),
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
                  onPressed: _saving || _selectedPlanId == null ? null : _continue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppThemeV3.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(_saving ? 'Saving...' : 'Continue'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
