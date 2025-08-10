import 'package:flutter/foundation.dart';

// Minimal, local-only notification service stub used by Upcoming Orders.
// Replace with flutter_local_notifications or Firebase Cloud Messaging as needed.
class NotificationServiceV3 {
  NotificationServiceV3._();
  static final NotificationServiceV3 instance = NotificationServiceV3._();

  Future<void> init() async {
    // No-op for stub
  }

  Future<void> scheduleOneHourBefore({
    required int id,
    required DateTime deliveryTime,
    required String title,
    required String body,
    String? payload,
  }) async {
    // Stub logs only. Integrate with a notification plugin to actually schedule.
    debugPrint('[NotificationServiceV3] scheduleOneHourBefore id=$id at ${deliveryTime.subtract(const Duration(hours: 1))}');
  }

  Future<void> cancel(int id) async {
    debugPrint('[NotificationServiceV3] cancel id=$id');
  }
}

