import 'package:flutter/material.dart';
import '../theme/app_theme_v3.dart';

class CircleOfHealthPageV3 extends StatefulWidget {
  const CircleOfHealthPageV3({super.key});

  @override
  State<CircleOfHealthPageV3> createState() => _CircleOfHealthPageV3State();
}

class _CircleOfHealthPageV3State extends State<CircleOfHealthPageV3> {
  // Mock health data - in real app, this would come from Firebase
  final String _currentMealPlan = 'DietKnight'; // 2 meals/day
  final Map<String, dynamic> _todayStats = {
    'calories': 850,
    'protein': 45,
    'carbs': 95,
    'fat': 32,
    'fiber': 18,
    'water': 6.2, // glasses
  };
  
  final Map<String, dynamic> _weeklyGoals = {
    'calories': 1800,
    'protein': 80,
    'carbs': 200,
    'fat': 60,
    'fiber': 25,
    'water': 8.0,
  };
  
  final List<Map<String, dynamic>> _weeklyProgress = [
    {'day': 'Mon', 'calories': 1650, 'protein': 75, 'completed': true},
    {'day': 'Tue', 'calories': 1720, 'protein': 82, 'completed': true},
    {'day': 'Wed', 'calories': 1590, 'protein': 68, 'completed': true},
    {'day': 'Thu', 'calories': 1800, 'protein': 85, 'completed': true},
    {'day': 'Fri', 'calories': 1670, 'protein': 78, 'completed': true},
    {'day': 'Sat', 'calories': 1520, 'protein': 65, 'completed': true},
    {'day': 'Today', 'calories': 850, 'protein': 45, 'completed': false},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeV3.background,
      appBar: AppBar(
        backgroundColor: AppThemeV3.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Circle of Health',
          style: AppThemeV3.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Large Circle of Health
            _buildLargeHealthCircle(),
            
            const SizedBox(height: 32),
            
            // Today's Nutrition Breakdown
            _buildNutritionBreakdown(),
            
            const SizedBox(height: 32),
            
            // Weekly Progress
            _buildWeeklyProgress(),
            
            const SizedBox(height: 32),
            
            // Health Insights
            _buildHealthInsights(),
          ],
        ),
      ),
    );
  }

  Widget _buildLargeHealthCircle() {
    return Center(
      child: SizedBox(
        width: 280,
        height: 280,
        child: Stack(
          children: [
            // Outer progress ring for calories
            SizedBox(
              width: 280,
              height: 280,
              child: CircularProgressIndicator(
                value: _todayStats['calories'] / _weeklyGoals['calories'],
                strokeWidth: 12,
                backgroundColor: AppThemeV3.accent.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation<Color>(AppThemeV3.accent),
              ),
            ),
            
            // Middle ring for protein
            Positioned(
              top: 20,
              left: 20,
              child: SizedBox(
                width: 240,
                height: 240,
                child: CircularProgressIndicator(
                  value: _todayStats['protein'] / _weeklyGoals['protein'],
                  strokeWidth: 8,
                  backgroundColor: Colors.orange.withOpacity(0.1),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
                ),
              ),
            ),
            
            // Inner circle content
            Positioned(
              top: 60,
              left: 60,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppThemeV3.surface,
                  boxShadow: AppThemeV3.cardShadow,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _currentMealPlan,
                      style: AppThemeV3.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppThemeV3.accent,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_todayStats['calories']}',
                      style: AppThemeV3.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'calories today',
                      style: AppThemeV3.textTheme.bodySmall?.copyWith(
                        color: AppThemeV3.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Progress labels
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 16,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppThemeV3.accent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Calories',
                        style: AppThemeV3.textTheme.bodySmall,
                      ),
                      Text(
                        '${((_todayStats['calories'] / _weeklyGoals['calories']) * 100).round()}%',
                        style: AppThemeV3.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      Container(
                        width: 16,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Protein',
                        style: AppThemeV3.textTheme.bodySmall,
                      ),
                      Text(
                        '${((_todayStats['protein'] / _weeklyGoals['protein']) * 100).round()}%',
                        style: AppThemeV3.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutritionBreakdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Today\'s Nutrition',
          style: AppThemeV3.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        
        // Nutrition cards grid
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.5,
          children: [
            _buildNutritionCard('Carbs', '${_todayStats['carbs']}g', '${_weeklyGoals['carbs']}g', Colors.blue),
            _buildNutritionCard('Fat', '${_todayStats['fat']}g', '${_weeklyGoals['fat']}g', Colors.purple),
            _buildNutritionCard('Fiber', '${_todayStats['fiber']}g', '${_weeklyGoals['fiber']}g', Colors.green),
            _buildNutritionCard('Water', '${_todayStats['water']} glasses', '${_weeklyGoals['water']} glasses', Colors.cyan),
          ],
        ),
      ],
    );
  }

  Widget _buildNutritionCard(String title, String current, String goal, Color color) {
    final currentValue = double.parse(current.replaceAll(RegExp(r'[^0-9.]'), ''));
    final goalValue = double.parse(goal.replaceAll(RegExp(r'[^0-9.]'), ''));
    final progress = (currentValue / goalValue).clamp(0.0, 1.0);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppThemeV3.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppThemeV3.border),
        boxShadow: AppThemeV3.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppThemeV3.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            current,
            style: AppThemeV3.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            'of $goal',
            style: AppThemeV3.textTheme.bodySmall?.copyWith(
              color: AppThemeV3.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: color.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyProgress() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Weekly Progress',
          style: AppThemeV3.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        
        // Weekly chart
        Container(
          height: 200,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppThemeV3.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppThemeV3.border),
            boxShadow: AppThemeV3.cardShadow,
          ),
          child: Column(
            children: [
              // Chart bars
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: _weeklyProgress.map((day) {
                    final progress = day['calories'] / _weeklyGoals['calories'];
                    final isToday = day['day'] == 'Today';
                    
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          width: 24,
                          height: (progress * 120).clamp(8.0, 120.0),
                          decoration: BoxDecoration(
                            color: isToday 
                                ? AppThemeV3.accent.withOpacity(0.6)
                                : day['completed'] 
                                    ? AppThemeV3.accent 
                                    : AppThemeV3.accent.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          day['day'],
                          style: AppThemeV3.textTheme.bodySmall?.copyWith(
                            fontWeight: isToday ? FontWeight.w600 : FontWeight.normal,
                            color: isToday ? AppThemeV3.accent : AppThemeV3.textSecondary,
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHealthInsights() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Health Insights',
          style: AppThemeV3.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        
        // Insight cards
        _buildInsightCard(
          icon: Icons.trending_up,
          title: 'Great Progress!',
          subtitle: 'You\'re 47% ahead of your weekly protein goal',
          color: Colors.green,
        ),
        const SizedBox(height: 12),
        _buildInsightCard(
          icon: Icons.local_drink,
          title: 'Stay Hydrated',
          subtitle: 'Drink 2 more glasses to reach your daily water goal',
          color: Colors.blue,
        ),
        const SizedBox(height: 12),
        _buildInsightCard(
          icon: Icons.restaurant,
          title: 'Meal Reminder',
          subtitle: 'Your next meal is scheduled for 6:30 PM today',
          color: Colors.orange,
        ),
      ],
    );
  }

  Widget _buildInsightCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppThemeV3.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppThemeV3.border),
        boxShadow: AppThemeV3.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: color,
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
                  style: AppThemeV3.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: AppThemeV3.textTheme.bodyMedium?.copyWith(
                    color: AppThemeV3.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
