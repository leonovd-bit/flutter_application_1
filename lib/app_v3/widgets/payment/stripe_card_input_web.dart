import 'package:flutter/material.dart';
import 'dart:ui_web' as ui_web;
import 'package:web/web.dart' as web;
import '../../services/payment/stripe_web_service.dart';

class StripeCardInputWeb extends StatefulWidget {
  final String clientSecret;
  final void Function(String paymentMethodId) onSuccess;
  final void Function(String error) onError;
  final String publishableKey;

  const StripeCardInputWeb({
    super.key,
    required this.clientSecret,
    required this.onSuccess,
    required this.onError,
    required this.publishableKey,
  });

  @override
  State<StripeCardInputWeb> createState() => _StripeCardInputWebState();
}

class _StripeCardInputWebState extends State<StripeCardInputWeb> {
  late final StripeWebService _stripeService;
  bool _isLoading = false;
  static const String _cardElementId = 'stripe-card-element';
  bool _elementMounted = false;

  @override
  void initState() {
    super.initState();
    _stripeService = StripeWebService(widget.publishableKey);
    
    ui_web.platformViewRegistry.registerViewFactory(
      _cardElementId,
      (int viewId) {
        final element = web.document.createElement('div') as web.HTMLDivElement;
        element.id = _cardElementId;
        element.style.padding = '10px';
        element.style.border = '1px solid #ccc';
        element.style.borderRadius = '4px';
        return element;
      },
    );
    
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      try {
        _stripeService.createAndMountCardElement(_cardElementId);
        setState(() {
          _elementMounted = true;
        });
      } catch (e) {
        debugPrint('[StripeCardInput] Error mounting card element: ');
        widget.onError('Failed to initialize card form');
      }
    });
  }

  @override
  void dispose() {
    _stripeService.dispose();
    super.dispose();
  }

  Future<void> _submitCard() async {
    if (_isLoading || !_elementMounted) return;

    setState(() => _isLoading = true);

    try {
      final paymentMethodId = await _stripeService.confirmCardSetup(
        widget.clientSecret,
      );
      widget.onSuccess(paymentMethodId);
    } catch (e) {
      widget.onError(e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Card Information',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 20),
            Container(
              height: 50,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const HtmlElementView(
                viewType: _cardElementId,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.lock_outline, size: 18, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your card information is secure and never stored.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading || !_elementMounted ? null : _submitCard,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Add Card',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
