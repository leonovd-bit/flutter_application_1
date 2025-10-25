import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/meal_model_v3.dart';
import '../services/firestore_service_v3.dart';
import 'delivery_schedule_page_v5.dart';

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
  String _selectedPlan = ''; // 'standard', 'premium', 'pro'
  bool _proteinPlusEnabled = false;

  final Map<String, Map<String, dynamic>> _planDetails = {
    'standard': {
      'name': 'Standard',
      'mealsPerDay': 1,
      'price': 390, // Monthly price
      'description': '1 meal per day',
    },
    'pro': {
      'name': 'Pro',
      'mealsPerDay': 2,
      'price': 780,
      'description': '2 meals per day',
    },
    'premium': {
      'name': 'Premium',
      'mealsPerDay': 3,
      'price': 1170,
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
        debugPrint('[ChooseMealPlan] Protein+ enabled: $_proteinPlusEnabled');
      }

      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final planDetails = _planDetails[_selectedPlan]!;
      
      await prefs.setString('selectedPlan', _selectedPlan);
      await prefs.setInt('mealsPerDay', planDetails['mealsPerDay'] as int);
      await prefs.setBool('proteinPlusEnabled', _proteinPlusEnabled);

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
        'proteinPlusEnabled': _proteinPlusEnabled,
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
    return Scaffold(
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
        iconTheme: const IconThemeData(color: Colors.black),
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

            // Plan selection
            ...['standard', 'premium', 'pro'].map((planId) {
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
                          '${plan['mealsPerDay']} meal(s) per day • from \$${plan['price']}/mo',
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

            const SizedBox(height: 24),

            // Protein+ Option
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black, width: 2),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Text('💪', style: TextStyle(fontSize: 24)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Protein + Option',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Colors.black,
                              ),
                            ),
                            Text(
                              'Customize your protein choices',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _proteinPlusEnabled = !_proteinPlusEnabled),
                        child: Container(
                          width: 48,
                          height: 24,
                          decoration: BoxDecoration(
                            color: _proteinPlusEnabled ? Colors.black : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: AnimatedAlign(
                            duration: const Duration(milliseconds: 200),
                            alignment: _proteinPlusEnabled ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              width: 20,
                              height: 20,
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_proteinPlusEnabled) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200, width: 2),
                      ),
                      child: const Text(
                        '✓ Select specific proteins for your meals in the next step',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

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
    );
  }
}
