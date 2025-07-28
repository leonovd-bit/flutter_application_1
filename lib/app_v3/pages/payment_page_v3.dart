import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import '../theme/app_theme_v3.dart';
import '../models/meal_model_v3.dart';
import 'home_page_v3.dart';

class PaymentPageV3 extends StatefulWidget {
  final MealPlanModelV3 mealPlan;
  final Map<String, Map<String, dynamic>> weeklySchedule;
  final Map<String, Map<String, MealModelV3?>> selectedMeals;
  
  const PaymentPageV3({
    super.key,
    required this.mealPlan,
    required this.weeklySchedule,
    required this.selectedMeals,
  });

  @override
  State<PaymentPageV3> createState() => _PaymentPageV3State();
}

class _PaymentPageV3State extends State<PaymentPageV3> {
  bool _isProcessing = false;
  String _selectedPaymentMethod = 'card';
  
  // Calculate monthly price (weekly * 4.33 weeks per month on average)
  double get _monthlyPrice => widget.mealPlan.pricePerWeek * 4.33;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeV3.background,
      appBar: AppBar(
        backgroundColor: AppThemeV3.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Subscription Payment',
          style: AppThemeV3.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Subscription Summary
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppThemeV3.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppThemeV3.border),
                boxShadow: AppThemeV3.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Subscription Summary',
                    style: AppThemeV3.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Meal Plan Details
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.mealPlan.displayName,
                            style: AppThemeV3.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppThemeV3.accent,
                            ),
                          ),
                          Text(
                            widget.mealPlan.description,
                            style: AppThemeV3.textTheme.bodyMedium?.copyWith(
                              color: AppThemeV3.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppThemeV3.accent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${widget.mealPlan.mealsPerDay} meals/day',
                          style: AppThemeV3.textTheme.bodySmall?.copyWith(
                            color: AppThemeV3.accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  const Divider(color: AppThemeV3.border),
                  const SizedBox(height: 16),
                  
                  // Pricing
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Weekly Price',
                        style: AppThemeV3.textTheme.bodyLarge,
                      ),
                      Text(
                        '\$${widget.mealPlan.pricePerWeek.toStringAsFixed(2)}',
                        style: AppThemeV3.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Monthly Subscription',
                        style: AppThemeV3.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '\$${_monthlyPrice.toStringAsFixed(2)}',
                        style: AppThemeV3.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppThemeV3.accent,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Billing Info
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppThemeV3.accent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: AppThemeV3.accent,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Billed monthly. Cancel anytime.',
                            style: AppThemeV3.textTheme.bodySmall?.copyWith(
                              color: AppThemeV3.accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Payment Method Selection
            Text(
              'Payment Method',
              style: AppThemeV3.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            
            // Credit/Debit Card Option
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppThemeV3.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _selectedPaymentMethod == 'card' 
                      ? AppThemeV3.accent 
                      : AppThemeV3.border,
                  width: _selectedPaymentMethod == 'card' ? 2 : 1,
                ),
              ),
              child: RadioListTile<String>(
                value: 'card',
                groupValue: _selectedPaymentMethod,
                onChanged: (value) {
                  setState(() {
                    _selectedPaymentMethod = value!;
                  });
                },
                title: Row(
                  children: [
                    Icon(
                      Icons.credit_card,
                      color: AppThemeV3.accent,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Credit/Debit Card',
                      style: AppThemeV3.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                subtitle: const Padding(
                  padding: EdgeInsets.only(left: 36),
                  child: Text('Visa, MasterCard, American Express'),
                ),
                activeColor: AppThemeV3.accent,
              ),
            ),
            
            // PayPal Option
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppThemeV3.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _selectedPaymentMethod == 'paypal' 
                      ? AppThemeV3.accent 
                      : AppThemeV3.border,
                  width: _selectedPaymentMethod == 'paypal' ? 2 : 1,
                ),
              ),
              child: RadioListTile<String>(
                value: 'paypal',
                groupValue: _selectedPaymentMethod,
                onChanged: (value) {
                  setState(() {
                    _selectedPaymentMethod = value!;
                  });
                },
                title: Row(
                  children: [
                    Icon(
                      Icons.account_balance_wallet,
                      color: AppThemeV3.accent,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'PayPal',
                      style: AppThemeV3.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                subtitle: const Padding(
                  padding: EdgeInsets.only(left: 36),
                  child: Text('Pay with your PayPal account'),
                ),
                activeColor: AppThemeV3.accent,
              ),
            ),
            
            // Apple Pay Option (iOS)
            Container(
              decoration: BoxDecoration(
                color: AppThemeV3.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _selectedPaymentMethod == 'apple' 
                      ? AppThemeV3.accent 
                      : AppThemeV3.border,
                  width: _selectedPaymentMethod == 'apple' ? 2 : 1,
                ),
              ),
              child: RadioListTile<String>(
                value: 'apple',
                groupValue: _selectedPaymentMethod,
                onChanged: (value) {
                  setState(() {
                    _selectedPaymentMethod = value!;
                  });
                },
                title: Row(
                  children: [
                    Icon(
                      Icons.apple,
                      color: AppThemeV3.accent,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Apple Pay',
                      style: AppThemeV3.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                subtitle: const Padding(
                  padding: EdgeInsets.only(left: 36),
                  child: Text('Touch ID or Face ID'),
                ),
                activeColor: AppThemeV3.accent,
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Terms and Conditions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppThemeV3.surfaceElevated,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Subscription Terms',
                    style: AppThemeV3.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Monthly billing cycle\n'
                    '• Cancel anytime before next billing cycle\n'
                    '• Meals delivered according to your schedule\n'
                    '• 24/7 customer support',
                    style: AppThemeV3.textTheme.bodySmall?.copyWith(
                      color: AppThemeV3.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Start Subscription Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _startSubscription,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppThemeV3.accent,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isProcessing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'Start Subscription - \$${_monthlyPrice.toStringAsFixed(2)}/month',
                        style: AppThemeV3.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Security Notice
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock_outline,
                  color: AppThemeV3.textSecondary,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  'Secured by Stripe',
                  style: AppThemeV3.textTheme.bodySmall?.copyWith(
                    color: AppThemeV3.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startSubscription() async {
    setState(() => _isProcessing = true);

    try {
      switch (_selectedPaymentMethod) {
        case 'card':
          await _processCardPayment();
          break;
        case 'paypal':
          await _processPayPalPayment();
          break;
        case 'apple':
          await _processApplePayment();
          break;
      }
      
      // If payment successful, navigate to home
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => const HomePageV3(),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment failed: ${e.toString()}'),
            backgroundColor: AppThemeV3.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _processCardPayment() async {
    // Initialize payment sheet
    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        merchantDisplayName: 'FreshPunk',
        paymentIntentClientSecret: 'your_payment_intent_client_secret', // Get from backend
        customerEphemeralKeySecret: 'your_ephemeral_key', // Get from backend
        customerId: 'your_customer_id', // Get from backend
        setupIntentClientSecret: 'your_setup_intent_client_secret', // For subscriptions
        allowsDelayedPaymentMethods: true,
      ),
    );

    // Present payment sheet
    await Stripe.instance.presentPaymentSheet();
    
    // If we get here, payment was successful
    await _saveSubscriptionToFirebase();
  }

  Future<void> _processPayPalPayment() async {
    // Implement PayPal integration
    // For now, simulate successful payment
    await Future.delayed(const Duration(seconds: 2));
    await _saveSubscriptionToFirebase();
  }

  Future<void> _processApplePayment() async {
    // Implement Apple Pay integration
    // For now, simulate successful payment
    await Future.delayed(const Duration(seconds: 2));
    await _saveSubscriptionToFirebase();
  }

  Future<void> _saveSubscriptionToFirebase() async {
    // Save subscription data to Firebase
    // This would include:
    // - User's meal plan
    // - Weekly schedule
    // - Selected meals
    // - Payment method
    // - Subscription status
    
    // For now, just simulate the save
    await Future.delayed(const Duration(seconds: 1));
  }
}
