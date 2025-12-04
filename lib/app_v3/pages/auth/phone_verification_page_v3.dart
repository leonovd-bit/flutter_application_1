import 'package:flutter/material.dart';
import 'dart:async';
import '../../theme/app_theme_v3.dart';
import '../../services/auth/phone_verification_service.dart';
import '../onboarding/choose_meal_plan_page_v3.dart';

class PhoneVerificationPageV3 extends StatefulWidget {
  final String phoneNumber;
  
  const PhoneVerificationPageV3({
    super.key,
    required this.phoneNumber,
  });

  @override
  State<PhoneVerificationPageV3> createState() => _PhoneVerificationPageV3State();
}

class _PhoneVerificationPageV3State extends State<PhoneVerificationPageV3> {
  Timer? _timer;
  Timer? _resendTimer;
  bool _isLoading = false;
  bool _canResendSms = false;
  int _resendCooldown = 60;
  final _codeController = TextEditingController();
  bool _hasNavigated = false; // Prevent double navigation

  @override
  void initState() {
    super.initState();
    _codeController.addListener(() {
      setState(() {}); // Update button state when text changes
    });
    _startPhoneVerificationCheck();
    _startResendCooldown();
  }

  void _startPhoneVerificationCheck() {
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (_hasNavigated) {
        timer.cancel();
        return;
      }
      
      try {
        // Check if phone is verified in Firestore
        final hasVerified = await PhoneVerificationService.instance
            .checkPhoneVerificationStatus();
        
        if (hasVerified && !_hasNavigated) {
          _hasNavigated = true;
          timer.cancel();
          if (mounted) {
            try {
              print('[PhoneVerification] Phone verified via polling, navigating to meal plan selection');
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const ChooseMealPlanPageV3(isSignupFlow: true),
                ),
              );
            } catch (e) {
              print('[PhoneVerification] Navigation error: $e');
              _hasNavigated = false; // Reset if navigation failed
            }
          }
        }
      } catch (e) {
        print('[PhoneVerification] Check status error: $e');
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
          _canResendSms = true;
        });
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _resendTimer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();
    
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the verification code'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_hasNavigated) {
      print('[PhoneVerification] Already navigated, ignoring verify attempt');
      return;
    }

    setState(() => _isLoading = true);

    try {
      print('[PhoneVerification] Verifying code: $code');
      
      // Verify the code with Firebase and get credential
      final credential = await PhoneVerificationService.instance.verifyCode(code);
      print('[PhoneVerification] Code verified, got credential');

      // Link the phone credential to current user
      await PhoneVerificationService.instance.linkPhoneToCurrentUser(credential);
      print('[PhoneVerification] Phone linked to user');

      // Update Firestore with phone verification
      await PhoneVerificationService.instance.updateUserProfilePhone();
      print('[PhoneVerification] Firestore updated');

      _hasNavigated = true;
      
      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Phone verified successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        // Navigate to meal plan selection
        await Future.delayed(const Duration(seconds: 1));
        if (mounted && !_hasNavigated) {
          _hasNavigated = true;
          print('[PhoneVerification] Navigating to meal plan page');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const ChooseMealPlanPageV3(isSignupFlow: true),
            ),
          );
        }
      }
    } catch (e) {
      print('[PhoneVerification] Error during verification: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _resendVerificationSms() async {
    setState(() => _isLoading = true);

    try {
      // Start a new phone verification with the same phone number
      await PhoneVerificationService.instance
          .startPhoneVerification(widget.phoneNumber);
      
      setState(() {
        _canResendSms = false;
        _resendCooldown = 60;
        _codeController.clear();
      });
      
      _startResendCooldown();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification code sent successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to resend code: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Prevent back navigation to bypass verification
      child: Scaffold(
        backgroundColor: AppThemeV3.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false, // Remove back button
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              
              // Phone verification icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppThemeV3.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(60),
                ),
                child: Icon(
                  Icons.phone_outlined,
                  size: 60,
                  color: AppThemeV3.accent,
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Title
              Text(
                'Verify your phone',
                style: AppThemeV3.textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppThemeV3.textPrimary,
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Description
              Text(
                'We\'ve sent a verification code to',
                textAlign: TextAlign.center,
                style: AppThemeV3.textTheme.bodyLarge?.copyWith(
                  color: AppThemeV3.textSecondary,
                ),
              ),
              
              const SizedBox(height: 8),
              
              // Phone number
              Text(
                widget.phoneNumber,
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
                      'Enter the 6-digit code from the text message to verify your phone number.',
                      textAlign: TextAlign.center,
                      style: AppThemeV3.textTheme.bodyMedium?.copyWith(
                        color: AppThemeV3.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Code input field
              TextFormField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                decoration: InputDecoration(
                  hintText: '000000',
                  hintStyle: AppThemeV3.textTheme.headlineSmall?.copyWith(
                    color: Colors.grey[400],
                    letterSpacing: 8,
                  ),
                  counterText: '', // Hide character counter
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppThemeV3.border, width: 2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppThemeV3.border, width: 2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppThemeV3.accent, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 20),
                ),
                style: AppThemeV3.textTheme.headlineSmall?.copyWith(
                  letterSpacing: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Verify button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _verifyCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _codeController.text.length == 6 
                        ? Colors.black 
                        : Colors.grey,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: _codeController.text.length == 6 
                            ? Colors.black 
                            : Colors.grey,
                        width: 2,
                      ),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          'Verify Phone',
                          style: AppThemeV3.textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Resend SMS button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _canResendSms && !_isLoading ? _resendVerificationSms : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _canResendSms 
                        ? AppThemeV3.accent 
                        : AppThemeV3.surfaceElevated,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          _canResendSms 
                              ? 'Resend verification code' 
                              : 'Resend in ${_resendCooldown}s',
                          style: AppThemeV3.textTheme.titleMedium?.copyWith(
                            color: _canResendSms ? Colors.white : AppThemeV3.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Help text
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.help_outline,
                      color: Colors.blue.shade700,
                      size: 24,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Didn\'t receive the code?',
                      style: AppThemeV3.textTheme.titleSmall?.copyWith(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Check your spam folder or use the Resend button above to get a new code.',
                      textAlign: TextAlign.center,
                      style: AppThemeV3.textTheme.bodySmall?.copyWith(
                        color: Colors.blue.shade600,
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
      ),
    );
  }
}
