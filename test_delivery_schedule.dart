import 'package:flutter/material.dart';
import 'lib/app_v3/pages/delivery_schedule_page_v3.dart';
import 'lib/app_v3/theme/app_theme_v3.dart';

void main() {
  runApp(TestApp());
}

class TestApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Delivery Schedule Test',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: DeliverySchedulePageV3(),
    );
  }
}
