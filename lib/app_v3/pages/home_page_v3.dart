import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../theme/app_theme_v3.dart';
import '../models/meal_model_v3.dart';
import 'map_page_v3.dart';
import 'settings_page_v3.dart';
import 'circle_of_health_page_v3.dart';
import 'upcoming_orders_page_v3.dart';
import 'past_orders_page_v3.dart';
import 'address_page_v3.dart';

class HomePageV3 extends StatefulWidget {
  const HomePageV3({super.key});

  @override
  State<HomePageV3> createState() => _HomePageV3State();
}

class _HomePageV3State extends State<HomePageV3> {
  // Mock user data - in real app, this would come from Firebase
  final String _currentMealPlan = 'DietKnight'; // 2 meals/day
  final Map<String, int> _todayStats = {
    'calories': 850,
    'protein': 45,
  };
  final String _mostEatenMealType = 'Breakfast';
  
  // Mock upcoming order
  final Map<String, dynamic> _nextOrder = {
    'mealType': 'Breakfast',
    'mealName': 'Avocado Toast Bowl',
    'deliveryTime': '8:30 AM',
    'calories': 320,
    'protein': 12,
    'type': 'Healthy',
    'image': 'breakfast_1',
  };
  
  // Mock past orders
  final List<Map<String, dynamic>> _recentOrders = [
    {
      'name': 'Greek Yogurt Parfait',
      'image': 'breakfast_2',
      'date': '2025-07-26',
    },
    {
      'name': 'Quinoa Buddha Bowl',
      'image': 'lunch_1',
      'date': '2025-07-25',
    },
    {
      'name': 'Salmon Dinner',
      'image': 'dinner_1',
      'date': '2025-07-24',
    },
  ];
  
  // Mock addresses
  final List<AddressModelV3> _userAddresses = [
    AddressModelV3(
      id: '1',
      userId: 'user1',
      label: 'Home',
      streetAddress: '123 Main Street',
      apartment: 'Apt 4B',
      city: 'New York City',
      state: 'New York',
      zipCode: '10001',
      isDefault: true,
    ),
    AddressModelV3(
      id: '2',
      userId: 'user1',
      label: 'Work',
      streetAddress: '456 Broadway',
      city: 'New York City',
      state: 'New York',
      zipCode: '10013',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeV3.background,
      body: Stack(
        children: [
          // Main content
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 100, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Circle of Health
                _buildCircleOfHealth(),
                
                const SizedBox(height: 32),
                
                // Addresses Section
                _buildAddressesSection(),
                
                const SizedBox(height: 24),
                
                // Upcoming Orders
                _buildUpcomingOrdersSection(),
                
                const SizedBox(height: 24),
                
                // Past Orders
                _buildPastOrdersSection(),
              ],
            ),
          ),
          
          // Floating header
          _buildFloatingHeader(),
        ],
      ),
    );
  }

  Widget _buildFloatingHeader() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 50, 24, 16),
        decoration: BoxDecoration(
          color: AppThemeV3.background.withOpacity(0.95),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Map icon
            IconButton(
              icon: const Icon(Icons.map, size: 28),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const MapPageV3()),
                );
              },
            ),
            
            // FreshPunk logo
            Text(
              'FreshPunk',
              style: AppThemeV3.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppThemeV3.accent,
              ),
            ),
            
            // Settings icon
            IconButton(
              icon: const Icon(Icons.settings, size: 28),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsPageV3()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircleOfHealth() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CircleOfHealthPageV3()),
        );
      },
      child: Center(
        child: SizedBox(
          width: 200,
          height: 200,
          child: Stack(
            children: [
              // Outer circle
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppThemeV3.accent,
                    width: 3,
                  ),
                ),
              ),
              
              // Inner circle
              Positioned(
                top: 40,
                left: 40,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppThemeV3.accent.withOpacity(0.1),
                    border: Border.all(
                      color: AppThemeV3.accent,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      _currentMealPlan,
                      textAlign: TextAlign.center,
                      style: AppThemeV3.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppThemeV3.accent,
                      ),
                    ),
                  ),
                ),
              ),
              
              // Curved text at bottom
              Positioned(
                bottom: 15,
                left: 0,
                right: 0,
                child: _buildCurvedText(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurvedText() {
    return SizedBox(
      height: 50,
      child: CustomPaint(
        painter: CurvedTextPainter(
          text: '${_todayStats['calories']} Cal • ${_todayStats['protein']}g Protein • $_mostEatenMealType',
          textStyle: AppThemeV3.textTheme.bodySmall?.copyWith(
            color: AppThemeV3.textSecondary,
            fontWeight: FontWeight.w500,
          ) ?? const TextStyle(),
        ),
        child: Container(),
      ),
    );
  }

  Widget _buildAddressesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Your Addresses',
              style: AppThemeV3.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AddressPageV3()),
                );
              },
              child: Text(
                'Edit',
                style: AppThemeV3.textTheme.titleMedium?.copyWith(
                  color: AppThemeV3.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        // Address cards
        Column(
          children: _userAddresses.map((address) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppThemeV3.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppThemeV3.border),
              boxShadow: AppThemeV3.cardShadow,
            ),
            child: Row(
              children: [
                Icon(
                  address.label.toLowerCase() == 'home' 
                      ? Icons.home 
                      : Icons.work,
                  color: AppThemeV3.accent,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            address.label,
                            style: AppThemeV3.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (address.isDefault) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppThemeV3.accent,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Default',
                                style: AppThemeV3.textTheme.bodySmall?.copyWith(
                                  color: Colors.white,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        address.fullAddress,
                        style: AppThemeV3.textTheme.bodyMedium?.copyWith(
                          color: AppThemeV3.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildUpcomingOrdersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Upcoming Orders',
          style: AppThemeV3.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        
        // Next order card
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const UpcomingOrdersPageV3()),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppThemeV3.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppThemeV3.border),
              boxShadow: AppThemeV3.cardShadow,
            ),
            child: Row(
              children: [
                // Meal image placeholder
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: AppThemeV3.accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _nextOrder['mealType'] == 'Breakfast' 
                        ? Icons.breakfast_dining
                        : _nextOrder['mealType'] == 'Lunch'
                            ? Icons.lunch_dining
                            : Icons.dinner_dining,
                    color: AppThemeV3.accent,
                    size: 30,
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // Order details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _nextOrder['mealType'],
                        style: AppThemeV3.textTheme.bodyMedium?.copyWith(
                          color: AppThemeV3.textSecondary,
                        ),
                      ),
                      Text(
                        _nextOrder['deliveryTime'],
                        style: AppThemeV3.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Nutrition info
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${_nextOrder['calories']} Cal',
                      style: AppThemeV3.textTheme.bodySmall?.copyWith(
                        color: AppThemeV3.textSecondary,
                      ),
                    ),
                    Text(
                      '${_nextOrder['protein']}g Protein',
                      style: AppThemeV3.textTheme.bodySmall?.copyWith(
                        color: AppThemeV3.textSecondary,
                      ),
                    ),
                    Text(
                      _nextOrder['type'],
                      style: AppThemeV3.textTheme.bodySmall?.copyWith(
                        color: AppThemeV3.accent,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPastOrdersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Past Orders',
          style: AppThemeV3.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        
        // Past orders horizontal list
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const PastOrdersPageV3()),
            );
          },
          child: SizedBox(
            height: 120,
            child: Row(
              children: _recentOrders.map((order) => Container(
                width: 100,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: AppThemeV3.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppThemeV3.border),
                  boxShadow: AppThemeV3.cardShadow,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Meal image placeholder
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: AppThemeV3.accent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.fastfood,
                        color: AppThemeV3.accent,
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      order['name'],
                      style: AppThemeV3.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              )).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

// Custom painter for curved text at bottom of circle
class CurvedTextPainter extends CustomPainter {
  final String text;
  final TextStyle textStyle;

  CurvedTextPainter({required this.text, required this.textStyle});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );
    
    // Split text and draw each character along the curve
    final characters = text.split('');
    final angleStep = math.pi / characters.length;
    
    for (int i = 0; i < characters.length; i++) {
      textPainter.text = TextSpan(
        text: characters[i],
        style: textStyle,
      );
      textPainter.layout();
      
      final angle = math.pi + angleStep * i;
      final x = center.dx + radius * math.cos(angle) - textPainter.width / 2;
      final y = center.dy + radius * math.sin(angle) - textPainter.height / 2;
      
      canvas.save();
      canvas.translate(x + textPainter.width / 2, y + textPainter.height / 2);
      canvas.rotate(angle + math.pi / 2);
      canvas.translate(-textPainter.width / 2, -textPainter.height / 2);
      textPainter.paint(canvas, Offset.zero);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
