import 'package:flutter/material.dart';
import '../theme/app_theme_v3.dart';

class SplashPageV1 extends StatelessWidget {
	const SplashPageV1({super.key});

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			backgroundColor: AppThemeV3.background,
			body: Center(
				child: Column(
					mainAxisSize: MainAxisSize.min,
					children: [
						SizedBox(
							width: 64,
							height: 64,
							child: CircularProgressIndicator(
								valueColor: AlwaysStoppedAnimation<Color>(AppThemeV3.accent),
								strokeWidth: 4,
							),
						),
						const SizedBox(height: 16),
						Text(
							'FreshPunk starting… (SPV1-1200ms)',
							style: TextStyle(
								color: AppThemeV3.textPrimary,
								fontSize: 16,
								fontWeight: FontWeight.w600,
							),
						)
					],
				),
			),
		);
	}
}

