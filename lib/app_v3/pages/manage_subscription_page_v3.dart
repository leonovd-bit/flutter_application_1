import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/meal_model_v3.dart';
import '../services/firestore_service_v3.dart';
import '../theme/app_theme_v3.dart';
import 'payment_methods_page_v3.dart';
import '../services/order_functions_service.dart';
import '../config/stripe_prices.dart';
import 'pause_resume_subscription_page_v1.dart';
 
class ManageSubscriptionPageV3 extends StatefulWidget {
	const ManageSubscriptionPageV3({super.key});

	@override
	State<ManageSubscriptionPageV3> createState() => _ManageSubscriptionPageV3State();
}

class _ManageSubscriptionPageV3State extends State<ManageSubscriptionPageV3> {
	final _auth = FirebaseAuth.instance;
	final _plans = MealPlanModelV3.getAvailablePlans();
	String? _selectedPlanId;
	String? _initialPlanId; // to detect changes
	bool _saving = false;
	bool _cancelling = false;
	Map<String, dynamic>? _activeSub;

	Widget _buildStatusChip(String? statusRaw) {
		final status = (statusRaw ?? 'active').toLowerCase();
		Color bg;
		Color fg;
		String label = status;
		switch (status) {
			case 'active':
				bg = Colors.green.withValues(alpha: 0.12);
				fg = Colors.green.shade700;
				label = 'Active';
				break;
			case 'paused':
				bg = Colors.orange.withValues(alpha: 0.12);
				fg = Colors.orange.shade700;
				label = 'Paused';
				break;
			case 'canceled':
			case 'canceled_at_period_end':
				bg = Colors.grey.withValues(alpha: 0.15);
				fg = Colors.grey.shade700;
				label = 'Canceled';
				break;
			case 'past_due':
				bg = Colors.red.withValues(alpha: 0.12);
				fg = Colors.red.shade700;
				label = 'Past due';
				break;
			case 'trialing':
				bg = Colors.blue.withValues(alpha: 0.12);
				fg = Colors.blue.shade700;
				label = 'Trialing';
				break;
			default:
				bg = Colors.grey.withValues(alpha: 0.12);
				fg = Colors.grey.shade700;
				label = statusRaw ?? '—';
		}
		return Container(
			decoration: BoxDecoration(
				color: bg,
				borderRadius: BorderRadius.circular(999),
			),
			padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
			child: Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w600)),
		);
	}

	@override
	void initState() {
		super.initState();
		_loadCurrent();
	}

	Future<void> _loadCurrent() async {
		final uid = _auth.currentUser?.uid;
		if (uid == null) return;
		try {
			final current = await FirestoreServiceV3.getCurrentMealPlan(uid);
			final sub = await FirestoreServiceV3.getActiveSubscription(uid);
			if (mounted) setState(() { _selectedPlanId = current?.id; _initialPlanId = current?.id; _activeSub = sub; });
		} catch (_) {}
	}

	Future<void> _save() async {
		final uid = _auth.currentUser?.uid;
		if (uid == null || _selectedPlanId == null) return;
		final plan = _plans.firstWhere((p) => p.id == _selectedPlanId);
		setState(() => _saving = true);
		try {
				// If there's an active Stripe subscription, update its price first.
				final currentSub = _activeSub;
				if (currentSub != null) {
					final subId = (currentSub['stripeSubscriptionId'] ?? currentSub['id'])?.toString();
					final newPriceId = StripePricesConfig.priceIdForPlanId(plan.id);
					if ((subId ?? '').isNotEmpty && (newPriceId).isNotEmpty) {
						try {
							await OrderFunctionsService.instance.updateSubscription(
								subscriptionId: subId!,
								newPriceId: newPriceId,
							);
						} catch (e) {
							// Surface but still allow Firestore/local update to proceed
							if (mounted) {
								ScaffoldMessenger.of(context).showSnackBar(
									SnackBar(content: Text('Stripe plan change error: $e')),
								);
							}
						}
					}
				}

				// Update app state regardless so UI reflects intended plan.
				await FirestoreServiceV3.setActiveMealPlan(uid, plan);
				await FirestoreServiceV3.updateActiveSubscriptionPlan(uid, plan);
			try {
				final prefs = await SharedPreferences.getInstance();
				await prefs.setString('selected_meal_plan_id', plan.id);
				await prefs.setString('selected_meal_plan_name', plan.name);
				await prefs.setString('selected_meal_plan_display_name', plan.displayName);
			} catch (_) {}
			if (!mounted) return;
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('Subscription updated')),
			);
			setState(() { _initialPlanId = _selectedPlanId; });
		} catch (e) {
			if (!mounted) return;
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(content: Text('Failed to update: $e')),
			);
		} finally {
			if (mounted) setState(() => _saving = false);
		}
	}

	Future<void> _cancelSubscription() async {
		final subId = (_activeSub?['stripeSubscriptionId'] ?? _activeSub?['id'])?.toString();
		if (subId == null || subId.isEmpty) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('No active subscription to cancel.')),
			);
			return;
		}
		final confirm = await showDialog<bool>(
			context: context,
			builder: (_) => AlertDialog(
				title: const Text('Cancel subscription?'),
				content: const Text('This will cancel at the end of the current period.'),
				actions: [
					TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep')),
					TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Cancel')),
				],
			),
		);
		if (confirm != true) return;
		setState(() { _cancelling = true; });
		try {
			final ok = await OrderFunctionsService.instance.cancelSubscription(subId);
			if (ok) {
				if (!mounted) return;
				ScaffoldMessenger.of(context).showSnackBar(
					const SnackBar(content: Text('Subscription cancellation requested.')),
				);
				Navigator.pop(context);
			} else {
				if (!mounted) return;
				ScaffoldMessenger.of(context).showSnackBar(
					const SnackBar(content: Text('Failed to cancel subscription.')),
				);
			}
		} catch (e) {
			if (!mounted) return;
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(content: Text('Error: $e')),
			);
		} finally {
			if (mounted) setState(() { _cancelling = false; });
		}
	}

	@override
	Widget build(BuildContext context) {
		final hasChanges = (_selectedPlanId != null && _selectedPlanId != _initialPlanId);
		return Scaffold(
			appBar: AppBar(
				title: const Text('Manage Subscription'),
				backgroundColor: Colors.white,
				foregroundColor: Colors.black87,
				elevation: 0,
			),
			backgroundColor: Colors.white,
			body: Column(
				children: [
					Expanded(
						child: SingleChildScrollView(
							padding: const EdgeInsets.all(16),
							child: Column(
								crossAxisAlignment: CrossAxisAlignment.start,
								children: [
																			if (!StripePricesConfig.isConfigured)
																				Container(
																					margin: const EdgeInsets.only(bottom: 12),
																					padding: const EdgeInsets.all(12),
																					decoration: BoxDecoration(
																						color: const Color(0xFFFFF8E1), // amber-50
																						borderRadius: BorderRadius.circular(8),
																						border: Border.all(color: const Color(0xFFFFE082)),
																					),
																					child: Row(
																						crossAxisAlignment: CrossAxisAlignment.start,
																						children: [
																							const Icon(Icons.info_outline, color: Color(0xFFF57C00)),
																							const SizedBox(width: 8),
																							Expanded(
																								child: Text(
																									'Stripe price IDs are not configured. Plan changes will update in the app but will not update your Stripe subscription until STRIPE_PRICE_1_MEAL/2_MEAL/3_MEAL are provided via --dart-define.',
																									style: const TextStyle(color: Color(0xFF6D4C41)),
																								),
																							),
																						],
																					),
																				),
									// Status Card
									Container(
										padding: const EdgeInsets.all(16),
										decoration: BoxDecoration(
											color: Colors.white,
											borderRadius: BorderRadius.circular(12),
											boxShadow: [
												BoxShadow(
													color: Colors.black.withValues(alpha: 0.05),
													blurRadius: 10,
													offset: const Offset(0, 4),
												),
											],
										),
										child: Column(
											crossAxisAlignment: CrossAxisAlignment.start,
											children: [
																								Row(
																									children: [
																										Icon(Icons.subscriptions, color: AppThemeV3.primaryGreen),
																										const SizedBox(width: 8),
																										Text('Subscription Status', style: const TextStyle(fontWeight: FontWeight.w700)),
																										const Spacer(),
																										TextButton.icon(
																											onPressed: () async {
																												await Navigator.push(
																													context,
																													MaterialPageRoute(builder: (_) => const PauseResumeSubscriptionPageV1()),
																												);
																												if (mounted) _loadCurrent();
																											},
																											icon: const Icon(Icons.pause_circle_outline),
																											label: const Text('Pause/Resume'),
																										),
																									],
																								),
																								const SizedBox(height: 12),
																								Row(
																									children: [
																										_buildStatusChip((_activeSub?['status'] ?? 'active')?.toString()),
																									],
																								),
												const SizedBox(height: 6),
												Builder(builder: (_) {
													final plan = _plans.where((p) => p.id == _selectedPlanId).cast<MealPlanModelV3?>().firstOrNull;
													final name = plan?.displayName.isNotEmpty == true ? plan!.displayName : (plan?.name ?? '');
													return Text('Selected: ${name.isEmpty ? '—' : name}', style: const TextStyle(color: Colors.black54));
												}),
												const SizedBox(height: 6),
																								Builder(builder: (_) {
																									final nb = _activeSub?['nextBillingDate'];
																									DateTime? dt;
																									if (nb is DateTime) dt = nb;
																									// Firestore Timestamp support
																									try { if (dt == null && nb != null && nb.toString().isNotEmpty) { dt = (nb as dynamic).toDate() as DateTime; } } catch (_) {}
																									final amt = _activeSub?['monthlyAmount'];
																									String amtStr = '';
																									if (amt is num) {
																										amtStr = '~\$${amt.toDouble().toStringAsFixed(0)}/mo';
																									}
																									final dateStr = dt != null ? dt.toLocal().toString().split('.').first : '—';
																									final tail = amtStr.isNotEmpty ? ' • $amtStr' : '';
																									return Text('Next billing: $dateStr$tail', style: const TextStyle(color: Colors.black54));
																								}),
												const SizedBox(height: 8),
												Text('Plan changes apply at the next billing cycle.', style: TextStyle(color: Colors.black54, fontSize: 12)),
											],
										),
									),

									const SizedBox(height: 16),

									// Plan Selection Card
									Container(
										padding: const EdgeInsets.all(16),
										decoration: BoxDecoration(
											color: Colors.white,
											borderRadius: BorderRadius.circular(12),
											boxShadow: [
												BoxShadow(
													color: Colors.black.withValues(alpha: 0.05),
													blurRadius: 10,
													offset: const Offset(0, 4),
												),
											],
										),
										child: Column(
											crossAxisAlignment: CrossAxisAlignment.start,
											children: [
												Row(children: [
													Icon(Icons.restaurant_menu, color: AppThemeV3.primaryGreen),
													const SizedBox(width: 8),
													Text('Choose your meal plan', style: const TextStyle(fontWeight: FontWeight.w700)),
												]),
												const SizedBox(height: 12),
												..._plans.map((plan) {
													final selected = plan.id == _selectedPlanId;
													return Container(
														margin: const EdgeInsets.only(bottom: 12),
														decoration: BoxDecoration(
															color: Colors.grey[50],
															borderRadius: BorderRadius.circular(12),
															border: Border.all(
																color: selected ? AppThemeV3.primaryGreen : Colors.grey.shade200,
																width: selected ? 2 : 1,
															),
														),
														child: ListTile(
															contentPadding: const EdgeInsets.all(16),
															leading: Radio<String>(
																value: plan.id,
																groupValue: _selectedPlanId,
																activeColor: AppThemeV3.primaryGreen,
																onChanged: (val) => setState(() => _selectedPlanId = val),
															),
															title: Text(plan.displayName, style: const TextStyle(fontWeight: FontWeight.w700)),
															subtitle: Text('${plan.mealsPerDay} meal(s)/day • ~\$${plan.monthlyPrice.toStringAsFixed(0)}/mo'),
															onTap: () => setState(() => _selectedPlanId = plan.id),
														),
													);
												}).toList(),
										],
									),
								),

								const SizedBox(height: 16),

								// Payment & Management Card
								Container(
									padding: const EdgeInsets.all(16),
									decoration: BoxDecoration(
										color: Colors.white,
										borderRadius: BorderRadius.circular(12),
										boxShadow: [
											BoxShadow(
												color: Colors.black.withValues(alpha: 0.05),
												blurRadius: 10,
												offset: const Offset(0, 4),
											),
										],
									),
									child: Column(
										crossAxisAlignment: CrossAxisAlignment.start,
										children: [
											Row(children: [
												Icon(Icons.manage_accounts, color: AppThemeV3.primaryGreen),
												const SizedBox(width: 8),
												Text('Manage', style: const TextStyle(fontWeight: FontWeight.w700)),
											]),
											const SizedBox(height: 12),
											ListTile(
												leading: const Icon(Icons.credit_card),
												title: const Text('Payment methods'),
												subtitle: const Text('Add, remove, or set default card'),
												onTap: () => Navigator.push(
													context,
													MaterialPageRoute(builder: (_) => const PaymentMethodsPageV3()),
												),
											),
											const Divider(height: 1),
											ListTile(
												leading: const Icon(Icons.pause_circle_outline),
												title: const Text('Pause or resume'),
												subtitle: const Text('Temporarily stop billing and deliveries'),
												onTap: () async {
													await Navigator.push(
														context,
														MaterialPageRoute(builder: (_) => const PauseResumeSubscriptionPageV1()),
													);
													if (mounted) _loadCurrent();
												},
											),
											const Divider(height: 1),
											ListTile(
												leading: const Icon(Icons.cancel_outlined),
												title: const Text('Cancel subscription'),
												subtitle: const Text('Stops at the end of the current period'),
												trailing: TextButton(
													onPressed: _cancelling ? null : _cancelSubscription,
													style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
													child: Text(_cancelling ? 'Cancelling…' : 'Cancel'),
												),
											),
										],
									),
								),
							],
							),
						),
					),
					SafeArea(
						child: Padding(
							padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
							child: SizedBox(
								width: double.infinity,
								child: ElevatedButton(
									onPressed: _saving || !hasChanges ? null : _save,
									style: ElevatedButton.styleFrom(
										backgroundColor: AppThemeV3.primaryGreen,
										foregroundColor: Colors.white,
										padding: const EdgeInsets.symmetric(vertical: 16),
										shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
									),
									child: Text(_saving ? 'Saving...' : (hasChanges ? 'Save changes' : 'No changes')),
								),
							),
						),
					),
				],
			),
		);
	}
}
