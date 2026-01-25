import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../../theme/app_theme_v3.dart';
import '../../services/auth/progress_manager.dart';
import '../../services/auth/auth_service.dart';
import '../../services/auth/auth_wrapper.dart' show ExplicitSetupApproval; // approve explicit setup
import '../../services/auth/phone_verification_service.dart';
import 'phone_verification_page_v3.dart';
import 'phone_collection_page_v3.dart';
import 'login_page_v3.dart';
import '../onboarding/choose_meal_plan_page_v3.dart';
import '../home_page_v3.dart';
import 'welcome_page_v3.dart';

class SignUpPageV3 extends StatefulWidget {
  const SignUpPageV3({super.key});

  @override
  State<SignUpPageV3> createState() => _SignUpPageV3State();
}

class _SignUpPageV3State extends State<SignUpPageV3> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;
  
  // Validation states
  bool _isEmailValid = false;
  bool _isPhoneValid = false;
  bool _emailTouched = false;
  bool _phoneTouched = false;

  // Password complexity helpers (match Settings requirements)
  bool get _hasMinLength => _passwordController.text.length >= 8;
  bool get _hasLetter => RegExp(r'[A-Za-z]').hasMatch(_passwordController.text);
  bool get _hasNumber => RegExp(r'[0-9]').hasMatch(_passwordController.text);
  bool get _hasSymbol => RegExp(r'[^A-Za-z0-9]').hasMatch(_passwordController.text);
  bool get _meetsPasswordComplexity => _hasMinLength && _hasLetter && _hasNumber && _hasSymbol;

  @override
  void initState() {
    super.initState();
    // Add listeners for real-time validation
    _emailController.addListener(_validateEmail);
    _phoneController.addListener(_validatePhone);
    _nameController.addListener(() => setState(() {}));
    _passwordController.addListener(() => setState(() {}));
    _confirmPasswordController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  // Email validation method
  void _validateEmail() {
    final email = _emailController.text;
    setState(() {
      _emailTouched = email.isNotEmpty;
      _isEmailValid = _isValidEmail(email);
    });
  }

  // Phone validation method
  void _validatePhone() {
    final phone = _phoneController.text;
    setState(() {
      _phoneTouched = phone.isNotEmpty;
      _isPhoneValid = _isValidPhone(phone);
    });
  }

  // Email format validation
  bool _isValidEmail(String email) {
    if (email.isEmpty) return false;
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  // Phone format validation
  bool _isValidPhone(String phone) {
    if (phone.isEmpty) return false;
    // Remove all non-digit characters
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    // US phone number should have 10 digits
    return digits.length == 10;
  }

  // Format phone number as user types
  String _formatPhoneNumber(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length <= 3) {
      return digits;
    } else if (digits.length <= 6) {
      return '(${digits.substring(0, 3)}) ${digits.substring(3)}';
    } else {
      return '(${digits.substring(0, 3)}) ${digits.substring(3, 6)}-${digits.substring(6, digits.length > 10 ? 10 : digits.length)}';
    }
  }

  // Check if all required fields are valid
  bool _areFieldsValid() {
    return _nameController.text.isNotEmpty &&
           _isEmailValid &&
           _isPhoneValid &&
           _meetsPasswordComplexity &&
           _passwordController.text == _confirmPasswordController.text;
  }

  // Build requirement item widget
  Widget _buildRequirementItem(String requirement, bool isValid) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            isValid ? Icons.check_circle : Icons.radio_button_unchecked,
            color: isValid ? Colors.green : AppThemeV3.textSecondary,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            requirement,
            style: TextStyle(
              color: isValid ? Colors.green : AppThemeV3.textSecondary,
              fontSize: 13,
              fontWeight: isValid ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  void _handleBackNavigation() {
    // If we can pop, do it (means we came from login or another page)
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      // If we can't pop (came from welcome), go to welcome page
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const WelcomePageV3()),
      );
    }
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
          onPressed: () => _handleBackNavigation(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                
                // Tab-like header
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const LoginPageV3()),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        child: Text(
                          'Sign In',
                          style: AppThemeV3.textTheme.titleLarge?.copyWith(
                            color: AppThemeV3.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.black,
                          width: 2,
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
                  ],
                ),
                
                const SizedBox(height: 40),
                // Security Notice (match Settings)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppThemeV3.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppThemeV3.accent.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.security, color: AppThemeV3.accent, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Security Notice',
                              style: AppThemeV3.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppThemeV3.accent,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Choose a strong password with at least 8 characters, including letters, numbers, and symbols.',
                              style: AppThemeV3.textTheme.bodySmall?.copyWith(
                                color: AppThemeV3.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // Validation Requirements Panel
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black, width: 2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.black, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Account Requirements',
                            style: AppThemeV3.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildRequirementItem('Valid email address', _isEmailValid),
                      _buildRequirementItem('Valid 10-digit phone number', _isPhoneValid),
                      _buildRequirementItem('Password (8+ characters)', _hasMinLength),
                      _buildRequirementItem('Contains letters, numbers, and symbols', _hasLetter && _hasNumber && _hasSymbol),
                      _buildRequirementItem('Passwords match', _confirmPasswordController.text == _passwordController.text && _passwordController.text.isNotEmpty),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Name field
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    hintText: 'Full Name',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => _nameController.clear(),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your name';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 16),
                
                // Email field
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: 'Email',
                    suffixIcon: _emailTouched
                        ? Icon(
                            _isEmailValid ? Icons.check_circle : Icons.error,
                            color: _isEmailValid ? Colors.green : Colors.red,
                          )
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => _emailController.clear(),
                          ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: _emailTouched
                            ? (_isEmailValid ? Colors.green : Colors.red)
                            : AppThemeV3.border,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: _emailTouched
                            ? (_isEmailValid ? Colors.green : Colors.red)
                            : AppThemeV3.border,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: _emailTouched
                            ? (_isEmailValid ? Colors.green : Colors.red)
                            : AppThemeV3.accent,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!_isValidEmail(value)) {
                      return 'Please enter a valid email address';
                    }
                    return null;
                  },
                ),
                
                // Email validation message
                if (_emailTouched && !_isEmailValid) ...[
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Text(
                      'Please enter a valid email format (e.g., user@example.com)',
                      style: TextStyle(
                        color: Colors.red.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
                
                const SizedBox(height: 16),
                
                // Phone field
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    hintText: 'Phone (e.g., (555) 123-4567)',
                    suffixIcon: _phoneTouched
                        ? Icon(
                            _isPhoneValid ? Icons.check_circle : Icons.error,
                            color: _isPhoneValid ? Colors.green : Colors.red,
                          )
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => _phoneController.clear(),
                          ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: _phoneTouched
                            ? (_isPhoneValid ? Colors.green : Colors.red)
                            : AppThemeV3.border,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: _phoneTouched
                            ? (_isPhoneValid ? Colors.green : Colors.red)
                            : AppThemeV3.border,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: _phoneTouched
                            ? (_isPhoneValid ? Colors.green : Colors.red)
                            : AppThemeV3.accent,
                      ),
                    ),
                  ),
                  onChanged: (value) {
                    // Format phone number as user types
                    final formatted = _formatPhoneNumber(value);
                    if (formatted != value) {
                      _phoneController.value = _phoneController.value.copyWith(
                        text: formatted,
                        selection: TextSelection.collapsed(offset: formatted.length),
                      );
                    }
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your phone number';
                    }
                    if (!_isValidPhone(value)) {
                      return 'Please enter a valid 10-digit phone number';
                    }
                    return null;
                  },
                ),
                
                // Phone validation message
                if (_phoneTouched && !_isPhoneValid) ...[
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Text(
                      'Please enter a valid 10-digit US phone number',
                      style: TextStyle(
                        color: Colors.red.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
                
                const SizedBox(height: 16),
                
                // Password field
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible,
                  decoration: InputDecoration(
                    hintText: 'Password (8+ with letters, numbers, symbols)',
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_passwordController.text.isNotEmpty)
                          Icon(
                            _meetsPasswordComplexity ? Icons.check_circle : Icons.error,
                            color: _meetsPasswordComplexity ? Colors.green : Colors.red,
                            size: 20,
                          ),
                        IconButton(
                          icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off),
                          onPressed: () {
                            setState(() {
                              _isPasswordVisible = !_isPasswordVisible;
                            });
                          },
                        ),
                      ],
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: _passwordController.text.isNotEmpty
                            ? (_meetsPasswordComplexity ? Colors.green : Colors.red)
                            : AppThemeV3.border,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: _passwordController.text.isNotEmpty
                            ? (_meetsPasswordComplexity ? Colors.green : Colors.red)
                            : AppThemeV3.border,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: _passwordController.text.isNotEmpty
                            ? (_meetsPasswordComplexity ? Colors.green : Colors.red)
                            : AppThemeV3.accent,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a password';
                    }
                    if (value.length < 8) {
                      return 'Password must be at least 8 characters';
                    }
                    final hasLetter = RegExp(r'[A-Za-z]').hasMatch(value);
                    final hasNumber = RegExp(r'[0-9]').hasMatch(value);
                    final hasSymbol = RegExp(r'[^A-Za-z0-9]').hasMatch(value);
                    if (!(hasLetter && hasNumber && hasSymbol)) {
                      return 'Use letters, numbers, and symbols';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 16),
                
                // Confirm Password field
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: !_isConfirmPasswordVisible,
                  decoration: InputDecoration(
                    hintText: 'Confirm Password',
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_confirmPasswordController.text.isNotEmpty)
                          Icon(
                            _confirmPasswordController.text == _passwordController.text && _confirmPasswordController.text.isNotEmpty 
                                ? Icons.check_circle : Icons.error,
                            color: _confirmPasswordController.text == _passwordController.text && _confirmPasswordController.text.isNotEmpty 
                                ? Colors.green : Colors.red,
                            size: 20,
                          ),
                        IconButton(
                          icon: Icon(_isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off),
                          onPressed: () {
                            setState(() {
                              _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                            });
                          },
                        ),
                      ],
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: _confirmPasswordController.text.isNotEmpty
                            ? (_confirmPasswordController.text == _passwordController.text ? Colors.green : Colors.red)
                            : AppThemeV3.border,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: _confirmPasswordController.text.isNotEmpty
                            ? (_confirmPasswordController.text == _passwordController.text ? Colors.green : Colors.red)
                            : AppThemeV3.border,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: _confirmPasswordController.text.isNotEmpty
                            ? (_confirmPasswordController.text == _passwordController.text ? Colors.green : Colors.red)
                            : AppThemeV3.accent,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your password';
                    }
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 32),
                
                // Create Account Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (_isLoading || !_areFieldsValid()) ? null : _signUpWithEmail,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _areFieldsValid() ? Colors.black : Colors.grey,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: _areFieldsValid() ? Colors.black : Colors.grey,
                          width: 2,
                        ),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            'Create Account',
                            style: AppThemeV3.textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
                
                // Validation status message
                if (!_areFieldsValid() && (_emailTouched || _phoneTouched || _nameController.text.isNotEmpty)) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppThemeV3.borderLight),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.black, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Complete all fields with valid information to create account',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                const SizedBox(height: 24),
                
                // "Or sign up with" text
                Text(
                  'Or sign up with',
                  style: AppThemeV3.textTheme.bodyMedium?.copyWith(
                    color: AppThemeV3.textSecondary,
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Google Sign Up Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      debugPrint('[SignupPage] ========== BUTTON TAPPED ==========');
                      debugPrint('[SignupPage] Google button pressed! _isLoading=$_isLoading');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Button tapped! _isLoading=$_isLoading'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                      if (!_isLoading) {
                        _signUpWithGoogle();
                      } else {
                        debugPrint('[SignupPage] Button disabled because _isLoading=true');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppThemeV3.textPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.g_mobiledata, size: 24, color: Colors.white),
                    label: Text(
                      _isLoading ? 'Loading...' : 'Continue with Google',
                      style: AppThemeV3.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Apple Sign Up Button (iOS only)
                if (!kIsWeb && Platform.isIOS)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : _signUpWithApple,
                      style: OutlinedButton.styleFrom(
                        backgroundColor: AppThemeV3.textPrimary,
                        foregroundColor: Colors.white,
                        side: BorderSide.none,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.apple, size: 24),
                      label: Text(
                        'Continue with Apple',
                        style: AppThemeV3.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                
                if (!kIsWeb && Platform.isIOS) const SizedBox(height: 16),
                
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _signUpWithEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      debugPrint('Starting Firebase sign-up process...');
      debugPrint('Email: ${_emailController.text.trim()}');
      
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      debugPrint('User created successfully: ${credential.user?.uid}');

      // Update user profile
      await credential.user?.updateDisplayName(_nameController.text.trim());
      debugPrint('Display name updated');

      // Format phone number to E.164 format for Firebase
      final digits = _phoneController.text.replaceAll(RegExp(r'\D'), '');
      final phoneNumber = '+1$digits'; // Assuming US phone numbers

      // Mark explicit approval since user intentionally created an account
      if (mounted) {
        ExplicitSetupApproval.approve(context);
      }

      // Update progress to phone verification step and save phone number
      await ProgressManager.saveCurrentStep(OnboardingStep.phoneVerification);
      await ProgressManager.saveSignupProgress(
        email: _emailController.text.trim(),
        phone: phoneNumber,
        name: _nameController.text.trim(),
        authMethod: 'email',
      );

      // Start phone verification
      debugPrint('Starting phone verification for: $phoneNumber');
      try {
        await PhoneVerificationService.instance.startPhoneVerification(phoneNumber);
        
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => PhoneVerificationPageV3(
                phoneNumber: phoneNumber,
              ),
            ),
          );
        }
      } catch (e) {
        debugPrint('Phone verification error: $e');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to send verification SMS: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 8),
            ),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase Auth Exception: ${e.code} - ${e.message}');
      String message = 'An error occurred';
      if (e.code == 'weak-password') {
        message = 'The password provided is too weak.';
      } else if (e.code == 'email-already-in-use') {
        message = 'The account already exists for that email.';
      } else if (e.code == 'invalid-email') {
        message = 'The email address is not valid.';
      } else if (e.code == 'operation-not-allowed') {
        message = 'Email/password accounts are not enabled in Firebase Console.';
      } else if (e.code == 'network-request-failed') {
        message = 'Network error. Please check your internet connection.';
      } else {
        message = 'Firebase Error: ${e.code} - ${e.message}';
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 8),
          ),
        );
      }
    } catch (e) {
      debugPrint('General Exception: $e');
      debugPrint('Exception type: ${e.runtimeType}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unexpected error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 8),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signUpWithGoogle() async {
    debugPrint('[SignupPage] _signUpWithGoogle called');
    setState(() => _isLoading = true);

    try {
      // Use AuthService instead of creating local GoogleSignIn
      final userCredential = await AuthService.instance.signInWithGoogle();
      
      if (userCredential == null) {
        debugPrint('[SignupPage] User cancelled sign-in');
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }

      debugPrint('[SignupPage] Firebase sign-in successful: ${userCredential.user?.uid}');

      // Check if this is a new user or existing user
      final isNewUser = userCredential.additionalUserInfo?.isNewUser ?? false;
      debugPrint('[SignupPage] Is new user: $isNewUser');

      if (mounted) {
        if (isNewUser) {
          // New user - collect phone number first
          debugPrint('[SignupPage] New user detected - collecting phone');
          await ProgressManager.saveCurrentStep(OnboardingStep.phoneVerification);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const PhoneCollectionPageV3()),
          );
        } else {
          // Existing user who came to signup page - redirect to home
          debugPrint('[SignupPage] Existing user detected - going to home');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomePageV3()),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('[SignupPage] Firebase Auth Exception in Google sign-in: ${e.code} - ${e.message}');
      debugPrint('[SignupPage] Full exception details: $e');
      if (mounted) {
        String errorMessage = 'Unable to sign in with Google: ${e.code} - ${e.message}';
        if (e.code == 'account-exists-with-different-credential') {
          errorMessage = 'An account already exists with this email using a different sign-in method';
        } else if (e.code == 'invalid-credential') {
          errorMessage = 'Google sign-in credentials are invalid: ${e.message}';
        } else if (e.code == 'operation-not-allowed') {
          errorMessage = 'Google sign-in is not enabled in Firebase';
        } else if (e.code == 'user-disabled') {
          errorMessage = 'This account has been disabled';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      debugPrint('[SignupPage] Unexpected error in Google sign-in: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error during Google sign-in: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signUpWithApple() async {
    setState(() => _isLoading = true);

    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: credential.identityToken,
        accessToken: credential.authorizationCode,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(oauthCredential);

      // Check if this is a new user or existing user
      final isNewUser = userCredential.additionalUserInfo?.isNewUser ?? false;
      debugPrint('Apple Sign-In - Is new user: $isNewUser'); // Debug

      if (mounted) {
        if (isNewUser) {
          // New user - collect phone number first
          debugPrint('New Apple user - collecting phone'); // Debug
          await ProgressManager.saveCurrentStep(OnboardingStep.phoneVerification);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const PhoneCollectionPageV3()),
          );
        } else {
          // Existing user who came to signup page - redirect to home
          debugPrint('Existing Apple user - going to home'); // Debug
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomePageV3()),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to sign up with Apple')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
