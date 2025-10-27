import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme_v3.dart';
import 'signup_page_v3.dart';
import '../meals/menu_page_v3.dart';

class WelcomePageV3 extends StatefulWidget {
  const WelcomePageV3({super.key});

  @override
  State<WelcomePageV3> createState() => _WelcomePageV3State();
}

class _WelcomePageV3State extends State<WelcomePageV3> {
  @override
  void initState() {
    super.initState();
    _markWelcomeSeen();
  }

  Future<void> _markWelcomeSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_welcome', true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeV3.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              
              // Welcome text
              Text(
                'Welcome to\nVictus',
                textAlign: TextAlign.center,
                style: AppThemeV3.textTheme.displayLarge?.copyWith(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: AppThemeV3.textPrimary,
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Sign Up Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) => const SignUpPageV3(),
                        transitionDuration: Duration.zero,
                        reverseTransitionDuration: Duration.zero,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppThemeV3.primaryBlack,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(
                        color: AppThemeV3.border,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Text(
                    'Sign Up',
                    style: AppThemeV3.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 40),
              
              // "or" divider
              Row(
                children: [
                  const Expanded(child: Divider(color: AppThemeV3.border)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'or',
                      style: AppThemeV3.textTheme.bodyMedium?.copyWith(
                        color: AppThemeV3.textSecondary,
                      ),
                    ),
                  ),
                  const Expanded(child: Divider(color: AppThemeV3.border)),
                ],
              ),
              
              const SizedBox(height: 40),
              
              // Check out the menus text
              Text(
                'Check out the menus',
                style: AppThemeV3.textTheme.headlineSmall?.copyWith(
                  color: AppThemeV3.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Menu cards (Breakfast, Lunch, Dinner)
              Row(
                children: [
                  Expanded(
                    child: _buildMenuCard(
                      context,
                      'Victus\nBreakfast menu',
                      'Breakfast\nmenus',
                      () => _navigateToMenu(context, 'breakfast'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMenuCard(
                      context,
                      'Victus\nLunch menu',
                      'Lunch\nmenus',
                      () => _navigateToMenu(context, 'lunch'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMenuCard(
                      context,
                      'Victus\nDinner menu',
                      'Dinner\nmenus',
                      () => _navigateToMenu(context, 'dinner'),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 40),
              
              // Map section
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppThemeV3.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppThemeV3.border, // 2px black border
                    width: 2,
                  ),
                  boxShadow: AppThemeV3.cardShadow,
                ),
                child: Stack(
                  children: [
                    // Map placeholder with location pins
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: AppThemeV3.surfaceElevated,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Location pins scattered
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildLocationPin(),
                                _buildLocationPin(),
                                _buildLocationPin(),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildLocationPin(),
                                _buildLocationPin(),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    // View Map button
                    Positioned(
                      bottom: 16,
                      left: 16,
                      right: 16,
                      child: ElevatedButton(
                        onPressed: () {
                          // Navigate to map page
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppThemeV3.primaryBlack,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(
                              color: AppThemeV3.border,
                              width: 2,
                            ),
                          ),
                        ),
                        child: Text(
                          'View Map',
                          style: AppThemeV3.textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuCard(BuildContext context, String title, String subtitle, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: AppThemeV3.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppThemeV3.border, // 2px black border
            width: 2,
          ),
          boxShadow: AppThemeV3.cardShadow,
        ),
        child: Column(
          children: [
            // Icon section
            Expanded(
              flex: 2,
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(14),
                    topRight: Radius.circular(14),
                  ),
                ),
                child: const Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.restaurant, size: 20, color: AppThemeV3.textPrimary),
                      SizedBox(width: 8),
                      Icon(Icons.fastfood, size: 20, color: AppThemeV3.textPrimary),
                      SizedBox(width: 8),
                      Icon(Icons.restaurant, size: 20, color: AppThemeV3.textPrimary),
                    ],
                  ),
                ),
              ),
            ),
            // Text section
            Expanded(
              flex: 1,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppThemeV3.surfaceElevated,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(14),
                    bottomRight: Radius.circular(14),
                  ),
                ),
                child: Center(
                  child: Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: AppThemeV3.textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppThemeV3.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationPin() {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: AppThemeV3.primaryBlack,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppThemeV3.border,
          width: 2,
        ),
      ),
      child: const Icon(
        Icons.location_on,
        size: 16,
        color: Colors.white,
      ),
    );
  }

  void _navigateToMenu(BuildContext context, String menuType) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MenuPageV3(menuType: menuType),
      ),
    );
  }
}
