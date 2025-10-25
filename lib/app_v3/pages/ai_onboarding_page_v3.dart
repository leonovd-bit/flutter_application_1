import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import '../theme/app_theme_v3.dart';
import '../models/meal_model_v3.dart';
import '../services/ai_meal_planner_service.dart';
import '../services/firestore_service_v3.dart';
import 'payment_methods_page_v3.dart';
import 'home_page_v3.dart';

class AIOnboardingPageV3 extends StatefulWidget {
  const AIOnboardingPageV3({super.key});

  @override
  State<AIOnboardingPageV3> createState() => _AIOnboardingPageV3State();
}

class _AIOnboardingPageV3State extends State<AIOnboardingPageV3> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  bool _isProcessing = false;
  
  // User data collection
  final Map<String, dynamic> _aiUserData = {
    'basicInfo': <String, dynamic>{},
    'healthGoals': <String, dynamic>{},
    'dietaryPreferences': <String, dynamic>{},
    'lifestyle': <String, dynamic>{},
    'address': <String, dynamic>{},
    'mealPlan': <String, dynamic>{},
    'deliverySchedule': <String, dynamic>{},
  };

  final List<String> _stepTitles = [
    'Tell us about yourself',
    'Your health goals', 
    'Dietary preferences',
    'Your lifestyle',
    'Delivery address',
    'AI Recommendations',
    'Payment setup',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeV3.background,
      appBar: AppBar(
        backgroundColor: AppThemeV3.surface,
        elevation: 0,
        leading: _currentStep > 0 
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _previousStep,
              )
            : null,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AI Setup',
              style: AppThemeV3.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'Step ${_currentStep + 1} of ${_stepTitles.length}',
              style: AppThemeV3.textTheme.bodySmall?.copyWith(
                color: AppThemeV3.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          if (_currentStep < _stepTitles.length - 2)
            TextButton(
              onPressed: _skipToEnd,
              child: Text(
                'Skip',
                style: TextStyle(color: AppThemeV3.textSecondary),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Progress indicator
          Container(
            color: AppThemeV3.surface,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _stepTitles[_currentStep],
                  style: AppThemeV3.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: (_currentStep + 1) / _stepTitles.length,
                  backgroundColor: AppThemeV3.border,
                  valueColor: AlwaysStoppedAnimation<Color>(AppThemeV3.accent),
                ),
              ],
            ),
          ),
          
          // Page content
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildBasicInfoStep(),
                _buildHealthGoalsStep(),
                _buildDietaryPreferencesStep(),
                _buildLifestyleStep(),
                _buildAddressStep(),
                _buildAIRecommendationsStep(),
                _buildPaymentStep(),
              ],
            ),
          ),
          
          // Bottom navigation
          if (!_isProcessing)
            Container(
              color: AppThemeV3.surface,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _previousStep,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: AppThemeV3.border),
                        ),
                        child: const Text('Back'),
                      ),
                    ),
                  
                  if (_currentStep > 0) const SizedBox(width: 16),
                  
                  Expanded(
                    flex: _currentStep > 0 ? 2 : 1,
                    child: ElevatedButton(
                      onPressed: _nextStep,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppThemeV3.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _currentStep == _stepTitles.length - 1 
                            ? 'Complete Setup'
                            : _currentStep == _stepTitles.length - 2
                                ? 'Set Payment'  
                                : 'Continue',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.person_outline,
            size: 48,
            color: Colors.green,
          ),
          const SizedBox(height: 24),
          
          Text(
            'Let\'s start with the basics',
            style: AppThemeV3.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This helps us personalize your meal recommendations',
            style: AppThemeV3.textTheme.bodyMedium?.copyWith(
              color: AppThemeV3.textSecondary,
            ),
          ),
          const SizedBox(height: 32),
          
          _buildQuestionCard(
            'What\'s your age range?',
            [
              {'label': 'Under 18', 'value': 'under_18'},
              {'label': '18-25', 'value': '18_25'},
              {'label': '26-35', 'value': '26_35'},
              {'label': '36-45', 'value': '36_45'},
              {'label': '46-55', 'value': '46_55'},
              {'label': '55+', 'value': '55_plus'},
            ],
            'ageRange',
          ),
          
          const SizedBox(height: 24),
          
          _buildQuestionCard(
            'What\'s your gender?',
            [
              {'label': 'Male', 'value': 'male'},
              {'label': 'Female', 'value': 'female'},
              {'label': 'Non-binary', 'value': 'non_binary'},
              {'label': 'Prefer not to say', 'value': 'prefer_not_to_say'},
            ],
            'gender',
          ),
          
          const SizedBox(height: 24),
          
          _buildQuestionCard(
            'What\'s your current weight goal?',
            [
              {'label': 'Lose weight', 'value': 'lose_weight'},
              {'label': 'Maintain weight', 'value': 'maintain'},
              {'label': 'Gain weight', 'value': 'gain_weight'},
              {'label': 'Build muscle', 'value': 'build_muscle'},
            ],
            'weightGoal',
          ),
        ],
      ),
    );
  }

  Widget _buildHealthGoalsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.favorite_outline,
            size: 48,
            color: Colors.red,
          ),
          const SizedBox(height: 24),
          
          Text(
            'What are your health goals?',
            style: AppThemeV3.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select all that apply to you',
            style: AppThemeV3.textTheme.bodyMedium?.copyWith(
              color: AppThemeV3.textSecondary,
            ),
          ),
          const SizedBox(height: 32),
          
          _buildMultiSelectCard(
            'Health priorities',
            [
              {'label': 'Weight management', 'value': 'weight_management'},
              {'label': 'Muscle building', 'value': 'muscle_building'},
              {'label': 'Heart health', 'value': 'heart_health'},
              {'label': 'Energy & vitality', 'value': 'energy_vitality'},
              {'label': 'Better digestion', 'value': 'digestion'},
              {'label': 'Immune support', 'value': 'immune_support'},
              {'label': 'Better sleep', 'value': 'better_sleep'},
              {'label': 'Stress reduction', 'value': 'stress_reduction'},
            ],
            'healthGoals',
          ),
          
          const SizedBox(height: 24),
          
          _buildQuestionCard(
            'How active are you?',
            [
              {'label': 'Sedentary (little to no exercise)', 'value': 'sedentary'},
              {'label': 'Light (1-3 days per week)', 'value': 'light'},
              {'label': 'Moderate (3-5 days per week)', 'value': 'moderate'},
              {'label': 'Active (6-7 days per week)', 'value': 'active'},
              {'label': 'Very active (intense exercise daily)', 'value': 'very_active'},
            ],
            'activityLevel',
          ),
        ],
      ),
    );
  }

  Widget _buildDietaryPreferencesStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.restaurant,
            size: 48,
            color: Colors.orange,
          ),
          const SizedBox(height: 24),
          
          Text(
            'Tell us about your food preferences',
            style: AppThemeV3.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We\'ll make sure your meals fit your dietary needs',
            style: AppThemeV3.textTheme.bodyMedium?.copyWith(
              color: AppThemeV3.textSecondary,
            ),
          ),
          const SizedBox(height: 32),
          
          _buildMultiSelectCard(
            'Dietary restrictions',
            [
              {'label': 'None', 'value': 'none'},
              {'label': 'Vegetarian', 'value': 'vegetarian'},
              {'label': 'Vegan', 'value': 'vegan'},
              {'label': 'Pescatarian', 'value': 'pescatarian'},
              {'label': 'Keto', 'value': 'keto'},
              {'label': 'Paleo', 'value': 'paleo'},
              {'label': 'Gluten-free', 'value': 'gluten_free'},
              {'label': 'Dairy-free', 'value': 'dairy_free'},
            ],
            'dietaryRestrictions',
          ),
          
          const SizedBox(height: 24),
          
          _buildMultiSelectCard(
            'Food allergies',
            [
              {'label': 'None', 'value': 'none'},
              {'label': 'Nuts', 'value': 'nuts'},
              {'label': 'Shellfish', 'value': 'shellfish'},
              {'label': 'Eggs', 'value': 'eggs'},
              {'label': 'Dairy', 'value': 'dairy'},
              {'label': 'Soy', 'value': 'soy'},
              {'label': 'Wheat/Gluten', 'value': 'wheat'},
            ],
            'allergies',
          ),
          
          const SizedBox(height: 24),
          
          _buildMultiSelectCard(
            'Cuisine preferences',
            [
              {'label': 'American', 'value': 'american'},
              {'label': 'Mediterranean', 'value': 'mediterranean'},
              {'label': 'Asian', 'value': 'asian'},
              {'label': 'Mexican', 'value': 'mexican'},
              {'label': 'Italian', 'value': 'italian'},
              {'label': 'Indian', 'value': 'indian'},
              {'label': 'Middle Eastern', 'value': 'middle_eastern'},
              {'label': 'No preference', 'value': 'no_preference'},
            ],
            'preferredCuisines',
          ),
        ],
      ),
    );
  }

  Widget _buildLifestyleStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.schedule,
            size: 48,
            color: Colors.blue,
          ),
          const SizedBox(height: 24),
          
          Text(
            'Tell us about your lifestyle',
            style: AppThemeV3.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This helps us create the perfect meal schedule for you',
            style: AppThemeV3.textTheme.bodyMedium?.copyWith(
              color: AppThemeV3.textSecondary,
            ),
          ),
          const SizedBox(height: 32),
          
          _buildQuestionCard(
            'How many meals per day do you prefer?',
            [
              {'label': '2 meals (Brunch + Dinner)', 'value': '2'},
              {'label': '3 meals (Breakfast + Lunch + Dinner)', 'value': '3'},
              {'label': '4+ meals (Multiple small meals)', 'value': '4'},
            ],
            'mealsPerDay',
          ),
          
          const SizedBox(height: 24),
          
          _buildQuestionCard(
            'What\'s your cooking experience?',
            [
              {'label': 'Beginner - I prefer ready-to-eat meals', 'value': 'beginner'},
              {'label': 'Intermediate - I can do basic cooking', 'value': 'intermediate'},
              {'label': 'Advanced - I enjoy complex recipes', 'value': 'advanced'},
            ],
            'cookingLevel',
          ),
          
          const SizedBox(height: 24),
          
          _buildQuestionCard(
            'How often do you want meal deliveries?',
            [
              {'label': 'Daily', 'value': 'daily'},
              {'label': 'Every other day', 'value': 'every_other_day'},
              {'label': 'Twice a week', 'value': 'twice_weekly'},
              {'label': 'Weekly', 'value': 'weekly'},
            ],
            'deliveryFrequency',
          ),
          
          const SizedBox(height: 24),
          
          _buildQuestionCard(
            'Preferred delivery time?',
            [
              {'label': 'Morning (8AM - 12PM)', 'value': 'morning'},
              {'label': 'Afternoon (12PM - 5PM)', 'value': 'afternoon'},
              {'label': 'Evening (5PM - 8PM)', 'value': 'evening'},
            ],
            'preferredDeliveryTime',
          ),
        ],
      ),
    );
  }

  Widget _buildAddressStep() {
    final TextEditingController streetController = TextEditingController();
    final TextEditingController apartmentController = TextEditingController();
    final TextEditingController cityController = TextEditingController(text: 'New York City');
    final TextEditingController stateController = TextEditingController(text: 'New York');
    final TextEditingController zipController = TextEditingController();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.location_on_outlined,
            size: 48,
            color: Colors.purple,
          ),
          const SizedBox(height: 24),
          
          Text(
            'Where should we deliver?',
            style: AppThemeV3.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We need your address to schedule deliveries',
            style: AppThemeV3.textTheme.bodyMedium?.copyWith(
              color: AppThemeV3.textSecondary,
            ),
          ),
          const SizedBox(height: 32),
          
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppThemeV3.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppThemeV3.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Delivery Address',
                  style: AppThemeV3.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                
                TextFormField(
                  controller: streetController,
                  decoration: InputDecoration(
                    labelText: 'Street Address',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onChanged: (value) {
                    _aiUserData['address']['streetAddress'] = value;
                  },
                ),
                
                const SizedBox(height: 16),
                
                TextFormField(
                  controller: apartmentController,
                  decoration: InputDecoration(
                    labelText: 'Apartment/Unit (Optional)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onChanged: (value) {
                    _aiUserData['address']['apartment'] = value;
                  },
                ),
                
                const SizedBox(height: 16),
                
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: cityController,
                        decoration: InputDecoration(
                          labelText: 'City',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onChanged: (value) {
                          _aiUserData['address']['city'] = value;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: stateController,
                        decoration: InputDecoration(
                          labelText: 'State',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onChanged: (value) {
                          _aiUserData['address']['state'] = value;
                        },
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                TextFormField(
                  controller: zipController,
                  decoration: InputDecoration(
                    labelText: 'ZIP Code',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    _aiUserData['address']['zipCode'] = value;
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIRecommendationsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.auto_awesome,
            size: 48,
            color: Colors.green,
          ),
          const SizedBox(height: 24),
          
          Text(
            'Your AI-Generated Plan',
            style: AppThemeV3.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Based on your preferences, here\'s your personalized meal plan',
            style: AppThemeV3.textTheme.bodyMedium?.copyWith(
              color: AppThemeV3.textSecondary,
            ),
          ),
          const SizedBox(height: 32),
          
          // AI Plan Summary
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppThemeV3.accent.withValues(alpha: 0.1),
                  AppThemeV3.accent.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppThemeV3.accent.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.restaurant_menu,
                      color: AppThemeV3.accent,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Recommended: ${_getRecommendedPlan()}',
                      style: AppThemeV3.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppThemeV3.accent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                _buildSummaryRow('Meals per day', _aiUserData['lifestyle']['mealsPerDay'] ?? '3'),
                _buildSummaryRow('Delivery frequency', _getDeliveryFrequencyText()),
                _buildSummaryRow('Dietary preferences', _getDietaryRestrictionsText()),
                _buildSummaryRow('Health goals', _getHealthGoalsText()),
                
                const SizedBox(height: 20),
                
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppThemeV3.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Monthly Plan: \$${_calculateMonthlyPrice()}',
                        style: AppThemeV3.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppThemeV3.accent,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Includes ${_aiUserData['lifestyle']['mealsPerDay'] ?? '3'} meals per day, ${_getDeliveryFrequencyText().toLowerCase()}',
                        style: AppThemeV3.textTheme.bodySmall?.copyWith(
                          color: AppThemeV3.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Sample meals preview
          Text(
            'Sample meals we\'ll recommend:',
            style: AppThemeV3.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          
          // This would show actual AI-recommended meals
          ..._buildSampleMealCards(),
          
          const SizedBox(height: 24),
          
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppThemeV3.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppThemeV3.accent.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: AppThemeV3.accent,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'You can always modify your meal selections and preferences after setup.',
                    style: AppThemeV3.textTheme.bodySmall?.copyWith(
                      color: AppThemeV3.accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.payment,
            size: 48,
            color: Colors.blue,
          ),
          const SizedBox(height: 24),
          
          Text(
            'Almost done!',
            style: AppThemeV3.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Set up your payment method to complete your AI meal plan',
            style: AppThemeV3.textTheme.bodyMedium?.copyWith(
              color: AppThemeV3.textSecondary,
            ),
          ),
          const SizedBox(height: 32),
          
          // Plan summary
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppThemeV3.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppThemeV3.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Plan Summary',
                  style: AppThemeV3.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Plan:', style: AppThemeV3.textTheme.bodyMedium),
                    Text(
                      _getRecommendedPlan(),
                      style: AppThemeV3.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Meals per day:', style: AppThemeV3.textTheme.bodyMedium),
                    Text(
                      _aiUserData['lifestyle']['mealsPerDay'] ?? '3',
                      style: AppThemeV3.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Delivery:', style: AppThemeV3.textTheme.bodyMedium),
                    Text(
                      _getDeliveryFrequencyText(),
                      style: AppThemeV3.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                
                const Divider(height: 32),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Monthly Total:',
                      style: AppThemeV3.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '\$${_calculateMonthlyPrice()}',
                      style: AppThemeV3.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppThemeV3.accent,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppThemeV3.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppThemeV3.accent.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.security,
                  color: AppThemeV3.accent,
                  size: 24,
                ),
                const SizedBox(height: 8),
                Text(
                  'Secure Payment',
                  style: AppThemeV3.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppThemeV3.accent,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your payment information is encrypted and secure',
                  style: AppThemeV3.textTheme.bodySmall?.copyWith(
                    color: AppThemeV3.accent,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(String question, List<Map<String, String>> options, String dataKey) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppThemeV3.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppThemeV3.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: AppThemeV3.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          
          ...options.map((option) {
            final isSelected = _getSelectedValue(dataKey) == option['value'];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: () => _updateSelection(dataKey, option['value']!),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected ? AppThemeV3.accent.withValues(alpha: 0.1) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? AppThemeV3.accent : AppThemeV3.border,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected ? AppThemeV3.accent : Colors.transparent,
                          border: Border.all(
                            color: isSelected ? AppThemeV3.accent : AppThemeV3.textSecondary,
                            width: 2,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check,
                                size: 12,
                                color: Colors.white,
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          option['label']!,
                          style: AppThemeV3.textTheme.bodyMedium?.copyWith(
                            color: isSelected ? AppThemeV3.accent : AppThemeV3.textPrimary,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildMultiSelectCard(String question, List<Map<String, String>> options, String dataKey) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppThemeV3.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppThemeV3.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: AppThemeV3.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          
          ...options.map((option) {
            final selectedValues = _getSelectedValues(dataKey);
            final isSelected = selectedValues.contains(option['value']);
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: () => _toggleMultiSelection(dataKey, option['value']!),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected ? AppThemeV3.accent.withValues(alpha: 0.1) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? AppThemeV3.accent : AppThemeV3.border,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: isSelected ? AppThemeV3.accent : Colors.transparent,
                          border: Border.all(
                            color: isSelected ? AppThemeV3.accent : AppThemeV3.textSecondary,
                            width: 2,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check,
                                size: 12,
                                color: Colors.white,
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          option['label']!,
                          style: AppThemeV3.textTheme.bodyMedium?.copyWith(
                            color: isSelected ? AppThemeV3.accent : AppThemeV3.textPrimary,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: AppThemeV3.textTheme.bodyMedium?.copyWith(
                color: AppThemeV3.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppThemeV3.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSampleMealCards() {
    // This would use actual AI recommendations - for now showing examples
    final sampleMeals = [
      {'name': 'Grilled Chicken Quinoa Bowl', 'description': 'High protein, balanced macros'},
      {'name': 'Mediterranean Salmon Salad', 'description': 'Heart-healthy, omega-3 rich'},
      {'name': 'Veggie Lentil Curry', 'description': 'Plant-based protein, fiber rich'},
    ];

    return sampleMeals.map((meal) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppThemeV3.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppThemeV3.border),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppThemeV3.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.restaurant,
                color: AppThemeV3.accent,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    meal['name']!,
                    style: AppThemeV3.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    meal['description']!,
                    style: AppThemeV3.textTheme.bodySmall?.copyWith(
                      color: AppThemeV3.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  // Helper methods
  String? _getSelectedValue(String key) {
    return _getCurrentStepData()[key];
  }

  List<String> _getSelectedValues(String key) {
    final data = _getCurrentStepData()[key];
    return data is List ? List<String>.from(data) : [];
  }

  Map<String, dynamic> _getCurrentStepData() {
    final data = switch (_currentStep) {
      0 => _aiUserData['basicInfo'],
      1 => _aiUserData['healthGoals'],
      2 => _aiUserData['dietaryPreferences'],
      3 => _aiUserData['lifestyle'],
      4 => _aiUserData['address'],
      _ => <String, dynamic>{},
    };
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  void _updateSelection(String key, String value) {
    setState(() {
      _getCurrentStepData()[key] = value;
    });
  }

  void _toggleMultiSelection(String key, String value) {
    setState(() {
      final currentData = _getCurrentStepData();
      List<String> selectedValues = List<String>.from(currentData[key] ?? []);
      
      if (value == 'none') {
        selectedValues.clear();
        selectedValues.add('none');
      } else {
        selectedValues.remove('none');
        if (selectedValues.contains(value)) {
          selectedValues.remove(value);
        } else {
          selectedValues.add(value);
        }
      }
      
      currentData[key] = selectedValues;
    });
  }

  String _getRecommendedPlan() {
    final mealsPerDay = int.tryParse(_aiUserData['lifestyle']['mealsPerDay'] ?? '3') ?? 3;
    final activityLevel = _aiUserData['healthGoals']['activityLevel'] ?? 'moderate';
    final weightGoal = _aiUserData['basicInfo']['weightGoal'] ?? 'maintain';

    if (mealsPerDay >= 4 || activityLevel == 'very_active' || weightGoal == 'build_muscle') {
      return 'Premium Plan';
    } else if (weightGoal == 'lose_weight') {
      return 'Pro Plan';
    } else {
      return 'Standard Plan';
    }
  }

  String _getDeliveryFrequencyText() {
    final frequency = _aiUserData['lifestyle']['deliveryFrequency'] ?? 'weekly';
    switch (frequency) {
      case 'daily': return 'Daily delivery';
      case 'every_other_day': return 'Every other day';
      case 'twice_weekly': return 'Twice weekly';
      case 'weekly': return 'Weekly delivery';
      default: return 'Weekly delivery';
    }
  }

  String _getDietaryRestrictionsText() {
    final restrictions = _getSelectedValues('dietaryRestrictions');
    if (restrictions.isEmpty || restrictions.contains('none')) {
      return 'No restrictions';
    }
    return restrictions.join(', ');
  }

  String _getHealthGoalsText() {
    final goals = _getSelectedValues('healthGoals');
    if (goals.isEmpty) {
      return 'General wellness';
    }
    return goals.take(2).join(', ') + (goals.length > 2 ? '...' : '');
  }

  String _calculateMonthlyPrice() {
    final mealsPerDay = int.tryParse(_aiUserData['lifestyle']['mealsPerDay'] ?? '3') ?? 3;
    final deliveryFreq = _aiUserData['lifestyle']['deliveryFrequency'] ?? 'weekly';
    
    int mealsPerWeek = mealsPerDay * 7;
    if (deliveryFreq == 'twice_weekly') mealsPerWeek = mealsPerDay * 2;
    else if (deliveryFreq == 'every_other_day') mealsPerWeek = mealsPerDay * 3;
    
    const basePrice = 12.99; // Per meal
    final monthlyMeals = mealsPerWeek * 4.33; // Average weeks per month
    
    return (monthlyMeals * basePrice).toStringAsFixed(2);
  }

  void _nextStep() {
    if (_currentStep == _stepTitles.length - 1) {
      _completeSetup();
    } else if (_currentStep == _stepTitles.length - 2) {
      _navigateToPayment();
    } else {
      setState(() {
        _currentStep++;
      });
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _skipToEnd() {
    // Fill with default values and go to recommendations
    _fillDefaultValues();
    setState(() {
      _currentStep = _stepTitles.length - 2; // Go to recommendations step
    });
    _pageController.animateToPage(
      _stepTitles.length - 2,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _fillDefaultValues() {
    // Fill with reasonable defaults for skipped steps
    _aiUserData['basicInfo'].addAll({
      'ageRange': '26_35',
      'gender': 'prefer_not_to_say',
      'weightGoal': 'maintain',
    });
    
    _aiUserData['healthGoals'].addAll({
      'healthGoals': ['energy_vitality'],
      'activityLevel': 'moderate',
    });
    
    _aiUserData['dietaryPreferences'].addAll({
      'dietaryRestrictions': ['none'],
      'allergies': ['none'],
      'preferredCuisines': ['no_preference'],
    });
    
    _aiUserData['lifestyle'].addAll({
      'mealsPerDay': '3',
      'cookingLevel': 'intermediate',
      'deliveryFrequency': 'weekly',
      'preferredDeliveryTime': 'afternoon',
    });
  }

  Future<void> _saveAIPreferences() async {
    try {
      // Save AI preferences
      final preferences = <String, dynamic>{
        'allergies': _getSelectedValues('allergies'),
        'dietaryRestrictions': _getSelectedValues('dietaryRestrictions'),
        'dislikedIngredients': <String>[], // Could be collected in an additional step
        'preferredCuisines': _getSelectedValues('preferredCuisines'),
        'nutritionGoals': <String, dynamic>{
          'calories': _calculateCalorieGoal(),
          'protein': _calculateProteinGoal(),
          'carbs': _calculateCarbGoal(),
          'fat': _calculateFatGoal(),
        },
        'mealFrequency': int.tryParse(_aiUserData['lifestyle']['mealsPerDay'] ?? '3') ?? 3,
        'activityLevel': _aiUserData['healthGoals']['activityLevel'] ?? 'moderate',
        'healthGoals': _getSelectedValues('healthGoals'),
      };
      
      await AIMealPlannerService.saveUserPreferences(preferences);
      
      // Save address
      await _saveAddress();
      
      // Save meal plan selection
      await _saveMealPlanSelection();
      
      // Save delivery schedule
      await _saveDeliverySchedule();
      
    } catch (e) {
      debugPrint('[AIOnboarding] Error saving preferences: $e');
    }
  }

  Future<void> _saveAddress() async {
    final address = _aiUserData['address'];
    if (address['streetAddress'] != null && address['zipCode'] != null) {
      final addressData = {
        'id': 'ai_onboarding_address',
        'label': 'Home',
        'streetAddress': address['streetAddress'],
        'apartment': address['apartment'] ?? '',
        'city': address['city'] ?? 'New York City',
        'state': address['state'] ?? 'New York',
        'zipCode': address['zipCode'],
        'isDefault': true,
      };
      
      final prefs = await SharedPreferences.getInstance();
      final addressList = prefs.getStringList('user_addresses') ?? [];
      addressList.clear(); // Replace any existing addresses
      addressList.add(json.encode(addressData));
      await prefs.setStringList('user_addresses', addressList);
    }
  }

  Future<void> _saveMealPlanSelection() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final recommendedPlan = _getRecommendedPlan();
      MealPlanType planType;
      
      switch (recommendedPlan) {
        case 'Premium Plan':
          planType = MealPlanType.premium;
          break;
        case 'Pro Plan':
          planType = MealPlanType.pro;
          break;
        default:
          planType = MealPlanType.standard;
          break;
      }
      
      final plan = MealPlanModelV3.getAvailablePlans()
          .firstWhere((p) => p.name.toLowerCase().contains(planType.name.toLowerCase()));
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_meal_plan_id_${user.uid}', plan.id);
      await prefs.setString('selected_meal_plan_display_name_${user.uid}', plan.displayName);
      
      // Also save to Firestore
      await FirestoreServiceV3.updateUserProfile(user.uid, {
        'selectedMealPlanId': plan.id,
        'selectedMealPlanDisplayName': plan.displayName,
      });
    }
  }

  Future<void> _saveDeliverySchedule() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    final deliveryFreq = _aiUserData['lifestyle']['deliveryFrequency'] ?? 'weekly';
    final preferredTime = _aiUserData['lifestyle']['preferredDeliveryTime'] ?? 'afternoon';
    
    // Create a smart delivery schedule based on AI preferences
    final scheduleData = {
      'userId': user.uid,
      'scheduleType': deliveryFreq,
      'deliveryDays': _generateDeliveryDays(deliveryFreq),
      'deliveryTime': _getDeliveryTimeSlot(preferredTime),
      'isActive': true,
      'createdAt': DateTime.now().toIso8601String(),
      'aiGenerated': true,
    };
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('delivery_schedule_${user.uid}', json.encode(scheduleData));
    await prefs.setString('selected_schedule_${user.uid}', deliveryFreq);
  }

  List<String> _generateDeliveryDays(String frequency) {
    switch (frequency) {
      case 'daily':
        return ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      case 'every_other_day':
        return ['Monday', 'Wednesday', 'Friday'];
      case 'twice_weekly':
        return ['Tuesday', 'Friday'];
      case 'weekly':
      default:
        return ['Wednesday'];
    }
  }

  String _getDeliveryTimeSlot(String preferredTime) {
    switch (preferredTime) {
      case 'morning': return '8:00 AM - 12:00 PM';
      case 'afternoon': return '12:00 PM - 5:00 PM';
      case 'evening': return '5:00 PM - 8:00 PM';
      default: return '12:00 PM - 5:00 PM';
    }
  }

  int _calculateCalorieGoal() {
    final ageRange = _aiUserData['basicInfo']['ageRange'] ?? '26_35';
    final gender = _aiUserData['basicInfo']['gender'] ?? 'prefer_not_to_say';
    final activityLevel = _aiUserData['healthGoals']['activityLevel'] ?? 'moderate';
    final weightGoal = _aiUserData['basicInfo']['weightGoal'] ?? 'maintain';
    
    int baseCalories = 2000;
    
    // Adjust for age and gender
    if (gender == 'male') baseCalories = 2200;
    else if (gender == 'female') baseCalories = 1800;
    
    // Adjust for activity level
    switch (activityLevel) {
      case 'sedentary': baseCalories = (baseCalories * 0.9).round();
      case 'light': baseCalories = (baseCalories * 0.95).round();
      case 'active': baseCalories = (baseCalories * 1.1).round();
      case 'very_active': baseCalories = (baseCalories * 1.2).round();
    }
    
    // Adjust for weight goal
    switch (weightGoal) {
      case 'lose_weight': baseCalories = (baseCalories * 0.85).round();
      case 'gain_weight': baseCalories = (baseCalories * 1.15).round();
      case 'build_muscle': baseCalories = (baseCalories * 1.2).round();
    }
    
    return baseCalories;
  }

  int _calculateProteinGoal() {
    final calories = _calculateCalorieGoal();
    final weightGoal = _aiUserData['basicInfo']['weightGoal'] ?? 'maintain';
    
    double proteinRatio = 0.3; // Default 30% of calories
    
    if (weightGoal == 'build_muscle' || weightGoal == 'gain_weight') {
      proteinRatio = 0.35;
    } else if (weightGoal == 'lose_weight') {
      proteinRatio = 0.35; // Higher protein for weight loss
    }
    
    return ((calories * proteinRatio) / 4).round(); // 4 calories per gram of protein
  }

  int _calculateCarbGoal() {
    final calories = _calculateCalorieGoal();
    final dietaryRestrictions = _getSelectedValues('dietaryRestrictions');
    
    double carbRatio = 0.4; // Default 40% of calories
    
    if (dietaryRestrictions.contains('keto')) {
      carbRatio = 0.1;
    } else if (dietaryRestrictions.contains('paleo')) {
      carbRatio = 0.25;
    }
    
    return ((calories * carbRatio) / 4).round(); // 4 calories per gram of carbs
  }

  int _calculateFatGoal() {
    final calories = _calculateCalorieGoal();
    final proteinCalories = _calculateProteinGoal() * 4;
    final carbCalories = _calculateCarbGoal() * 4;
    
    final remainingCalories = calories - proteinCalories - carbCalories;
    return (remainingCalories / 9).round(); // 9 calories per gram of fat
  }

  void _navigateToPayment() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentMethodsPageV3(
          onPaymentComplete: () {
            _completeSetup();
          },
          isOnboarding: true,
        ),
      ),
    );
  }

  Future<void> _completeSetup() async {
    setState(() {
      _isProcessing = true;
    });
    
    try {
      // Save all AI preferences and data
      await _saveAIPreferences();
      
      // Show success message and navigate to home
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomePageV3()),
          (route) => false,
        );
      }
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Setup complete! Welcome to FreshPunk!'),
            backgroundColor: AppThemeV3.accent,
          ),
        );
        
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomePageV3()),
          (route) => false,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }
}
