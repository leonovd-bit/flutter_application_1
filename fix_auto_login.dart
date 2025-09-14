import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  print('Fixing auto-login setup...');
  
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('setup_completed', true);
  
  print('✅ Set setup_completed flag to true');
  print('Now refresh your app - it should route to home instead of signup!');
}
