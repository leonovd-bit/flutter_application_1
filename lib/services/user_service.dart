import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile.dart';

class UserService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'users';

  // Create user profile
  static Future<void> createUserProfile(UserProfile userProfile) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(userProfile.uid)
          .set(userProfile.toMap());
    } catch (e) {
      throw Exception('Failed to create user profile: $e');
    }
  }

  // Get user profile
  static Future<UserProfile?> getUserProfile(String uid) async {
    try {
      final doc = await _firestore.collection(_collection).doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return UserProfile.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get user profile: $e');
    }
  }

  // Update user profile
  static Future<void> updateUserProfile(UserProfile userProfile) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(userProfile.uid)
          .update(userProfile.copyWith(updatedAt: DateTime.now()).toMap());
    } catch (e) {
      throw Exception('Failed to update user profile: $e');
    }
  }

  // Update subscription plan
  static Future<void> updateSubscriptionPlan(String uid, String subscriptionPlan) async {
    try {
      await _firestore.collection(_collection).doc(uid).update({
        'subscriptionPlan': subscriptionPlan,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to update subscription plan: $e');
    }
  }

  // Update current schedule ID
  static Future<void> updateCurrentScheduleId(String uid, String? scheduleId) async {
    try {
      await _firestore.collection(_collection).doc(uid).update({
        'currentScheduleId': scheduleId,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to update current schedule ID: $e');
    }
  }

  // Delete user profile
  static Future<void> deleteUserProfile(String uid) async {
    try {
      await _firestore.collection(_collection).doc(uid).delete();
    } catch (e) {
      throw Exception('Failed to delete user profile: $e');
    }
  }

  // Stream user profile
  static Stream<UserProfile?> streamUserProfile(String uid) {
    return _firestore
        .collection(_collection)
        .doc(uid)
        .snapshots()
        .map((doc) {
      if (doc.exists && doc.data() != null) {
        return UserProfile.fromMap(doc.data()!);
      }
      return null;
    });
  }
}
