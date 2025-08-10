import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme_v3.dart';

class PrivacyPolicyPageV3 extends StatelessWidget {
  const PrivacyPolicyPageV3({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeV3.background,
      appBar: AppBar(
        backgroundColor: AppThemeV3.background,
        elevation: 0,
        title: Text(
          'Privacy Policy',
          style: AppThemeV3.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new),
            onPressed: () => _openFullPolicy(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Last Updated
            _buildLastUpdated(),
            
            const SizedBox(height: 24),
            
            // Overview
            _buildOverview(),
            
            const SizedBox(height: 24),
            
            // Privacy Sections
            ..._buildPrivacySections(),
            
            const SizedBox(height: 32),
            
            // Your Rights
            _buildYourRights(),
            
            const SizedBox(height: 24),
            
            // Contact Information
            _buildContactInfo(),
          ],
        ),
      ),
    );
  }

  Widget _buildLastUpdated() {
    return Container(
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
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            'Last Updated: December 15, 2024',
            style: AppThemeV3.textTheme.bodyMedium?.copyWith(
              color: AppThemeV3.accent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverview() {
    return Container(
      padding: const EdgeInsets.all(20),
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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Our Commitment to Privacy',
            style: AppThemeV3.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppThemeV3.accent,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'At FreshPunk, we respect your privacy and are committed to protecting your personal information. This Privacy Policy explains how we collect, use, and safeguard your data when you use our meal delivery service.',
            style: AppThemeV3.textTheme.bodyLarge?.copyWith(
              color: AppThemeV3.textSecondary,
              fontWeight: FontWeight.w600,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'We only collect information necessary to provide you with excellent service, and we never sell your personal data to third parties.',
            style: AppThemeV3.textTheme.bodyLarge?.copyWith(
              color: AppThemeV3.textSecondary,
              fontWeight: FontWeight.w600,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPrivacySections() {
    final sections = [
      PrivacySection(
        title: '1. Information We Collect',
        content: 'We collect information you provide directly and automatically when you use our app.',
        categories: [
          DataCategory(
            title: 'Personal Information',
            items: [
              'Name, email address, and phone number',
              'Delivery address and location data',
              'Payment information and billing details',
              'Dietary preferences and food allergies',
            ],
          ),
          DataCategory(
            title: 'Usage Information',
            items: [
              'App usage patterns and preferences',
              'Order history and meal ratings',
              'Device information and IP address',
              'Push notification preferences',
            ],
          ),
          DataCategory(
            title: 'Location Data',
            items: [
              'Delivery address for order fulfillment',
              'Real-time location for delivery tracking',
              'Service area verification',
              'Route optimization for deliveries',
            ],
          ),
        ],
      ),
      PrivacySection(
        title: '2. How We Use Your Information',
        content: 'Your information helps us provide, improve, and personalize our services.',
        categories: [
          DataCategory(
            title: 'Service Delivery',
            items: [
              'Process and fulfill your meal orders',
              'Coordinate delivery schedules and routes',
              'Provide customer support and assistance',
              'Send order confirmations and updates',
            ],
          ),
          DataCategory(
            title: 'Personalization',
            items: [
              'Recommend meals based on your preferences',
              'Customize your nutrition tracking',
              'Remember your favorite orders',
              'Tailor promotional offers to your interests',
            ],
          ),
          DataCategory(
            title: 'Communication',
            items: [
              'Send important service announcements',
              'Provide promotional offers and discounts',
              'Request feedback on your experience',
              'Share updates about new features',
            ],
          ),
        ],
      ),
      PrivacySection(
        title: '3. Information Sharing',
        content: 'We share your information only when necessary to provide our services.',
        categories: [
          DataCategory(
            title: 'Service Providers',
            items: [
              'Payment processors for secure transactions',
              'Delivery partners for order fulfillment',
              'Cloud hosting providers for data storage',
              'Analytics services for app improvement',
            ],
          ),
          DataCategory(
            title: 'Legal Requirements',
            items: [
              'Comply with applicable laws and regulations',
              'Respond to legal requests and court orders',
              'Protect our rights and prevent fraud',
              'Ensure the safety of our users and staff',
            ],
          ),
        ],
      ),
      PrivacySection(
        title: '4. Data Security',
        content: 'We implement robust security measures to protect your information.',
        categories: [
          DataCategory(
            title: 'Technical Safeguards',
            items: [
              'End-to-end encryption for sensitive data',
              'Secure servers with regular updates',
              'Multi-factor authentication systems',
              'Regular security audits and monitoring',
            ],
          ),
          DataCategory(
            title: 'Access Controls',
            items: [
              'Limited employee access to personal data',
              'Regular security training for staff',
              'Strict data handling procedures',
              'Incident response and breach protocols',
            ],
          ),
        ],
      ),
    ];

    return sections.map((section) => _buildPrivacySection(section)).toList();
  }

  Widget _buildPrivacySection(PrivacySection section) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
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
          color: AppThemeV3.border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.title,
            style: AppThemeV3.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppThemeV3.accent,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            section.content,
            style: AppThemeV3.textTheme.bodyMedium?.copyWith(
              color: AppThemeV3.textSecondary,
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          ...section.categories.map((category) => _buildDataCategory(category)),
        ],
      ),
    );
  }

  Widget _buildDataCategory(DataCategory category) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppThemeV3.accent.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppThemeV3.accent.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            category.title,
            style: AppThemeV3.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppThemeV3.accent,
            ),
          ),
          const SizedBox(height: 12),
          ...category.items.map((item) => _buildBulletPoint(item)),
        ],
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8, right: 12),
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppThemeV3.accent,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: AppThemeV3.textTheme.bodyMedium?.copyWith(
                color: AppThemeV3.textSecondary,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYourRights() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppThemeV3.accent.withValues(alpha: 0.1),
            AppThemeV3.accent.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppThemeV3.accent.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.verified_user,
                color: AppThemeV3.accent,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Your Privacy Rights',
                style: AppThemeV3.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppThemeV3.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'You have the following rights regarding your personal information:',
            style: AppThemeV3.textTheme.bodyMedium?.copyWith(
              color: AppThemeV3.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          _buildRightItem('Access', 'Request a copy of your personal data'),
          _buildRightItem('Correction', 'Update or correct your information'),
          _buildRightItem('Deletion', 'Request deletion of your account and data'),
          _buildRightItem('Portability', 'Export your data in a readable format'),
          _buildRightItem('Opt-out', 'Unsubscribe from marketing communications'),
        ],
      ),
    );
  }

  Widget _buildRightItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppThemeV3.accent.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.check,
              color: AppThemeV3.accent,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppThemeV3.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppThemeV3.accent,
                  ),
                ),
                Text(
                  description,
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
    );
  }

  Widget _buildContactInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.contact_support,
                color: AppThemeV3.accent,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Privacy Questions?',
                style: AppThemeV3.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppThemeV3.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'If you have questions about this Privacy Policy or want to exercise your rights:',
            style: AppThemeV3.textTheme.bodyMedium?.copyWith(
              color: AppThemeV3.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildContactButton(
                  icon: Icons.email_outlined,
                  label: 'Privacy Team',
                  subtitle: 'privacy@freshpunk.com',
                  onTap: () => _contactPrivacy(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildContactButton(
                  icon: Icons.open_in_new,
                  label: 'Full Policy',
                  subtitle: 'View online',
                  onTap: () => _openFullPolicy(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContactButton({
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppThemeV3.accent.withValues(alpha: 0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: AppThemeV3.accent.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: AppThemeV3.accent,
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: AppThemeV3.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppThemeV3.accent,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: AppThemeV3.textTheme.bodySmall?.copyWith(
                color: AppThemeV3.textSecondary,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _contactPrivacy() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'privacy@freshpunk.com',
      query: 'subject=Privacy Policy Question',
    );
    
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    }
  }

  void _openFullPolicy() async {
    const url = 'https://freshpunk.com/privacy';
    final Uri uri = Uri.parse(url);
    
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}

class PrivacySection {
  final String title;
  final String content;
  final List<DataCategory> categories;

  PrivacySection({
    required this.title,
    required this.content,
    required this.categories,
  });
}

class DataCategory {
  final String title;
  final List<String> items;

  DataCategory({
    required this.title,
    required this.items,
  });
}
