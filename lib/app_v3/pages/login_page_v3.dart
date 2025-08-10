import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../theme/app_theme_v3.dart';
import '../services/connectivity_service_v3.dart';
import '../services/offline_auth_service_v3.dart';
import 'signup_page_v3.dart';
import 'home_page_v3.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeV3.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppThemeV3.accent),
          onPressed: () => _handleBackNavigation(),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppThemeV3.background,
              AppThemeV3.background.withValues(alpha: 0.95),
            ],
          ),
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
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppThemeV3.accent,
                                AppThemeV3.accent.withValues(alpha: 0.8),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: AppThemeV3.boldShadow,
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
                
                  const SizedBox(height: 40),
                  
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
                        backgroundColor: AppThemeV3.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
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
                                fontWeight: FontWeight.w600,
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
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : _signInWithGoogle,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppThemeV3.textPrimary,
                        side: BorderSide(color: AppThemeV3.accent.withValues(alpha: 0.3)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.g_mobiledata, size: 24),
                      label: Text(
                        'Continue with Google',
                        style: AppThemeV3.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Apple Sign In Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : _signInWithApple,
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
                  
                  const SizedBox(height: 16),
                  
                  // Demo Account Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : _signInWithDemoAccount,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppThemeV3.accent,
                        side: BorderSide(color: AppThemeV3.accent.withValues(alpha: 0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.person_outline, size: 24),
                      label: Text(
                        'Try Demo Account',
                        style: AppThemeV3.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppThemeV3.accent,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Forgot password
                  TextButton(
                    onPressed: _forgotPassword,
                    child: Text(
                      'Forgot Password?',
                      style: AppThemeV3.textTheme.bodyMedium?.copyWith(
                        color: AppThemeV3.accent,
                        fontWeight: FontWeight.w500,
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
      if (mounted) {
        // Try offline authentication first
        final offlineSuccess = await OfflineAuthServiceV3.signInOffline(
          _emailController.text.trim(),
          _passwordController.text,
        );
        
        if (offlineSuccess) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Signed in offline! Some features may be limited.'),
              backgroundColor: Colors.orange,
            ),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomePageV3()),
          );
          return;
        } else {
          setState(() => _isLoading = false);
          _showNetworkErrorDialog();
          return;
        }
      }
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
        if (mounted) {
          debugPrint('Navigating to home page');
          // Navigate to home page
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomePageV3()),
          );
        }
      } else {
        if (mounted) {
          debugPrint('Email not verified, showing verification dialog');
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Email Not Verified'),
              content: const Text('Please check your email and click the verification link before signing in.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
                TextButton(
                  onPressed: () async {
                    try {
                      await credential.user!.sendEmailVerification();
                      if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Verification email sent')),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Failed to send verification email. Please check your connection.')),
                        );
                      }
                    }
                  },
                  child: const Text('Resend Verification'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Sign in error: $e');
      if (mounted) {
        // Try offline authentication as fallback
        final offlineSuccess = await OfflineAuthServiceV3.signInOffline(
          _emailController.text.trim(),
          _passwordController.text,
        );
        
        if (offlineSuccess) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Signed in offline! Some features may be limited.'),
              backgroundColor: Colors.orange,
            ),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomePageV3()),
          );
          return;
        }
        
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
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Google sign in timeout. Please check your internet connection.');
        },
      );

      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Firebase authentication timeout. Please check your internet connection.');
        },
      );

      if (mounted) {
        // Navigate to home page
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePageV3()),
        );
      }
    } catch (e) {
  debugPrint('Google sign in error: $e');
      if (mounted) {
        String errorMessage = 'Failed to sign in with Google';
        
        if (e.toString().contains('network-request-failed') || 
            e.toString().contains('timeout') ||
            e.toString().contains('Failed host lookup')) {
          errorMessage = 'Network error. Please check your internet connection and try again.';
        } else if (e.toString().contains('sign_in_canceled')) {
          errorMessage = 'Sign in was cancelled';
        } else if (e.toString().contains('sign_in_failed')) {
          errorMessage = 'Google sign in failed. Please try again.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            duration: const Duration(seconds: 4),
            action: errorMessage.contains('Network error') 
              ? SnackBarAction(
                  label: 'Retry',
                  onPressed: () => _signInWithGoogle(),
                )
              : null,
          ),
        );
      }
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

      await FirebaseAuth.instance.signInWithCredential(oauthCredential);

      if (mounted) {
        // Navigate to home page
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePageV3()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to sign in with Apple')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signInWithDemoAccount() async {
    setState(() => _isLoading = true);

    try {
      // Try to sign in with a demo account
      // If it doesn't exist, create it
      const demoEmail = 'demo@freshpunk.com';
      const demoPassword = 'demo123456';

      try {
        final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: demoEmail,
          password: demoPassword,
        );

        if (mounted) {
          if (credential.user != null) {
            // Navigate to home page
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const HomePageV3()),
            );
          }
        }
      } catch (signInError) {
        // If sign in fails, try to create the demo account
        if (signInError.toString().contains('user-not-found')) {
          try {
            final newCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
              email: demoEmail,
              password: demoPassword,
            );

            // Mark the email as verified for demo purposes
            await newCredential.user?.sendEmailVerification();
            
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Demo account created! You can now explore the app.'),
                  duration: Duration(seconds: 3),
                ),
              );
              
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const HomePageV3()),
              );
            }
          } catch (createError) {
            throw signInError; // Re-throw the original error
          }
        } else {
          throw signInError;
        }
      }
    } catch (e) {
  debugPrint('Demo account error: $e');
      if (mounted) {
        String errorMessage = 'Failed to sign in with demo account';
        
        if (e.toString().contains('network-request-failed') || 
            e.toString().contains('timeout') ||
            e.toString().contains('Failed host lookup')) {
          errorMessage = 'Network error. The demo account requires an internet connection.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
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
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset email sent')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send password reset email')),
        );
      }
    }
  }

  void _showNetworkErrorDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connection Problem'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ConnectivityServiceV3.getNetworkErrorMessage()),
            const SizedBox(height: 16),
            const Text(
              'Offline Demo Accounts:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(OfflineAuthServiceV3.getOfflineAccountsInfo()),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _signInWithEmail();
            },
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }
}
