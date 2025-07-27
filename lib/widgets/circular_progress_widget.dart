import 'package:flutter/material.dart';
import 'dart:math' as math;

class CircularProgressWidget extends StatelessWidget {
  final Map<String, dynamic> trackingData;

  const CircularProgressWidget({
    super.key,
    required this.trackingData,
  });

  @override
  Widget build(BuildContext context) {
    final totalCalories = trackingData['totalCalories'] ?? 0;
    final caloriesGoal = trackingData['caloriesGoal'] ?? 2000;
    final totalProtein = trackingData['totalProtein'] ?? 0;
    final proteinGoal = trackingData['proteinGoal'] ?? 100;
    final mostCommonMealType = trackingData['mostCommonMealType'] ?? 'Lunch';

    return SizedBox(
      width: 280,
      height: 280,
      child: CustomPaint(
        painter: CircularTrackingPainter(
          caloriesProgress: totalCalories / caloriesGoal,
          proteinProgress: totalProtein / proteinGoal,
          mostCommonMealType: mostCommonMealType,
          totalCalories: totalCalories,
          totalProtein: totalProtein,
        ),
      ),
    );
  }
}

class CircularTrackingPainter extends CustomPainter {
  final double caloriesProgress;
  final double proteinProgress;
  final String mostCommonMealType;
  final int totalCalories;
  final int totalProtein;

  CircularTrackingPainter({
    required this.caloriesProgress,
    required this.proteinProgress,
    required this.mostCommonMealType,
    required this.totalCalories,
    required this.totalProtein,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 20;
    
    // Background circle
    final backgroundPaint = Paint()
      ..color = const Color(0xFFF3F4F6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20;
    
    canvas.drawCircle(center, radius, backgroundPaint);

    // Calories progress arc (top third)
    final caloriesPaint = Paint()
      ..color = const Color(0xFF6366F1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.round;
    
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2, // Start from top
      (2 * math.pi / 3) * caloriesProgress, // First third of circle
      false,
      caloriesPaint,
    );

    // Protein progress arc (middle third)
    final proteinPaint = Paint()
      ..color = const Color(0xFF10B981)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.round;
    
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2 + (2 * math.pi / 3), // Start after calories
      (2 * math.pi / 3) * proteinProgress, // Second third of circle
      false,
      proteinPaint,
    );

    // Most common meal type indicator (last third)
    final mealTypePaint = Paint()
      ..color = const Color(0xFFF59E0B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.round;
    
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2 + (4 * math.pi / 3), // Start after protein
      (2 * math.pi / 3), // Full third for meal type
      false,
      mealTypePaint,
    );

    // Draw curved text labels
    _drawCurvedText(
      canvas, 
      '${totalCalories}cal', 
      center, 
      radius + 30, 
      -math.pi / 3, // Position in calories section
      const Color(0xFF6366F1),
    );
    
    _drawCurvedText(
      canvas, 
      '${totalProtein}g protein', 
      center, 
      radius + 30, 
      math.pi / 3, // Position in protein section
      const Color(0xFF10B981),
    );
    
    _drawCurvedText(
      canvas, 
      mostCommonMealType, 
      center, 
      radius + 30, 
      math.pi, // Position in meal type section
      const Color(0xFFF59E0B),
    );
  }

  void _drawCurvedText(
    Canvas canvas,
    String text,
    Offset center,
    double radius,
    double angle,
    Color color,
  ) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    // Calculate position for text
    final textOffset = Offset(
      center.dx + radius * math.cos(angle) - textPainter.width / 2,
      center.dy + radius * math.sin(angle) - textPainter.height / 2,
    );

    textPainter.paint(canvas, textOffset);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
