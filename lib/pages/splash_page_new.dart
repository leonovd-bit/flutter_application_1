import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'welcome_page.dart';
import 'login_page.dart';
import 'user_portal_page.dart';
import '../theme/app_theme.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.2, 0.8, curve: Curves.elasticOut),
    ));

    _animationController.forward();
    _navigateToNextPage();
  }

  Future<void> _navigateToNextPage() async {
    await Future.delayed(const Duration(milliseconds: 3000));
    
    // Check if user is already authenticated with Firebase
    final currentUser = FirebaseAuth.instance.currentUser;
    
    if (currentUser != null) {
      // User is already signed in, go directly to User Portal
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const UserPortalPage()),
        );
      }
      return;
    }
    
    // Check SharedPreferences for returning user preference
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    
    if (mounted) {
      if (isLoggedIn) {
        // Navigate to login page for returning users
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      } else {
        // Navigate to welcome page for new users
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const WelcomePage()),
        );
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.2,
            colors: [
              AppTheme.background,
              AppTheme.surface.withValues(alpha: 0.2),
              AppTheme.background,
            ],
            stops: const [0.0, 0.6, 1.0],
          ),
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Opacity(
                opacity: _fadeAnimation.value,
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Modern Logo Design
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(
                            color: AppTheme.accent.withValues(alpha: 0.3),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.accent.withValues(alpha: 0.3),
                              blurRadius: 30,
                              spreadRadius: 10,
                            ),
                            BoxShadow(
                              color: AppTheme.background,
                              blurRadius: 20,
                              spreadRadius: -5,
                              offset: const Offset(0, 0),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Fork Icon
                            Icon(
                              Icons.restaurant,
                              size: 56,
                              color: AppTheme.accent,
                            ),
                            const SizedBox(width: 32),
                            
                            // Central Food Grid
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppTheme.accent,
                                    AppTheme.hover,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.accent.withValues(alpha: 0.5),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  // Top row
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Container(
                                            decoration: const BoxDecoration(
                                              border: Border(
                                                right: BorderSide(color: AppTheme.textPrimary, width: 1.5),
                                                bottom: BorderSide(color: AppTheme.textPrimary, width: 1.5),
                                              ),
                                            ),
                                            child: const Icon(
                                              Icons.lunch_dining,
                                              size: 28,
                                              color: AppTheme.textPrimary,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Container(
                                            decoration: const BoxDecoration(
                                              border: Border(
                                                bottom: BorderSide(color: AppTheme.textPrimary, width: 1.5),
                                              ),
                                            ),
                                            child: const Icon(
                                              Icons.grass,
                                              size: 28,
                                              color: AppTheme.textPrimary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Bottom row
                                  Expanded(
                                    child: SizedBox(
                                      width: double.infinity,
                                      child: const Icon(
                                        Icons.eco,
                                        size: 28,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            const SizedBox(width: 32),
                            
                            // Knife Icon
                            Icon(
                              Icons.local_dining,
                              size: 56,
                              color: AppTheme.accent,
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 64),
                      
                      // Brand Name with Modern Typography
                      Text(
                        'FRESHPUNK',
                        style: AppTheme.textTheme.displayLarge?.copyWith(
                          fontSize: 48,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 4.0,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Tagline
                      Text(
                        'PREMIUM MEAL DELIVERY',
                        style: AppTheme.textTheme.bodyMedium?.copyWith(
                          letterSpacing: 2.4,
                          color: AppTheme.textPrimary.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
