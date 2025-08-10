import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme_v3.dart';

class AboutPageV3 extends StatelessWidget {
  const AboutPageV3({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeV3.background,
      appBar: AppBar(
        backgroundColor: AppThemeV3.background,
        elevation: 0,
        title: Text(
          'About FreshPunk',
          style: AppThemeV3.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // App Logo and Info
            _buildAppHeader(),
            
            const SizedBox(height: 32),
            
            // App Description
            _buildAppDescription(),
            
            const SizedBox(height: 32),
            
            // Features Section
            _buildFeaturesSection(),
            
            const SizedBox(height: 32),
            
            // Company Information
            _buildCompanyInfo(),
            
            const SizedBox(height: 32),
            
            // Social Links
            _buildSocialLinks(),
            
            const SizedBox(height: 32),
            
            // Version Information
            _buildVersionInfo(),
          ],
        ),
      ),
    );
  }

  Widget _buildAppHeader() {
    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppThemeV3.accent,
                AppThemeV3.accent.withValues(alpha: 0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppThemeV3.accent.withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.restaurant_menu,
            size: 50,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'FreshPunk',
          style: AppThemeV3.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Fresh, Healthy Meals Delivered',
          style: AppThemeV3.textTheme.titleMedium?.copyWith(
            color: AppThemeV3.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildAppDescription() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppThemeV3.surface,
            AppThemeV3.surface.withValues(alpha: 0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppThemeV3.accent.withValues(alpha: 0.2),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Our Mission',
            style: AppThemeV3.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppThemeV3.accent,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'FreshPunk revolutionizes the way you eat by delivering fresh, nutritious, and delicious meals right to your doorstep. We believe that healthy eating should be convenient, affordable, and enjoyable for everyone.',
            style: AppThemeV3.textTheme.bodyLarge?.copyWith(
              color: AppThemeV3.textSecondary,
              fontWeight: FontWeight.w600,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'With our carefully crafted meal plans, locally sourced ingredients, and personalized nutrition tracking, we make it easy to maintain a healthy lifestyle without compromising on taste or convenience.',
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

  Widget _buildFeaturesSection() {
    final features = [
      Feature(
        icon: Icons.restaurant_outlined,
        title: 'Fresh Meals',
        description: 'Locally sourced, chef-prepared meals delivered fresh daily',
      ),
      Feature(
        icon: Icons.health_and_safety_outlined,
        title: 'Nutrition Tracking',
        description: 'Track your calories, protein, and nutrients automatically',
      ),
      Feature(
        icon: Icons.schedule_outlined,
        title: 'Flexible Delivery',
        description: 'Choose your delivery times and customize your schedule',
      ),
      Feature(
        icon: Icons.eco_outlined,
        title: 'Sustainable',
        description: 'Eco-friendly packaging and responsible sourcing',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Key Features',
          style: AppThemeV3.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 16),
        ...features.map((feature) => _buildFeatureItem(feature)),
      ],
    );
  }

  Widget _buildFeatureItem(Feature feature) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppThemeV3.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              feature.icon,
              color: AppThemeV3.accent,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feature.title,
                  style: AppThemeV3.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  feature.description,
                  style: AppThemeV3.textTheme.bodyMedium?.copyWith(
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

  Widget _buildCompanyInfo() {
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
            'Company Information',
            style: AppThemeV3.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoRow('Founded', '2024'),
          _buildInfoRow('Headquarters', 'San Francisco, CA'),
          _buildInfoRow('Team Size', '50+ employees'),
          _buildInfoRow('Cities Served', '25+ cities'),
          _buildInfoRow('Meals Delivered', '1M+ meals'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppThemeV3.textTheme.bodyMedium?.copyWith(
              color: AppThemeV3.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: AppThemeV3.textTheme.bodyMedium?.copyWith(
              color: AppThemeV3.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialLinks() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Connect With Us',
          style: AppThemeV3.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildSocialButton(
              icon: Icons.language,
              label: 'Website',
              onTap: () => _launchUrl('https://freshpunk.com'),
            ),
            _buildSocialButton(
              icon: Icons.email,
              label: 'Email',
              onTap: () => _launchEmail(),
            ),
            _buildSocialButton(
              icon: Icons.phone,
              label: 'Phone',
              onTap: () => _launchPhone(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppThemeV3.accent.withValues(alpha: 0.1),
              AppThemeV3.accent.withValues(alpha: 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppThemeV3.accent.withValues(alpha: 0.3),
            width: 1,
          ),
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
              style: AppThemeV3.textTheme.bodySmall?.copyWith(
                color: AppThemeV3.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVersionInfo() {
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
        children: [
          Text(
            'Version 1.0.0 (Build 100)',
            style: AppThemeV3.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '© 2024 FreshPunk Inc. All rights reserved.',
            style: AppThemeV3.textTheme.bodySmall?.copyWith(
              color: AppThemeV3.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _launchEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'hello@freshpunk.com',
      query: 'subject=Hello from FreshPunk App',
    );
    
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    }
  }

  void _launchPhone() async {
    final Uri phoneUri = Uri(
      scheme: 'tel',
      path: '+15551234567',
    );
    
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    }
  }
}

class Feature {
  final IconData icon;
  final String title;
  final String description;

  Feature({
    required this.icon,
    required this.title,
    required this.description,
  });
}
