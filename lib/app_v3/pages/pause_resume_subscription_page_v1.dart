import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme_v3.dart';
import '../services/firestore_service_v3.dart';
import '../services/order_functions_service.dart';

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
      if (mounted) setState(() { _activeSub = sub; _loading = false; });
    } catch (_) { if (mounted) setState(() { _loading = false; }); }
  }

  Future<void> _pause() async {
    final subId = (_activeSub?['stripeSubscriptionId'] ?? _activeSub?['id'])?.toString();
    if (subId == null || subId.isEmpty) return;
    setState(() { _working = true; });
    try {
      final ok = await OrderFunctionsService.instance.pauseSubscription(subId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? 'Subscription paused' : 'Failed to pause')),
      );
      Navigator.pop(context, ok);
    } catch (e) {
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
    final subId = (_activeSub?['stripeSubscriptionId'] ?? _activeSub?['id'])?.toString();
    if (subId == null || subId.isEmpty) return;
    setState(() { _working = true; });
    try {
      final ok = await OrderFunctionsService.instance.resumeSubscription(subId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? 'Subscription resumed' : 'Failed to resume')),
      );
      Navigator.pop(context, ok);
    } catch (e) {
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
                          onPressed: _working ? null : _pause,
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                          child: Text(_working ? 'Working…' : 'Pause'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _working ? null : _resume,
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
                  const SizedBox(height: 12),
                ],
              ),
            ),
    );
  }
}
