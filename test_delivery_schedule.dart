import 'package:flutter/material.dart';
import 'lib/app_v3/pages/delivery_schedule_page_v4.dart';

void main() {
  runApp(TestApp());
}

class TestApp extends StatelessWidget {
  const TestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Delivery Schedule Test',
      home: DeliverySchedulePageV4(),
    );
  }
}
