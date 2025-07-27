import 'package:flutter/material.dart';
import 'signup_page.dart';
import 'login_page.dart';
import 'menu_page.dart';
import 'map_page.dart';
import '../theme/app_theme.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppTheme.background,
                AppTheme.surface.withOpacity(0.3),
                AppTheme.background,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                
                // Header with Welcome text and action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'WELCOME TO\nFRESHPUNK',
                        style: AppTheme.textTheme.displayLarge?.copyWith(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    Column(
                      children: [
                        AppButton(
                          text: 'SIGN UP',
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const SignUpPage()),
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        AppButton(
                          text: 'Login',
                          isPrimary: false,
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const LoginPage()),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                
                const SizedBox(height: 40),
                
                // "or" divider
                Row(
                  children: [
                    Expanded(child: Container(height: 1, color: AppTheme.border)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'OR',
                        style: AppTheme.textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textPrimary.withOpacity(0.6),
                          letterSpacing: 1.0,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(child: Container(height: 1, color: AppTheme.border)),
                  ],
                ),
                
                const SizedBox(height: 40),
                
                // "Check this out" text
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'CHECK THIS OUT',
                    style: AppTheme.textTheme.headlineMedium?.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Menu cards
                Row(
                  children: [
                    Expanded(
                      child: _buildMenuCard(
                        context,
                        'FreshPunk\nBreakfast',
                        'breakfast',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMenuCard(
                        context,
                        'FreshPunk\nLunch',
                        'lunch',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMenuCard(
                        context,
                        'FreshPunk\nDinner',
                        'dinner',
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 40),
                
                // Map section
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: Stack(
                            children: [
                              // Map placeholder with location markers
                              Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.map,
                                      size: 80,
                                      color: AppTheme.accent,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'KITCHEN LOCATIONS NEAR YOU',
                                      style: AppTheme.textTheme.bodyMedium?.copyWith(
                                        color: AppTheme.textPrimary.withOpacity(0.8),
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Sample location markers
                              Positioned(
                                top: 40,
                                left: 60,
                                child: _buildLocationMarker(),
                              ),
                              Positioned(
                                top: 80,
                                right: 80,
                                child: _buildLocationMarker(),
                              ),
                              Positioned(
                                bottom: 60,
                                left: 100,
                                child: _buildLocationMarker(),
                              ),
                            ],
                          ),
                        ),
                        // View Map button
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(20),
                              bottomRight: Radius.circular(20),
                            ),
                            border: Border(
                              top: BorderSide(color: AppTheme.border),
                            ),
                          ),
                          child: AppButton(
                            text: 'VIEW MAP',
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const MapPage()),
                              );
                            },
                          ),
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

  Widget _buildMenuCard(BuildContext context, String title, String mealType) {
    return AppCard(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MenuPage(mealType: mealType),
          ),
        );
      },
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        height: 120,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Utensils icon
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.restaurant,
                  size: 20,
                  color: AppTheme.accent,
                ),
                const SizedBox(width: 12),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppTheme.accent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.lunch_dining,
                    size: 16,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.local_dining,
                  size: 20,
                  color: AppTheme.accent,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title.toUpperCase(),
              textAlign: TextAlign.center,
              style: AppTheme.textTheme.bodyMedium?.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationMarker() {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: AppTheme.accent,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppTheme.accent.withOpacity(0.6),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      child: const Icon(
        Icons.location_on,
        size: 14,
        color: AppTheme.textPrimary,
      ),
    );
  }
}
