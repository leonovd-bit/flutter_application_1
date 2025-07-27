import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/subscription.dart';
import '../services/subscription_service.dart';

class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({super.key});

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  Subscription? _currentSubscription;
  bool _isLoading = true;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _loadSubscription();
  }

  Future<void> _loadSubscription() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final subscription = await SubscriptionService.getUserSubscription(user.uid);
        setState(() {
          _currentSubscription = subscription;
          _isLoading = false;
        });
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error loading subscription: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<bool> _showPasswordDialog(String action) async {
    final passwordController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm ${action.toUpperCase()}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Please enter your password to $action:'),
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
            onPressed: () {
              // In production, verify password with Firebase Auth
              Navigator.of(context).pop(true);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    passwordController.dispose();
    return result ?? false;
  }

  Future<void> _changePlan(SubscriptionPlan newPlan) async {
    final confirmed = await _showPasswordDialog('change your subscription plan');
    if (!confirmed) return;

    setState(() {
      _isUpdating = true;
    });

    try {
      final updatedSubscription = _currentSubscription!.copyWith(
        plan: newPlan,
        monthlyPrice: newPlan.monthlyPrice,
        updatedAt: DateTime.now(),
      );

      await SubscriptionService.updateSubscription(updatedSubscription);

      setState(() {
        _currentSubscription = updatedSubscription;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Subscription plan updated successfully! Changes will take effect in your next billing cycle.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating subscription: $e'),
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

  Future<void> _cancelSubscription() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Subscription'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to cancel your subscription?'),
            SizedBox(height: 16),
            Text(
              '• Your subscription will remain active until the end of your current billing period',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 8),
            Text(
              '• You will continue to receive meals until your subscription expires',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 8),
            Text(
              '• You can reactivate your subscription anytime before it expires',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep Subscription'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Cancel Subscription'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Second confirmation with password
    final passwordConfirmed = await _showPasswordDialog('cancel your subscription');
    if (!passwordConfirmed) return;

    setState(() {
      _isUpdating = true;
    });

    try {
      await SubscriptionService.cancelSubscription(_currentSubscription!.id);

      final updatedSubscription = _currentSubscription!.copyWith(
        status: SubscriptionStatus.canceled,
        updatedAt: DateTime.now(),
      );

      setState(() {
        _currentSubscription = updatedSubscription;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Subscription cancelled. You will continue to receive meals until the end of your billing period.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cancelling subscription: $e'),
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
      appBar: AppBar(
        title: const Text('Subscription'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _currentSubscription == null
              ? const Center(
                  child: Text(
                    'No active subscription found',
                    style: TextStyle(fontSize: 18),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Current Subscription Status
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Current Plan',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(_currentSubscription!.status),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      _currentSubscription!.status.displayName.toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _currentSubscription!.plan.displayName,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '\$${_currentSubscription!.monthlyPrice.toStringAsFixed(2)}/month',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _currentSubscription!.plan.description,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Started: ${_formatDate(_currentSubscription!.startDate)}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Plan Options
                      if (_currentSubscription!.status != SubscriptionStatus.canceled) ...[
                        const Text(
                          'Change Plan',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ...SubscriptionPlan.values.map((plan) {
                          final isCurrentPlan = plan == _currentSubscription!.plan;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              title: Text(
                                plan.displayName,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isCurrentPlan ? Colors.green : null,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('\$${plan.monthlyPrice.toStringAsFixed(2)}/month'),
                                  Text(plan.description),
                                ],
                              ),
                              trailing: isCurrentPlan
                                  ? const Icon(Icons.check_circle, color: Colors.green)
                                  : ElevatedButton(
                                      onPressed: _isUpdating ? null : () => _changePlan(plan),
                                      child: const Text('Select'),
                                    ),
                            ),
                          );
                        }),
                        const SizedBox(height: 24),
                      ],

                      // Subscription Actions
                      const Text(
                        'Subscription Actions',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      if (_currentSubscription!.status != SubscriptionStatus.canceled) ...[
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _isUpdating ? null : _cancelSubscription,
                            icon: const Icon(Icons.cancel_outlined),
                            label: const Text('Cancel Subscription'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.all(16),
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                            ),
                          ),
                        ),
                      ] else ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            border: Border.all(color: Colors.orange),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Column(
                            children: [
                              Icon(Icons.info_outline, color: Colors.orange),
                              SizedBox(height: 8),
                              Text(
                                'Subscription Cancelled',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Your subscription has been cancelled. You will continue to receive meals until the end of your billing period.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ],

                      if (_isUpdating) ...[
                        const SizedBox(height: 16),
                        const Center(
                          child: CircularProgressIndicator(),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }

  Color _getStatusColor(SubscriptionStatus status) {
    switch (status) {
      case SubscriptionStatus.active:
        return Colors.green;
      case SubscriptionStatus.pending:
        return Colors.orange;
      case SubscriptionStatus.canceled:
        return Colors.red;
      case SubscriptionStatus.pastDue:
        return Colors.orange;
      case SubscriptionStatus.unpaid:
        return Colors.red;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }
}
