import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../theme/app_theme_v3.dart';
import '../services/progress_manager.dart';
import 'email_verification_page_v3.dart';
import 'login_page_v3.dart';
import 'delivery_schedule_page_v3.dart';
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

  @override
  void initState() {
    super.initState();
    // Add listeners for real-time validation
    _emailController.addListener(_validateEmail);
    _phoneController.addListener(_validatePhone);
    _nameController.addListener(() => setState(() {}));
    _passwordController.addListener(() => setState(() {}));
    _confirmPasswordController.addListener(() => setState(() {}));
    
    // Load any existing signup progress
    _loadExistingProgress();
  }

  Future<void> _loadExistingProgress() async {
    final signupData = await ProgressManager.getSignupProgress();
    if (signupData != null) {
      setState(() {
        _emailController.text = signupData['email'] ?? '';
        _phoneController.text = signupData['phone'] ?? '';
        _nameController.text = signupData['name'] ?? '';
      });
    }
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
           _passwordController.text.length >= 6 &&
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
                        color: AppThemeV3.accent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Sign Up',
                        style: AppThemeV3.textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 40),
                
                // Validation Requirements Panel
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppThemeV3.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppThemeV3.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: AppThemeV3.accent, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Account Requirements',
                            style: AppThemeV3.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppThemeV3.accent,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildRequirementItem('Valid email address', _isEmailValid),
                      _buildRequirementItem('Valid 10-digit phone number', _isPhoneValid),
                      _buildRequirementItem('Password (6+ characters)', _passwordController.text.length >= 6),
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
                    hintText: 'Password (minimum 6 characters)',
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_passwordController.text.isNotEmpty)
                          Icon(
                            _passwordController.text.length >= 6 ? Icons.check_circle : Icons.error,
                            color: _passwordController.text.length >= 6 ? Colors.green : Colors.red,
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
                            ? (_passwordController.text.length >= 6 ? Colors.green : Colors.red)
                            : AppThemeV3.border,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: _passwordController.text.isNotEmpty
                            ? (_passwordController.text.length >= 6 ? Colors.green : Colors.red)
                            : AppThemeV3.border,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: _passwordController.text.isNotEmpty
                            ? (_passwordController.text.length >= 6 ? Colors.green : Colors.red)
                            : AppThemeV3.accent,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
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
                      backgroundColor: _areFieldsValid() ? AppThemeV3.textPrimary : Colors.grey,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            'Create Account',
                            style: AppThemeV3.textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
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
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue, size: 16),
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
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _signUpWithGoogle,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: AppThemeV3.textPrimary,
                      foregroundColor: Colors.white,
                      side: BorderSide.none,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.g_mobiledata, size: 24),
                    label: Text(
                      'Continue with Google',
                      style: AppThemeV3.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Apple Sign Up Button
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
                
                const SizedBox(height: 24),
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
      // Save signup step progress
      await ProgressManager.saveCurrentStep(OnboardingStep.signup);
      await ProgressManager.saveSignupProgress(
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        name: _nameController.text.trim(),
        authMethod: 'email',
      );

      // Test Firebase connectivity first
      print('Testing Firebase connectivity...'); // Debug
      final currentUser = FirebaseAuth.instance.currentUser;
      print('Current Firebase user: $currentUser'); // Debug
      
      print('Starting Firebase sign-up process...'); // Debug
      print('Email: ${_emailController.text.trim()}'); // Debug
      
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      print('User created successfully: ${credential.user?.uid}'); // Debug

      // Update user profile
      await credential.user?.updateDisplayName(_nameController.text.trim());
      print('Display name updated'); // Debug

      // Send email verification
      await credential.user?.sendEmailVerification();
      print('Email verification sent'); // Debug

      // Update progress to email verification step
      await ProgressManager.saveCurrentStep(OnboardingStep.emailVerification);
      await ProgressManager.saveSignupProgress(
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        name: _nameController.text.trim(),
        authMethod: 'email',
        isEmailVerified: false,
      );

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => EmailVerificationPageV3(
              email: _emailController.text.trim(),
            ),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      print('Firebase Auth Exception: ${e.code} - ${e.message}'); // Debug
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
      print('General Exception: $e'); // Debug
      print('Exception type: ${e.runtimeType}'); // Debug
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
    setState(() => _isLoading = true);

    try {
      // Save signup step progress
      await ProgressManager.saveCurrentStep(OnboardingStep.signup);
      
      print('Starting Google sign-in process...'); // Debug
      
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      print('Google user: $googleUser'); // Debug
      
      if (googleUser == null) {
        print('Google sign-in was cancelled by user'); // Debug
        setState(() => _isLoading = false);
        return;
      }

      print('Getting Google authentication...'); // Debug
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      print('Access token: ${googleAuth.accessToken != null ? "Present" : "Missing"}'); // Debug
      print('ID token: ${googleAuth.idToken != null ? "Present" : "Missing"}'); // Debug
      
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      print('Signing in with Firebase...'); // Debug
      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      print('Firebase sign-in successful: ${userCredential.user?.uid}'); // Debug

      // Save progress with Google auth data
      await ProgressManager.saveSignupProgress(
        email: userCredential.user?.email,
        name: userCredential.user?.displayName,
        authMethod: 'google',
        isEmailVerified: userCredential.user?.emailVerified ?? false,
      );

      // Move to delivery schedule step
      await ProgressManager.saveCurrentStep(OnboardingStep.deliverySchedule);

      if (mounted) {
        // Navigate to delivery schedule
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const DeliverySchedulePageV3()),
        );
      }
    } on FirebaseAuthException catch (e) {
      print('Firebase Auth Exception in Google sign-in: ${e.code} - ${e.message}'); // Debug
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Firebase Error: ${e.code} - ${e.message}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 8),
          ),
        );
      }
    } catch (e) {
      print('General Exception in Google sign-in: $e'); // Debug
      print('Exception type: ${e.runtimeType}'); // Debug
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Google sign-in failed: $e'),
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

      await FirebaseAuth.instance.signInWithCredential(oauthCredential);

      if (mounted) {
        // Navigate to delivery schedule
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const DeliverySchedulePageV3()),
        );
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
