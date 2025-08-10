import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme_v3.dart';

class TermsOfServicePageV3 extends StatelessWidget {
  const TermsOfServicePageV3({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeV3.background,
      appBar: AppBar(
        backgroundColor: AppThemeV3.background,
        elevation: 0,
        title: Text(
          'Terms of Service',
          style: AppThemeV3.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new),
            onPressed: () => _openFullTerms(),
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
            
            // Terms Sections
            ..._buildTermsSections(),
            
            const SizedBox(height: 32),
            
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
            Icons.update,
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
            'Terms Overview',
            style: AppThemeV3.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppThemeV3.accent,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'By using the FreshPunk mobile application and services, you agree to be bound by these Terms of Service. Please read them carefully before using our app.',
            style: AppThemeV3.textTheme.bodyLarge?.copyWith(
              color: AppThemeV3.textSecondary,
              fontWeight: FontWeight.w600,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'These terms govern your access to and use of our meal delivery service, including ordering, payment, delivery, and account management features.',
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

  List<Widget> _buildTermsSections() {
    final sections = [
      TermsSection(
        title: '1. Service Description',
        content: 'FreshPunk provides a meal delivery service through our mobile application. We offer fresh, prepared meals delivered to your specified location within our service areas.',
        points: [
          'Meal ordering and customization',
          'Scheduled delivery services',
          'Nutrition tracking and meal history',
          'Account management and preferences',
        ],
      ),
      TermsSection(
        title: '2. Account Registration',
        content: 'To use our services, you must create an account with accurate and complete information.',
        points: [
          'You must be at least 18 years old',
          'Provide accurate contact and payment information',
          'Maintain the security of your account credentials',
          'Notify us immediately of any unauthorized access',
        ],
      ),
      TermsSection(
        title: '3. Ordering and Payment',
        content: 'All orders are subject to availability and delivery area restrictions.',
        points: [
          'Payment is required at the time of order',
          'We accept major credit cards and digital payment methods',
          'Prices may change without prior notice',
          'Subscription plans may include recurring charges',
        ],
      ),
      TermsSection(
        title: '4. Delivery Terms',
        content: 'We strive to deliver your meals within the specified time windows.',
        points: [
          'Delivery times are estimates, not guarantees',
          'You must be available to receive deliveries',
          'Special delivery instructions should be provided',
          'Failed deliveries may result in additional charges',
        ],
      ),
      TermsSection(
        title: '5. Cancellation and Refunds',
        content: 'Cancellation policies vary depending on when you cancel your order.',
        points: [
          'Orders can be cancelled up to 24 hours before delivery',
          'Subscription plans can be paused or cancelled anytime',
          'Refunds are processed within 5-7 business days',
          'Quality issues will be addressed with refunds or credits',
        ],
      ),
      TermsSection(
        title: '6. User Responsibilities',
        content: 'You are responsible for appropriate use of our service and app.',
        points: [
          'Provide accurate delivery information',
          'Use the app in accordance with its intended purpose',
          'Do not share account credentials with others',
          'Report any issues or concerns promptly',
        ],
      ),
      TermsSection(
        title: '7. Privacy and Data',
        content: 'Your privacy is important to us. Please review our Privacy Policy for details on how we collect, use, and protect your information.',
        points: [
          'We collect necessary information to provide services',
          'Your data is protected with industry-standard security',
          'We do not sell your personal information to third parties',
          'You can request data deletion at any time',
        ],
      ),
      TermsSection(
        title: '8. Limitation of Liability',
        content: 'Our liability is limited to the maximum extent permitted by law.',
        points: [
          'We are not liable for indirect or consequential damages',
          'Total liability is limited to the amount paid for services',
          'Food allergies and dietary restrictions are your responsibility',
          'We recommend checking ingredients before consumption',
        ],
      ),
    ];

    return sections.map((section) => _buildTermsSection(section)).toList();
  }

  Widget _buildTermsSection(TermsSection section) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
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
            style: AppThemeV3.textTheme.titleMedium?.copyWith(
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
          const SizedBox(height: 16),
          ...section.points.map((point) => _buildBulletPoint(point)),
        ],
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8, right: 12),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
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

  Widget _buildContactInfo() {
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
                Icons.contact_support,
                color: AppThemeV3.accent,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Questions About These Terms?',
                style: AppThemeV3.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppThemeV3.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'If you have any questions about these Terms of Service, please contact us:',
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
                  label: 'Email Support',
                  subtitle: 'legal@freshpunk.com',
                  onTap: () => _contactEmail(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildContactButton(
                  icon: Icons.open_in_new,
                  label: 'Full Terms',
                  subtitle: 'View online',
                  onTap: () => _openFullTerms(),
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

  void _contactEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'legal@freshpunk.com',
      query: 'subject=Terms of Service Question',
    );
    
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    }
  }

  void _openFullTerms() async {
    const url = 'https://freshpunk.com/terms';
    final Uri uri = Uri.parse(url);
    
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}

class TermsSection {
  final String title;
  final String content;
  final List<String> points;

  TermsSection({
    required this.title,
    required this.content,
    required this.points,
  });
}
