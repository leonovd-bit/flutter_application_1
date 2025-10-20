import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

class MealImageFixService {
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;

  static Future<void> clearMealsAndReseed(BuildContext context) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          title: Text('Updating Meal Images'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Clearing old meals and updating to local images...'),
            ],
          ),
        ),
      );

      // Call the Cloud Function
      final callable = _functions.httpsCallable('clearMealsAndReseed');
      final result = await callable.call();
      
      // Close loading dialog
      if (context.mounted) Navigator.of(context).pop();
      
      // Show success dialog
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('✅ Success!'),
            content: Text(result.data['message'] ?? 'Meals updated successfully!'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if open
      if (context.mounted) Navigator.of(context).pop();
      
      // Show error dialog
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('❌ Error'),
            content: Text('Failed to update meal images: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }
}
