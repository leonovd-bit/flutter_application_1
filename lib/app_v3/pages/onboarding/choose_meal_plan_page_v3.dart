import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/meal_model_v3.dart';
import '../../services/auth/firestore_service_v3.dart';
import '../delivery/delivery_schedule_page_v5.dart';

class ChooseMealPlanPageV3 extends StatefulWidget {
  final bool isSignupFlow;
  
  const ChooseMealPlanPageV3({
    super.key,
    this.isSignupFlow = false,
  });

  @override
  State<ChooseMealPlanPageV3> createState() => _ChooseMealPlanPageV3State();
}

class _ChooseMealPlanPageV3State extends State<ChooseMealPlanPageV3> {
  final _auth = FirebaseAuth.instance;
  bool _isLoading = false;
  String _selectedPlan = ''; // 'standard', 'pro', 'premium'

  final Map<String, Map<String, dynamic>> _planDetails = {
    'standard': {
      'name': 'Standard',
      'mealsPerDay': 1,
      'description': '1 meal per day',
    },
    'pro': {
      'name': 'Pro',
      'mealsPerDay': 2,
      'description': '2 meals per day',
    },
    'premium': {
      'name': 'Premium',
      'mealsPerDay': 3,
      'description': '3 meals per day',
    },
  };

  Future<void> _continue() async {
    if (_selectedPlan.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a meal plan'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No user logged in');

      if (kDebugMode) {
        debugPrint('[ChooseMealPlan] Selected plan: $_selectedPlan');
      }

      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final planDetails = _planDetails[_selectedPlan]!;
      
      await prefs.setString('selectedPlan', _selectedPlan);
      await prefs.setInt('mealsPerDay', planDetails['mealsPerDay'] as int);

      // Find the meal plan model by matching mealsPerDay
      final availablePlans = MealPlanModelV3.getAvailablePlans();
      final mealsPerDay = planDetails['mealsPerDay'] as int;
      final selectedPlanModel = availablePlans.firstWhere(
        (p) => p.mealsPerDay == mealsPerDay,
        orElse: () => availablePlans.first,
      );
      
      await prefs.setString('selected_meal_plan_id', selectedPlanModel.id);

      if (kDebugMode) {
        debugPrint('[ChooseMealPlan] Saved to SharedPreferences (plan: $_selectedPlan, mealsPerDay: $mealsPerDay, plan ID: ${selectedPlanModel.id}, plan name: ${selectedPlanModel.name})');
      }

      // Save to Firestore in background
      FirestoreServiceV3.updateUserProfile(user.uid, {
        'selectedPlan': _selectedPlan,
        'mealsPerDay': planDetails['mealsPerDay'],
        'planSelectedAt': DateTime.now().toIso8601String(),
      }).then((_) {
        if (kDebugMode) {
          debugPrint('[ChooseMealPlan] Firestore saved successfully');
        }
      }).catchError((e) {
        if (kDebugMode) {
          debugPrint('[ChooseMealPlan] Firestore save failed: $e');
        }
      });

      setState(() => _isLoading = false);

      if (!mounted) return;

      // Navigate to Delivery Schedule only if in signup flow, otherwise pop back
      if (widget.isSignupFlow) {
        // Fixed version - removed TextEditingController to resolve Windows crash
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const DeliverySchedulePageV5(
              isSignupFlow: true,
            ),
          ),
        );
      } else {
        // Just pop back with success result
        Navigator.pop(context, true);
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('[ChooseMealPlan] ERROR: $e');
        debugPrint('[ChooseMealPlan] Stack trace: $stackTrace');
      }
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.isSignupFlow, // Prevent back navigation during signup
      onPopInvoked: (bool didPop) {
        // Prevent back navigation during signup flow
        if (widget.isSignupFlow && !didPop) {
          if (kDebugMode) {
            debugPrint('[ChooseMealPlan] Back navigation blocked during signup');
          }
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text(
            'Choose your meal plan',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: Colors.black,
            ),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          automaticallyImplyLeading: !widget.isSignupFlow, // Remove back button during signup
        ),
        body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          // Make all children span the available width so cards are full-bleed within padding
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Info card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black, width: 2),
              ),
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: Colors.black, width: 2),
                    ),
                    child: const Center(
                      child: Text('🏛️', style: TextStyle(fontSize: 32)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Choose Your Plan',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.black,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Select the meal plan that best fits your lifestyle. You can always change this later in your settings.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Plan selection (Standard → Pro → Premium)
            ...['standard', 'pro', 'premium'].map((planId) {
              final plan = _planDetails[planId]!;
              final isSelected = _selectedPlan == planId;

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: GestureDetector(
                  onTap: () => setState(() => _selectedPlan = planId),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.black : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.black, width: 2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan['name'] as String,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: isSelected ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${plan['mealsPerDay']} meal(s) per day',
                          style: TextStyle(
                            fontSize: 14,
                            color: isSelected ? Colors.grey.shade200 : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),

            const SizedBox(height: 32),

            // Continue button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _continue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Continue',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}
