import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../theme/app_theme_v3.dart';
import '../../services/auth/firestore_service_v3.dart';
import '../../services/orders/order_functions_service.dart';
import '../payment/payment_methods_page_v3.dart';

class PauseResumeSubscriptionPageV1 extends StatefulWidget {
  const PauseResumeSubscriptionPageV1({super.key});

  @override
  State<PauseResumeSubscriptionPageV1> createState() => _PauseResumeSubscriptionPageV1State();
}

class _PauseResumeSubscriptionPageV1State extends State<PauseResumeSubscriptionPageV1> {
  final _auth = FirebaseAuth.instance;
  Map<String, dynamic>? _activeSub;
  bool _loading = true;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      setState(() { _loading = false; });
      return;
    }
    try {
      final sub = await FirestoreServiceV3.getActiveSubscription(uid);
      debugPrint('[PauseResume] Loaded subscription: $sub');
      if (mounted) setState(() { _activeSub = sub; _loading = false; });
    } catch (e) { 
      debugPrint('[PauseResume] Error loading subscription: $e');
      if (mounted) setState(() { _loading = false; }); 
    }
  }

  Future<void> _pause() async {
    final subId = _activeSub?['stripeSubscriptionId']?.toString() ??
                 _activeSub?['stripe_subscription_id']?.toString() ??
                 _activeSub?['subscriptionId']?.toString() ??
                 _activeSub?['id']?.toString();
    
    debugPrint('[PauseResume] Attempting to pause subscription: $subId');
    
    if (subId == null || subId.isEmpty || subId == 'local' || subId.startsWith('temp_')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No valid Stripe subscription found')),
      );
      return;
    }
    
    setState(() { _working = true; });
    try {
      final ok = await OrderFunctionsService.instance.pauseSubscription(subId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? 'Subscription paused' : 'Failed to pause')),
      );
      if (ok) Navigator.pop(context, ok);
    } catch (e) {
      debugPrint('[PauseResume] Error pausing subscription: $e');
      if (!mounted) return;
      final errorMsg = e.toString().toLowerCase();
      if (errorMsg.contains('unable to establish connection') || 
          errorMsg.contains('channel') ||
          errorMsg.contains('pigeon')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ This feature requires Cloud Functions connection. Not available in offline/debug mode.'),
            duration: Duration(seconds: 4),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() { _working = false; });
    }
  }

  Future<void> _resume() async {
    final subId = _activeSub?['stripeSubscriptionId']?.toString() ??
                 _activeSub?['stripe_subscription_id']?.toString() ??
                 _activeSub?['subscriptionId']?.toString() ??
                 _activeSub?['id']?.toString();
    
    debugPrint('[PauseResume] Attempting to resume subscription: $subId');
    
    if (subId == null || subId.isEmpty || subId == 'local' || subId.startsWith('temp_')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No valid Stripe subscription found')),
      );
      return;
    }
    
    setState(() { _working = true; });
    try {
      final ok = await OrderFunctionsService.instance.resumeSubscription(subId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? 'Subscription resumed' : 'Failed to resume')),
      );
      if (ok) Navigator.pop(context, ok);
    } catch (e) {
      debugPrint('[PauseResume] Error resuming subscription: $e');
      if (!mounted) return;
      final errorMsg = e.toString().toLowerCase();
      if (errorMsg.contains('unable to establish connection') || 
          errorMsg.contains('channel') ||
          errorMsg.contains('pigeon')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ This feature requires Cloud Functions connection. Not available in offline/debug mode.'),
            duration: Duration(seconds: 4),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() { _working = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Try multiple field names for Stripe subscription ID
    final stripeSubId = _activeSub?['stripeSubscriptionId']?.toString() ??
                       _activeSub?['stripe_subscription_id']?.toString() ??
                       _activeSub?['subscriptionId']?.toString() ??
                       _activeSub?['id']?.toString();
    
    final hasStripeSub = stripeSubId != null && 
                        stripeSubId.isNotEmpty && 
                        stripeSubId != 'local' &&
                        !stripeSubId.startsWith('temp_');
    
    debugPrint('[PauseResume] Stripe subscription ID: $stripeSubId, hasStripeSub: $hasStripeSub');
    debugPrint('[PauseResume] Available fields: ${_activeSub?.keys.toList()}');
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pause / Resume Subscription'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      backgroundColor: Colors.white,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Control your billing cycle',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Text(
                      'Pausing will stop invoicing and deliveries until you resume. You can resume anytime.',
                      style: const TextStyle(color: Colors.black87),
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _working || !hasStripeSub ? null : _pause,
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                          child: Text(_working ? 'Working…' : 'Pause'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _working || !hasStripeSub ? null : _resume,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppThemeV3.primaryGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: Text(_working ? 'Working…' : 'Resume'),
                        ),
                      ),
                    ],
                  ),
                  if (!hasStripeSub) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'No Stripe subscription linked',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.orange.shade900,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'You have selected a meal plan but haven\'t completed payment setup. To pause/resume your subscription, you need to:\n\n1. Add a payment method\n2. Subscribe to a plan via Stripe\n\nOnce you have an active Stripe subscription, you\'ll be able to pause and resume it here.',
                                  style: TextStyle(
                                    color: Colors.orange.shade800,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const PaymentMethodsPageV3(),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.credit_card, size: 18),
                                    label: const Text('Set Up Payment'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange.shade700,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                ],
              ),
            ),
    );
  }
}
