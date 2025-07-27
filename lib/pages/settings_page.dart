import 'package:flutter/material.dart';
import 'account_page.dart';
import 'payment_page.dart';
import 'subscription_page.dart';
import 'security_page.dart';
import 'terms_of_service_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 20),
              
              // Settings options
              _buildSettingsItem(
                context,
                icon: Icons.person_outline,
                title: 'Account',
                subtitle: 'Profile, addresses, and personal information',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AccountPage()),
                ),
              ),
              
              _buildSettingsItem(
                context,
                icon: Icons.payment,
                title: 'Payment',
                subtitle: 'Payment methods and billing',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PaymentPage()),
                ),
              ),
              
              _buildSettingsItem(
                context,
                icon: Icons.subscriptions,
                title: 'Subscription',
                subtitle: 'Manage your meal plan',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SubscriptionPage()),
                ),
              ),
              
              _buildSettingsItem(
                context,
                icon: Icons.security,
                title: 'Security',
                subtitle: 'Password, biometrics, and notifications',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SecurityPage()),
                ),
              ),
              
              _buildSettingsItem(
                context,
                icon: Icons.description,
                title: 'Terms of Service',
                subtitle: 'Legal information and policies',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const TermsOfServicePage()),
                ),
              ),
              
              const Spacer(),
              
              // App version
              Text(
                'FreshPunk v1.0.0',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D5A2D).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: const Color(0xFF2D5A2D),
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
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.grey[400],
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
