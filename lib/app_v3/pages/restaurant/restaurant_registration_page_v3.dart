import 'package:flutter/material.dart';
import '../../theme/app_theme_v3.dart';
import '../../services/notifications/restaurant_notification_service.dart';
import '../restaurant_dashboard_simple_v3.dart';

class RestaurantRegistrationPageV3 extends StatefulWidget {
  const RestaurantRegistrationPageV3({super.key});

  @override
  State<RestaurantRegistrationPageV3> createState() => _RestaurantRegistrationPageV3State();
}

class _RestaurantRegistrationPageV3State extends State<RestaurantRegistrationPageV3> {
  final _formKey = GlobalKey<FormState>();
  final _restaurantNameController = TextEditingController();
  final _contactEmailController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  String _selectedBusinessType = 'restaurant';
  bool _isLoading = false;
  bool _emailNotifications = true;
  bool _smsNotifications = true;
  bool _dashboardNotifications = true;
  
  final List<Map<String, String>> _businessTypes = [
    {'value': 'restaurant', 'label': 'Restaurant'},
    {'value': 'cafe', 'label': 'Café'},
    {'value': 'bakery', 'label': 'Bakery'},
    {'value': 'food_truck', 'label': 'Food Truck'},
    {'value': 'catering', 'label': 'Catering Service'},
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
        title: const Text('Join FreshPunk Partner Network'),
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
                      'Simple Order Notifications',
                      style: AppThemeV3.textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Receive customer orders directly via email, SMS, and dashboard',
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
                  Icons.notifications_active,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'No POS Integration Required',
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
    final benefits = [
      {
        'icon': '📧',
        'title': 'Email Notifications',
        'description': 'Get detailed order information sent directly to your email',
      },
      {
        'icon': '📱',
        'title': 'SMS Alerts',
        'description': 'Instant text message alerts for new orders',
      },
      {
        'icon': '📊',
        'title': 'Simple Dashboard',
        'description': 'View all orders and track your restaurant performance',
      },
      {
        'icon': '🎯',
        'title': 'Direct Integration',
        'description': 'No complex POS setup - just receive notifications and fulfill orders',
      },
      {
        'icon': '💰',
        'title': 'Immediate Revenue',
        'description': 'Start receiving orders right away with simple setup',
      },
      {
        'icon': '🚀',
        'title': 'Quick Setup',
        'description': 'Get started in minutes, not hours or days',
      },
    ];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Why Partner with FreshPunk?',
          style: AppThemeV3.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppThemeV3.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.2,
          ),
          itemCount: benefits.length,
          itemBuilder: (context, index) {
            final benefit = benefits[index];
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppThemeV3.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppThemeV3.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    benefit['icon'] as String,
                    style: const TextStyle(fontSize: 24),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    benefit['title'] as String,
                    style: AppThemeV3.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppThemeV3.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Text(
                      benefit['description'] as String,
                      style: AppThemeV3.textTheme.bodySmall?.copyWith(
                        color: AppThemeV3.textSecondary,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
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
                value: type['value'],
                child: Text(type['label']!),
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
            onChanged: (value) {
              setState(() {
                _smsNotifications = value.isNotEmpty;
              });
            },
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
          
          // Notification Preferences
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
                    Icon(Icons.notifications, color: AppThemeV3.primaryGreen),
                    const SizedBox(width: 8),
                    Text(
                      'Notification Preferences',
                      style: AppThemeV3.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  title: const Text('Email Notifications'),
                  subtitle: const Text('Receive detailed order information via email'),
                  value: _emailNotifications,
                  onChanged: (value) {
                    setState(() {
                      _emailNotifications = value ?? false;
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                ),
                CheckboxListTile(
                  title: const Text('SMS Notifications'),
                  subtitle: Text(_contactPhoneController.text.isEmpty 
                    ? 'Add phone number to enable SMS' 
                    : 'Receive instant text alerts'),
                  value: _smsNotifications && _contactPhoneController.text.isNotEmpty,
                  onChanged: _contactPhoneController.text.isEmpty 
                    ? null 
                    : (value) {
                        setState(() {
                          _smsNotifications = value ?? false;
                        });
                      },
                  contentPadding: EdgeInsets.zero,
                ),
                CheckboxListTile(
                  title: const Text('Dashboard Notifications'),
                  subtitle: const Text('View orders in restaurant dashboard'),
                  value: _dashboardNotifications,
                  onChanged: (value) {
                    setState(() {
                      _dashboardNotifications = value ?? false;
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Requirements Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue.shade600),
                    const SizedBox(width: 8),
                    Text(
                      'How It Works',
                      style: AppThemeV3.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('1. Customers schedule meals from your restaurant'),
                const Text('2. You receive order notifications instantly'),
                const Text('3. Prepare meals for scheduled delivery time'),
                const Text('4. FreshPunk handles delivery and payment'),
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
                      'Join FreshPunk Network',
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

    // Validate notification preferences
    if (!_emailNotifications && !_smsNotifications && !_dashboardNotifications) {
      _showErrorDialog('Notification Preferences Required', 
        'Please enable at least one notification method to receive orders.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Validate data client-side
      final validation = RestaurantNotificationService.validateRestaurantData(
        restaurantName: _restaurantNameController.text.trim(),
        contactEmail: _contactEmailController.text.trim(),
        contactPhone: _contactPhoneController.text.trim().isNotEmpty 
          ? _contactPhoneController.text.trim() : null,
      );

      if (!validation['isValid']) {
        _showErrorDialog('Validation Error', 
          (validation['errors'] as List<String>).join('\n'));
        return;
      }

      // Register restaurant
      final result = await RestaurantNotificationService.registerRestaurant(
        restaurantName: _restaurantNameController.text.trim(),
        contactEmail: _contactEmailController.text.trim(),
        contactPhone: _contactPhoneController.text.trim().isNotEmpty 
          ? _contactPhoneController.text.trim() : null,
        address: _addressController.text.trim().isNotEmpty 
          ? _addressController.text.trim() : null,
        businessType: _selectedBusinessType,
        description: _descriptionController.text.trim().isNotEmpty 
          ? _descriptionController.text.trim() : null,
        notificationPreferences: {
          'email': _emailNotifications,
          'sms': _smsNotifications,
          'dashboard': _dashboardNotifications,
        },
      );

      if (result['success'] == true) {
        _showSuccessDialog(
          _restaurantNameController.text.trim(),
          result['restaurantId'],
        );
      } else {
        _showErrorDialog('Registration Failed', result['error'] ?? 'Unknown error');
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
            Text('$restaurantName has been successfully registered!'),
            const SizedBox(height: 16),
            const Text('You will now receive order notifications when customers schedule meals from your restaurant.'),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => RestaurantDashboardSimpleV3(
                    restaurantId: restaurantId,
                    restaurantName: restaurantName,
                  ),
                ),
              );
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