import 'package:flutter/material.dart';
import '../theme/app_theme_v3.dart';
import 'delivery_schedule_overview_page_v2.dart';
import 'meal_schedule_overview_page_v2.dart';
import 'delivery_schedule_page_v4.dart';
import 'meal_schedule_page_v3.dart';
import 'payment_methods_page_v3.dart';
import 'address_page_v3.dart';
import 'manage_subscription_page_v3.dart';

class ManagePageV1 extends StatelessWidget {
  const ManagePageV1({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeV3.background,
      appBar: AppBar(
        backgroundColor: AppThemeV3.surface,
        title: const Text('Manage'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionHeader('Schedules & Meals'),
          _tile(
            context,
            icon: Icons.calendar_month_outlined,
            title: 'Delivery Schedule Overview',
            subtitle: 'View your saved delivery schedules',
            builder: (ctx) => const DeliveryScheduleOverviewPageV2(),
          ),
          _tile(
            context,
            icon: Icons.edit_calendar_outlined,
            title: 'Edit Delivery Schedule',
            subtitle: 'Open the schedule builder',
            builder: (ctx) => const DeliverySchedulePageV4(),
          ),
          _tile(
            context,
            icon: Icons.restaurant_menu_outlined,
            title: 'Meal Schedule Overview',
            subtitle: 'View meals selected per delivery',
            builder: (ctx) => const MealScheduleOverviewPageV2(),
          ),
          _tile(
            context,
            icon: Icons.edit_note_outlined,
            title: 'Edit Meal Schedule',
            subtitle: 'Open the meal selection builder',
            builder: (ctx) => const MealSchedulePageV3(),
          ),

          const SizedBox(height: 24),
          _sectionHeader('Billing & Addresses'),
          _tile(
            context,
            icon: Icons.payment_outlined,
            title: 'Payment Methods',
            subtitle: 'Manage cards and billing',
            builder: (ctx) => const PaymentMethodsPageV3(),
          ),
          _tile(
            context,
            icon: Icons.location_on_outlined,
            title: 'Addresses',
            subtitle: 'Manage delivery addresses',
            builder: (ctx) => const AddressPageV3(),
          ),
          _tile(
            context,
            icon: Icons.subscriptions_outlined,
            title: 'Meal Plan Subscription',
            subtitle: 'Change or manage your plan',
            builder: (ctx) => const ManageSubscriptionPageV3(),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required WidgetBuilder builder,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppThemeV3.primaryGreen.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppThemeV3.primaryGreen),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: Colors.grey.shade700),
        ),
        trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade400),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: builder)),
      ),
    );
  }
}
