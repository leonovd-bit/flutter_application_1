import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../../theme/app_theme_v3.dart';
import '../onboarding/onboarding_choice_page_v3.dart';

class EmailVerificationPageV3 extends StatefulWidget {
  final String email;
  
  const EmailVerificationPageV3({super.key, required this.email});

  @override
  State<EmailVerificationPageV3> createState() => _EmailVerificationPageV3State();
}

class _EmailVerificationPageV3State extends State<EmailVerificationPageV3> {
  Timer? _timer;
  Timer? _resendTimer;
  bool _isLoading = false;
  bool _canResendEmail = false;
  int _resendCooldown = 60;

  @override
  void initState() {
    super.initState();
    _startEmailVerificationCheck();
    _startResendCooldown();
  }

  void _startEmailVerificationCheck() {
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      await FirebaseAuth.instance.currentUser?.reload();
      final user = FirebaseAuth.instance.currentUser;
      
      if (user != null && user.emailVerified) {
        timer.cancel();
        if (mounted) {
          try {
            print('[EmailVerification] User verified, navigating to onboarding choice');
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const OnboardingChoicePageV3(),
              ),
            );
          } catch (e) {
            print('[EmailVerification] Navigation error: $e');
          }
        }
      }
    });
  }

  void _startResendCooldown() {
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      if (_resendCooldown > 0) {
        setState(() {
          _resendCooldown--;
        });
      } else {
        setState(() {
          _canResendEmail = true;
        });
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _resendTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeV3.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              
              // Email verification icon
        Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
          color: AppThemeV3.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(60),
                ),
                child: Icon(
                  Icons.email_outlined,
                  size: 60,
                  color: AppThemeV3.accent,
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Title
              Text(
                'Verify your email',
                style: AppThemeV3.textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppThemeV3.textPrimary,
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Description
              Text(
                'We\'ve sent a verification link to',
                textAlign: TextAlign.center,
                style: AppThemeV3.textTheme.bodyLarge?.copyWith(
                  color: AppThemeV3.textSecondary,
                ),
              ),
              
              const SizedBox(height: 8),
              
              // Email address
              Text(
                widget.email,
                textAlign: TextAlign.center,
                style: AppThemeV3.textTheme.titleMedium?.copyWith(
                  color: AppThemeV3.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Instructions
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppThemeV3.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppThemeV3.border),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: AppThemeV3.accent,
                      size: 24,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please check your email and click the verification link to activate your account.',
                      textAlign: TextAlign.center,
                      style: AppThemeV3.textTheme.bodyMedium?.copyWith(
                        color: AppThemeV3.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Resend email button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _canResendEmail && !_isLoading ? _resendVerificationEmail : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _canResendEmail ? AppThemeV3.accent : AppThemeV3.surfaceElevated,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          _canResendEmail 
                              ? 'Resend verification email' 
                              : 'Resend in ${_resendCooldown}s',
                          style: AppThemeV3.textTheme.titleMedium?.copyWith(
                            color: _canResendEmail ? Colors.white : AppThemeV3.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Check verification status button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _checkVerificationStatus,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppThemeV3.accent,
                    side: const BorderSide(color: AppThemeV3.accent),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'I\'ve verified my email',
                    style: AppThemeV3.textTheme.titleMedium?.copyWith(
                      color: AppThemeV3.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Change email option
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Change email address',
                  style: AppThemeV3.textTheme.bodyMedium?.copyWith(
                    color: AppThemeV3.textSecondary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _resendVerificationEmail() async {
    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.currentUser?.sendEmailVerification();
      
      setState(() {
        _canResendEmail = false;
        _resendCooldown = 60;
      });
      
      _startResendCooldown();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification email sent successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send verification email'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _checkVerificationStatus() async {
    await FirebaseAuth.instance.currentUser?.reload();
    final user = FirebaseAuth.instance.currentUser;
    
    if (user != null && user.emailVerified) {
      if (mounted) {
        try {
          print('[EmailVerification] Manual check - user verified, navigating to onboarding choice');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const OnboardingChoicePageV3(),
            ),
          );
        } catch (e) {
          print('[EmailVerification] Manual navigation error: $e');
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email not verified yet. Please check your email.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }
}
