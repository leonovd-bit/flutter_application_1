import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth/firestore_service_v3.dart';
import 'order_service_v3.dart';
import '../models/meal_model_v3.dart';

class SchedulerServiceV3 {
  // Generate upcoming orders for the next N days based on active schedules
  static Future<int> generateUpcomingOrders({required String userId, int daysAhead = 7}) async {
    try {
      final plan = await FirestoreServiceV3.getCurrentMealPlan(userId);
      if (plan == null) {
        debugPrint('[Scheduler] skip: no current meal plan for user=$userId');
        return 0;
      }
      final schedules = await FirestoreServiceV3.getActiveDeliverySchedules(userId);
      if (schedules.isEmpty) {
        debugPrint('[Scheduler] skip: no active schedules for user=$userId');
        return 0;
      }
      var addresses = await FirestoreServiceV3.getUserAddresses(userId);
      if (addresses.isEmpty) {
        // Fallback to simple name/address pairs (choose first as default) for robustness
        try {
          final pairs = await FirestoreServiceV3.getUserAddressPairs(userId);
          if (pairs.isNotEmpty) {
            // Map the pair to a minimal AddressModelV3-like structure
            addresses = [
              AddressModelV3(
                id: 'pair-0',
                userId: userId,
                label: (pairs.first['name'] ?? 'Address'),
                streetAddress: (pairs.first['address'] ?? ''),
                apartment: '',
                city: 'New York City',
                state: 'New York',
                zipCode: '10001',
                isDefault: true,
              ),
            ];
          }
        } catch (_) {}
      }
      if (addresses.isEmpty) {
        debugPrint('[Scheduler] skip: no addresses for user=$userId');
        return 0;
      }
      final defaultAddress = addresses.firstWhere((a) => a.isDefault, orElse: () => addresses.first);

      final now = DateTime.now();
  debugPrint('[Scheduler] start: user=$userId plan=${plan.id} schedules=${schedules.length} addresses=${addresses.length} defaultAddress=${defaultAddress.id}');
      // Fetch once for dedupe window and build a set of existing delivery slots (epoch minutes)
      final existing = await FirestoreServiceV3.getUpcomingOrders(userId);
      final existingSlots = existing.map<int>((o) {
        final ts = o['deliveryDate'];
        DateTime dt;
        if (ts is Timestamp) {
          dt = ts.toDate();
        } else if (ts is int) {
          dt = DateTime.fromMillisecondsSinceEpoch(ts);
        } else if (ts is DateTime) {
          dt = ts;
        } else {
          return -1;
        }
        return dt.millisecondsSinceEpoch ~/ 60000; // minute resolution
      }).where((v) => v >= 0).toSet();
      int created = 0;
      for (var i = 0; i < daysAhead; i++) {
        final day = now.add(Duration(days: i));
        final weekday = _weekdayName(day.weekday);
        for (final s in schedules.where((s) => s.dayOfWeek.toLowerCase() == weekday)) {
          // Build delivery datetime from the schedule's time
          final deliveryDate = DateTime(day.year, day.month, day.day, s.deliveryTime.hour, s.deliveryTime.minute);
          // Skip if an order already exists for this user at this delivery time (best-effort)
          final slotKey = deliveryDate.millisecondsSinceEpoch ~/ 60000;
          if (existingSlots.contains(slotKey)) continue;

          await OrderServiceV3.createScheduledOrder(
            userId: userId,
            plan: plan,
            schedule: s,
            address: defaultAddress,
            deliveryDate: deliveryDate,
          );
          existingSlots.add(slotKey);
          created++;
        }
      }
  debugPrint('[Scheduler] Generated $created orders for user=$userId (daysAhead=$daysAhead)');
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
