import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart' hide PaymentMethod;
import 'package:firebase_auth/firebase_auth.dart';
import '../models/subscription.dart';
import '../models/user_profile.dart';
import '../services/stripe_service.dart';
import '../services/subscription_service.dart';
import '../services/user_service.dart';
import 'user_portal_page.dart';

class SubscriptionPaymentPage extends StatefulWidget {
  final SubscriptionPlan selectedPlan;
  
  const SubscriptionPaymentPage({
    super.key,
    required this.selectedPlan,
  });

  @override
  State<SubscriptionPaymentPage> createState() => _SubscriptionPaymentPageState();
}

class _SubscriptionPaymentPageState extends State<SubscriptionPaymentPage> {
  final _formKey = GlobalKey<FormState>();
  final _cardController = CardFormEditController();
  
  UserProfile? _userProfile;
  bool _isLoading = false;
  bool _isProcessingPayment = false;
  String? _errorMessage;
  
  // Form fields
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressLine1Controller = TextEditingController();
  final _addressLine2Controller = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _zipController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _cardController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _addressLine1Controller.dispose();
    _addressLine2Controller.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        _userProfile = await UserService.getUserProfile(user.uid);
        if (_userProfile != null) {
          _nameController.text = '${_userProfile!.firstName} ${_userProfile!.lastName}';
          _emailController.text = _userProfile!.email;
        }
      }
    } catch (e) {
      _showErrorSnackBar('Failed to load profile: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _processSubscription() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_cardController.details.complete) {
      _showErrorSnackBar('Please complete your card information');
      return;
    }

    setState(() {
      _isProcessingPayment = true;
      _errorMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Step 1: Create Stripe customer
      final customerData = await StripeService.createCustomer(
        email: _emailController.text.trim(),
        name: _nameController.text.trim(),
      );
      final customerId = customerData['id'];

      // Step 2: Create setup intent for saving payment method
      final setupIntentData = await StripeService.createSetupIntent(
        customerId: customerId,
      );
      final setupIntentClientSecret = setupIntentData['client_secret'];

      // Step 3: Confirm setup intent to save payment method
      final paymentResult = await StripeService.confirmSetupIntent(
        clientSecret: setupIntentClientSecret,
      );

      if (!paymentResult.success) {
        throw Exception(paymentResult.error ?? 'Payment setup failed');
      }

      final paymentMethodId = paymentResult.paymentMethodId;
      if (paymentMethodId == null) {
        throw Exception('Failed to create payment method');
      }

      // Step 4: Create Stripe subscription
      final subscriptionData = await StripeService.createSubscription(
        customerId: customerId,
        paymentMethodId: paymentMethodId,
        plan: widget.selectedPlan,
      );

      // Step 5: Create subscription record in Firestore
      final subscription = Subscription(
        id: '', // Will be set by Firestore
        userId: user.uid,
        plan: widget.selectedPlan,
        status: SubscriptionStatus.active,
        monthlyPrice: widget.selectedPlan.monthlyPrice,
        startDate: DateTime.now(),
        stripeSubscriptionId: subscriptionData['id'],
        stripeCustomerId: customerId,
        paymentMethod: PaymentMethod(
          stripePaymentMethodId: paymentMethodId,
          cardLast4: _cardController.details.last4 ?? '0000',
          cardBrand: _cardController.details.brand ?? 'unknown',
          expMonth: _cardController.details.expiryMonth ?? 0,
          expYear: _cardController.details.expiryYear ?? 0,
          isDefault: true,
        ),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await SubscriptionService.createSubscription(subscription);

      // Step 6: Update user profile with subscription plan
      if (_userProfile != null) {
        await UserService.updateSubscriptionPlan(
          user.uid,
          widget.selectedPlan == SubscriptionPlan.oneMeal ? '1-meal' : '2-meal',
        );
      }

      // Success - navigate to portal
      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
      _showErrorSnackBar('Payment failed: $e');
    } finally {
      setState(() {
        _isProcessingPayment = false;
      });
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 12),
            Text('Success!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Your ${widget.selectedPlan.displayName} subscription has been activated!'),
            const SizedBox(height: 16),
            const Text('You can now start planning your fresh meal deliveries.'),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const UserPortalPage()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('Subscription Payment'),
          backgroundColor: Colors.white,
          elevation: 0,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Complete Your Subscription',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Plan Summary
          _buildPlanSummary(),
          
          // Payment Form
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Billing Information
                    _buildBillingInformation(),
                    
                    const SizedBox(height: 32),
                    
                    // Payment Information
                    _buildPaymentInformation(),
                    
                    const SizedBox(height: 32),
                    
                    // Error Message
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red[200]!),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    
                    // Subscribe Button
                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isProcessingPayment ? null : _processSubscription,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isProcessingPayment
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text('Processing...'),
                                ],
                              )
                            : Text(
                                'Subscribe for \$${widget.selectedPlan.monthlyPrice}/month',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Security Notice
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.security, color: Colors.grey, size: 20),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Your payment information is secured with 256-bit SSL encryption',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanSummary() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).primaryColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.restaurant_menu,
                color: Theme.of(context).primaryColor,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.selectedPlan.displayName,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ),
              Text(
                '\$${widget.selectedPlan.monthlyPrice}/month',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.selectedPlan.description,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillingInformation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Billing Information',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        
        TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Full Name',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.person),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your full name';
            }
            return null;
          },
        ),
        
        const SizedBox(height: 16),
        
        TextFormField(
          controller: _emailController,
          decoration: const InputDecoration(
            labelText: 'Email',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.email),
          ),
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your email';
            }
            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
              return 'Please enter a valid email address';
            }
            return null;
          },
        ),
        
        const SizedBox(height: 16),
        
        TextFormField(
          controller: _addressLine1Controller,
          decoration: const InputDecoration(
            labelText: 'Address Line 1',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.home),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your address';
            }
            return null;
          },
        ),
        
        const SizedBox(height: 16),
        
        TextFormField(
          controller: _addressLine2Controller,
          decoration: const InputDecoration(
            labelText: 'Address Line 2 (Optional)',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.home),
          ),
        ),
        
        const SizedBox(height: 16),
        
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: _cityController,
                decoration: const InputDecoration(
                  labelText: 'City',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your city';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _stateController,
                decoration: const InputDecoration(
                  labelText: 'State',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Required';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _zipController,
                decoration: const InputDecoration(
                  labelText: 'ZIP',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Required';
                  }
                  if (value.length != 5) {
                    return 'Invalid ZIP';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPaymentInformation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Payment Information',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: CardFormField(
            controller: _cardController,
            style: CardFormStyle(
              backgroundColor: Colors.white,
              textColor: Colors.black,
              fontSize: 16,
              placeholderColor: Colors.grey[400],
            ),
          ),
        ),
      ],
    );
  }
}
