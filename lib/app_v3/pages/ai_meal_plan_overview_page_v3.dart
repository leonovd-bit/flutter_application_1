import 'package:flutter/material.dart';
import '../models/meal_model_v3.dart';
import '../services/ai_meal_planner_service.dart';

import '../theme/app_theme_v3.dart';
import 'delivery_schedule_page_v4.dart';


class AIMealPlanOverviewPageV3 extends StatefulWidget {
  final MealPlanModelV3 selectedPlan;
  final Map<String, List<MealModelV3>> weeklyPlan;
  final Map<String, double> nutritionAnalysis;

  const AIMealPlanOverviewPageV3({
    super.key,
    required this.selectedPlan,
    required this.weeklyPlan,
    required this.nutritionAnalysis,
  });

  @override
  State<AIMealPlanOverviewPageV3> createState() => _AIMealPlanOverviewPageV3State();
}

class _AIMealPlanOverviewPageV3State extends State<AIMealPlanOverviewPageV3> {
  late Map<String, List<MealModelV3>> _currentPlan;
  late Map<String, double> _currentNutrition;
  bool _isRegenerating = false;
  bool _isSubstituting = false;
  String? _substitutingMealKey;

  @override
  void initState() {
    super.initState();
    _currentPlan = Map.from(widget.weeklyPlan);
    _currentNutrition = Map.from(widget.nutritionAnalysis);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your AI Meal Plan'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isRegenerating ? null : _regenerateFullPlan,
            tooltip: 'Regenerate Plan',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: AppThemeV3.backgroundGradient),
        child: Column(
          children: [
            _buildPlanSummary(),
            Expanded(
              child: _buildWeeklyPlanList(),
            ),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanSummary() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, Colors.grey[50]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppThemeV3.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: AppThemeV3.accent, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${widget.selectedPlan.name} AI Plan',
                  style: AppThemeV3.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppThemeV3.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Personalized for your preferences and goals',
            style: AppThemeV3.textTheme.bodyMedium?.copyWith(
              color: AppThemeV3.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          _buildNutritionSummary(),
        ],
      ),
    );
  }

  Widget _buildNutritionSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppThemeV3.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Daily Nutrition (Average)',
            style: AppThemeV3.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildNutritionItem('Calories', '${(_currentNutrition['calories']! / 7).round()}', 'kcal'),
              _buildNutritionItem('Protein', '${(_currentNutrition['protein']! / 7).round()}g', ''),
              _buildNutritionItem('Carbs', '${(_currentNutrition['carbs']! / 7).round()}g', ''),
              _buildNutritionItem('Fat', '${(_currentNutrition['fat']! / 7).round()}g', ''),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionItem(String label, String value, String unit) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: AppThemeV3.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppThemeV3.accent,
            ),
          ),
          Text(
            label,
            style: AppThemeV3.textTheme.bodySmall?.copyWith(
              color: AppThemeV3.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyPlanList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _currentPlan.keys.length,
      itemBuilder: (context, index) {
        final dayKey = _currentPlan.keys.elementAt(index);
        final dayMeals = _currentPlan[dayKey]!;
        final date = DateTime.parse('$dayKey 00:00:00');
        
        return _buildDayCard(dayKey, date, dayMeals);
      },
    );
  }

  Widget _buildDayCard(String dayKey, DateTime date, List<MealModelV3> meals) {
    final dayName = _getDayName(date.weekday);
    final monthDay = '${date.month}/${date.day}';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        title: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: AppThemeV3.accent,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '$dayName ($monthDay)',
              style: AppThemeV3.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        subtitle: Text(
          '${meals.length} meals • ${meals.map((m) => m.calories).reduce((a, b) => a + b)} calories',
          style: AppThemeV3.textTheme.bodySmall?.copyWith(
            color: AppThemeV3.textSecondary,
          ),
        ),
        children: meals.map((meal) => _buildMealTile(dayKey, meal)).toList(),
      ),
    );
  }

  Widget _buildMealTile(String dayKey, MealModelV3 meal) {
    final isSubstituting = _isSubstituting && _substitutingMealKey == '${dayKey}_${meal.id}';
    
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          meal.imageUrl,
          width: 60,
          height: 60,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            width: 60,
            height: 60,
            color: Colors.grey[200],
            child: Icon(Icons.fastfood, color: Colors.grey[400]),
          ),
        ),
      ),
      title: Text(
        meal.name,
        style: AppThemeV3.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            meal.mealType.toUpperCase(),
            style: AppThemeV3.textTheme.bodySmall?.copyWith(
              color: AppThemeV3.accent,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            '${meal.calories} cal • ${meal.protein}g protein',
            style: AppThemeV3.textTheme.bodySmall?.copyWith(
              color: AppThemeV3.textSecondary,
            ),
          ),
        ],
      ),
      trailing: isSubstituting
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : IconButton(
              icon: const Icon(Icons.swap_horiz),
              onPressed: () => _substituteMeal(dayKey, meal),
              tooltip: 'Find substitute',
            ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            offset: const Offset(0, -2),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _proceedToScheduling,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppThemeV3.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.schedule),
                  const SizedBox(width: 8),
                  Text(
                    'Set Delivery Schedule',
                    style: AppThemeV3.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: TextButton(
              onPressed: _editPreferences,
              child: Text(
                'Edit AI Preferences',
                style: AppThemeV3.textTheme.titleSmall?.copyWith(
                  color: AppThemeV3.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getDayName(int weekday) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[weekday - 1];
  }

  Future<void> _regenerateFullPlan() async {
    setState(() => _isRegenerating = true);
    
    try {
      final newPlan = await AIMealPlannerService.generateWeeklyPlan(plan: widget.selectedPlan);
      final newNutrition = _calculateTotalNutrition(newPlan);
      
      setState(() {
        _currentPlan = newPlan;
        _currentNutrition = newNutrition;
        _isRegenerating = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New meal plan generated!')),
      );
    } catch (e) {
      setState(() => _isRegenerating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error regenerating plan: $e')),
      );
    }
  }

  Future<void> _substituteMeal(String dayKey, MealModelV3 originalMeal) async {
    final mealKey = '${dayKey}_${originalMeal.id}';
    setState(() {
      _isSubstituting = true;
      _substitutingMealKey = mealKey;
    });
    
    try {
      final substitutions = await AIMealPlannerService.getSmartSubstitutions(originalMeal);
      
      if (!mounted) return;
      setState(() {
        _isSubstituting = false;
        _substitutingMealKey = null;
      });
      
      if (substitutions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No suitable substitutes found')),
        );
        return;
      }
      
      // Show substitution options
      _showSubstitutionDialog(dayKey, originalMeal, substitutions);
    } catch (e) {
      setState(() {
        _isSubstituting = false;
        _substitutingMealKey = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error finding substitutes: $e')),
      );
    }
  }

  void _showSubstitutionDialog(String dayKey, MealModelV3 originalMeal, List<MealModelV3> substitutions) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Replace ${originalMeal.name}'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: substitutions.length,
            itemBuilder: (context, index) {
              final substitute = substitutions[index];
              return ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    substitute.imageUrl,
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                  ),
                ),
                title: Text(substitute.name),
                subtitle: Text('${substitute.calories} cal • ${substitute.protein}g protein'),
                onTap: () {
                  Navigator.pop(context);
                  _replaceMeal(dayKey, originalMeal, substitute);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _replaceMeal(String dayKey, MealModelV3 originalMeal, MealModelV3 substitute) {
    setState(() {
      final dayMeals = _currentPlan[dayKey]!;
      final index = dayMeals.indexWhere((meal) => meal.id == originalMeal.id);
      if (index != -1) {
        dayMeals[index] = substitute;
        _currentNutrition = _calculateTotalNutrition(_currentPlan);
      }
    });
    
    // Track the substitution for AI learning
    AIMealPlannerService.updateMealRating(originalMeal.id, 2.0); // Neutral rating for replaced meal
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Replaced with ${substitute.name}')),
    );
  }

  Map<String, double> _calculateTotalNutrition(Map<String, List<MealModelV3>> plan) {
    final allMeals = plan.values.expand((meals) => meals).toList();
    return AIMealPlannerService.analyzeNutrition(allMeals);
  }

  void _proceedToScheduling() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const DeliverySchedulePageV4(
          isSignupFlow: true,
        ),
      ),
    );
  }

  void _editPreferences() {
    // Navigate to AI preferences page (to be created)
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('AI preferences editing coming soon!')),
    );
  }
}
