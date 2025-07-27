import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/subscription.dart';
import '../services/subscription_service.dart';

class PaymentPage extends StatefulWidget {
  const PaymentPage({super.key});

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  Subscription? _currentSubscription;
  PaymentMethod? _currentPaymentMethod;
  bool _isLoading = true;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _loadPaymentData();
  }

  Future<void> _loadPaymentData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final subscription = await SubscriptionService.getUserSubscription(user.uid);
      
      setState(() {
        _currentSubscription = subscription;
        _isLoading = false;
      });

      // Load payment method if subscription exists
      if (subscription != null) {
        setState(() {
          _currentPaymentMethod = subscription.paymentMethod;
        });
      }
    } catch (e) {
      print('Error loading payment data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<bool> _showPasswordDialog(String action) async {
    final passwordController = TextEditingController();
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Verify Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Please enter your password to $action.'),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              // In production, verify password here
              Navigator.of(context).pop(true);
            },
            child: const Text('Verify'),
          ),
        ],
      ),
    );

    return confirmed ?? false;
  }

  Future<void> _updatePaymentMethod() async {
    final confirmed = await _showPasswordDialog('update your payment method');
    if (!confirmed) return;

    setState(() {
      _isUpdating = true;
    });

    try {
      // In production, you would integrate with Stripe to update payment method
      // For now, we'll simulate a successful update
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment method updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating payment method: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isUpdating = false;
      });
    }
  }

  Future<void> _removePaymentMethod() async {
    final confirmed = await _showPasswordDialog('remove your payment method');
    if (!confirmed) return;

    final doubleConfirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Payment Method'),
        content: const Text(
          'Are you sure you want to remove your payment method? This will also cancel your subscription.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (doubleConfirmed != true) return;

    setState(() {
      _isUpdating = true;
    });

    try {
      // In production, remove payment method from Stripe and cancel subscription
      
      setState(() {
        _currentPaymentMethod = null;
        _currentSubscription = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment method removed successfully'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error removing payment method: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isUpdating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Payment',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Current Payment Method
                  _buildPaymentMethodSection(),
                  const SizedBox(height: 32),
                  
                  // Billing Information
                  if (_currentSubscription != null) _buildBillingSection(),
                  
                  // Payment History
                  if (_currentSubscription != null) _buildPaymentHistorySection(),
                ],
              ),
            ),
    );
  }

  Widget _buildPaymentMethodSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Payment Method',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        
        if (_currentPaymentMethod != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 25,
                      decoration: BoxDecoration(
                        color: _getCardColor(_currentPaymentMethod!.cardBrand),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Center(
                        child: Text(
                          _currentPaymentMethod!.cardBrand.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '•••• •••• •••• ${_currentPaymentMethod!.cardLast4}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Expires ${_currentPaymentMethod!.expMonth}/${_currentPaymentMethod!.expYear}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isUpdating ? null : _updatePaymentMethod,
                        child: _isUpdating
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Update'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isUpdating ? null : _removePaymentMethod,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                        ),
                        child: const Text('Remove'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.credit_card_off,
                  size: 48,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 12),
                Text(
                  'No payment method on file',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    // Navigate to subscription setup
                    Navigator.pushNamed(context, '/subscription-setup');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D5A2D),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Add Payment Method'),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildBillingSection() {
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
        
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBillingRow('Plan', _getSubscriptionPlanName(_currentSubscription!.plan)),
              _buildBillingRow('Amount', '\$${_currentSubscription!.monthlyPrice.toStringAsFixed(2)}/month'),
              _buildBillingRow('Next Billing', _formatNextBilling(_currentSubscription!.startDate)),
              _buildBillingRow('Status', _currentSubscription!.status.toString().split('.').last),
            ],
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildBillingRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Payment History',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        
        // Mock payment history
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: const Text(
            'Payment history will appear here once you have completed transactions.',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Color _getCardColor(String brand) {
    switch (brand.toLowerCase()) {
      case 'visa':
        return Colors.blue;
      case 'mastercard':
        return Colors.red;
      case 'amex':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getSubscriptionPlanName(SubscriptionPlan plan) {
    switch (plan.mealsPerDay) {
      case 1:
        return '1 Meal Plan';
      case 2:
        return '2 Meal Plan';
      default:
        return 'Custom Plan';
    }
  }

  String _formatNextBilling(DateTime startDate) {
    final nextBilling = DateTime(startDate.year, startDate.month + 1, startDate.day);
    return '${nextBilling.day}/${nextBilling.month}/${nextBilling.year}';
  }
}
