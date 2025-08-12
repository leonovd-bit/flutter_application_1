import 'package:flutter/material.dart';
import '../theme/app_theme_v3.dart';
import '../services/token_service_v3.dart';

class TokenBalanceWidget extends StatelessWidget {
  final bool showBuyButton;
  const TokenBalanceWidget({super.key, this.showBuyButton = true});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: TokenServiceV3.balanceStream(),
      builder: (context, snapshot) {
        final tokens = snapshot.data ?? 0;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            border: Border.all(color: Colors.orange.shade200),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.toll, color: Colors.orange),
              const SizedBox(width: 8),
              Text('$tokens tokens', style: AppThemeV3.textTheme.titleMedium),
              const Spacer(),
              if (showBuyButton)
                TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Go to Plans to buy tokens')),
                    );
                  },
                  child: const Text('Buy tokens'),
                ),
            ],
          ),
        );
      },
    );
  }
}
