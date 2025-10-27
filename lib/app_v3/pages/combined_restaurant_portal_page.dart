import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme_v3.dart';
import '../services/auth/square_integration_service.dart';
import '../utils/web_utils.dart';

/// Comprehensive Restaurant Portal that combines onboarding and ongoing portal features
class CombinedRestaurantPortalPage extends StatefulWidget {
  const CombinedRestaurantPortalPage({super.key});

  @override
  State<CombinedRestaurantPortalPage> createState() => _CombinedRestaurantPortalPageState();
}

class _CombinedRestaurantPortalPageState extends State<CombinedRestaurantPortalPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Form controllers for onboarding
  final _formKey = GlobalKey<FormState>();
  final _restaurantNameController = TextEditingController();
  final _contactEmailController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  String _selectedBusinessType = 'restaurant';
  bool _isLoading = false;
  bool _isPartnerAlready = false;
  
  final List<String> _businessTypes = [
    'restaurant',
    'cafe',
    'bakery',
    'food_truck',
    'catering',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _checkPartnerStatus();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _restaurantNameController.dispose();
    _contactEmailController.dispose();
    _contactPhoneController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _checkPartnerStatus() {
    // In a real app, this would check if the restaurant is already a partner
    // For now, we'll assume they're not a partner yet
    setState(() {
      _isPartnerAlready = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeV3.background,
      appBar: AppBar(
        title: const Text('FreshPunk Restaurant Partnership'),
        backgroundColor: AppThemeV3.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.handshake), text: 'Join Partnership'),
            Tab(icon: Icon(Icons.schedule), text: 'Prep Schedules'),
            Tab(icon: Icon(Icons.settings), text: 'Portal Settings'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOnboardingTab(),
          _buildPrepSchedulesTab(),
          _buildPortalSettingsTab(),
        ],
      ),
    );
  }

  Widget _buildOnboardingTab() {
    if (_isPartnerAlready) {
      return _buildAlreadyPartnerView();
    }
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderSection(),
          const SizedBox(height: 24),
          _buildBenefitsSection(),
          const SizedBox(height: 32),
          _buildRegistrationForm(),
        ],
      ),
    );
  }

  Widget _buildAlreadyPartnerView() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text(
                  'Welcome Back, Partner!',
                  style: AppThemeV3.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You\'re already a FreshPunk restaurant partner. Use the tabs above to manage your prep schedules and portal settings.',
                  textAlign: TextAlign.center,
                  style: AppThemeV3.textTheme.bodyMedium?.copyWith(
                    color: Colors.green.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppThemeV3.primaryGreen,
            AppThemeV3.primaryGreen.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.restaurant_menu,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Partner with FreshPunk',
                      style: AppThemeV3.textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Connect your Square POS and reach more customers',
                      style: AppThemeV3.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.square,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Powered by Square Integration',
                  style: AppThemeV3.textTheme.bodySmall?.copyWith(
                    color: Colors.white,
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

  Widget _buildBenefitsSection() {
    final benefits = SquareIntegrationService.getIntegrationBenefits();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Why Partner with Us?',
          style: AppThemeV3.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppThemeV3.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        ...benefits.map((benefit) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                benefit['icon'] as String,
                style: const TextStyle(fontSize: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      benefit['title'] as String,
                      style: AppThemeV3.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppThemeV3.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      benefit['description'] as String,
                      style: AppThemeV3.textTheme.bodySmall?.copyWith(
                        color: AppThemeV3.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        )).toList(),
      ],
    );
  }

  Widget _buildRegistrationForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Restaurant Information',
            style: AppThemeV3.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppThemeV3.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          
          // Restaurant Name
          TextFormField(
            controller: _restaurantNameController,
            decoration: InputDecoration(
              labelText: 'Restaurant Name *',
              hintText: 'Enter your restaurant name',
              prefixIcon: const Icon(Icons.restaurant),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Restaurant name is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          
          // Business Type
          DropdownButtonFormField<String>(
            value: _selectedBusinessType,
            decoration: InputDecoration(
              labelText: 'Business Type',
              prefixIcon: const Icon(Icons.business),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            items: _businessTypes.map((type) {
              return DropdownMenuItem(
                value: type,
                child: Text(type.split('_').map((word) => 
                  word[0].toUpperCase() + word.substring(1)).join(' ')),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedBusinessType = value!;
              });
            },
          ),
          const SizedBox(height: 16),
          
          // Contact Email
          TextFormField(
            controller: _contactEmailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Contact Email *',
              hintText: 'your@email.com',
              prefixIcon: const Icon(Icons.email),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Email is required';
              }
              if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value)) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          
          // Contact Phone
          TextFormField(
            controller: _contactPhoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'Contact Phone',
              hintText: '+1 (555) 123-4567',
              prefixIcon: const Icon(Icons.phone),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Address
          TextFormField(
            controller: _addressController,
            decoration: InputDecoration(
              labelText: 'Restaurant Address',
              hintText: '123 Main St, City, State 12345',
              prefixIcon: const Icon(Icons.location_on),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Description
          TextFormField(
            controller: _descriptionController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Restaurant Description',
              hintText: 'Tell us about your restaurant, cuisine type, specialties...',
              prefixIcon: const Icon(Icons.description),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          // Submit Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _startSquareOnboarding,
              icon: _isLoading 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.square),
              label: Text(_isLoading ? 'Connecting...' : 'Connect with Square'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppThemeV3.primaryGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrepSchedulesTab() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Weekly Prep Schedules',
            style: AppThemeV3.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              children: [
                Icon(Icons.schedule, size: 48, color: Colors.blue.shade600),
                const SizedBox(height: 16),
                Text(
                  'Prep Schedules Coming Soon',
                  style: AppThemeV3.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Once you\'re connected as a partner, you\'ll receive weekly prep schedules here showing which meals to prepare for FreshPunk customers.',
                  textAlign: TextAlign.center,
                  style: AppThemeV3.textTheme.bodyMedium?.copyWith(
                    color: Colors.blue.shade600,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => _tabController.animateTo(0),
                  child: const Text('Join Partnership First'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPortalSettingsTab() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Portal Settings',
            style: AppThemeV3.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // Square Integration Status
          Card(
            child: ListTile(
              leading: const Icon(Icons.square, color: Colors.blue),
              title: const Text('Square Integration'),
              subtitle: const Text('Connect your Square POS system'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: _viewSquareIntegration,
            ),
          ),
          
          // Support
          Card(
            child: ListTile(
              leading: const Icon(Icons.support_agent, color: Colors.green),
              title: const Text('Contact Support'),
              subtitle: const Text('Get help with partnership questions'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: _contactSupport,
            ),
          ),
          
          // Documentation
          Card(
            child: ListTile(
              leading: const Icon(Icons.description, color: Colors.orange),
              title: const Text('Partnership Guide'),
              subtitle: const Text('Learn about FreshPunk partnership'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: _openPartnershipGuide,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startSquareOnboarding() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Check if user is authenticated first
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        // Show authentication required dialog
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('🔐 Authentication Required'),
              content: const Text(
                'To complete restaurant partnership setup, you need to be signed in.\n\n'
                'This helps us:\n'
                '• Secure your restaurant information\n'
                '• Connect your Square account safely\n'
                '• Send you important partnership updates\n\n'
                'Would you like to sign in now?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Later'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/');
                  },
                  child: const Text('Sign In'),
                ),
              ],
            ),
          );
        }
        return;
      }

      final result = await SquareIntegrationService.initiateRestaurantOnboarding(
        restaurantName: _restaurantNameController.text.trim(),
        contactEmail: _contactEmailController.text.trim(),
        contactPhone: _contactPhoneController.text.trim(),
      );

      if (result['success'] == true && result['oauthUrl'] != null) {
        // Show success dialog
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('🎉 Ready to Connect!'),
              content: Text(
                'Great! We\'ve prepared your Square integration.\n\n'
                'Restaurant: ${_restaurantNameController.text}\n'
                'Email: ${_contactEmailController.text}\n\n'
                'You\'ll now be redirected to Square to complete the connection.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    WebUtils.openUrl(result['oauthUrl']);
                  },
                  child: const Text('Continue to Square'),
                ),
              ],
            ),
          );
        }
      } else {
        throw Exception(result['message'] ?? 'Failed to initiate Square onboarding');
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _viewSquareIntegration() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🔗 Square Integration'),
        content: const Text(
          'Square Integration Status:\n\n'
          '✅ OAuth Flow: Ready\n'
          '✅ Menu Sync: Available\n'
          '✅ Order Forwarding: Ready\n'
          '💰 Commission: 10% FreshPunk, 90% Restaurant\n\n'
          'Complete the partnership onboarding to activate your Square integration.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _contactSupport() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('📧 Contact Support'),
        content: const Text(
          'FreshPunk Partnership Support:\n\n'
          'Email: partners@freshpunk.com\n'
          'Phone: (555) 123-4567\n'
          'Hours: Mon-Fri 9AM-6PM\n\n'
          'For urgent issues, call our 24/7 support line.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _openPartnershipGuide() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('📖 Partnership Guide'),
        content: const Text(
          'FreshPunk Restaurant Partnership:\n\n'
          '1. Complete onboarding form\n'
          '2. Connect your Square POS\n'
          '3. Sync your menu items\n'
          '4. Receive weekly prep schedules\n'
          '5. Process customer orders through Square\n\n'
          'Commission: 10% to FreshPunk, 90% to you\n'
          'Support: Available 24/7',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}