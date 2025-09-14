// Complete cleanup script for testing - clears both Auth and Firestore data
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> completeUserCleanup() async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final uid = user.uid;
      print('Cleaning up user: ${user.email} (${uid})');
      
      // 1. Clear Firestore documents for this user
      final batch = FirebaseFirestore.instance.batch();
      
      // Delete user profile
      batch.delete(FirebaseFirestore.instance.collection('users').doc(uid).collection('profile').doc('main'));
      
      // Delete meal plans
      final mealPlansQuery = await FirebaseFirestore.instance.collection('users').doc(uid).collection('mealPlans').get();
      for (final doc in mealPlansQuery.docs) {
        batch.delete(doc.reference);
      }
      
      // Delete delivery schedules
      final schedulesQuery = await FirebaseFirestore.instance.collection('users').doc(uid).collection('deliverySchedules').get();
      for (final doc in schedulesQuery.docs) {
        batch.delete(doc.reference);
      }
      
      // Delete subscriptions
      final subscriptionsQuery = await FirebaseFirestore.instance.collection('users').doc(uid).collection('subscriptions').get();
      for (final doc in subscriptionsQuery.docs) {
        batch.delete(doc.reference);
      }
      
      // Delete orders
      final ordersQuery = await FirebaseFirestore.instance.collection('users').doc(uid).collection('orders').get();
      for (final doc in ordersQuery.docs) {
        batch.delete(doc.reference);
      }
      
      // Delete the entire user document
      batch.delete(FirebaseFirestore.instance.collection('users').doc(uid));
      
      // Commit the batch
      await batch.commit();
      print('✅ Cleared Firestore data for user ${uid}');
      
      // 2. Clear SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('setup_completed');
      await prefs.remove('saved_schedules');
      await prefs.remove('selected_meal_plan_display_name');
      await prefs.remove('selected_meal_plan_id');
      await prefs.remove('selected_meal_plan_name');
      await prefs.remove('current_step');
      await prefs.remove('signup_data');
      await prefs.remove('schedule_data');
      await prefs.remove('payment_data');
      await prefs.remove('step_timestamp');
      
      // Clear uid-specific keys
      await prefs.remove('saved_schedules_${uid}');
      await prefs.remove('selected_meal_plan_id_${uid}');
      await prefs.remove('selected_meal_plan_display_name_${uid}');
      
      print('✅ Cleared SharedPreferences');
      
      // 3. Sign out and delete Auth user
      await FirebaseAuth.instance.signOut();
      await user.delete();
      print('✅ Deleted Firebase Auth user');
      
      print('🎉 Complete cleanup successful! You can now test with a fresh signup.');
      
    } else {
      print('❌ No user signed in');
    }
  } catch (e) {
    print('❌ Error during cleanup: $e');
    print('You may need to sign in first, then run this script');
  }
}

void main() async {
  await completeUserCleanup();
}
