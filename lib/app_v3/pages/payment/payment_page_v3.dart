import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme_v3.dart';
import '../../models/meal_model_v3.dart';
import '../home_page_v3.dart';
import '../../services/auth/progress_manager.dart';
import '../../services/auth/firestore_service_v3.dart';
import '../../services/meals/scheduler_service_v3.dart';
import '../../services/orders/order_generation_service.dart';
import '../../services/payment/stripe_service.dart';
import '../../services/payment/square_web_payments.dart';
import '../../services/billing/pricing_service.dart';
import '../../services/billing/invoicing_service.dart';
import '../../config/feature_flags.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/mock_user_model.dart';
import 'package:flutter/foundation.dart';
import '../../widgets/swipeable_page.dart';

class PaymentPageV3 extends StatefulWidget {
  final MealPlanModelV3 mealPlan;
  final Map<String, Map<String, dynamic>> weeklySchedule;
  final Map<String, Map<String, MealModelV3?>> selectedMeals;
  final MockUser? mockUser;
  
  const PaymentPageV3({
    super.key,
    required this.mealPlan,
    required this.weeklySchedule,
    required this.selectedMeals,
    this.mockUser,
  });

  @override
  State<PaymentPageV3> createState() => _PaymentPageV3State();
}

class _PaymentPageV3State extends State<PaymentPageV3> {
  MockUser? _mockUser;
  bool _isProcessing = false;
  String _selectedPaymentMethod = 'card';
  bool _squareInitializing = false;
  bool _squareReady = false;
  String? _squareError;
  String? _squareRestaurantId;
  bool _squareInitScheduled = false;
  final bool _squarePaymentsEnabled = FeatureFlags.enableSquarePayments;

  @override
  void initState() {
    super.initState();
    _mockUser = widget.mockUser;
  }
  @override
  Widget build(BuildContext context) {
  final pricing = _calculatePricing();

  if (_squarePaymentsEnabled && pricing != null && !_squareReady && !_squareInitializing && !_squareInitScheduled) {
    final restaurantId = _getSingleRestaurantId(_getSelectedMeals(), throwOnMultiple: false);
    if (restaurantId != null) {
      _squareInitScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) {
          _squareInitScheduled = false;
          return;
        }
        try {
          await _ensureSquareReady(restaurantId);
        } finally {
          _squareInitScheduled = false;
        }
      });
    }
  }

  return SwipeablePage(
    child: Scaffold(
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
                          color: AppThemeV3.accent.withValues(alpha: 0.1),
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
                  
                  // Dynamic Pricing Breakdown
                  _buildPricingBreakdown(pricing),
                  
                  const SizedBox(height: 16),
                  const Divider(color: AppThemeV3.border),
                  const SizedBox(height: 16),
                  if (pricing != null)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Subscription Total',
                          style: AppThemeV3.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '\$${pricing.totalAmount.toStringAsFixed(2)}',
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
                      color: AppThemeV3.accent.withValues(alpha: 0.1),
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
                            'Billed weekly. Cancel anytime.',
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
            if (kIsWeb && _squarePaymentsEnabled) ...[
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
                      'Card for Meals + Delivery (Square)',
                      style: AppThemeV3.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This card is charged by the kitchen via Square for meals and delivery.',
                      style: AppThemeV3.textTheme.bodySmall?.copyWith(
                        color: AppThemeV3.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppThemeV3.border),
                      ),
                      child: SizedBox(
                        height: 56,
                        child: SquareWebPayments.instance.buildCardView(),
                      ),
                    ),
                    if (_squareError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _squareError!,
                        style: AppThemeV3.textTheme.bodySmall?.copyWith(
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
            if (!kIsWeb && _squarePaymentsEnabled) ...[
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
                      'Card for Meals + Delivery (Square)',
                      style: AppThemeV3.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You will enter a card for Square on the next step.',
                      style: AppThemeV3.textTheme.bodySmall?.copyWith(
                        color: AppThemeV3.textSecondary,
                      ),
                    ),
                    if (_squareError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _squareError!,
                        style: AppThemeV3.textTheme.bodySmall?.copyWith(
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],

            if (!_squarePaymentsEnabled) ...[
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
                      'Square payments temporarily disabled',
                      style: AppThemeV3.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You will be charged via Stripe only for now.',
                      style: AppThemeV3.textTheme.bodySmall?.copyWith(
                        color: AppThemeV3.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],

            // Start Subscription Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isProcessing || pricing == null ? null : _startSubscription,
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
                        'Start Subscription - \$${pricing?.totalAmount.toStringAsFixed(2) ?? '--'}',
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
                  'Secured by Stripe & Square',
                  style: AppThemeV3.textTheme.bodySmall?.copyWith(
                    color: AppThemeV3.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      ),
    );
  }
  Future<void> _startSubscription() async {
    setState(() => _isProcessing = true);

    try {
      // 1. Calculate upfront pricing based on meal selections
      debugPrint('[Payment] Calculating upfront pricing...');
      final selectedMealsList = _getSelectedMeals();
      final mealCount = _countMeals();

      if (selectedMealsList.isEmpty) {
        throw Exception('No meals selected');
      }

      final pricing = PricingService.calculateSubscriptionPrice(
        selectedMeals: selectedMealsList,
        mealCount: mealCount,
        stripeOnly: !_squarePaymentsEnabled,
      );

      debugPrint('[Payment] Pricing calculated: \$${pricing.totalAmount.toStringAsFixed(2)}');
      debugPrint('[Payment] ${pricing.toMap()}');

      final restaurantId = _getSingleRestaurantId(selectedMealsList);
      if (restaurantId == null) {
        throw Exception('Missing restaurant for selected meals');
      }

      setState(() {
        _squareError = null;
      });

      if (_squarePaymentsEnabled) {
        // 2. Tokenize Square card and store card on file
        final squareSourceId = await _tokenizeSquareCard(restaurantId);
        final squareAmountCents = (pricing.squareChargeTotal * 100).round();

        final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
        final storeCardCallable = functions.httpsCallable('storeSquareCardForSubscription');
        final storeCardResult = await storeCardCallable.call({
          'restaurantId': restaurantId,
          'sourceId': squareSourceId,
          'customerEmail': FirebaseAuth.instance.currentUser?.email ?? '',
          'customerName': FirebaseAuth.instance.currentUser?.displayName ?? '',
        });
        final storeCardData = storeCardResult.data as Map<dynamic, dynamic>;
        final squareCardId = storeCardData['squareCardId'] as String?;
        if (squareCardId == null || squareCardId.isEmpty) {
          throw Exception('Failed to store Square card for recurring billing');
        }

        // 3. Charge meals + delivery via Square using stored card
        final squareCallable = functions.httpsCallable('chargeSquareForSubscription');
        final squareResult = await squareCallable.call({
          'restaurantId': restaurantId,
          'amountCents': squareAmountCents,
          'cardId': squareCardId,
          'idempotencyKey': 'fp_sub_${DateTime.now().millisecondsSinceEpoch}',
          'customerEmail': FirebaseAuth.instance.currentUser?.email ?? '',
          'customerName': FirebaseAuth.instance.currentUser?.displayName ?? '',
        });

        final squareData = squareResult.data as Map<dynamic, dynamic>;
        if (squareData['success'] != true) {
          throw Exception('Square payment failed');
        }
      }

      // 4. Add payment method via Stripe
      debugPrint('[Payment] Presenting Stripe payment sheet...');
      final StripeService stripe = StripeService.instance;
      final paymentAdded = await stripe.addPaymentMethod(context);

      if (!paymentAdded) {
        setState(() => _isProcessing = false);
        return;
      }

      final userId = _mockUser?.uid ?? FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Create Stripe customer using StripeService
      debugPrint('[Payment] Payment processing initiated for user: $userId');
      final user = FirebaseAuth.instance.currentUser;
      final email = user?.email ?? '';
      final name = user?.displayName;
      
      String? customerId;
      try {
        // Call createCustomer Cloud Function to ensure customer exists
        final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
        final callable = functions.httpsCallable('createCustomer');
        final result = await callable.call({
          'email': email,
          if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
        });
        final data = result.data as Map?;
        final customer = (data?['customer'] as Map?) ?? {};
        customerId = customer['id'] as String?;
        if (customerId == null) {
          throw Exception('Failed to create Stripe customer - no customer ID returned');
        }
        debugPrint('[Payment] Stripe customer created: $customerId');
        
        // Save Stripe customer ID to user profile
        await FirebaseFirestore.instance.collection('users').doc(userId).set({
          'stripeCustomerId': customerId,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        debugPrint('[Payment] Stripe customer ID saved to user profile');
      } catch (e) {
        debugPrint('[Payment] Error creating Stripe customer: $e');
        throw Exception('Failed to create Stripe customer: $e');
      }
      
      // 4. Create invoice for upfront billing
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✓ Processing payment...'),
            backgroundColor: AppThemeV3.success,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      
      // Create invoice with calculated pricing
      final invoicingService = InvoicingService();
      final formattedMealSelections = _formatMealSelections();
      
      final invoiceId = await invoicingService.createSubscriptionInvoice(
        customerId: customerId,
        pricing: pricing,
        mealSelections: formattedMealSelections,
        deliverySchedule: _formatDeliverySchedule(),
      );
      
      debugPrint('[Payment] Invoice created: $invoiceId, Amount: \$${pricing.totalAmount.toStringAsFixed(2)}');

      // Persist meal selections and subscription status for recurring billing
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('meal_selections')
          .doc('current')
          .set({
        'mealSelections': formattedMealSelections,
        'mealCount': pricing.mealCount,
        'restaurantId': restaurantId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final nextBillingDate = DateTime.now().add(const Duration(days: 7));
      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'subscriptionStatus': 'active',
        'subscriptionStartedAt': FieldValue.serverTimestamp(),
        'nextBillingDate': Timestamp.fromDate(nextBillingDate),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      // PERSIST DELIVERY SCHEDULE TO FIREBASE
      try {
        // Convert weekly schedule to DeliveryScheduleModelV3 list
        final List<DeliveryScheduleModelV3> schedules = [];
        final now = DateTime.now();
        final weekStart = now.subtract(Duration(days: now.weekday - DateTime.monday));
        
        widget.weeklySchedule.forEach((day, mealMap) {
          mealMap.forEach((mealType, cfg) {
            final enabled = (cfg['enabled'] ?? true) == true;
            if (!enabled) return;
            
            final timeVal = cfg['time'];
            int hour = 12, minute = 0;
            if (timeVal is String) {
              final parts = timeVal.split(':');
              if (parts.length == 2) {
                hour = int.tryParse(parts[0]) ?? 12;
                minute = int.tryParse(parts[1]) ?? 0;
              }
            }
            
            final id = '${day.toLowerCase()}_${mealType.toString().toLowerCase()}';
            schedules.add(DeliveryScheduleModelV3(
              id: id,
              userId: userId,
              dayOfWeek: day.toLowerCase(),
              mealType: mealType.toString().toLowerCase(),
              deliveryTime: TimeOfDay(hour: hour, minute: minute),
              addressId: 'default',
              isActive: true,
              weekStartDate: weekStart,
            ));
          });
        });
        
        // Save to Firebase
        await FirestoreServiceV3.replaceActiveDeliverySchedules(userId, schedules);
        debugPrint('[Payment] ✓ Delivery schedules persisted to Firebase (${schedules.length} schedules)');
      } catch (e) {
        debugPrint('[Payment] Warning: Failed to persist delivery schedules: $e');
        // Don't fail the whole flow if this fails
      }
      
      // 5. Generate orders from meal selections
      try {
        debugPrint('[Payment] Starting order generation for user: $userId');
        
        final result = await OrderGenerationService.generateOrdersFromMealSelection(
          mealSelections: formattedMealSelections,
          deliverySchedule: widget.weeklySchedule,
          deliveryAddress: 'default',
        );
        
        if (result['success'] == true) {
          debugPrint('[Payment] Successfully generated ${result['ordersGenerated'] ?? 0} orders');
        } else {
          debugPrint('[Payment] Order generation failed: ${result['error'] ?? 'Unknown error'}');
        }
      } catch (e) {
        debugPrint('[Payment] Failed to generate orders: $e');
      }
      
      // 5. Mark setup as completed
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('setup_completed', true);
        await ProgressManager.saveCurrentStep(OnboardingStep.completed);
        await ProgressManager.clearOnboardingProgress();
      } catch (e) {
        debugPrint('[Payment] Error marking setup completed: $e');
      }
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('🎉 Subscription created! Welcome to FreshPunk!'),
            backgroundColor: AppThemeV3.success,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      
      // Navigate to home
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
            content: Text('Subscription creation failed: ${e.toString()}'),
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

  /// Get list of selected meals
  List<MealModelV3> _getSelectedMeals() {
    final meals = <MealModelV3>[];
    widget.selectedMeals.forEach((day, mealMap) {
      mealMap.forEach((mealType, meal) {
        if (meal != null) {
          meals.add(meal);
        }
      });
    });
    return meals;
  }

  /// Count total number of meals selected
  int _countMeals() {
    int count = 0;
    widget.selectedMeals.forEach((day, mealMap) {
      count += mealMap.values.where((m) => m != null).length;
    });
    return count;
  }

  String? _getSingleRestaurantId(List<MealModelV3> meals, {bool throwOnMultiple = true}) {
    final ids = meals
        .map((meal) => meal.restaurantId)
        .whereType<String>()
        .toSet();

    if (ids.isEmpty) {
      return null;
    }

    if (ids.length > 1) {
      if (throwOnMultiple) {
        throw Exception('Multiple kitchens are not supported for a single checkout yet');
      }
      return null;
    }

    return ids.first;
  }

  Future<void> _ensureSquareReady(String restaurantId) async {
    if (_squareReady && _squareRestaurantId == restaurantId) {
      return;
    }

    if (_squareInitializing) {
      return;
    }

    setState(() {
      _squareInitializing = true;
      _squareError = null;
    });

    try {
      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
      final configCallable = functions.httpsCallable('getSquarePaymentConfig');
      final restaurantCallable = functions.httpsCallable('getRestaurantPaymentConfig');

      final configResult = await configCallable.call();
      final configData = configResult.data as Map<dynamic, dynamic>;
      final applicationId = configData['applicationId'] as String?;
      final env = configData['env'] as String? ?? 'production';

      if (applicationId == null || applicationId.trim().isEmpty) {
        throw Exception('Square application ID is not configured');
      }

      final restaurantResult = await restaurantCallable.call({'restaurantId': restaurantId});
      final restaurantData = restaurantResult.data as Map<dynamic, dynamic>;
      final locationId = restaurantData['squareLocationId'] as String?;

      if (locationId == null || locationId.trim().isEmpty) {
        throw Exception('Restaurant is missing Square location ID');
      }

      await SquareWebPayments.instance.initialize(
        applicationId: applicationId,
        locationId: locationId,
        env: env,
      );

      setState(() {
        _squareReady = true;
        _squareRestaurantId = restaurantId;
      });
    } catch (e) {
      setState(() {
        _squareError = e.toString();
      });
      rethrow;
    } finally {
      if (mounted) {
        setState(() {
          _squareInitializing = false;
        });
      }
    }
  }

  Future<String> _tokenizeSquareCard(String restaurantId) async {
    await _ensureSquareReady(restaurantId);
    return SquareWebPayments.instance.tokenize();
  }

  /// Format meal selections for Cloud Function
  List<Map<String, dynamic>> _formatMealSelections() {
    final formattedMealSelections = <Map<String, dynamic>>[];
    widget.selectedMeals.forEach((day, mealMap) {
      mealMap.forEach((mealType, meal) {
        if (meal != null) {
          formattedMealSelections.add({
            'day': day,
            'mealType': mealType,
            'id': meal.id,
            'name': meal.name,
            'description': meal.description,
            'calories': meal.calories,
            'protein': meal.protein,
            'imageUrl': meal.imagePath,
            'price': meal.price,
            if (meal.restaurantId != null) 'restaurantId': meal.restaurantId,
            if (meal.squareItemId != null) 'squareItemId': meal.squareItemId,
            if (meal.squareVariationId != null) 'squareVariationId': meal.squareVariationId,
          });
        }
      });
    });
    return formattedMealSelections;
  }

  /// Format delivery schedule for Cloud Function
  List<Map<String, dynamic>> _formatDeliverySchedule() {
    final schedule = <Map<String, dynamic>>[];
    widget.weeklySchedule.forEach((day, config) {
      schedule.add({
        'day': day,
        'addressId': config['addressId'] ?? 'default',
        'enabled': config['enabled'] ?? true,
      });
    });
    return schedule;
  }

  SubscriptionPrice? _calculatePricing() {
    final selectedMeals = _getSelectedMeals();
    final mealCount = _countMeals();

    if (selectedMeals.isEmpty || mealCount == 0) {
      return null;
    }

    return PricingService.calculateSubscriptionPrice(
      selectedMeals: selectedMeals,
      mealCount: mealCount,
      stripeOnly: !_squarePaymentsEnabled,
    );
  }

  /// Build dynamic pricing breakdown widget
  Widget _buildPricingBreakdown(SubscriptionPrice? pricing) {
    if (pricing == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No meals selected',
            style: AppThemeV3.textTheme.bodyLarge?.copyWith(
              color: Colors.red,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    if (!_squarePaymentsEnabled) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _pricingRow('Meals Subtotal', pricing.mealSubtotal),
          const SizedBox(height: 8),
          _pricingRow('Delivery (\$9.75 × ${pricing.mealCount})', pricing.deliveryFees),
          const SizedBox(height: 8),
          _pricingRow('Stripe Processing Fee', pricing.stripeFee, isSmall: true),
          const SizedBox(height: 8),
          _pricingRow('Stripe Charge (full amount)', pricing.stripeChargeTotal),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: AppThemeV3.border),
                bottom: BorderSide(color: AppThemeV3.border),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Due Today',
                  style: AppThemeV3.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppThemeV3.accent,
                  ),
                ),
                Text(
                  '\$${pricing.totalAmount.toStringAsFixed(2)}',
                  style: AppThemeV3.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppThemeV3.accent,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _pricingRow('Meals Subtotal', pricing.mealSubtotal),
        const SizedBox(height: 8),
        _pricingRow('Delivery (\$9.75 × ${pricing.mealCount})', pricing.deliveryFees),
        const SizedBox(height: 8),
        _pricingRow('FreshPunk Service Fee (10% of meals)', pricing.freshpunkFee),
        const SizedBox(height: 8),
        _pricingRow('Stripe Processing Fee', pricing.stripeFee, isSmall: true),
        const SizedBox(height: 8),
        _pricingRow('Stripe Charge (platform fee)', pricing.stripeChargeTotal),
        const SizedBox(height: 8),
        _pricingRow('Square Charge (meals + delivery)', pricing.squareChargeTotal),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: AppThemeV3.border),
              bottom: BorderSide(color: AppThemeV3.border),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Due Today',
                style: AppThemeV3.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppThemeV3.accent,
                ),
              ),
              Text(
                '\$${pricing.totalAmount.toStringAsFixed(2)}',
                style: AppThemeV3.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppThemeV3.accent,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Helper to build a pricing row
  Widget _pricingRow(String label, double amount, {bool isSmall = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppThemeV3.textTheme.bodyMedium?.copyWith(
            color: isSmall ? AppThemeV3.textSecondary : null,
            fontSize: isSmall ? 12 : null,
          ),
        ),
        Text(
          '\$${amount.toStringAsFixed(2)}',
          style: AppThemeV3.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: isSmall ? AppThemeV3.textSecondary : null,
            fontSize: isSmall ? 12 : null,
          ),
        ),
      ],
    );
  }

  /// Legacy fallback method for order generation if server-side fails

}
