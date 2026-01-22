import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme_v3.dart';
import '../../services/connectivity_service_v3.dart';
import '../../services/auth/progress_manager.dart';
import 'signup_page_v3.dart';
import 'phone_collection_page_v3.dart';
import '../home_page_v3.dart';
import '../onboarding/choose_meal_plan_page_v3.dart';
import 'welcome_page_v3.dart';

class LoginPageV3 extends StatefulWidget {
  const LoginPageV3({super.key});

  @override
  State<LoginPageV3> createState() => _LoginPageV3State();
}

class _LoginPageV3State extends State<LoginPageV3> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleBackNavigation() {
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const WelcomePageV3()),
      );
    }
  }

  Widget _buildCurrentUserInfo() {
    final currentUser = FirebaseAuth.instance.currentUser;
    
    if (currentUser == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.account_circle, color: Colors.black, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Currently signed in as:',
                      style: AppThemeV3.textTheme.bodyMedium?.copyWith(
                        color: AppThemeV3.textSecondary,
                      ),
                    ),
                    Text(
                      currentUser.email ?? 'Unknown user',
                      style: AppThemeV3.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    // Mark setup as completed and go to home
                    try {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('setup_completed', true);
                      if (mounted) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => const HomePageV3()),
                        );
                      }
                    } catch (e) {
                      // Handle error
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.black, width: 2),
                    ),
                  ),
                  child: const Text(
                    'Continue as This User',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    // Sign out and clear all data
                    await FirebaseAuth.instance.signOut();
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.clear();
                    if (mounted) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const WelcomePageV3()),
                      );
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                    side: BorderSide(color: Colors.black, width: 2),
                  ),
                  child: const Text(
                    'Start Fresh',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeV3.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => _handleBackNavigation(),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          color: Colors.white,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  
                  // Clean tab header without any box outline
                  Container(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.black,
                              width: 2,
                            ),
                          ),
                          child: Text(
                            'Sign In',
                            style: AppThemeV3.textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const SignUpPageV3()),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                            child: Text(
                              'Sign Up',
                              style: AppThemeV3.textTheme.titleLarge?.copyWith(
                                color: AppThemeV3.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                
                  const SizedBox(height: 24),
                  
                  // Current user info and options
                  _buildCurrentUserInfo(),
                  
                  const SizedBox(height: 24),
                  
                  // Email field
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: 'Email',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _emailController.clear(),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Password field
                  TextFormField(
                    controller: _passwordController,
                    obscureText: !_isPasswordVisible,
                    decoration: InputDecoration(
                      hintText: 'Password',
                      suffixIcon: IconButton(
                        icon: Icon(_isPasswordVisible ? Icons.visibility_off : Icons.visibility),
                        onPressed: () {
                          setState(() => _isPasswordVisible = !_isPasswordVisible);
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Sign In Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _signInWithEmail,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.black, width: 2),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'Sign In',
                              style: AppThemeV3.textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Divider
                  Row(
                    children: [
                      Expanded(child: Divider(color: Colors.grey[300])),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'OR',
                          style: AppThemeV3.textTheme.bodyMedium?.copyWith(
                            color: AppThemeV3.textSecondary,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: Colors.grey[300])),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Google Sign In Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        debugPrint('[LoginPage] Google button pressed! _isLoading=$_isLoading');
                        if (!_isLoading) {
                          _signInWithGoogle();
                        } else {
                          debugPrint('[LoginPage] Button disabled because _isLoading=true');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: Colors.black, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.g_mobiledata, size: 24, color: Colors.black),
                      label: Text(
                        _isLoading ? 'Loading...' : 'Continue with Google',
                        style: AppThemeV3.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Apple Sign In Button (iOS only)
                  if (!kIsWeb && Platform.isIOS)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isLoading ? null : _signInWithApple,
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          side: BorderSide(color: Colors.black, width: 2),
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
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  
                  if (!kIsWeb && Platform.isIOS) const SizedBox(height: 16),
                  
                  const SizedBox(height: 8),
                  
                  // Forgot password
                  TextButton(
                    onPressed: _forgotPassword,
                    child: Text(
                      'Forgot Password?',
                      style: AppThemeV3.textTheme.bodyMedium?.copyWith(
                        color: Colors.black,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _signInWithEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    // Check internet connectivity first
    final hasConnection = await ConnectivityServiceV3.hasInternetConnection();
    if (!hasConnection) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No internet connection. Please check your network and try again.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
  debugPrint('Attempting to sign in with email: ${_emailController.text.trim()}');
      
      // Add timeout to catch network issues faster
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Connection timeout. Please check your internet connection and try again.');
        },
      );

  debugPrint('Sign in successful. User: ${credential.user?.email}');
  debugPrint('Email verified: ${credential.user?.emailVerified}');

      if (credential.user != null && credential.user!.emailVerified) {
        if (!mounted) return;
        debugPrint('Navigating to home page');
        // Navigate to home page
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePageV3()),
        );
      } else {
        if (!mounted) return;
        debugPrint('Email not verified, showing verification dialog');
        showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Email Not Verified'),
            content: const Text('Please check your email and click the verification link before signing in.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('OK'),
              ),
              TextButton(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    await credential.user!.sendEmailVerification();
                    Navigator.pop(dialogContext);
                    if (!mounted) return;
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Verification email sent')),
                    );
                  } catch (e) {
                    Navigator.pop(dialogContext);
                    if (!mounted) return;
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Failed to send verification email. Please check your connection.')),
                    );
                  }
                },
                child: const Text('Resend Verification'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint('Sign in error: $e');
      if (!mounted) return;
      
      String errorMessage = 'Failed to sign in';
      
      if (e.toString().contains('network-request-failed') || 
          e.toString().contains('timeout') ||
          e.toString().contains('Failed host lookup') ||
          e.toString().contains('Connection timeout')) {
        errorMessage = 'Network error. Please check your internet connection and try again.';
      } else if (e.toString().contains('user-not-found')) {
        errorMessage = 'No account found with this email';
      } else if (e.toString().contains('wrong-password') || e.toString().contains('invalid-credential')) {
        errorMessage = 'Incorrect email or password';
      } else if (e.toString().contains('invalid-email')) {
        errorMessage = 'Invalid email address';
      } else if (e.toString().contains('too-many-requests')) {
        errorMessage = 'Too many failed attempts. Please try again later.';
      } else if (e.toString().contains('user-disabled')) {
        errorMessage = 'This account has been disabled. Please contact support.';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          duration: const Duration(seconds: 4),
          action: errorMessage.contains('Network error') 
            ? SnackBarAction(
                label: 'Retry',
                onPressed: () => _signInWithEmail(),
              )
            : null,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    debugPrint('[LoginPage] _signInWithGoogle called');
    setState(() => _isLoading = true);
    
    try {
      debugPrint('[LoginPage] Initializing GoogleSignIn');
      final googleSignIn = GoogleSignIn(
        scopes: [
          'email',
          'profile',
        ],
      );
      debugPrint('[LoginPage] Calling googleSignIn.signIn()');
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      
      debugPrint('[LoginPage] GoogleSignIn result: ${googleUser?.email ?? "null"}');
      
      // User cancelled the sign-in
      if (googleUser == null) {
        debugPrint('[LoginPage] User cancelled sign-in');
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }

      debugPrint('[LoginPage] Getting authentication details');
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      debugPrint('[LoginPage] Creating Firebase credential');
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      debugPrint('[LoginPage] Signing in with Firebase');
      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Firebase authentication timeout. Please check your internet connection.');
        },
      );

      debugPrint('[LoginPage] Firebase sign-in successful: ${userCredential.user?.uid}');
      
      if (!mounted) return;
      
      // Check if this is a new user or existing user
      final isNewUser = userCredential.additionalUserInfo?.isNewUser ?? false;
      debugPrint('[LoginPage] Google Sign-In - Is new user: $isNewUser');
      
      if (isNewUser) {
        // New user accidentally used login page - collect phone first
        debugPrint('[LoginPage] New user on login page - collecting phone');
        await ProgressManager.saveCurrentStep(OnboardingStep.phoneVerification);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const PhoneCollectionPageV3()),
        );
      } else {
        // Existing user - go to home
        debugPrint('[LoginPage] Existing user - going to home');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePageV3()),
        );
      }
    } catch (e) {
      debugPrint('[LoginPage] Error caught: ${e.toString()}');
      debugPrint('[LoginPage] Error type: ${e.runtimeType}');
      
      // Check for user cancellation first - be completely silent
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('sign_in_canceled') || 
          errorString.contains('popup_closed') ||
          errorString.contains('user_cancelled') ||
          errorString.contains('cancel') ||
          e.runtimeType.toString().contains('PlatformException')) {
        debugPrint('[LoginPage] Google sign-in cancelled by user');
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return; // Silent return for cancellation
      }
      
      debugPrint('Google sign in error: $e');
      if (!mounted) return;
      
      // User-friendly error messages
      String errorMessage = 'Unable to sign in with Google';
      
      if (e.toString().contains('network-request-failed') || 
          e.toString().contains('timeout') ||
          e.toString().contains('Failed host lookup')) {
        errorMessage = 'Network error. Please check your internet connection';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signInWithApple() async {
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

      if (!mounted) return;
      
      // Check if this is a new user or existing user
      final isNewUser = userCredential.additionalUserInfo?.isNewUser ?? false;
      debugPrint('Apple Sign-In - Is new user: $isNewUser'); // Debug
      
      if (isNewUser) {
        // New user accidentally used login page - collect phone first
        debugPrint('New Apple user on login page - collecting phone'); // Debug
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const PhoneCollectionPageV3()),
        );
      } else {
        // Existing user - go to home
        debugPrint('Existing Apple user - going to home'); // Debug
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePageV3()),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to sign in with Apple')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _forgotPassword() async {
    if (_emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email first')),
      );
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset email sent')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send password reset email')),
      );
    }
  }
}
