import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme_v3.dart';

class HelpSupportPageV3 extends StatelessWidget {
  const HelpSupportPageV3({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeV3.background,
      appBar: AppBar(
        backgroundColor: AppThemeV3.background,
        elevation: 0,
        title: Text(
          'Help & Support',
          style: AppThemeV3.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Quick Actions
            _buildQuickActions(context),
            
            const SizedBox(height: 24),
            
            // FAQ Section
            _buildFAQSection(context),
            
            const SizedBox(height: 24),
            
            // Contact Support
            _buildContactSupport(context),
            
            const SizedBox(height: 24),
            
            // App Information
            _buildAppInformation(context),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: AppThemeV3.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                context,
                icon: Icons.chat_bubble_outline,
                title: 'Live Chat',
                subtitle: 'Chat with our support team',
                onTap: () => _launchLiveChat(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                context,
                icon: Icons.email_outlined,
                title: 'Email Us',
                subtitle: 'Send us an email',
                onTap: () => _launchEmail(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
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
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: AppThemeV3.accent,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: AppThemeV3.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
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

  Widget _buildFAQSection(BuildContext context) {
    final faqs = [
      FAQ(
        question: 'How do I change my meal plan?',
        answer: 'You can change your meal plan by going to Settings > Meal Plan and selecting a new plan. Changes take effect with your next order.',
      ),
      FAQ(
        question: 'When will my meals be delivered?',
        answer: 'Meals are delivered based on your selected delivery schedule. You can track your order status in the Upcoming Orders section.',
      ),
      FAQ(
        question: 'How do I update my delivery address?',
        answer: 'Go to Settings > Addresses to add, edit, or remove delivery addresses. Make sure to set your preferred address as default.',
      ),
      FAQ(
        question: 'Can I pause my subscription?',
        answer: 'Yes, you can pause your subscription for up to 4 weeks. Contact support or manage it through your account settings.',
      ),
      FAQ(
        question: 'What if I have dietary restrictions?',
        answer: 'We offer various meal options including vegetarian, vegan, gluten-free, and more. Update your preferences in the app settings.',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Frequently Asked Questions',
          style: AppThemeV3.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 16),
        ...faqs.map((faq) => _buildFAQItem(context, faq)),
      ],
    );
  }

  Widget _buildFAQItem(BuildContext context, FAQ faq) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppThemeV3.surface,
            AppThemeV3.surface.withValues(alpha: 0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppThemeV3.accent.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: ExpansionTile(
        title: Text(
          faq.question,
          style: AppThemeV3.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              faq.answer,
              style: AppThemeV3.textTheme.bodyMedium?.copyWith(
                color: AppThemeV3.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactSupport(BuildContext context) {
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
                Icons.support_agent,
                color: AppThemeV3.accent,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Need More Help?',
                style: AppThemeV3.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppThemeV3.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Our support team is available 24/7 to help you with any questions or issues.',
            style: AppThemeV3.textTheme.bodyMedium?.copyWith(
              color: AppThemeV3.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _launchPhone(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppThemeV3.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.phone, size: 18),
                  label: const Text('Call Us'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _launchEmail(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppThemeV3.accent,
                    side: BorderSide(color: AppThemeV3.accent),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.email, size: 18),
                  label: const Text('Email'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAppInformation(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'App Information',
          style: AppThemeV3.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppThemeV3.surface,
                AppThemeV3.surface.withValues(alpha: 0.95),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppThemeV3.accent.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              _buildInfoRow('App Version', '1.0.0'),
              _buildInfoRow('Build Number', '100'),
              _buildInfoRow('Last Updated', 'July 29, 2025'),
              _buildInfoRow('Support Email', 'support@freshpunk.com'),
              _buildInfoRow('Support Phone', '+1 (555) 123-4567'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
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

  void _launchLiveChat() {
    // TODO: Integrate with chat service like Intercom, Zendesk, etc.
    _showComingSoonDialog();
  }

  void _launchEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'support@freshpunk.com',
      query: 'subject=Support Request&body=Please describe your issue here...',
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

  void _showComingSoonDialog() {
    // This would be implemented with proper context in a StatefulWidget
    // For now, this is a placeholder
  }
}

class FAQ {
  final String question;
  final String answer;

  FAQ({required this.question, required this.answer});
}
