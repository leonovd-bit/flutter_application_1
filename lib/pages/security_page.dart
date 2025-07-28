import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

class SecurityPage extends StatefulWidget {
  const SecurityPage({super.key});

  @override
  State<SecurityPage> createState() => _SecurityPageState();
}

class _SecurityPageState extends State<SecurityPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _biometricEnabled = false;
  bool _pushNotificationsEnabled = true;
  bool _emailNotificationsEnabled = true;
  bool _twoFactorEnabled = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _biometricEnabled = prefs.getBool('biometric_enabled') ?? false;
      _pushNotificationsEnabled = prefs.getBool('push_notifications') ?? true;
      _emailNotificationsEnabled = prefs.getBool('email_notifications') ?? true;
      _twoFactorEnabled = prefs.getBool('two_factor_enabled') ?? false;
      _isLoading = false;
    });
  }

  Future<void> _updateBiometric(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometric_enabled', enabled);
    setState(() {
      _biometricEnabled = enabled;
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enabled 
                ? 'Biometric authentication enabled' 
                : 'Biometric authentication disabled'
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _updatePushNotifications(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('push_notifications', enabled);
    setState(() {
      _pushNotificationsEnabled = enabled;
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enabled 
                ? 'Push notifications enabled' 
                : 'Push notifications disabled'
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _updateEmailNotifications(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('email_notifications', enabled);
    setState(() {
      _emailNotificationsEnabled = enabled;
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enabled 
                ? 'Email notifications enabled' 
                : 'Email notifications disabled'
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _updateTwoFactor(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('two_factor_enabled', enabled);
    setState(() {
      _twoFactorEnabled = enabled;
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enabled 
                ? 'Two-factor authentication enabled' 
                : 'Two-factor authentication disabled'
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _changePassword() async {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Current Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: newPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'New Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirmPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm New Password',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (newPasswordController.text != confirmPasswordController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('New passwords do not match'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              Navigator.of(context).pop(true);
            },
            child: const Text('Change Password'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        final user = _auth.currentUser;
        if (user != null) {
          // Re-authenticate user
          final credential = EmailAuthProvider.credential(
            email: user.email!,
            password: currentPasswordController.text,
          );
          await user.reauthenticateWithCredential(credential);
          
          // Update password
          await user.updatePassword(newPasswordController.text);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Password changed successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to change password: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }

    currentPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
  }

  Future<void> _resetPassword() async {
    final user = _auth.currentUser;
    if (user?.email != null) {
      try {
        await _auth.sendPasswordResetEmail(email: user!.email!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Password reset email sent. Check your inbox.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 4),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to send reset email: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _showDeleteAccountDialog() async {
    final passwordController = TextEditingController();
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This action cannot be undone. All your data will be permanently deleted.',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text('Please enter your password to confirm:'),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete Account'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final user = _auth.currentUser;
        if (user != null) {
          // Re-authenticate user
          final credential = EmailAuthProvider.credential(
            email: user.email!,
            password: passwordController.text,
          );
          await user.reauthenticateWithCredential(credential);
          
          // Delete user account
          await user.delete();
          
          // Navigate to login screen or app start
          if (mounted) {
            Navigator.of(context).pushNamedAndRemoveUntil(
              '/login',
              (route) => false,
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete account: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }

    passwordController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'SECURITY & PRIVACY',
          style: AppTheme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
            color: AppTheme.textPrimary,
          ),
        ),
        centerTitle: false,
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
        child: _isLoading
            ? Center(
                child: AppLoadingIndicator(),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Authentication Section
                    Text(
                      'AUTHENTICATION',
                      style: AppTheme.textTheme.displayMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                  
                  Card(
                    child: Column(
                      children: [
                        SwitchListTile(
                          title: const Text('Biometric Authentication'),
                          subtitle: const Text('Use Face ID or Fingerprint to unlock'),
                          value: _biometricEnabled,
                          onChanged: _updateBiometric,
                          secondary: const Icon(Icons.fingerprint),
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          title: const Text('Two-Factor Authentication'),
                          subtitle: const Text('Add an extra layer of security'),
                          value: _twoFactorEnabled,
                          onChanged: _updateTwoFactor,
                          secondary: const Icon(Icons.security),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Password Section
                  const Text(
                    'Password',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          title: const Text('Change Password'),
                          subtitle: const Text('Update your account password'),
                          leading: const Icon(Icons.lock_outline),
                          trailing: const Icon(Icons.arrow_forward_ios),
                          onTap: _changePassword,
                        ),
                        const Divider(height: 1),
                        ListTile(
                          title: const Text('Reset Password'),
                          subtitle: const Text('Send reset email to your inbox'),
                          leading: const Icon(Icons.email_outlined),
                          trailing: const Icon(Icons.arrow_forward_ios),
                          onTap: _resetPassword,
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Notifications Section
                  const Text(
                    'Notifications',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  Card(
                    child: Column(
                      children: [
                        SwitchListTile(
                          title: const Text('Push Notifications'),
                          subtitle: const Text('Receive notifications on your device'),
                          value: _pushNotificationsEnabled,
                          onChanged: _updatePushNotifications,
                          secondary: const Icon(Icons.notifications),
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          title: const Text('Email Notifications'),
                          subtitle: const Text('Receive notifications via email'),
                          value: _emailNotificationsEnabled,
                          onChanged: _updateEmailNotifications,
                          secondary: const Icon(Icons.mail_outline),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Privacy Section
                  const Text(
                    'Privacy',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          title: const Text('Privacy Policy'),
                          subtitle: const Text('View our privacy policy'),
                          leading: const Icon(Icons.privacy_tip_outlined),
                          trailing: const Icon(Icons.arrow_forward_ios),
                          onTap: () {
                            // Navigate to privacy policy page
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Privacy Policy page would open here'),
                              ),
                            );
                          },
                        ),
                        const Divider(height: 1),
                        ListTile(
                          title: const Text('Data Usage'),
                          subtitle: const Text('Manage your data preferences'),
                          leading: const Icon(Icons.data_usage),
                          trailing: const Icon(Icons.arrow_forward_ios),
                          onTap: () {
                            // Navigate to data usage page
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Data Usage page would open here'),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Danger Zone
                  const Text(
                    'Danger Zone',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  Card(
                    child: ListTile(
                      title: const Text(
                        'Delete Account',
                        style: TextStyle(color: Colors.red),
                      ),
                      subtitle: const Text('Permanently delete your account and all data'),
                      leading: const Icon(Icons.delete_forever, color: Colors.red),
                      trailing: const Icon(Icons.arrow_forward_ios, color: Colors.red),
                      onTap: _showDeleteAccountDialog,
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Current User Info
                  Card(
                    color: Colors.grey[100],
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Account Information',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (_auth.currentUser?.email != null) ...[
                            Row(
                              children: [
                                const Icon(Icons.email, size: 16),
                                const SizedBox(width: 8),
                                Text(_auth.currentUser!.email!),
                              ],
                            ),
                            const SizedBox(height: 4),
                          ],
                          Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                'Member since ${_formatDate(_auth.currentUser?.metadata.creationTime)}',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown';
    return '${date.month}/${date.day}/${date.year}';
  }
}
