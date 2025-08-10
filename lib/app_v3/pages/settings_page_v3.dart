import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme_v3.dart';
import 'welcome_page_v3.dart';
import 'address_page_v3.dart';
import 'profile_page_v3.dart';
import 'payment_methods_page_v3.dart';
import 'delivery_schedule_page_v4.dart';
import 'meal_schedule_page_v3.dart';
import 'plan_subscription_page_v3.dart';
import '../services/firestore_service_v3.dart';
import 'change_password_page_v3.dart';
import 'help_support_page_v3.dart';
import 'about_page_v3.dart';
import 'terms_of_service_page_v3.dart';
import 'privacy_policy_page_v3.dart';
// Removed Circle of Health from Settings

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
  
  bool _biometricEnabled = false;
  bool _pushNotifications = true;
  bool _emailNotifications = true;
  bool _orderUpdates = true;
  bool _promotionalEmails = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    // Load user settings from Firebase or local storage
    // For now, using default values
    final user = _auth.currentUser;
    if (user == null) {
      setState(() {
        _accountName = null;
        _accountEmail = null;
        _isLoading = false;
      });
      return;
    }

    try {
      // Fetch in sequence (fast enough); could be parallelized if needed
      final profileName = user.displayName;
      final profileEmail = user.email;

      final subscription = await FirestoreServiceV3.getActiveSubscription(user.uid);
      final mealPlan = await FirestoreServiceV3.getCurrentMealPlan(user.uid);
  // Address summary removed from Settings; still fetchable elsewhere if needed

      setState(() {
        _accountName = profileName;
        _accountEmail = profileEmail;
        _planName = mealPlan?.displayName.isNotEmpty == true ? mealPlan!.displayName : mealPlan?.name;
        _planMonthlyAmount = (subscription?['monthlyAmount'] as num?)?.toDouble();
        final ts = subscription?['nextBillingDate'];
        _nextBillingDate = ts is Timestamp ? ts.toDate() : ts is int ? DateTime.fromMillisecondsSinceEpoch(ts) : null;
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _accountName = user.displayName;
        _accountEmail = user.email;
        _isLoading = false;
      });
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
          localizedReason: 'Enable biometric authentication for FreshPunk',
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
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              
              try {
                // Sign out from Firebase
                await FirebaseAuth.instance.signOut();
                
                // Reset the welcome flag so user sees welcome page again
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('has_seen_welcome', false);
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

          const SizedBox(height: 24),

          // Orders & Schedules
          _buildSectionHeader('Orders & Schedules'),
          // Circle of Health removed from Settings per request
          _buildSettingsTile(
            icon: Icons.subscriptions_outlined,
            title: 'Meal Plan Subscription',
            subtitle: 'Change your meal plan',
            onTap: _navigateToPlanSubscription,
          ),
          _buildSettingsTile(
            icon: Icons.calendar_month_outlined,
            title: 'Delivery Schedule',
            subtitle: 'Create or edit your delivery schedule',
            onTap: _navigateToDeliverySchedule,
          ),
          _buildSettingsTile(
            icon: Icons.restaurant_menu_outlined,
            title: 'Meal Schedule',
            subtitle: 'Customize meals for each delivery',
            onTap: _navigateToMealSchedule,
          ),

          const SizedBox(height: 24),

          // Security Section
          _buildSectionHeader('Security'),
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
            onChanged: (value) {
              setState(() {
                _pushNotifications = value;
              });
            },
          ),
          _buildSwitchTile(
            icon: Icons.email_outlined,
            title: 'Email Notifications',
            subtitle: 'Receive notifications via email',
            value: _emailNotifications,
            onChanged: (value) {
              setState(() {
                _emailNotifications = value;
              });
            },
          ),
          _buildSwitchTile(
            icon: Icons.local_shipping_outlined,
            title: 'Order Updates',
            subtitle: 'Get notified about order status',
            value: _orderUpdates,
            onChanged: (value) {
              setState(() {
                _orderUpdates = value;
              });
            },
          ),
          _buildSwitchTile(
            icon: Icons.local_offer_outlined,
            title: 'Promotional Emails',
            subtitle: 'Receive offers and promotions',
            value: _promotionalEmails,
            onChanged: (value) {
              setState(() {
                _promotionalEmails = value;
              });
            },
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
            title: 'About FreshPunk',
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
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Sign Out',
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
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppThemeV3.primaryGreen.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.account_circle, color: AppThemeV3.primaryGreen),
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
                  onPressed: _navigateToMealSchedule,
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
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppThemeV3.primaryGreen.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: AppThemeV3.primaryGreen,
            size: 24,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
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
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppThemeV3.primaryGreen.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: AppThemeV3.primaryGreen,
            size: 24,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
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

  void _navigateToDeliverySchedule() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DeliverySchedulePageV4()),
    );
  }

  void _navigateToMealSchedule() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MealSchedulePageV3()),
    );
  }

  // Separate entry for changing the meal plan subscription (uses existing page)
  void _navigateToPlanSubscription() {
    Navigator.push(
      context,
  MaterialPageRoute(builder: (context) => const PlanSubscriptionPageV3()),
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
