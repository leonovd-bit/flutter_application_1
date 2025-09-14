import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/meal_model_v3.dart';
import '../services/simple_meal_plan_service.dart';
import '../theme/app_theme_v3.dart';

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
    // Pre-select the first plan (NutritiousJr) as default
    _selectedPlanId = _plans.first.id;
  }

  Future<void> _continue() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || _selectedPlanId == null) return;
    
    final plan = _plans.firstWhere((p) => p.id == _selectedPlanId);
    setState(() => _saving = true);
    
    try {
      debugPrint('[ChooseMealPlan] Setting up meal plan for new user: ${plan.displayName}');
      
      // Use the simplified service for onboarding - just store preferences
      await SimpleMealPlanService.setActiveMealPlanSimple(uid, plan);
      
      // Store locally for immediate use
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_meal_plan_id', plan.id);
      await prefs.setString('selected_meal_plan_name', plan.name);
      await prefs.setString('selected_meal_plan_display_name', plan.displayName);
      await prefs.setBool('onboarding_plan_selected', true);
      
      debugPrint('[ChooseMealPlan] Plan selection successful, navigating to home');
      
      if (mounted) {
        // Navigate to home page - onboarding complete
        Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
      }
    } catch (e) {
      debugPrint('[ChooseMealPlan] Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save plan selection. You can change this later in settings.'),
            backgroundColor: Colors.orange,
            action: SnackBarAction(
              label: 'Continue Anyway',
              textColor: Colors.white,
              onPressed: () {
                // Continue to home even if plan save failed
                Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
              },
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Choose your meal plan'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        automaticallyImplyLeading: false, // Remove back button for onboarding
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.restaurant_menu,
                    size: 48,
                    color: AppThemeV3.primaryGreen,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Choose Your Fresh Punk Plan',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Select a meal plan that fits your lifestyle. You can always change this later in settings.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Plans List
            Expanded(
              child: ListView.builder(
                itemCount: _plans.length,
                itemBuilder: (context, index) {
                  final plan = _plans[index];
                  final selected = plan.id == _selectedPlanId;
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected ? AppThemeV3.primaryGreen : Colors.grey[300]!,
                        width: selected ? 2 : 1,
                      ),
                      boxShadow: selected ? [
                        BoxShadow(
                          color: AppThemeV3.primaryGreen.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ] : null,
                    ),
                    child: RadioListTile<String>(
                      value: plan.id,
                      groupValue: _selectedPlanId,
                      activeColor: AppThemeV3.primaryGreen,
                      onChanged: (val) => setState(() => _selectedPlanId = val),
                      title: Text(
                        plan.displayName,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: selected ? AppThemeV3.primaryGreen : Colors.black87,
                        ),
                      ),
                      subtitle: Text('${plan.mealsPerDay} meal(s) per day • ~\$${plan.monthlyPrice.toStringAsFixed(0)}/mo'),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      onTap: () => setState(() => _selectedPlanId = plan.id),
                    ),
                  );
                },
              ),
            ),
            
            // Continue Button
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _saving || _selectedPlanId == null ? null : _continue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppThemeV3.primaryGreen,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _saving
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Setting up your plan...',
                              style: TextStyle(fontSize: 16),
                            ),
                          ],
                        )
                      : const Text(
                          'Continue to Fresh Punk',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
