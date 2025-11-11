import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../../theme/app_theme_v3.dart';

class ChangePasswordPageV3 extends StatefulWidget {
  const ChangePasswordPageV3({super.key});

  @override
  State<ChangePasswordPageV3> createState() => _ChangePasswordPageV3State();
}

class _ChangePasswordPageV3State extends State<ChangePasswordPageV3> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isCurrentPasswordVisible = false;
  bool _isNewPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not found');
      }

      debugPrint('[ChangePassword] Starting password change for ${user.email}');

      // Re-authenticate user with current password with timeout
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: _currentPasswordController.text,
      );

      debugPrint('[ChangePassword] Re-authenticating user...');
      
      // Add timeout to prevent hanging
      await user.reauthenticateWithCredential(credential).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Re-authentication timed out. Please check your internet connection and try again.');
        },
      );

      debugPrint('[ChangePassword] Re-authentication successful');

      // Update password with timeout
      debugPrint('[ChangePassword] Updating password...');
      await user.updatePassword(_newPasswordController.text).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Password update timed out. Please try again.');
        },
      );

      debugPrint('[ChangePassword] Password changed successfully');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password changed successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('[ChangePassword] FirebaseAuthException: ${e.code} - ${e.message}');
      String message = 'Failed to change password';
      
      switch (e.code) {
        case 'wrong-password':
        case 'invalid-credential':
          message = 'Current password is incorrect';
          break;
        case 'weak-password':
          message = 'New password is too weak';
          break;
        case 'requires-recent-login':
          message = 'Please sign out and sign in again before changing password';
          break;
        case 'network-request-failed':
          message = 'Network error. Please check your internet connection.';
          break;
        default:
          message = e.message ?? 'Failed to change password';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } on TimeoutException catch (e) {
      debugPrint('[ChangePassword] Timeout: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request timed out. Please check your internet connection and try again.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      debugPrint('[ChangePassword] Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      debugPrint('[ChangePassword] Resetting loading state');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeV3.background,
      appBar: AppBar(
        backgroundColor: AppThemeV3.background,
        elevation: 0,
        title: Text(
          'Change Password',
          style: AppThemeV3.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Security Notice
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppThemeV3.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppThemeV3.accent.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.security,
                      color: AppThemeV3.accent,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
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

              const SizedBox(height: 32),

              // Current Password
              _buildPasswordField(
                controller: _currentPasswordController,
                label: 'Current Password',
                isVisible: _isCurrentPasswordVisible,
                onVisibilityToggle: () {
                  setState(() => _isCurrentPasswordVisible = !_isCurrentPasswordVisible);
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your current password';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 20),

              // New Password
              _buildPasswordField(
                controller: _newPasswordController,
                label: 'New Password',
                isVisible: _isNewPasswordVisible,
                onVisibilityToggle: () {
                  setState(() => _isNewPasswordVisible = !_isNewPasswordVisible);
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a new password';
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
                  if (value == _currentPasswordController.text) {
                    return 'New password must be different from current password';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 20),

              // Confirm Password
              _buildPasswordField(
                controller: _confirmPasswordController,
                label: 'Confirm New Password',
                isVisible: _isConfirmPasswordVisible,
                onVisibilityToggle: () {
                  setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible);
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please confirm your new password';
                  }
                  if (value != _newPasswordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 40),

              // Change Password Button
              ElevatedButton(
                onPressed: _isLoading ? null : _changePassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppThemeV3.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
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
                        'Change Password',
                        style: AppThemeV3.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),

              const SizedBox(height: 20),

              // Password Requirements
              _buildPasswordRequirements(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool isVisible,
    required VoidCallback onVisibilityToggle,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppThemeV3.surface,
            AppThemeV3.surface.withValues(alpha: 0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppThemeV3.accent.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: !isVisible,
        validator: validator,
        style: AppThemeV3.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(Icons.lock_outline, color: AppThemeV3.accent),
          suffixIcon: IconButton(
            onPressed: onVisibilityToggle,
            icon: Icon(
              isVisible ? Icons.visibility_off : Icons.visibility,
              color: AppThemeV3.accent,
            ),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(20),
          labelStyle: AppThemeV3.textTheme.bodyMedium?.copyWith(
            color: AppThemeV3.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordRequirements() {
  return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
    color: AppThemeV3.surface.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppThemeV3.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Password Requirements:',
            style: AppThemeV3.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          _buildRequirement('At least 8 characters long'),
          _buildRequirement('Contains letters, numbers, and symbols'),
          _buildRequirement('Different from your current password'),
          _buildRequirement('Avoid common passwords'),
        ],
      ),
    );
  }

  Widget _buildRequirement(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 16,
            color: AppThemeV3.textSecondary,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: AppThemeV3.textTheme.bodySmall?.copyWith(
              color: AppThemeV3.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
