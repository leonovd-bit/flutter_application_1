import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme_v3.dart';
import 'welcome_page_v3.dart';
import 'home_page_v3.dart';
import 'login_page_v3.dart';

class SplashPageV3 extends StatefulWidget {
  const SplashPageV3({super.key});

  @override
  State<SplashPageV3> createState() => _SplashPageV3State();
}

class _SplashPageV3State extends State<SplashPageV3> with SingleTickerProviderStateMixin {
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
    
    if (!mounted) return;
    
    // Check if user is already logged in
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.emailVerified) {
      // User is already logged in, go directly to home page
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomePageV3()),
      );
      return;
    }

    // Check if user has seen welcome before (returning user)
    final prefs = await SharedPreferences.getInstance();
    final hasSeenWelcome = prefs.getBool('has_seen_welcome') ?? false;
    
    if (hasSeenWelcome) {
      // Returning user who isn't logged in - go straight to login
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginPageV3()),
      );
    } else {
      // First time user - show welcome page
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const WelcomePageV3()),
      );
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
      backgroundColor: AppThemeV3.background,
      body: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // FreshPunk Logo
                    Container(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          // Utensils and plate icon
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Fork
                              Icon(
                                Icons.restaurant,
                                size: 40,
                                color: AppThemeV3.textPrimary,
                              ),
                              const SizedBox(width: 16),
                              // Plate with food items
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: AppThemeV3.textPrimary,
                                    width: 3,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  children: [
                                    // Top section with leaf
                                    Expanded(
                                      child: Container(
                                        width: double.infinity,
                                        decoration: const BoxDecoration(
                                          borderRadius: BorderRadius.only(
                                            topLeft: Radius.circular(5),
                                            topRight: Radius.circular(5),
                                          ),
                                        ),
                                        child: Center(
                                          child: Container(
                                            width: 30,
                                            height: 20,
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                color: AppThemeV3.textPrimary,
                                                width: 2,
                                              ),
                                              borderRadius: BorderRadius.circular(15),
                                            ),
                                            child: Icon(
                                              Icons.eco,
                                              size: 12,
                                              color: AppThemeV3.accent,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Bottom section with checkmark
                                    Expanded(
                                      child: Container(
                                        width: double.infinity,
                                        decoration: const BoxDecoration(
                                          borderRadius: BorderRadius.only(
                                            bottomLeft: Radius.circular(5),
                                            bottomRight: Radius.circular(5),
                                          ),
                                        ),
                                        child: Center(
                                          child: Icon(
                                            Icons.check,
                                            size: 20,
                                            color: AppThemeV3.accent,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Knife
                              Transform.rotate(
                                angle: 0,
                                child: Icon(
                                  Icons.local_dining,
                                  size: 40,
                                  color: AppThemeV3.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          // FreshPunk Text
                          Text(
                            'FreshPunk',
                            style: AppThemeV3.textTheme.displayLarge?.copyWith(
                              fontSize: 36,
                              fontWeight: FontWeight.w800,
                              color: AppThemeV3.textPrimary,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
