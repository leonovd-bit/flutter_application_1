// Utility to clear setup flags for debugging unintended auto sign-up.
import 'package:shared_preferences/shared_preferences.dart';

Future<void> clearFlags() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('setup_completed');
  await prefs.remove('saved_schedules');
  await prefs.remove('selected_meal_plan_display_name');
  await prefs.remove('selected_meal_plan_id');
  await prefs.remove('force_sign_out');
}

void main() async {
  await clearFlags();
  // ignore: avoid_print
  print('Cleared setup flags.');
}
