import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../theme/app_theme_v3.dart';
import '../../services/payment/stripe_service.dart';
import '../../models/mock_user_model.dart';
import '../../widgets/swipeable_page.dart';

class PaymentMethodsPageV3 extends StatefulWidget {
  final VoidCallback? onPaymentComplete;
  final bool isOnboarding;
  final MockUser? mockUser;
  const PaymentMethodsPageV3({
    super.key,
    this.onPaymentComplete,
    this.isOnboarding = false,
    this.mockUser,
  });

  @override
  State<PaymentMethodsPageV3> createState() => _PaymentMethodsPageV3State();
}

class _PaymentMethodsPageV3State extends State<PaymentMethodsPageV3> {
  bool _isLoading = true;
  List<PaymentMethod> _paymentMethods = [];

  @override
  void initState() {
    super.initState();
    _loadPaymentMethods();
  }

  Future<void> _loadPaymentMethods() async {
    setState(() => _isLoading = true);
    try {
      debugPrint('[PaymentMethods] Loading payment methods...');
      final items = await StripeService.instance.listPaymentMethods();
      debugPrint('[PaymentMethods] Loaded ${items.length} payment methods');
      debugPrint('[PaymentMethods] Raw data: $items');
      final mapped = items.map((pm) {
        return PaymentMethod(
          id: pm['id'] as String? ?? '',
          type: PaymentMethodType.card,
          lastFour: (pm['card']?['last4'] as String?) ?? '****',
          brand: (pm['card']?['brand'] as String?) ?? 'Card',
          expiryMonth: (pm['card']?['exp_month'] as int?) ?? 1,
          expiryYear: (pm['card']?['exp_year'] as int?) ?? 2100,
          isDefault: (pm['default'] as bool?) ?? false,
        );
      }).toList();
      setState(() {
        _paymentMethods = mapped;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[PaymentMethods] Error loading payment methods: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addPaymentMethod() async {
    final ok = await StripeService.instance.addPaymentMethod(context);
    if (ok) {
      _showSnackBar('Payment method added');
      await _loadPaymentMethods();
      
      // If this is during onboarding, call the completion callback
      if (widget.isOnboarding && widget.onPaymentComplete != null) {
        widget.onPaymentComplete!();
      }
    }
  }

  Future<void> _removePaymentMethod(PaymentMethod method) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Payment Method'),
        content: Text('Are you sure you want to remove **** ${method.lastFour}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final ok = await StripeService.instance.detachPaymentMethod(method.id);
              if (ok) {
                _showSnackBar('Payment method removed');
                await _loadPaymentMethods();
              } else {
                _showSnackBar('Failed to remove payment method');
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  Future<void> _setDefaultPaymentMethod(PaymentMethod method) async {
    final ok = await StripeService.instance.setDefaultPaymentMethod(method.id);
    if (ok) {
      _showSnackBar('Default payment method updated');
      await _loadPaymentMethods();
    } else {
      _showSnackBar('Failed to set default');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SwipeablePage(
      child: Scaffold(
        backgroundColor: AppThemeV3.background,
        appBar: AppBar(
        backgroundColor: AppThemeV3.background,
        elevation: 0,
        title: Text(
          'Payment Methods',
          style: AppThemeV3.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _addPaymentMethod,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _paymentMethods.isEmpty
              ? _buildEmptyState()
              : _buildPaymentMethodsList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.credit_card_off,
              size: 80,
              color: AppThemeV3.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'No Payment Methods',
              style: AppThemeV3.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppThemeV3.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Add a payment method to complete your orders',
              style: AppThemeV3.textTheme.bodyMedium?.copyWith(
                color: AppThemeV3.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _addPaymentMethod,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppThemeV3.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Add Payment Method'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _paymentMethods.length,
      itemBuilder: (context, index) {
        final method = _paymentMethods[index];
        return _buildPaymentMethodCard(method);
      },
    );
  }

  Widget _buildPaymentMethodCard(PaymentMethod method) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppThemeV3.surface,
            AppThemeV3.surface.withValues(alpha: 0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: method.isDefault 
              ? AppThemeV3.accent 
              : AppThemeV3.accent.withValues(alpha: 0.2),
          width: method.isDefault ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getCardIcon(method.brand),
                size: 32,
                color: AppThemeV3.accent,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${method.brand} •••• ${method.lastFour}',
                      style: AppThemeV3.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Expires ${method.expiryMonth.toString().padLeft(2, '0')}/${method.expiryYear.toString().substring(2)}',
                      style: AppThemeV3.textTheme.bodyMedium?.copyWith(
                        color: AppThemeV3.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'default':
                      _setDefaultPaymentMethod(method);
                      break;
                    case 'remove':
                      _removePaymentMethod(method);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  if (!method.isDefault)
                    const PopupMenuItem(
                      value: 'default',
                      child: Text('Set as Default'),
                    ),
                  const PopupMenuItem(
                    value: 'remove',
                    child: Text('Remove'),
                  ),
                ],
              ),
            ],
          ),
          if (method.isDefault) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppThemeV3.accent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Default',
                style: AppThemeV3.textTheme.bodySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _getCardIcon(String brand) {
    switch (brand.toLowerCase()) {
      case 'visa':
        return Icons.credit_card;
      case 'mastercard':
        return Icons.credit_card;
      case 'amex':
      case 'american express':
        return Icons.credit_card;
      default:
        return Icons.credit_card;
    }
  }
}

class PaymentMethod {
  final String id;
  final PaymentMethodType type;
  final String lastFour;
  final String brand;
  final int expiryMonth;
  final int expiryYear;
  bool isDefault;

  PaymentMethod({
    required this.id,
    required this.type,
    required this.lastFour,
    required this.brand,
    required this.expiryMonth,
    required this.expiryYear,
    required this.isDefault,
  });
}

enum PaymentMethodType { card, paypal, applePay, googlePay }
