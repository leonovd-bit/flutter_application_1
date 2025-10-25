import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme_v3.dart';
import '../models/meal_model_v3.dart';
import 'home_page_v3.dart';
import '../services/progress_manager.dart';
import '../services/firestore_service_v3.dart';
import '../services/scheduler_service_v3.dart';
import '../services/order_generation_service.dart';
import '../services/stripe_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/mock_user_model.dart';
import 'package:flutter/foundation.dart';

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
  
  // Monthly price derived from model getter ($13/meal * meals/day * 30)
  double get _monthlyPrice => widget.mealPlan.monthlyPrice;

  @override
  void initState() {
    super.initState();
    _mockUser = widget.mockUser;
  }
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
                  
                  // Pricing
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Weekly Price',
                        style: AppThemeV3.textTheme.bodyLarge,
                      ),
                      Text(
                        '\$${widget.mealPlan.weeklyPrice.toStringAsFixed(2)}',
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
      // Add payment method via Stripe (works on Web, iOS, Android)
      debugPrint('[Payment] Presenting Stripe payment sheet...');
      final StripeService stripe = StripeService.instance;
      final paymentAdded = await stripe.addPaymentMethod(context);
      
      if (!paymentAdded) {
        debugPrint('[Payment] User cancelled or payment method addition failed');
        if (mounted) {
          setState(() => _isProcessing = false);
        }
        return;
      }
      
      debugPrint('[Payment] Payment method successfully added');
      
      // Show confirmation message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✓ Creating your subscription...'),
            backgroundColor: AppThemeV3.success,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      
      // Generate orders from meal selections
      try {
  final uid = _mockUser?.uid ?? FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          debugPrint('[Payment] Starting order generation for user: $uid');
          
          // Convert meal selections to the format expected by the service
          final List<Map<String, dynamic>> formattedMealSelections = [];
          widget.selectedMeals.forEach((day, mealMap) {
            mealMap.forEach((mealType, meal) {
              if (meal != null) {
                formattedMealSelections.add({
                  'day': day,
                  'mealType': mealType,
                  'mealId': meal.id,
                  'mealName': meal.name,
                  'price': meal.price,
                });
              }
            });
          });
          
          // Use new OrderGenerationService to create orders from meal selections
          final result = await OrderGenerationService.generateOrdersFromMealSelection(
            mealSelections: formattedMealSelections,
            deliverySchedule: widget.weeklySchedule,
            deliveryAddress: 'default', // TODO: Get actual address from user profile
          );
          
          if (result['success'] == true) {
            debugPrint('[Payment] Successfully generated ${result['ordersGenerated'] ?? 0} orders');
          } else {
            debugPrint('[Payment] Order generation failed: ${result['error'] ?? 'Unknown error'}');
            // Fall back to legacy order generation if server-side fails
            await _generateOrdersLegacy(uid);
          }
        }
      } catch (e) {
        debugPrint('[Payment] Failed to generate orders: $e');
        // Fall back to legacy order generation
  final uid = _mockUser?.uid ?? FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          await _generateOrdersLegacy(uid);
        }
      }
      
      // Mark setup as completed and finalize onboarding
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('setup_completed', true);
        await ProgressManager.saveCurrentStep(OnboardingStep.completed);
        // Keep setup_completed flag but clear other onboarding progress data
        await ProgressManager.clearOnboardingProgress();
      } catch (e) {
        // ignore: avoid_print
        print('Error marking setup completed: $e');
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

  /// Legacy fallback method for order generation if server-side fails
  Future<void> _generateOrdersLegacy(String uid) async {
    try {
      debugPrint('[Payment] Using legacy order generation fallback');
      
      // Convert weekly schedule map -> list of DeliveryScheduleModelV3
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
            userId: uid,
            dayOfWeek: day.toLowerCase(),
            mealType: mealType.toString().toLowerCase(),
            deliveryTime: TimeOfDay(hour: hour, minute: minute),
            addressId: 'default',
            isActive: true,
            weekStartDate: weekStart,
          ));
        });
      });
      
      await FirestoreServiceV3.replaceActiveDeliverySchedules(uid, schedules);
      
      // Generate upcoming orders to reflect the new schedules
      final created = await SchedulerServiceV3.generateUpcomingOrders(
        userId: uid, 
        daysAhead: 7
      );
      
      debugPrint('[Payment] Legacy: Generated $created upcoming orders for user=$uid');
    } catch (e) {
      debugPrint('[Payment] Legacy order generation also failed: $e');
    }
  }
}
