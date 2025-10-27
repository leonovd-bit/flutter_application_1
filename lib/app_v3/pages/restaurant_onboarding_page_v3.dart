import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../theme/app_theme_v3.dart';
import '../services/auth/square_integration_service.dart';

class RestaurantOnboardingPageV3 extends StatefulWidget {
  const RestaurantOnboardingPageV3({super.key});

  @override
  State<RestaurantOnboardingPageV3> createState() => _RestaurantOnboardingPageV3State();
}

class _RestaurantOnboardingPageV3State extends State<RestaurantOnboardingPageV3> {
  final _formKey = GlobalKey<FormState>();
  final _restaurantNameController = TextEditingController();
  final _contactEmailController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  String _selectedBusinessType = 'restaurant';
  bool _isLoading = false;
  String? _oauthUrl;
  String? _applicationId;
  
  final List<String> _businessTypes = [
    'restaurant',
    'cafe',
    'bakery',
    'food_truck',
    'catering',
  ];

  @override
  void dispose() {
    _restaurantNameController.dispose();
    _contactEmailController.dispose();
    _contactPhoneController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeV3.background,
      appBar: AppBar(
        title: const Text('Restaurant Partner Registration'),
        backgroundColor: AppThemeV3.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
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
                Icon(
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
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Restaurant Address',
              hintText: 'Street address, city, state, zip',
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
              labelText: 'About Your Restaurant',
              hintText: 'Tell us about your cuisine, specialties, etc.',
              prefixIcon: const Icon(Icons.description),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          // Requirements Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppThemeV3.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppThemeV3.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.checklist, color: AppThemeV3.primaryGreen),
                    const SizedBox(width: 8),
                    Text(
                      'Requirements',
                      style: AppThemeV3.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('• Active Square POS account'),
                const Text('• Valid business license'),
                const Text('• Food safety certification'),
                const Text('• Delivery-ready menu items'),
              ],
            ),
          ),
          const SizedBox(height: 32),
          
          // Submit Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppThemeV3.primaryGreen,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      'Connect with Square',
                      style: AppThemeV3.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Validate eligibility
      final validation = SquareIntegrationService.validateRestaurantEligibility(
        restaurantName: _restaurantNameController.text.trim(),
        contactEmail: _contactEmailController.text.trim(),
        businessType: _selectedBusinessType,
      );

      if (!validation['isEligible']) {
        _showErrorDialog('Eligibility Check Failed', 
          validation['errors'].join('\n'));
        return;
      }

      // Initiate Square OAuth
      final result = await SquareIntegrationService.initiateRestaurantOnboarding(
        restaurantName: _restaurantNameController.text.trim(),
        contactEmail: _contactEmailController.text.trim(),
        contactPhone: _contactPhoneController.text.trim().isNotEmpty 
          ? _contactPhoneController.text.trim() : null,
      );

      if (result['success'] == true) {
        setState(() {
          _oauthUrl = result['oauthUrl'];
          _applicationId = result['applicationId'];
        });
        
        // Navigate to OAuth web view
        _showSquareOAuthDialog();
      } else {
        _showErrorDialog('Registration Failed', result['error'] ?? 'Unknown error');
      }

    } catch (e) {
      _showErrorDialog('Error', e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSquareOAuthDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Connect to Square'),
        content: SizedBox(
          width: 400,
          height: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('You will be redirected to Square to authorize FreshPunk access to your POS system.'),
              const SizedBox(height: 16),
              Expanded(
                child: WebViewWidget(
                  controller: WebViewController()
                    ..setJavaScriptMode(JavaScriptMode.unrestricted)
                    ..setNavigationDelegate(
                      NavigationDelegate(
                        onPageStarted: (String url) {
                          if (url.contains('freshpunk') || url.contains('localhost')) {
                            _handleOAuthCallback(url);
                            Navigator.of(context).pop();
                          }
                        },
                      ),
                    )
                    ..loadRequest(Uri.parse(_oauthUrl!)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _handleOAuthCallback(String callbackUrl) async {
    final params = SquareIntegrationService.parseOAuthCallback(callbackUrl);
    
    if (params['error'] != null) {
      _showErrorDialog('Authorization Failed', 
        params['error_description'] ?? 'Authorization was denied');
      return;
    }

    final code = params['code'];
    final state = params['state'];
    
    if (code == null || state == null) {
      _showErrorDialog('Authorization Failed', 'Invalid authorization response');
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      final result = await SquareIntegrationService.completeRestaurantOnboarding(
        authorizationCode: code,
        state: state,
      );

      if (result['success'] == true) {
        _showSuccessDialog(result['restaurantName'], result['restaurantId']);
      } else {
        _showErrorDialog('Setup Failed', result['error'] ?? 'Unknown error');
      }

    } catch (e) {
      _showErrorDialog('Error', e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String restaurantName, String restaurantId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('🎉 Welcome to FreshPunk!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$restaurantName has been successfully connected to FreshPunk!'),
            const SizedBox(height: 16),
            const Text('Your Square menu is now syncing. You can start receiving orders shortly.'),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
              // Navigate to restaurant dashboard
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppThemeV3.primaryGreen,
            ),
            child: const Text('Go to Dashboard', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}