import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/meal_model_v3.dart';
import '../services/firestore_service_v3.dart';
import '../services/ai_meal_planner_service.dart';
import '../theme/app_theme_v3.dart';
import 'delivery_schedule_page_v4.dart';
import 'ai_meal_plan_overview_page_v3.dart';

class ChooseMealPlanPageV3 extends StatefulWidget {
  const ChooseMealPlanPageV3({super.key});

  @override
  State<ChooseMealPlanPageV3> createState() => _ChooseMealPlanPageV3State();
}

class _ChooseMealPlanPageV3State extends State<ChooseMealPlanPageV3> {
  final _auth = FirebaseAuth.instance;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeV3.background,
      appBar: AppBar(
        title: const Text('Choose Your Plan'),
        backgroundColor: AppThemeV3.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppThemeV3.primaryGreen.withValues(alpha: 0.1),
              AppThemeV3.accent.withValues(alpha: 0.1),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                Text(
                  'Select Your Meal Plan',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppThemeV3.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose the perfect plan for your lifestyle',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppThemeV3.textSecondary,
                  ),
                ),
                const SizedBox(height: 30),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildAIPlanOption(),
                        const SizedBox(height: 16),
                        _buildPlanOption(
                          title: 'NutritiousJr',
                          description: 'Kid-friendly meals that are both nutritious and delicious',
                          mealsPerDay: 2,
                          price: '\$29.99/week',
                          color: Colors.orange,
                          planType: 'NutritiousJr',
                        ),
                        const SizedBox(height: 16),
                        _buildPlanOption(
                          title: 'DietKnight',
                          description: 'High-protein, low-carb meals for fitness enthusiasts',
                          mealsPerDay: 2,
                          price: '\$34.99/week',
                          color: Colors.blue,
                          planType: 'DietKnight',
                        ),
                        const SizedBox(height: 16),
                        _buildPlanOption(
                          title: 'LeanFreak',
                          description: 'Clean, lean meals for serious athletes and fitness goals',
                          mealsPerDay: 3,
                          price: '\$44.99/week',
                          color: Colors.green,
                          planType: 'LeanFreak',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAIPlanOption() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppThemeV3.accent.withValues(alpha: 0.1),
            AppThemeV3.accent.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppThemeV3.accent.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _isLoading ? null : () => _generateAIPlan(),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppThemeV3.accent, AppThemeV3.primaryGreen],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AI Personalized Plan',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppThemeV3.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Let AI create a custom meal plan just for you',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppThemeV3.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppThemeV3.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.stars,
                        color: AppThemeV3.accent,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Personalized based on your preferences, dietary restrictions, and goals',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppThemeV3.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isLoading) ...[
                  const SizedBox(height: 16),
                  Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppThemeV3.accent),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlanOption({
    required String title,
    required String description,
    required int mealsPerDay,
    required String price,
    required Color color,
    required String planType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _isLoading ? null : () => _selectPlan(planType, mealsPerDay),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getPlanIcon(planType),
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppThemeV3.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            description,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppThemeV3.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$mealsPerDay meals/day',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      price,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getPlanIcon(String planType) {
    switch (planType) {
      case 'NutritiousJr':
        return Icons.child_friendly;
      case 'DietKnight':
        return Icons.fitness_center;
      case 'LeanFreak':
        return Icons.flash_on;
      default:
        return Icons.restaurant;
    }
  }

  Future<void> _generateAIPlan() async {
    setState(() => _isLoading = true);

    try {
      // Show preferences dialog
      final preferences = await _showAIPreferencesDialog();
      if (preferences == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Save preferences
      await AIMealPlannerService.saveUserPreferences(preferences);

      // Create AI meal plan
      final aiPlan = MealPlanModelV3(
        id: 'ai_personalized',
        name: 'ai_personalized',
        displayName: 'AI Personalized Plan',
        mealsPerDay: preferences['mealsPerDay'] ?? 2,
        pricePerWeek: (preferences['mealsPerDay'] ?? 2) * 14.99 * 7,
        description: 'AI-generated personalized meal plan',
      );

      // Generate AI plan
      final weeklyPlan = await AIMealPlannerService.generateWeeklyPlan(plan: aiPlan);
      
      if (weeklyPlan.isNotEmpty) {
        // Create basic nutrition analysis
        final nutritionAnalysis = <String, double>{
          'calories': 2000.0,
          'protein': 150.0,
          'carbs': 250.0,
          'fat': 80.0,
          'fiber': 25.0,
        };

        // Navigate to AI plan overview
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AIMealPlanOverviewPageV3(
                selectedPlan: aiPlan,
                weeklyPlan: weeklyPlan,
                nutritionAnalysis: nutritionAnalysis,
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to generate AI meal plan. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error generating AI plan: $e');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error generating meal plan. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<Map<String, dynamic>?> _showAIPreferencesDialog() async {
    final preferences = <String, dynamic>{};
    
    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('AI Meal Preferences'),
              content: SizedBox(
                width: double.maxFinite,
                height: 400, // Set a fixed height to prevent overflow
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                    // Dietary restrictions
                    const Text('Dietary Restrictions:', style: TextStyle(fontWeight: FontWeight.bold)),
                    CheckboxListTile(
                      title: const Text('Vegetarian'),
                      value: preferences['vegetarian'] ?? false,
                      onChanged: (value) => setState(() => preferences['vegetarian'] = value),
                    ),
                    CheckboxListTile(
                      title: const Text('Vegan'),
                      value: preferences['vegan'] ?? false,
                      onChanged: (value) => setState(() => preferences['vegan'] = value),
                    ),
                    CheckboxListTile(
                      title: const Text('Gluten-Free'),
                      value: preferences['glutenFree'] ?? false,
                      onChanged: (value) => setState(() => preferences['glutenFree'] = value),
                    ),
                    CheckboxListTile(
                      title: const Text('Dairy-Free'),
                      value: preferences['dairyFree'] ?? false,
                      onChanged: (value) => setState(() => preferences['dairyFree'] = value),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Fitness goals
                    const Text('Fitness Goals:', style: TextStyle(fontWeight: FontWeight.bold)),
                    RadioListTile<String>(
                      title: const Text('Weight Loss'),
                      value: 'weight_loss',
                      groupValue: preferences['fitnessGoal'],
                      onChanged: (value) => setState(() => preferences['fitnessGoal'] = value),
                    ),
                    RadioListTile<String>(
                      title: const Text('Muscle Gain'),
                      value: 'muscle_gain',
                      groupValue: preferences['fitnessGoal'],
                      onChanged: (value) => setState(() => preferences['fitnessGoal'] = value),
                    ),
                    RadioListTile<String>(
                      title: const Text('Maintenance'),
                      value: 'maintenance',
                      groupValue: preferences['fitnessGoal'],
                      onChanged: (value) => setState(() => preferences['fitnessGoal'] = value),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Meals per day
                    const Text('Meals per Day:', style: TextStyle(fontWeight: FontWeight.bold)),
                    DropdownButtonFormField<int>(
                      value: preferences['mealsPerDay'] ?? 2,
                      items: [1, 2, 3].map((int value) {
                        return DropdownMenuItem<int>(
                          value: value,
                          child: Text('$value meals'),
                        );
                      }).toList(),
                      onChanged: (value) => setState(() => preferences['mealsPerDay'] = value),
                    ),
                  ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(preferences),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppThemeV3.primaryGreen,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Generate Plan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _selectPlan(String planType, int mealsPerDay) async {
    setState(() => _isLoading = true);

    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Save plan selection to user profile
        await FirestoreServiceV3.updateUserProfile(user.uid, {
          'selectedPlan': planType,
          'mealsPerDay': mealsPerDay,
          'planSelectedAt': DateTime.now().toIso8601String(),
        });

        // Save to SharedPreferences for quick access
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('selectedPlan', planType);
        await prefs.setInt('mealsPerDay', mealsPerDay);

        // Navigate to delivery schedule
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const DeliverySchedulePageV4(
                isSignupFlow: true,
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error selecting plan: $e');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error selecting plan. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
