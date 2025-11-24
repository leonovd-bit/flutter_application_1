import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme_v3.dart';
import '../auth/welcome_page_v3.dart';
import '../delivery/address_page_v3.dart';
import 'profile_page_v3.dart';
import '../payment/payment_methods_page_v3.dart';
import '../subscription/manage_subscription_page_v3.dart';
import '../delivery/delivery_schedule_overview_page_v2.dart';
import '../meals/meal_schedule_overview_page_v2.dart';
import '../info/about_page_v3.dart';
import '../info/terms_of_service_page_v3.dart';
import '../info/privacy_policy_page_v3.dart';
// Removed Circle of Health from Settings
import '../../services/orders/order_functions_service.dart';
import '../../services/auth/account_deletion_service.dart';
import '../auth/change_password_page_v3.dart';
import '../info/help_support_page_v3.dart';
import '../delivery/delivery_schedule_page_v5.dart';
import '../meals/meal_schedule_page_v3_fixed.dart';
import '../../services/notifications/fcm_service_v3.dart';
import '../../services/preferences/notification_preferences_service.dart';

class SettingsPageV3 extends StatefulWidget {
  const SettingsPageV3({super.key});

  @override
  State<SettingsPageV3> createState() => _SettingsPageV3State();
}

class _SettingsPageV3State extends State<SettingsPageV3> {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final _auth = FirebaseAuth.instance;
  String? _accountName;
  String? _accountEmail;
  // Summary extras
  String? _planName;
  double? _planMonthlyAmount;
  DateTime? _nextBillingDate;
  
  // UI state
  bool _isLoading = false;
  bool _biometricEnabled = false;
  bool _pushNotifications = true;
  bool _emailNotifications = true;
  bool _orderUpdates = true;

  @override
  void initState() {
    super.initState();
    _loadNotificationPreferences();
  }

  Future<void> _loadNotificationPreferences() async {
    try {
      final prefs = await NotificationPreferencesService.loadPreferences();
      if (mounted) {
        setState(() {
          _pushNotifications = prefs['pushNotifications'] ?? true;
          _emailNotifications = prefs['emailNotifications'] ?? true;
          _orderUpdates = prefs['orderUpdates'] ?? true;
        });
      }
    } catch (e) {
      debugPrint('[Settings] Error loading notification preferences: $e');
    }
  }

  Future<void> _togglePushNotifications(bool value) async {
    setState(() {
      _pushNotifications = value;
    });
    
    final success = await NotificationPreferencesService.setPushNotifications(value);
    if (!success) {
      // Revert on failure
      setState(() {
        _pushNotifications = !value;
      });
      _showSnackBar('Failed to update push notification preference');
    } else {
      _showSnackBar(value ? 'Push notifications enabled' : 'Push notifications disabled');
    }
  }

  Future<void> _toggleEmailNotifications(bool value) async {
    setState(() {
      _emailNotifications = value;
    });
    
    final success = await NotificationPreferencesService.setEmailNotifications(value);
    if (!success) {
      // Revert on failure
      setState(() {
        _emailNotifications = !value;
      });
      _showSnackBar('Failed to update email notification preference');
    } else {
      _showSnackBar(value ? 'Email notifications enabled' : 'Email notifications disabled');
    }
  }

  Future<void> _toggleOrderUpdates(bool value) async {
    setState(() {
      _orderUpdates = value;
    });
    
    final success = await NotificationPreferencesService.setOrderUpdates(value);
    if (!success) {
      // Revert on failure
      setState(() {
        _orderUpdates = !value;
      });
      _showSnackBar('Failed to update order updates preference');
    } else {
      _showSnackBar(value ? 'Order updates enabled' : 'Order updates disabled');
    }
  }

  Future<void> _toggleBiometric(bool value) async {
    if (value) {
      // Check if biometric authentication is available
      final bool isAvailable = await _localAuth.canCheckBiometrics;
      if (!isAvailable) {
        _showSnackBar('Biometric authentication is not available on this device');
        return;
      }

      // Get available biometric types
      final List<BiometricType> availableBiometrics = await _localAuth.getAvailableBiometrics();
      if (availableBiometrics.isEmpty) {
        _showSnackBar('No biometric authentication methods are set up');
        return;
      }

      // Authenticate to enable biometric login
      try {
        final bool didAuthenticate = await _localAuth.authenticate(
          localizedReason: 'Enable biometric authentication for Victus',
          options: const AuthenticationOptions(
            biometricOnly: true,
            stickyAuth: true,
          ),
        );

        if (didAuthenticate) {
          setState(() {
            _biometricEnabled = true;
          });
          _showSnackBar('Biometric authentication enabled');
        }
      } catch (e) {
        _showSnackBar('Failed to enable biometric authentication');
      }
    } else {
      setState(() {
        _biometricEnabled = false;
      });
      _showSnackBar('Biometric authentication disabled');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppThemeV3.primaryGreen,
      ),
    );
  }

  Future<void> _signOut() async {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              
              try {
                // Capture UID before sign-out for proper cleanup
                final prevUid = _auth.currentUser?.uid;
                // Sign out from Firebase
                await FirebaseAuth.instance.signOut();
                
                // Reset the welcome flag so user sees welcome page again
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('has_seen_welcome', false);
                // Cleanup local schedule lists to avoid cross-account leakage
                try {
                  // Remove legacy global list
                  await prefs.remove('saved_schedules');
                  // Remove namespaced list for previous user
                  if (prevUid != null) {
                    await prefs.remove('saved_schedules_${prevUid}');
                    await prefs.remove('selected_meal_plan_id_${prevUid}');
                    await prefs.remove('selected_meal_plan_display_name_${prevUid}');
                  }
                } catch (_) {}
                if (!mounted) return;
                // Navigate to welcome page and clear all previous routes
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const WelcomePageV3()),
                  (route) => false,
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error signing out: $e')),
                );
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) {
      _showSnackBar('No user is currently signed in');
      return;
    }

    // First, check if user has active subscriptions
    bool hasActiveSubscriptions = false;
    List<Map<String, dynamic>> subscriptions = [];
    
    try {
      hasActiveSubscriptions = await AccountDeletionService.hasActiveSubscriptions(user.uid);
      if (hasActiveSubscriptions) {
        subscriptions = await AccountDeletionService.getUserSubscriptions(user.uid);
      }
    } catch (e) {
      _showSnackBar('Error checking subscriptions: $e');
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red, size: 28),
            const SizedBox(width: 12),
            const Text('Delete Account'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This action cannot be undone. Deleting your account will:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              const Text('• Delete all your personal data'),
              const Text('• Cancel all active subscriptions'),
              const Text('• Remove all delivery addresses'),
              const Text('• Delete order history'),
              const Text('• Remove meal preferences'),
              
              if (hasActiveSubscriptions) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppThemeV3.borderLight),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.subscriptions, color: Colors.black, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'Active Subscriptions',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...subscriptions.map((sub) => Text(
                        '• ${sub['planName'] ?? 'Unknown Plan'} - \$${sub['monthlyAmount'] ?? 0}/month',
                        style: const TextStyle(fontSize: 12),
                      )),
                      const SizedBox(height: 8),
                      const Text(
                        'These will be canceled immediately.',
                        style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),
              ],
              
              const SizedBox(height: 16),
              const Text(
                'Are you absolutely sure you want to delete your account?',
                style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Colors.black, width: 2),
              ),
            ),
            child: const Text('Delete Account'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // FIRST: Reauthenticate the user before attempting deletion
    // Firebase requires recent authentication to delete accounts
    final reauthenticated = await _reauthenticateUser();
    if (!reauthenticated) {
      if (mounted) {
        _showSnackBar('Account deletion canceled - authentication required');
      }
      return;
    }

    // Show loading dialog after successful reauth
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Deleting account...'),
            SizedBox(height: 8),
            Text(
              'This may take a few moments',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );

    try {
      // Now delete the account (should succeed since we just reauthenticated)
      await AccountDeletionService.deleteUserAccount();
      
      if (!mounted) return;
      
      // Close loading dialog
      Navigator.pop(context);
      
      // Show success message and navigate to welcome
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Account deleted successfully'),
          backgroundColor: Colors.black,
        ),
      );
      
      // Navigate to welcome page
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const WelcomePageV3()),
        (route) => false,
      );
      
    } catch (e) {
      if (!mounted) return;
      
      // Close loading dialog
      Navigator.pop(context);
      
      // Show error message
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.error, color: Colors.red),
              const SizedBox(width: 8),
              const Text('Deletion Failed'),
            ],
          ),
          content: Text(
            'Failed to delete account: $e\n\n'
            'Please try signing out and signing back in, then try again.\n\n'
            'If this issue persists, please contact support.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  /// Re-authenticate user with their password or guide non-password accounts
  Future<bool> _reauthenticateUser() async {
    final passwordController = TextEditingController();
    String? errorMessage;
    final providers = _auth.currentUser?.providerData.map((p) => p.providerId).toList() ?? const [];
    final supportsPassword = providers.contains('password');

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (builderContext, setDialogState) => AlertDialog(
          title: const Text('Confirm Your Identity'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (supportsPassword) ...[
                const Text(
                  'For security reasons, please enter your password to continue with account deletion.',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  autofocus: true,
                  onSubmitted: (_) async {
                    final password = passwordController.text.trim();
                    if (password.isEmpty) {
                      setDialogState(() => errorMessage = 'Please enter your password');
                      return;
                    }
                    try {
                      final user = _auth.currentUser;
                      final email = user?.email;
                      if (user == null || email == null) {
                        throw Exception('User or email not found');
                      }
                      final credential = EmailAuthProvider.credential(email: email, password: password);
                      
                      await user.reauthenticateWithCredential(credential).timeout(
                        const Duration(seconds: 10),
                        onTimeout: () {
                          throw Exception('Authentication timed out. Try signing out and back in, then retry deletion.');
                        },
                      );
                      
                      if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                    } on FirebaseAuthException catch (e) {
                      debugPrint('[Reauth Enter] FirebaseAuthException: ${e.code} - ${e.message}');
                      setDialogState(() {
                        errorMessage = e.code == 'wrong-password'
                            ? 'Incorrect password. Please try again.'
                            : 'Authentication error: ${e.code.replaceAll('-', ' ')}';
                      });
                    } catch (e) {
                      debugPrint('[Reauth Enter] Unknown error: $e');
                      setDialogState(() => errorMessage = e.toString().contains('timed out')
                          ? 'Request timed out. On desktop, sign out and back in first, then try deletion.'
                          : 'Authentication error. Please try again.');
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'Password',
                    errorText: errorMessage,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.black, width: 2),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.black, width: 2),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.black, width: 2),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.red, width: 2),
                    ),
                  ),
                ),
              ] else ...[
                const Text(
                  'This account is not using a password (e.g., signed in with Google/Apple).\n\nTo confirm deletion, please sign out and sign back in, then try again.',
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            if (supportsPassword)
              ElevatedButton(
                onPressed: () async {
                  debugPrint('[Reauth] Confirm button pressed');
                  final password = passwordController.text.trim();
                  if (password.isEmpty) {
                    debugPrint('[Reauth] Password empty');
                    setDialogState(() => errorMessage = 'Please enter your password');
                    return;
                  }
                  debugPrint('[Reauth] Attempting reauthentication...');
                  try {
                    final user = _auth.currentUser;
                    final email = user?.email;
                    if (user == null || email == null) {
                      throw Exception('User or email not found');
                    }
                    final credential = EmailAuthProvider.credential(email: email, password: password);
                    
                    // Add timeout to prevent infinite hang on desktop
                    await user.reauthenticateWithCredential(credential).timeout(
                      const Duration(seconds: 10),
                      onTimeout: () {
                        debugPrint('[Reauth] Timeout after 10 seconds');
                        throw Exception('Authentication timed out. Try signing out and back in, then retry deletion.');
                      },
                    );
                    
                    debugPrint('[Reauth] Success! Closing dialog with true');
                    if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                  } on FirebaseAuthException catch (e) {
                    debugPrint('[Reauth Confirm] FirebaseAuthException: ${e.code} - ${e.message}');
                    setDialogState(() {
                      errorMessage = e.code == 'wrong-password'
                          ? 'Incorrect password. Please try again.'
                          : 'Authentication error: ${e.code.replaceAll('-', ' ')}';
                    });
                  } catch (e) {
                    debugPrint('[Reauth Confirm] Unknown error: $e');
                    setDialogState(() => errorMessage = e.toString().contains('timed out') 
                        ? 'Request timed out. On desktop, sign out and back in first, then try deletion.'
                        : 'Authentication error. Please try again.');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Confirm'),
              ),
            if (!supportsPassword)
              ElevatedButton(
                onPressed: () async {
                  try {
                    await _auth.signOut();
                  } finally {
                    if (mounted) {
                      Navigator.pop(dialogContext, false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Signed out. Please sign back in to continue account deletion.')),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Sign out to re-authenticate'),
              ),
          ],
        ),
      ),
    );

    passwordController.dispose();
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppThemeV3.primaryGreen),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Admin tools section hidden for clean UI
          // if (_isAdmin) ...[
            // _buildSectionHeader('Admin Tools'),
            // Card(
              // elevation: 0,
              // color: const Color(0xFFF6FFF8),
              // child: Padding(
                // padding: const EdgeInsets.all(12.0),
                // child: Column(
                  // crossAxisAlignment: CrossAxisAlignment.stretch,
                  // children: [
                    // ElevatedButton(
                      // onPressed: _adminSeeding ? null : _adminSeedMeals,
                      // style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange, foregroundColor: Colors.white),
                      // child: _adminSeeding
                          // ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          // : const Text('Seed Meals to Firestore'),
                    // ),
                    // const SizedBox(height: 8),
                    // ElevatedButton(
                      // onPressed: _adminFixing ? null : _adminFixImages,
                      // style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                      // child: _adminFixing
                          // ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          // : const Text('Fix Meal Images Only'),
                    // ),
                    // const SizedBox(height: 8),
                    // ElevatedButton(
                      // onPressed: _adminSwitching ? null : _adminSwitchImagesToAssets,
                      // style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                      // child: _adminSwitching
                          // ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          // : const Text('Use Bundled Asset Images for Meals'),
                    // ),
                    // const SizedBox(height: 8),
                    // ElevatedButton(
                      // onPressed: _adminSwitchingJfif ? null : _adminSwitchImagesToAssetsJfif,
                      // style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white),
                      // child: _adminSwitchingJfif
                          // ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          // : const Text('Use Bundled Asset Images (.jfif)'),
                    // ),
                    // const SizedBox(height: 8),
                    // ElevatedButton(
                      // onPressed: _adminSwitchingAuto ? null : _adminSwitchImagesToAssetsAuto,
                      // style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey, foregroundColor: Colors.white),
                      // child: _adminSwitchingAuto
                          // ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          // : const Text('Use Bundled Asset Images (Auto detect)'),
                    // ),
                    // if (_adminSeedMsg != null) ...[
                      // const SizedBox(height: 8),
                      // Text(_adminSeedMsg!, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                    // ],
                    // if (_adminFixMsg != null) ...[
                      // const SizedBox(height: 4),
                      // Text(_adminFixMsg!, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                    // ],
                    // if (_adminSwitchMsg != null) ...[
                      // const SizedBox(height: 4),
                      // Text(_adminSwitchMsg!, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                    // ],
                    // if (_adminSwitchJfifMsg != null) ...[
                      // const SizedBox(height: 4),
                      // Text(_adminSwitchJfifMsg!, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                    // ],
                    // if (_adminSwitchAutoMsg != null) ...[
                      // const SizedBox(height: 4),
                      // Text(_adminSwitchAutoMsg!, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                    // ],
                  // ],
                // ),
              // ),
            // ),
            // const SizedBox(height: 24),
          // ],
          if (_accountEmail != null || _accountName != null)
            _buildAccountSummary(),

          // Account Section
          _buildSectionHeader('Account'),
          _buildSettingsTile(
            icon: Icons.person_outline,
            title: 'Profile Information',
            subtitle: 'Manage your personal details',
            onTap: () => _navigateToProfile(),
          ),
          _buildSettingsTile(
            icon: Icons.location_on_outlined,
            title: 'Addresses',
            subtitle: 'Manage delivery addresses',
            onTap: () => _navigateToAddresses(),
          ),
          _buildSettingsTile(
            icon: Icons.payment_outlined,
            title: 'Payment Methods',
            subtitle: 'Manage cards and billing',
            onTap: () => _navigateToPayment(),
          ),
          _buildSettingsTile(
            icon: Icons.subscriptions_outlined,
            title: 'Manage Subscription',
            subtitle: 'View and manage your meal plan subscription',
            onTap: _navigateToManageSubscription,
          ),

          const SizedBox(height: 24),

          // Orders & Schedules
          _buildSectionHeader('Orders & Schedules'),
          // Circle of Health removed from Settings per request
          _buildSettingsTile(
            icon: Icons.calendar_month_outlined,
            title: 'Delivery Schedule',
            subtitle: 'Create a new delivery schedule',
            onTap: _navigateToDeliveryScheduleBuilder,
          ),
          _buildSettingsTile(
            icon: Icons.restaurant_menu_outlined,
            title: 'Meal Schedule',
            subtitle: 'Create a new meal schedule',
            onTap: _navigateToMealScheduleBuilder,
          ),
          _buildSettingsTile(
            icon: Icons.calendar_view_month_outlined,
            title: 'Delivery Schedule Overview',
            subtitle: 'View saved delivery schedules',
            onTap: _navigateToDeliveryScheduleOverview,
          ),
          _buildSettingsTile(
            icon: Icons.view_list_outlined,
            title: 'Meal Schedule Overview',
            subtitle: 'View meals selected per delivery',
            onTap: _navigateToMealScheduleOverview,
          ),

          const SizedBox(height: 24),

          // Security Section
          _buildSectionHeader('Security'),
          // Hide biometric auth on web (not supported)
          if (!kIsWeb)
            _buildSwitchTile(
              icon: Icons.fingerprint,
              title: 'Biometric Authentication',
              subtitle: 'Use fingerprint or face ID to sign in',
              value: _biometricEnabled,
              onChanged: _toggleBiometric,
            ),
          _buildSettingsTile(
            icon: Icons.lock_outline,
            title: 'Change Password',
            subtitle: 'Update your account password',
            onTap: () => _navigateToChangePassword(),
          ),

          const SizedBox(height: 24),

          // Notifications Section
          _buildSectionHeader('Notifications'),
          _buildSwitchTile(
            icon: Icons.notifications_outlined,
            title: 'Push Notifications',
            subtitle: 'Receive notifications on your device',
            value: _pushNotifications,
            onChanged: _togglePushNotifications,
          ),
          _buildSwitchTile(
            icon: Icons.email_outlined,
            title: 'Email Notifications',
            subtitle: 'Receive notifications via email',
            value: _emailNotifications,
            onChanged: _toggleEmailNotifications,
          ),
          _buildSwitchTile(
            icon: Icons.local_shipping_outlined,
            title: 'Order Updates',
            subtitle: 'Get notified about order status',
            value: _orderUpdates,
            onChanged: _toggleOrderUpdates,
          ),

          const SizedBox(height: 24),

          // Support Section
          _buildSectionHeader('Support'),
          _buildSettingsTile(
            icon: Icons.help_outline,
            title: 'Help & FAQ',
            subtitle: 'Get answers to common questions',
            onTap: () => _navigateToHelp(),
          ),
          _buildSettingsTile(
            icon: Icons.chat_bubble_outline,
            title: 'Contact Support',
            subtitle: 'Get in touch with our team',
            onTap: () => _navigateToSupport(),
          ),
          _buildSettingsTile(
            icon: Icons.info_outline,
            title: 'About Victus',
            subtitle: 'App version and information',
            onTap: () => _navigateToAbout(),
          ),

          const SizedBox(height: 24),

          // Legal Section
          _buildSectionHeader('Legal'),
          _buildSettingsTile(
            icon: Icons.description_outlined,
            title: 'Terms of Service',
            subtitle: 'Read our terms and conditions',
            onTap: () => _navigateToTerms(),
          ),
          _buildSettingsTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            subtitle: 'How we protect your data',
            onTap: () => _navigateToPrivacy(),
          ),

          const SizedBox(height: 32),

          // Sign Out Button
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton(
              onPressed: _signOut,
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
              child: const Text(
                'Sign Out',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Clean settings interface - admin buttons removed for user experience

          const SizedBox(height: 16),

          // Delete Account Button
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton(
              onPressed: _deleteAccount,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red, width: 2),
                foregroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Delete Account',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildAccountSummary() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black, width: 2),
                ),
                child: const Icon(Icons.account_circle, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if ((_accountName ?? '').isNotEmpty)
                      Text(
                        _accountName!,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    if ((_accountEmail ?? '').isNotEmpty)
                      Text(
                        _accountEmail!,
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if ((_planName ?? '').isNotEmpty || _planMonthlyAmount != null)
            Row(
              children: [
                const Icon(Icons.subscriptions_outlined, size: 18, color: Colors.black54),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                      (() {
                        final parts = <String>[];
                        if ((_planName ?? '').isNotEmpty) parts.add(_planName!);
                        if (_planMonthlyAmount != null) {
                          parts.add('\$${_planMonthlyAmount!.toStringAsFixed(2)} / mo');
                        }
                        return parts.join(' • ');
                      })(),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton(
                  onPressed: _navigateToManageSubscription,
                  child: const Text('Manage'),
                ),
              ],
            ),
          if (_nextBillingDate != null)
            Padding(
              padding: const EdgeInsets.only(left: 24.0, top: 2),
              child: Text(
                'Next billing: ${_formatDate(_nextBillingDate!)}',
                style: TextStyle(color: Colors.grey[700], fontSize: 12),
              ),
            ),
          // Address summary removed per request
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.black, width: 2),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          color: Colors.grey[400],
          size: 16,
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.black, width: 2),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeColor: AppThemeV3.primaryGreen,
        ),
      ),
    );
  }

  // Navigation methods
  void _navigateToProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ProfilePageV3()),
    );
  }

  void _navigateToAddresses() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddressPageV3()),
    );
  }

  void _navigateToPayment() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PaymentMethodsPageV3()),
    );
  }

  // Navigate to the restored overview pages

  void _navigateToDeliveryScheduleOverview() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DeliveryScheduleOverviewPageV2()),
    );
  }

  void _navigateToMealScheduleOverview() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MealScheduleOverviewPageV2()),
    );
  }

  void _navigateToDeliveryScheduleBuilder() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const DeliverySchedulePageV5(
          isSignupFlow: false, // From settings, not signup
        ),
      ),
    );
  }

  void _navigateToMealScheduleBuilder() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MealSchedulePageV3()),
    );
  }

  // Manage subscription hub (plan + billing)
  void _navigateToManageSubscription() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ManageSubscriptionPageV3()),
    );
  }

  String _formatDate(DateTime dt) {
    // Simple date formatting: Aug 9, 2025
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  void _navigateToChangePassword() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ChangePasswordPageV3()),
    );
  }

  void _navigateToHelp() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const HelpSupportPageV3()),
    );
  }

  void _navigateToSupport() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const HelpSupportPageV3()),
    );
  }

  void _navigateToAbout() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AboutPageV3()),
    );
  }

  void _navigateToTerms() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TermsOfServicePageV3()),
    );
  }

  void _navigateToPrivacy() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PrivacyPolicyPageV3()),
    );
  }
}
