import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/meal_model_v3.dart';
import '../services/simple_meal_plan_service.dart';
import '../theme/app_theme_v3.dart';

class OnboardingMealPlanPageV3 extends StatefulWidget {
  const OnboardingMealPlanPageV3({super.key});

  @override
  State<OnboardingMealPlanPageV3> createState() => _OnboardingMealPlanPageV3State();
}

class _OnboardingMealPlanPageV3State extends State<OnboardingMealPlanPageV3> {
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
      debugPrint('[OnboardingMealPlan] Setting up meal plan for new user: ${plan.displayName}');
      
      // Use the simplified service for onboarding - just store preferences
      await SimpleMealPlanService.setActiveMealPlanSimple(uid, plan);
      
      // Store locally for immediate use
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_meal_plan_id', plan.id);
      await prefs.setString('selected_meal_plan_name', plan.name);
      await prefs.setString('selected_meal_plan_display_name', plan.displayName);
      await prefs.setBool('onboarding_plan_selected', true);
      
      debugPrint('[OnboardingMealPlan] Plan selection successful, navigating to home');
      
      if (mounted) {
        // Navigate to home page - onboarding complete
        Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
      }
    } catch (e) {
      debugPrint('[OnboardingMealPlan] Error: $e');
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
    return WillPopScope(
      onWillPop: () async => false, // Prevent back navigation during onboarding
      child: Scaffold(
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
          children: [
            // Welcome message
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.only(bottom: 30),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
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
                    color: AppThemeV3.primaryColor,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Welcome to Fresh Punk!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Choose a meal plan to get started. You can always change this later in your settings.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            
            // Meal plans
            Expanded(
              child: ListView.builder(
                itemCount: _plans.length,
                itemBuilder: (context, index) {
                  final plan = _plans[index];
                  final isSelected = _selectedPlanId == plan.id;
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: InkWell(
                      onTap: () => setState(() => _selectedPlanId = plan.id),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? AppThemeV3.primaryColor : Colors.grey[300]!,
                            width: isSelected ? 2 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            // Radio button
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? AppThemeV3.primaryColor : Colors.grey[400]!,
                                  width: 2,
                                ),
                                color: isSelected ? AppThemeV3.primaryColor : Colors.transparent,
                              ),
                              child: isSelected
                                  ? const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 16,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 16),
                            
                            // Plan details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    plan.displayName,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${plan.mealsPerDay} meal(s) per day • ~\$${plan.monthlyPrice.toInt()}/mo',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    plan.description,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            
            // Continue button
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: ElevatedButton(
                onPressed: _saving ? null : _continue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppThemeV3.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: _saving
                    ? const Row(
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
          ],
        ),
      ),
    ); // Close WillPopScope
  }
}
