import 'package:flutter/material.dart';
import 'home_page.dart';
import 'meal_schedule_page.dart';
import 'admin_data_page.dart';
import 'settings_page_new.dart';
import '../theme/app_theme.dart';

class UserPortalPage extends StatelessWidget {
  const UserPortalPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        title: Text(
          'FRESHPUNK',
          style: AppTheme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
            color: AppTheme.textPrimary,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: AppTheme.textPrimary),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.5,
            colors: [
              AppTheme.background,
              AppTheme.surface.withValues(alpha: 0.2),
              AppTheme.background,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                
                // Welcome message
                Text(
                  'WELCOME TO FRESHPUNK!',
                  style: AppTheme.textTheme.displayLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                    color: AppTheme.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 16),
                
                Text(
                  'Your premium fresh meal delivery service',
                  style: AppTheme.textTheme.bodyLarge?.copyWith(
                    color: AppTheme.textPrimary.withValues(alpha: 0.7),
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 60),
                
                // Home Button
                SizedBox(
                  height: 60,
                  child: AppButton(
                    text: 'HOME',
                    icon: Icons.home,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const HomePage()),
                      );
                    },
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Meal Schedule Button
                SizedBox(
                  height: 60,
                  child: AppButton(
                    text: 'MEAL SCHEDULE',
                    icon: Icons.restaurant_menu,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const MealSchedulePage()),
                      );
                    },
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Admin Data Button (for development)
                SizedBox(
                  height: 60,
                  child: AppButton(
                    text: 'ADMIN DATA',
                    icon: Icons.admin_panel_settings,
                    isPrimary: false,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const AdminDataPage()),
                      );
                    },
                  ),
                ),
                
                const Spacer(),
                
                // Info card
                AppCard(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.accent.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.eco,
                          size: 40,
                          color: AppTheme.accent,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'FRESH • HEALTHY • DELIVERED',
                        style: AppTheme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.accent,
                          letterSpacing: 1.2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Create your personalized meal schedule and let us deliver fresh, healthy meals right to your door.',
                        style: AppTheme.textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textPrimary.withValues(alpha: 0.8),
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
