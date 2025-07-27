import 'package:flutter/material.dart';

class TermsOfServicePage extends StatelessWidget {
  const TermsOfServicePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms of Service'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Text(
              'Terms of Service',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Last updated: ${_formatDate(DateTime.now())}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),

            // Introduction
            _buildSection(
              title: '1. Introduction',
              content: 'Welcome to FreshPunk! These Terms of Service ("Terms") govern your use of our meal delivery service and mobile application. By using our service, you agree to these terms.',
            ),

            // Service Description
            _buildSection(
              title: '2. Service Description',
              content: 'FreshPunk provides a subscription-based meal delivery service that offers fresh, healthy meals delivered to your specified address. Our service includes:\n\n• Daily meal deliveries based on your subscription plan\n• Mobile app access for managing your account\n• Customer support and meal customization options',
            ),

            // Subscription Terms
            _buildSection(
              title: '3. Subscription Terms',
              content: 'Our service operates on a subscription basis with the following terms:\n\n• Subscriptions auto-renew monthly unless cancelled\n• You can change or cancel your subscription at any time\n• Changes take effect at the next billing cycle\n• Refunds are provided according to our refund policy',
            ),

            // Payment Terms
            _buildSection(
              title: '4. Payment Terms',
              content: 'Payment terms for our service:\n\n• Subscription fees are charged monthly in advance\n• We accept major credit cards and digital payment methods\n• Failed payments may result in service suspension\n• You are responsible for keeping payment information current',
            ),

            // Delivery Terms
            _buildSection(
              title: '5. Delivery Terms',
              content: 'Delivery terms and conditions:\n\n• We deliver to addresses within our service area\n• Delivery times are estimates and may vary\n• You must provide accurate delivery information\n• Special delivery instructions should be noted in your account\n• We are not responsible for meals left unattended per your instructions',
            ),

            // Food Safety
            _buildSection(
              title: '6. Food Safety and Quality',
              content: 'Food safety and quality standards:\n\n• All meals are prepared in licensed commercial kitchens\n• We follow strict food safety protocols\n• Meals should be consumed within recommended timeframes\n• Report any quality issues within 24 hours of delivery\n• We are not liable for allergic reactions - please check ingredients carefully',
            ),

            // User Responsibilities
            _buildSection(
              title: '7. User Responsibilities',
              content: 'As a user of our service, you agree to:\n\n• Provide accurate account and delivery information\n• Pay all fees associated with your subscription\n• Use the service only for personal, non-commercial purposes\n• Not share your account credentials with others\n• Comply with all applicable laws and regulations',
            ),

            // Privacy Policy
            _buildSection(
              title: '8. Privacy Policy',
              content: 'Your privacy is important to us. Our Privacy Policy explains how we collect, use, and protect your information. By using our service, you consent to our data practices as described in our Privacy Policy.',
            ),

            // Intellectual Property
            _buildSection(
              title: '9. Intellectual Property',
              content: 'All content in our app and service, including recipes, text, graphics, logos, and images, are owned by FreshPunk or our licensors and are protected by copyright and other intellectual property laws.',
            ),

            // Limitation of Liability
            _buildSection(
              title: '10. Limitation of Liability',
              content: 'To the maximum extent permitted by law, FreshPunk shall not be liable for any indirect, incidental, special, or consequential damages arising from your use of our service.',
            ),

            // Termination
            _buildSection(
              title: '11. Termination',
              content: 'Either party may terminate this agreement at any time. Upon termination:\n\n• Your access to the service will be discontinued\n• You remain responsible for any outstanding charges\n• These terms will continue to apply to past use of the service',
            ),

            // Changes to Terms
            _buildSection(
              title: '12. Changes to Terms',
              content: 'We may update these Terms from time to time. We will notify you of material changes through the app or via email. Your continued use of the service after changes constitutes acceptance of the new terms.',
            ),

            // Governing Law
            _buildSection(
              title: '13. Governing Law',
              content: 'These Terms are governed by the laws of the jurisdiction where FreshPunk operates. Any disputes will be resolved in the courts of that jurisdiction.',
            ),

            // Contact Information
            _buildSection(
              title: '14. Contact Information',
              content: 'If you have questions about these Terms, please contact us:\n\nFreshPunk Customer Service\nEmail: legal@freshpunk.com\nPhone: 1-800-FRESH-PUNK\nAddress: 123 Healthy Street, Fresh City, FC 12345',
            ),

            const SizedBox(height: 32),

            // Acceptance Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Thank you for reviewing our Terms of Service'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text(
                  'I Understand',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Additional Links
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Related Documents',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildLinkItem(
                      icon: Icons.privacy_tip_outlined,
                      title: 'Privacy Policy',
                      subtitle: 'How we handle your personal information',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Privacy Policy page would open here')),
                        );
                      },
                    ),
                    const Divider(),
                    _buildLinkItem(
                      icon: Icons.cookie_outlined,
                      title: 'Cookie Policy',
                      subtitle: 'Information about our use of cookies',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Cookie Policy page would open here')),
                        );
                      },
                    ),
                    const Divider(),
                    _buildLinkItem(
                      icon: Icons.assignment_return_outlined,
                      title: 'Refund Policy',
                      subtitle: 'Our refund and cancellation policy',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Refund Policy page would open here')),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required String content}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: const TextStyle(
            fontSize: 14,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildLinkItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            Icon(icon, color: Colors.blue),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.blue,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.blue),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
