import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/meal_model_v3.dart';
import '../../services/auth/firestore_service_v3.dart';
import '../../theme/app_theme_v3.dart';
import '../payment/payment_methods_page_v3.dart';
import '../../services/orders/order_functions_service.dart';
import '../../config/stripe_prices.dart';
import 'pause_resume_subscription_page_v1.dart';
import '../delivery/delivery_schedule_page_v5.dart';
import '../meals/meal_schedule_page_v3_fixed.dart';
 
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
	bool _loadingCurrent = true;
	bool _dirtySelection = false; // true when user selected a different plan than initial
	bool _saving = false;
	bool _cancelling = false;
	Map<String, dynamic>? _activeSub;

	Widget _buildStatusChip(String? statusRaw) {
		final status = (statusRaw ?? 'none').toLowerCase();
		Color bg;
		Color fg;
		String label = status;
		switch (status) {
			case 'none':
				bg = Colors.grey.withValues(alpha: 0.15);
				fg = Colors.grey.shade700;
				label = 'No subscription';
				break;
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
			if (mounted) {
				setState(() { 
					// If user has no current plan yet, preselect the first plan and mark as changeable
					if (current == null) {
						_selectedPlanId = _plans.first.id;
						_initialPlanId = null;
						_dirtySelection = true; // enable Save for first-time selection
					} else {
						_selectedPlanId = current.id; 
						_initialPlanId = current.id; 
						_dirtySelection = false;
					}
					_activeSub = sub; 
					_loadingCurrent = false;
				});
				// Debug: Print what we loaded
				debugPrint('[ManageSubscription] Loaded current plan: ${current?.id} (${current?.displayName})');

				// If user has no subscription record yet, bootstrap a local active subscription immediately
				if (sub == null) {
					final planForBootstrap = current ?? _plans.first;
					try {
						await FirestoreServiceV3.updateActiveSubscriptionPlan(uid, planForBootstrap);
						final refreshed = await FirestoreServiceV3.getActiveSubscription(uid);
						if (mounted) setState(() { _activeSub = refreshed; });
						debugPrint('[ManageSubscription] Bootstrapped local active subscription with plan ${planForBootstrap.id}');
					} catch (e) {
						debugPrint('[ManageSubscription] Failed to bootstrap subscription: $e');
					}
				}
			}
		} catch (e) {
			debugPrint('[ManageSubscription] Error loading current plan: $e');
			if (mounted) setState(() { _loadingCurrent = false; });
		}
	}

	Future<void> _save() async {
		debugPrint('[ManageSubscription] === SAVE STARTED ===');
		if (_loadingCurrent) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('Please wait, loading your current plan...')),
			);
			return;
		}
		final uid = _auth.currentUser?.uid;
		if (uid == null || _selectedPlanId == null) return;
		
		final newPlan = _plans.firstWhere((p) => p.id == _selectedPlanId);
		final oldPlan = _initialPlanId != null 
			? _plans.firstWhere((p) => p.id == _initialPlanId, orElse: () => newPlan)
			: newPlan;
		
		debugPrint('[ManageSubscription] Old plan: ${oldPlan.id} (${oldPlan.displayName})');
		debugPrint('[ManageSubscription] New plan: ${newPlan.id} (${newPlan.displayName})');
		
	// Check if plan actually changed - any plan change requires setup
	// Note: if _initialPlanId is null (e.g., slow load), treat as requiring setup when user selects a plan
	final needsScheduleUpdate = _selectedPlanId != _initialPlanId;
		
		debugPrint('[ManageSubscription] Plan change check: initialPlanId=$_initialPlanId, selectedPlanId=$_selectedPlanId, needsSetup=$needsScheduleUpdate');
		
		// If schedule update needed, show confirmation dialog
		if (needsScheduleUpdate) {
			debugPrint('[ManageSubscription] Showing schedule update dialog...');
			final confirmed = await _showScheduleUpdateDialog(oldPlan, newPlan);
			debugPrint('[ManageSubscription] Dialog confirmed: $confirmed');
			if (confirmed != true) return; // User backed out
			
			// Navigate through configuration workflow
			debugPrint('[ManageSubscription] Starting configuration workflow...');
			final completed = await _navigateConfigurationWorkflow(newPlan);
			debugPrint('[ManageSubscription] Workflow completed: $completed');
			if (completed != true) {
				// User backed out of workflow - don't save
				if (mounted) {
					ScaffoldMessenger.of(context).showSnackBar(
						const SnackBar(
							content: Text('Plan change cancelled - schedules not updated'),
							backgroundColor: Colors.orange,
						),
					);
				}
				return;
			}
		} else {
			debugPrint('[ManageSubscription] SKIPPING schedule update workflow (needsScheduleUpdate=false)');
		}
		
		setState(() => _saving = true);
		
		try {
			debugPrint('[ManageSubscription] Saving plan change: ${_initialPlanId} -> ${_selectedPlanId}');
			
			// If there's an active Stripe subscription, update its price first.
			final currentSub = _activeSub;
			if (currentSub != null) {
				final subId = (currentSub['stripeSubscriptionId'] ?? currentSub['id'])?.toString();
				final newPriceId = StripePricesConfig.priceIdForPlanId(newPlan.id);
				if ((subId ?? '').isNotEmpty && (newPriceId).isNotEmpty) {
					try {
						await OrderFunctionsService.instance.updateSubscription(
							subscriptionId: subId!,
							newPriceId: newPriceId,
						);
						debugPrint('[ManageSubscription] Stripe subscription updated successfully');
					} catch (e) {
						debugPrint('[ManageSubscription] Stripe update failed: $e');
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
			await FirestoreServiceV3.setActiveMealPlan(uid, newPlan);
			await FirestoreServiceV3.updateActiveSubscriptionPlan(uid, newPlan);

			// Refresh active subscription snapshot for immediate UI update
			try {
				final latestSub = await FirestoreServiceV3.getActiveSubscription(uid);
				if (mounted) setState(() { _activeSub = latestSub; });
			} catch (e) {
				debugPrint('[ManageSubscription] Could not refresh active subscription: $e');
			}
			
			try {
				final prefs = await SharedPreferences.getInstance();
				// Save with UID suffix for user isolation
				await prefs.setString('selected_meal_plan_id_$uid', newPlan.id);
				await prefs.setString('selected_meal_plan_name_$uid', newPlan.name);
				await prefs.setString('selected_meal_plan_display_name_$uid', newPlan.displayName);
				// Also save without suffix for backward compatibility
				await prefs.setString('selected_meal_plan_id', newPlan.id);
				await prefs.setString('selected_meal_plan_name', newPlan.name);
				await prefs.setString('selected_meal_plan_display_name', newPlan.displayName);
				debugPrint('[ManageSubscription] Local preferences updated to ${newPlan.id} (${newPlan.displayName})');
			} catch (e) {
				debugPrint('[ManageSubscription] Error updating local prefs: $e');
			}
			
			if (!mounted) return;
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(
					content: Text('Subscription updated to ${newPlan.displayName}'),
					backgroundColor: AppThemeV3.primaryGreen,
				),
			);
			setState(() { 
				_initialPlanId = _selectedPlanId; 
				_dirtySelection = false; // reset dirty flag after successful save
			});
			
			// Close the page after successful save
			Future.delayed(Duration(milliseconds: 1000), () {
				if (mounted) Navigator.of(context).pop();
			});
			
		} catch (e) {
			debugPrint('[ManageSubscription] Save failed: $e');
			if (!mounted) return;
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(content: Text('Failed to update: $e')),
			);
		} finally {
			if (mounted) setState(() => _saving = false);
		}
	}

	Future<void> _cancelSubscription() async {
		final subId = (_activeSub?['stripeSubscriptionId'] 
			?? _activeSub?['stripe_subscription_id'] 
			?? _activeSub?['id'])
			?.toString();
		if (subId == null || subId.isEmpty) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('No Stripe subscription linked to cancel.')),
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
				ScaffoldMessenger.of(context).showSnackBar(
					SnackBar(content: Text('Error: $e')),
				);
			}
		} finally {
			if (mounted) setState(() { _cancelling = false; });
		}
	}

	@override
	Widget build(BuildContext context) {
		final hasChanges = _dirtySelection;
		// Determine if this user has a real Stripe subscription that can be cancelled
		final stripeSubId = (_activeSub?['stripeSubscriptionId'] ?? _activeSub?['stripe_subscription_id'])?.toString();
		final canCancelStripe = (stripeSubId != null && stripeSubId.isNotEmpty);
		
		return Focus(
			autofocus: true,
			onKeyEvent: (node, event) {
				if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
					if (hasChanges && !_saving) {
						_save();
						return KeyEventResult.handled;
					}
				}
				return KeyEventResult.ignored;
			},
			child: Scaffold(
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
																										Icon(Icons.subscriptions, color: AppThemeV3.primaryGreen, size: 20),
																										const SizedBox(width: 8),
																										Expanded(
																											child: Text(
																												'Subscription Status', 
																												style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
																											),
																										),
																										IconButton(
																											icon: const Icon(Icons.pause_circle_outline, size: 20),
																											tooltip: 'Pause/Resume',
																											padding: EdgeInsets.zero,
																											constraints: const BoxConstraints(),
																											onPressed: () async {
																												await Navigator.push(
																													context,
																													MaterialPageRoute(builder: (_) => const PauseResumeSubscriptionPageV1()),
																												);
																												if (mounted) _loadCurrent();
																											},
																										),
																									],
																								),
																								const SizedBox(height: 12),
																								Row(
																																		children: [
																																				// Show clear state: if no active subscription doc, don't pretend it's Active
																																				if (_activeSub == null)
																																					_buildStatusChip('none')
																																				else
																																					_buildStatusChip((_activeSub?['status'])?.toString()),
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
																									final dateStr = dt != null ? dt.toLocal().toString().split('.').first : '—';
																									return Text('Next billing: $dateStr', style: const TextStyle(color: Colors.black54));
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
																									final isCurrentPlan = _initialPlanId != null && plan.id == _initialPlanId;
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
														child: RadioListTile<String>(
															value: plan.id,
															groupValue: _selectedPlanId,
															activeColor: AppThemeV3.primaryGreen,
																													title: Row(
																														children: [
																															Expanded(
																																child: Text(
																																	plan.displayName,
																																	style: const TextStyle(fontWeight: FontWeight.w700),
																																),
																															),
																															if (isCurrentPlan)
																																Container(
																																	padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
																																	decoration: BoxDecoration(
																																		color: Colors.grey.withValues(alpha: 0.15),
																																		borderRadius: BorderRadius.circular(999),
																																	),
																																	child: const Text(
																																		'Current',
																																		style: TextStyle(fontSize: 12, color: Colors.black54),
																																	),
																																),
																														],
																													),
																													subtitle: Text('${plan.mealsPerDay} meal(s) per day'),
															controlAffinity: ListTileControlAffinity.leading,
															onChanged: isCurrentPlan ? null : (val) {
																final chosen = val;
																debugPrint('[ManageSubscription] Plan tile changed -> ' + (chosen ?? 'null'));
																setState(() {
																	_selectedPlanId = chosen;
																	// Enable Save when the new selection differs from the initial selection.
																	// If there was no initial plan loaded (null), any non-null selection counts as a change.
																	_dirtySelection = (chosen != _initialPlanId);
																});
															},
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
												subtitle: Text(
													canCancelStripe
														? 'Stops at the end of the current period'
														: 'No Stripe subscription linked — nothing to cancel',
												),
												trailing: TextButton(
													onPressed: (_cancelling || !canCancelStripe) ? null : _cancelSubscription,
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
		), // Close Focus widget
		);
	}

	Future<bool?> _showScheduleUpdateDialog(MealPlanModelV3 oldPlan, MealPlanModelV3 newPlan) async {
			final changes = <String>[];
			// If the initial plan wasn't loaded, avoid misleading X->X rendering
			if (_initialPlanId == null) {
				changes.add('• Plan will be set to ${newPlan.displayName}');
			} else {
				changes.add('• Plan: ${oldPlan.displayName} → ${newPlan.displayName}');
			}
		if (oldPlan.mealsPerDay != newPlan.mealsPerDay) {
			changes.add('• Meals per day: ${oldPlan.mealsPerDay} → ${newPlan.mealsPerDay}');
		}

		return showDialog<bool>(
			context: context,
			barrierDismissible: false,
			builder: (context) => AlertDialog(
				title: Row(
					children: [
						Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
						const SizedBox(width: 8),
						const Flexible(
							child: Text(
								'Schedule Update Required',
								style: TextStyle(fontSize: 18),
							),
						),
					],
				),
				content: SingleChildScrollView(
					child: Column(
						mainAxisSize: MainAxisSize.min,
						crossAxisAlignment: CrossAxisAlignment.start,
						children: [
							const Text(
								'Changing your meal plan will affect your delivery and meal schedules:',
								style: TextStyle(fontWeight: FontWeight.w600),
							),
							const SizedBox(height: 12),
							...changes.map((change) => Padding(
								padding: const EdgeInsets.only(bottom: 4),
								child: Text(change, style: const TextStyle(fontSize: 14)),
							)),
							const SizedBox(height: 12),
							Container(
								padding: const EdgeInsets.all(12),
								decoration: BoxDecoration(
									color: Colors.orange.shade50,
									borderRadius: BorderRadius.circular(8),
									border: Border.all(color: Colors.orange.shade200),
								),
								child: const Text(
									'You\'ll need to update your:\n'
									'1. Delivery schedule\n'
									'2. Meal selections\n\n'
									'If you back out, your changes won\'t be saved.',
									style: TextStyle(fontSize: 13),
								),
							),
						],
					),
				),
				actions: [
					TextButton(
						onPressed: () => Navigator.pop(context, false),
						child: const Text('Cancel'),
					),
					ElevatedButton(
						onPressed: () => Navigator.pop(context, true),
						style: ElevatedButton.styleFrom(
							backgroundColor: Colors.orange,
						),
						child: const Text('Continue'),
					),
				],
			),
		);
	}

	Future<bool?> _navigateConfigurationWorkflow(MealPlanModelV3 newPlan) async {
		// Save the new plan to preferences first so the pages can access it
		try {
			final uid = _auth.currentUser?.uid;
			if (uid != null) {
				final prefs = await SharedPreferences.getInstance();
				// Save with UID suffix for user isolation
				await prefs.setString('selected_meal_plan_id_$uid', newPlan.id);
				await prefs.setString('selected_meal_plan_name_$uid', newPlan.name);
				await prefs.setString('selected_meal_plan_display_name_$uid', newPlan.displayName);
				// Also save without suffix for backward compatibility with other pages
				await prefs.setString('selected_meal_plan_id', newPlan.id);
				await prefs.setString('selected_meal_plan_name', newPlan.name);
				await prefs.setString('selected_meal_plan_display_name', newPlan.displayName);
				debugPrint('[ManageSubscription] Saved plan ${newPlan.id} (${newPlan.displayName}) with ${newPlan.mealsPerDay} meals/day');
			}
		} catch (e) {
			debugPrint('[ManageSubscription] Error saving temp plan: $e');
		}

		if (!mounted) return false;

		// Navigate to delivery schedule first
		final deliveryResult = await Navigator.push<bool>(
			context,
			MaterialPageRoute(
				builder: (context) => const DeliverySchedulePageV5(),
			),
		);

		// If they backed out of delivery schedule, workflow incomplete
		if (deliveryResult != true && !mounted) return false;
		if (deliveryResult != true) {
			final continueWorkflow = await showDialog<bool>(
				context: context,
				builder: (context) => AlertDialog(
					title: const Text('Incomplete Setup'),
					content: const Text(
						'You need to complete both delivery and meal schedules for the plan change to take effect.\n\n'
						'Continue with meal selection?'
					),
					actions: [
						TextButton(
							onPressed: () => Navigator.pop(context, false),
							child: const Text('Cancel All'),
						),
						ElevatedButton(
							onPressed: () => Navigator.pop(context, true),
							child: const Text('Continue'),
						),
					],
				),
			);
			if (continueWorkflow != true) return false;
		}

		if (!mounted) return false;

		// Navigate to meal schedule
		final mealResult = await Navigator.push<bool>(
			context,
			MaterialPageRoute(
				builder: (context) => MealSchedulePageV3(
					mealPlan: newPlan,
				),
			),
		);

		// Return true only if meal schedule was completed
		return mealResult == true;
	}
}
