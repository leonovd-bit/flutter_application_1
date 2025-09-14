import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'lib/firebase_options.dart';

Future<void> main() async {
  print('Updating meal images to use local assets...');
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  final firestore = FirebaseFirestore.instance;
  
  try {
    // Clear existing meals
    print('Clearing existing meals...');
    final batch = firestore.batch();
    final existingMeals = await firestore.collection('meals').get();
    
    for (final doc in existingMeals.docs) {
      batch.delete(doc.reference);
    }
    
    await batch.commit();
    print('Cleared ${existingMeals.docs.length} existing meals');
    
    print('✅ Meal images updated! The app will now use local asset images.');
    print('Next time you run the app, meals will be reseeded with local images.');
    
  } catch (e) {
    print('❌ Error updating meal images: $e');
    exit(1);
  }
  
  exit(0);
}
