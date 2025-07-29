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
        padding: const EdgeInsets.fromLTRB(24, 50, 24, 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppThemeV3.surface,
              AppThemeV3.surface.withOpacity(0.95),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 16,
              offset: const Offset(0, 4),
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Map icon
            Container(
              decoration: BoxDecoration(
                color: AppThemeV3.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppThemeV3.accent.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: Icon(Icons.map, size: 28, color: AppThemeV3.accent),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const MapPageV3()),
                  );
                },
              ),
            ),
            
            // FreshPunk logo
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppThemeV3.accent.withOpacity(0.1),
                    AppThemeV3.accent.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppThemeV3.accent.withOpacity(0.3),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppThemeV3.accent.withOpacity(0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                'FreshPunk',
                style: AppThemeV3.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppThemeV3.accent,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            
            // Settings icon
            Container(
              decoration: BoxDecoration(
                color: AppThemeV3.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppThemeV3.accent.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: Icon(Icons.settings, size: 28, color: AppThemeV3.accent),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SettingsPageV3()),
                  );
                },
              ),
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
        child: Container(
          width: 220,
          height: 220,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 0.8,
              colors: [
                AppThemeV3.accent.withOpacity(0.05),
                AppThemeV3.accent.withOpacity(0.01),
                Colors.transparent,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppThemeV3.accent.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
                spreadRadius: 5,
              ),
            ],
          ),
          child: SizedBox(
            width: 200,
            height: 200,
            child: Stack(
              children: [
                // Outer circle with enhanced styling
                Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppThemeV3.accent,
                        AppThemeV3.accent.withOpacity(0.8),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppThemeV3.accent.withOpacity(0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Container(
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppThemeV3.background,
                    ),
                  ),
                ),
                
                // Inner circle with enhanced styling
                Positioned(
                  top: 40,
                  left: 40,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppThemeV3.accent.withOpacity(0.15),
                          AppThemeV3.accent.withOpacity(0.08),
                        ],
                      ),
                      border: Border.all(
                        color: AppThemeV3.accent,
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppThemeV3.accent.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        _currentMealPlan,
                        textAlign: TextAlign.center,
                        style: AppThemeV3.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: AppThemeV3.accent,
                          letterSpacing: 0.5,
                          fontSize: 16,
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppThemeV3.surface,
            AppThemeV3.surface.withOpacity(0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppThemeV3.accent.withOpacity(0.2),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppThemeV3.accent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.location_on,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Your Addresses',
                    style: AppThemeV3.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppThemeV3.accent.withOpacity(0.1),
                      AppThemeV3.accent.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppThemeV3.accent.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: TextButton(
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
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Address cards
          Column(
          children: _userAddresses.map((address) => Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppThemeV3.accent.withOpacity(0.05),
                  AppThemeV3.accent.withOpacity(0.02),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppThemeV3.accent.withOpacity(0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppThemeV3.accent.withOpacity(0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppThemeV3.accent,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppThemeV3.accent.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    address.label.toLowerCase() == 'home' 
                        ? Icons.home 
                        : Icons.work,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            address.label,
                            style: AppThemeV3.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppThemeV3.textPrimary,
                            ),
                          ),
                          if (address.isDefault) ...[
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppThemeV3.accent,
                                    AppThemeV3.accent.withOpacity(0.8),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppThemeV3.accent.withOpacity(0.3),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                'DEFAULT',
                                style: AppThemeV3.textTheme.bodySmall?.copyWith(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        address.fullAddress,
                        style: AppThemeV3.textTheme.bodyMedium?.copyWith(
                          color: AppThemeV3.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
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
      ),
    );
  }

  Widget _buildUpcomingOrdersSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppThemeV3.surface,
            AppThemeV3.surface.withOpacity(0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppThemeV3.accent.withOpacity(0.2),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppThemeV3.accent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.schedule,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Upcoming Orders',
                style: AppThemeV3.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Next order card
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const UpcomingOrdersPageV3()),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppThemeV3.accent.withOpacity(0.05),
                    AppThemeV3.accent.withOpacity(0.02),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppThemeV3.accent.withOpacity(0.3),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppThemeV3.accent.withOpacity(0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                'Next order: ${_nextOrder['mealType']} - ${_nextOrder['deliveryTime']}',
                style: AppThemeV3.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppThemeV3.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
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
