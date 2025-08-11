import 'package:flutter/material.dart';
import '../theme/app_theme_v3.dart';

class SplashPageV3 extends StatelessWidget {
	const SplashPageV3({super.key});

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			backgroundColor: AppThemeV3.background,
			body: Container(
				decoration: BoxDecoration(gradient: AppThemeV3.backgroundGradient),
				child: Center(
					child: Column(
						mainAxisSize: MainAxisSize.min,
						children: [
							// Brand logo
							Container(
								width: 120,
								height: 120,
								decoration: BoxDecoration(
									shape: BoxShape.circle,
									boxShadow: AppThemeV3.boldShadow,
									color: AppThemeV3.surface,
								),
								padding: const EdgeInsets.all(16),
								child: Image.asset(
									'assets/images/freshpunk_logo.png',
									fit: BoxFit.contain,
								),
							),
							const SizedBox(height: 24),
							// Tagline
							Text(
								'Fresh meals, delivered.',
								style: AppThemeV3.textTheme.headlineMedium,
								textAlign: TextAlign.center,
							),
							const SizedBox(height: 16),
							// Progress indicator
							SizedBox(
								width: 56,
								height: 56,
								child: CircularProgressIndicator(
									strokeWidth: 4,
									valueColor: AlwaysStoppedAnimation<Color>(AppThemeV3.accent),
								),
							),
						],
					),
				),
			),
		);
	}
}

