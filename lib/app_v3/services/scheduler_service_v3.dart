import 'package:flutter/foundation.dart';
import 'firestore_service_v3.dart';
import 'order_service_v3.dart';

class SchedulerServiceV3 {
  // Generate upcoming orders for the next N days based on active schedules
  static Future<int> generateUpcomingOrders({required String userId, int daysAhead = 7}) async {
    try {
      final plan = await FirestoreServiceV3.getCurrentMealPlan(userId);
      if (plan == null) return 0;
      final schedules = await FirestoreServiceV3.getActiveDeliverySchedules(userId);
      if (schedules.isEmpty) return 0;
      final addresses = await FirestoreServiceV3.getUserAddresses(userId);
      if (addresses.isEmpty) return 0;
      final defaultAddress = addresses.firstWhere((a) => a.isDefault, orElse: () => addresses.first);

      final now = DateTime.now();
      int created = 0;
      for (var i = 0; i < daysAhead; i++) {
        final day = now.add(Duration(days: i));
        final weekday = _weekdayName(day.weekday);
        for (final s in schedules.where((s) => s.dayOfWeek.toLowerCase() == weekday)) {
          // Build delivery datetime from the schedule's time
          final deliveryDate = DateTime(day.year, day.month, day.day, s.deliveryTime.hour, s.deliveryTime.minute);
          // Skip if an order already exists for this user at this delivery time (best-effort)
          final existing = await FirestoreServiceV3.getUpcomingOrders(userId);
          final already = existing.any((o) {
            final ts = o['deliveryDate'];
            final dt = ts is int ? DateTime.fromMillisecondsSinceEpoch(ts) : (ts is DateTime ? ts : DateTime.now());
            return dt.year == deliveryDate.year && dt.month == deliveryDate.month && dt.day == deliveryDate.day && dt.hour == deliveryDate.hour && dt.minute == deliveryDate.minute;
          });
          if (already) continue;

          await OrderServiceV3.createScheduledOrder(
            userId: userId,
            plan: plan,
            schedule: s,
            address: defaultAddress,
            deliveryDate: deliveryDate,
          );
          created++;
        }
      }
      return created;
    } catch (e) {
      debugPrint('Scheduler generation failed: $e');
      return 0;
    }
  }

  static String _weekdayName(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'monday';
      case DateTime.tuesday:
        return 'tuesday';
      case DateTime.wednesday:
        return 'wednesday';
      case DateTime.thursday:
        return 'thursday';
      case DateTime.friday:
        return 'friday';
      case DateTime.saturday:
        return 'saturday';
      case DateTime.sunday:
        return 'sunday';
      default:
        return 'monday';
    }
  }
}
