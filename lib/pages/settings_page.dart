import 'package:flutter/material.dart';
import 'account_page.dart';
import 'payment_page.dart';
import 'subscription_page.dart';
import 'security_page.dart';
import 'terms_of_service_page.dart';
import '../theme/app_theme.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

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
          'SETTINGS',
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
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const SizedBox(height: 20),
                
                // Settings options
                _buildSettingsItem(
                  context,
                  icon: Icons.person_outline,
                  title: 'ACCOUNT',
                  subtitle: 'Profile, addresses, and personal information',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AccountPage()),
                  ),
                ),
                
                _buildSettingsItem(
                  context,
                  icon: Icons.payment,
                  title: 'PAYMENT',
                  subtitle: 'Payment methods and billing',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const PaymentPage()),
                  ),
                ),
                
                _buildSettingsItem(
                  context,
                  icon: Icons.subscriptions,
                  title: 'SUBSCRIPTION',
                  subtitle: 'Manage your meal plan',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SubscriptionPage()),
                  ),
                ),
                
                _buildSettingsItem(
                  context,
                  icon: Icons.security,
                  title: 'SECURITY',
                  subtitle: 'Password, biometrics, and notifications',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SecurityPage()),
                  ),
                ),
                
                _buildSettingsItem(
                  context,
                  icon: Icons.description,
                  title: 'TERMS OF SERVICE',
                  subtitle: 'Legal information and policies',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const TermsOfServicePage()),
                  ),
                ),
              
              const Spacer(),
              
              // App version
              Text(
                'FRESHPUNK v1.0.0',
                style: AppTheme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.textPrimary.withValues(alpha: 0.5),
                  letterSpacing: 1.0,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: AppCard(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: AppTheme.accent,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTheme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: AppTheme.textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textPrimary.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: AppTheme.textPrimary.withValues(alpha: 0.5),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
