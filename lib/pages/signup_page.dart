import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'email_verification_page.dart';
import '../models/user_profile.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';
import 'welcome_page.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _isLoading = false;
  String? _currentError;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Check if passwords match
    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() {
        _currentError = 'Passwords do not match';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _currentError = null;
    });

    try {
      // Create user account
      final UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // Create user profile
      final userProfile = UserProfile(
        uid: userCredential.user!.uid,
        email: _emailController.text.trim(),
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        subscriptionPlan: '1-meal', // Default plan
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Save user profile to Firestore
      await UserService.createUserProfile(userProfile);

      // Send email verification
      await userCredential.user!.sendEmailVerification();

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => EmailVerificationPage(
              email: _emailController.text.trim(),
            ),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'An error occurred during sign up';
      
      switch (e.code) {
        case 'weak-password':
          errorMessage = 'The password provided is too weak';
          break;
        case 'email-already-in-use':
          errorMessage = 'An account already exists for this email';
          break;
        case 'invalid-email':
          errorMessage = 'The email address is not valid';
          break;
        case 'operation-not-allowed':
          errorMessage = 'Email/password accounts are not enabled';
          break;
        default:
          errorMessage = e.message ?? 'An error occurred during sign up';
      }

      if (mounted) {
        setState(() {
          _currentError = errorMessage;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentError = 'An unexpected error occurred: ${e.toString()}';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'SIGN UP',
          style: AppTheme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const WelcomePage()),
            );
          },
        ),
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  
                  // Logo section
                  Container(
                    padding: const EdgeInsets.all(24),
                    margin: const EdgeInsets.only(bottom: 32),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.restaurant,
                          size: 32,
                          color: AppTheme.accent,
                        ),
                        const SizedBox(width: 16),
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppTheme.accent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.lunch_dining,
                            size: 20,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Icon(
                          Icons.local_dining,
                          size: 32,
                          color: AppTheme.accent,
                        ),
                      ],
                    ),
                  ),

                  // Welcome text
                  Text(
                    'JOIN FRESHPUNK',
                    style: AppTheme.textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.0,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'Create your account to get started',
                    style: AppTheme.textTheme.bodyLarge?.copyWith(
                      color: AppTheme.textPrimary.withValues(alpha: 0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 32),

                  // Error message
                  if (_currentError != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: AppTheme.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.error),
                      ),
                      child: Text(
                        _currentError!,
                        style: AppTheme.textTheme.bodyMedium?.copyWith(
                          color: AppTheme.error,
                        ),
                      ),
                    ),

                  // Name fields
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          label: 'FIRST NAME',
                          hint: 'First name',
                          controller: _firstNameController,
                          prefixIcon: Icons.person_outline,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your first name';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: AppTextField(
                          label: 'LAST NAME',
                          hint: 'Last name',
                          controller: _lastNameController,
                          prefixIcon: Icons.person_outline,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your last name';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),

                  // Email field
                  AppTextField(
                    label: 'EMAIL',
                    hint: 'Enter your email address',
                    controller: _emailController,
                    isEmail: true,
                    prefixIcon: Icons.email_outlined,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!value.contains('@')) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),

                  // Phone field
                  AppTextField(
                    label: 'PHONE',
                    hint: 'Enter your phone number',
                    controller: _phoneController,
                    prefixIcon: Icons.phone_outlined,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your phone number';
                      }
                      return null;
                    },
                  ),

                  // Password field
                  AppTextField(
                    label: 'PASSWORD',
                    hint: 'Create a password',
                    controller: _passwordController,
                    isPassword: true,
                    prefixIcon: Icons.lock_outline,
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

                  // Confirm Password field
                  AppTextField(
                    label: 'CONFIRM PASSWORD',
                    hint: 'Confirm your password',
                    controller: _confirmPasswordController,
                    isPassword: true,
                    prefixIcon: Icons.lock_outline,
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

                  const SizedBox(height: 16),

                  // Sign Up Button
                  SizedBox(
                    width: double.infinity,
                    child: AppButton(
                      text: 'Create Account',
                      icon: Icons.person_add,
                      isLoading: _isLoading,
                      onPressed: _isLoading ? null : _signUp,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Login link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an account? ',
                        style: AppTheme.textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textPrimary.withValues(alpha: 0.7),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Text(
                          'SIGN IN',
                          style: AppTheme.textTheme.bodyMedium?.copyWith(
                            color: AppTheme.accent,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
