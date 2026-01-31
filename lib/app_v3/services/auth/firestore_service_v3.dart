import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/meal_model_v3.dart';

class FirestoreServiceV3 {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collections
  static const String _usersCollection = 'users';
  static const String _mealPlansCollection = 'meal_plans';
  static const String _deliverySchedulesCollection = 'delivery_schedules';
  static const String _ordersCollection = 'orders';
  static const String _addressesCollection = 'addresses';
  static const String _subscriptionsCollection = 'subscriptions';

  // ===== USER PROFILE MANAGEMENT =====
  
  static Future<void> createUserProfile({
    required String userId,
    required String email,
    required String fullName,
    String? phoneNumber,
  }) async {
    try {
      await _firestore.collection(_usersCollection).doc(userId).set({
        'id': userId,
        'email': email,
        'fullName': fullName,
        'phoneNumber': phoneNumber,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'profileImageUrl': null,
        'preferences': {
          'notifications': true,
          'emailUpdates': true,
          'smsUpdates': false,
        },
      }, SetOptions(merge: false));
    } catch (e) {
      throw Exception('Failed to create user profile: $e');
    }
  }

  static Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final doc = await _firestore.collection(_usersCollection).doc(userId).get();
      return doc.exists ? doc.data() : null;
    } catch (e) {
      throw Exception('Failed to get user profile: $e');
    }
  }

  static Future<void> updateUserProfile(String userId, Map<String, dynamic> data) async {
    try {
      final ref = _firestore.collection(_usersCollection).doc(userId);
      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(ref);
        final Map<String, dynamic> update = Map<String, dynamic>.from(data);
        update['updatedAt'] = FieldValue.serverTimestamp();
        if (!snap.exists) {
          update['id'] = userId;
          update['createdAt'] = FieldValue.serverTimestamp();
        }
        tx.set(ref, update, SetOptions(merge: true));
      });
    } catch (e) {
      throw Exception('Failed to update user profile: $e');
    }
  }

  /// Update phone number verification status
  static Future<void> updatePhoneVerification(
    String userId,
    String phoneNumber,
  ) async {
    try {
      await _firestore.collection(_usersCollection).doc(userId).set({
        'phoneNumber': phoneNumber,
        'phoneNumberVerified': true,
        'phoneNumberVerifiedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to update phone verification: $e');
    }
  }

  /// Get user's verified phone number
  static Future<String?> getUserPhoneNumber(String userId) async {
    try {
      final doc = await _firestore.collection(_usersCollection).doc(userId).get();
      if (doc.exists) {
        return doc.data()?['phoneNumber'] as String?;
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get phone number: $e');
    }
  }

  /// Check if user's phone number is verified
  static Future<bool> isPhoneNumberVerified(String userId) async {
    try {
      final doc = await _firestore.collection(_usersCollection).doc(userId).get();
      if (doc.exists) {
        return doc.data()?['phoneNumberVerified'] == true;
      }
      return false;
    } catch (e) {
      throw Exception('Failed to check phone verification: $e');
    }
  }

  // ===== MEAL PLAN MANAGEMENT =====

  static Future<MealPlanModelV3?> getCurrentMealPlan(String userId) async {
    try {
      // Try to get from user profile first
      final userDoc = await _firestore.collection(_usersCollection).doc(userId).get();
      if (userDoc.exists) {
        final data = userDoc.data()!;
        final planId = data['currentMealPlanId'] as String?;
        if (planId != null) {
          final planDoc = await _firestore.collection(_mealPlansCollection).doc(planId).get();
          if (planDoc.exists) {
            return MealPlanModelV3.fromJson(planDoc.data()!);
          }
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error getting current meal plan: $e');
      return null;
    }
  }

  static Future<void> setActiveMealPlan(String userId, dynamic plan) async {
    try {
      await _firestore.collection(_usersCollection).doc(userId).update({
        'currentMealPlanId': plan.id,
        'currentPlanName': plan.name,
        'currentPlanDisplayName': plan.displayName,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error setting active meal plan: $e');
    }
  }

  static Future<String?> getDisplayPlanName(String userId) async {
    try {
      final userDoc = await _firestore.collection(_usersCollection).doc(userId).get();
      if (userDoc.exists) {
        final data = userDoc.data()!;
        return data['currentPlanDisplayName'] as String? ?? data['currentPlanName'] as String?;
      }
      return null;
    } catch (e) {
      debugPrint('Error getting display plan name: $e');
      return null;
    }
  }

  // ===== ADDRESS MANAGEMENT =====

  static Future<List<AddressModelV3>> getUserAddresses(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(_addressesCollection)
          .where('userId', isEqualTo: userId)
          .get();
      return snapshot.docs.map((doc) => AddressModelV3.fromJson(doc.data())).toList();
    } catch (e) {
      debugPrint('Error getting user addresses: $e');
      return [];
    }
  }

  static Future<void> saveAddress(dynamic address) async {
    try {
      await _firestore.collection(_addressesCollection).add(address.toJson());
    } catch (e) {
      debugPrint('Error saving address: $e');
    }
  }

  static Future<void> deleteUserAddress(String userId, String addressId) async {
    try {
      await _firestore.collection(_addressesCollection).doc(addressId).delete();
    } catch (e) {
      debugPrint('Error deleting user address: $e');
    }
  }

  // ===== ORDER MANAGEMENT =====

  static Future<Map<String, dynamic>?> getNextUpcomingOrder(String userId) async {
    try {
      debugPrint('[Firestore] Querying next upcoming order for user: $userId');
      
      // Try pending orders first
      var snapshot = await _firestore
          .collection(_ordersCollection)
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .orderBy('estimatedDeliveryTime')
          .limit(1)
          .get();
      
      debugPrint('[Firestore] Query returned ${snapshot.docs.length} pending orders');
      
      // If no pending orders, try confirmed orders (fallback for auto-confirmed orders)
      if (snapshot.docs.isEmpty) {
        debugPrint('[Firestore] No pending orders, trying confirmed orders...');
        snapshot = await _firestore
            .collection(_ordersCollection)
            .where('userId', isEqualTo: userId)
            .where('status', isEqualTo: 'confirmed')
            .orderBy('estimatedDeliveryTime')
            .limit(1)
            .get();
        debugPrint('[Firestore] Query returned ${snapshot.docs.length} confirmed orders');
      }
      
      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        final data = {
          ...doc.data(),
          'id': doc.id,
        };
        debugPrint('[Firestore] Found order: ${doc.id}, status: ${data['status']}, deliveryDate: ${data['deliveryDate']}');
        return data;
      }
      debugPrint('[Firestore] No upcoming orders found');
      return null;
    } catch (e) {
      debugPrint('[Firestore] Error getting next upcoming order: $e');
      return null;
    }
  }

  static Future<void> updateOrderStatus({required String orderId, required dynamic status}) async {
    try {
      String statusValue;
      if (status is OrderStatus) {
        statusValue = status.name;
      } else {
        final text = status?.toString() ?? '';
        statusValue = text.contains('OrderStatus.') ? text.split('.').last : text;
      }
      await _firestore.collection(_ordersCollection).doc(orderId).update({
        'status': statusValue,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating order status: $e');
    }
  }

  static Future<void> updateOrderMeals({required String orderId, required List<dynamic> meals}) async {
    try {
      await _firestore.collection(_ordersCollection).doc(orderId).update({
        'meals': meals,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating order meals: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getPastOrders(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(_ordersCollection)
          .where('userId', isEqualTo: userId)
          .where('status', whereIn: ['delivered', 'cancelled'])
          .orderBy('deliveryDate', descending: true)
          .limit(20)
          .get();
      
  return snapshot.docs.map((doc) => {
    ...doc.data(),
    'id': doc.id,
      }).toList();
    } catch (e) {
      debugPrint('Error getting past orders: $e');
      return [];
    }
  }

  // ===== SUBSCRIPTION MANAGEMENT =====

  static Future<Map<String, dynamic>?> getActiveSubscription(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(_subscriptionsCollection)
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();
      
      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first.data();
      }
      return null;
    } catch (e) {
      debugPrint('Error getting active subscription: $e');
      return null;
    }
  }

  static Future<void> updateActiveSubscriptionPlan(String userId, dynamic plan) async {
    try {
      await _firestore.collection(_subscriptionsCollection).doc(userId).set({
        'userId': userId,
        'planId': plan.id,
        'planName': plan.name,
        'planDisplayName': plan.displayName,
        'status': 'active',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error updating active subscription plan: $e');
    }
  }

  // ===== DELIVERY SCHEDULE MANAGEMENT =====

  static Future<List<dynamic>> getActiveDeliverySchedules(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .collection(_deliverySchedulesCollection)
          .where('isActive', isEqualTo: true)
          .get();
      
      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugPrint('Error getting active delivery schedules: $e');
      return [];
    }
  }

  static Future<void> replaceActiveDeliverySchedules(String userId, List<dynamic> schedules) async {
    try {
      // Delete existing schedules
      final existingSnapshot = await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .collection(_deliverySchedulesCollection)
          .get();
      
      for (final doc in existingSnapshot.docs) {
        await doc.reference.delete();
      }
      
      // Add new schedules as subcollection
      for (final schedule in schedules) {
        await _firestore
            .collection(_usersCollection)
            .doc(userId)
            .collection(_deliverySchedulesCollection)
            .doc(schedule.id)
            .set(schedule.toJson());
      }
    } catch (e) {
      debugPrint('Error replacing active delivery schedules: $e');
    }
  }

  // ===== UTILITY METHODS =====

  static String? getCurrentUserId() {
    return _auth.currentUser?.uid;
  }

  static Future<List<Map<String, dynamic>>> getUserAddressPairs(String userId) async {
    try {
      final addresses = await getUserAddresses(userId);
      return addresses.map((addr) => {
        'id': addr.id,
        'name': addr.label,
        'street': addr.street,
      }).toList();
    } catch (e) {
      debugPrint('Error getting user address pairs: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getUpcomingOrders(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(_ordersCollection)
          .where('userId', isEqualTo: userId)
          .where('status', whereIn: ['pending', 'confirmed'])
          .orderBy('estimatedDeliveryTime')
          .get();
      
  return snapshot.docs.map((doc) => {
    ...doc.data(),
    'id': doc.id,
      }).toList();
    } catch (e) {
      debugPrint('Error getting upcoming orders: $e');
      return [];
    }
  }

  static Future<bool> replaceNextUpcomingOrderMealOfType({
    required String userId,
    required String mealType,
    required dynamic newMeal,
  }) async {
    try {
      final snapshot = await _firestore
          .collection(_ordersCollection)
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .orderBy('deliveryDate')
          .limit(1)
          .get();
      
      if (snapshot.docs.isNotEmpty) {
        final orderDoc = snapshot.docs.first;
        final orderData = orderDoc.data();
        if (orderData['userConfirmed'] == true) {
          debugPrint('Order already user-confirmed; skipping meal replacement');
          return false;
        }
        final meals = List<Map<String, dynamic>>.from(orderData['meals'] ?? []);
        
        // Find and replace meal of the specified type
        for (int i = 0; i < meals.length; i++) {
          if (meals[i]['mealType'] == mealType) {
            meals[i] = newMeal.toJson();
            break;
          }
        }
        
        await orderDoc.reference.update({
          'meals': meals,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error replacing upcoming order meal: $e');
      return false;
    }
  }

  static Future<void> saveMealPlan(dynamic plan) async {
    try {
      await _firestore.collection(_mealPlansCollection).doc(plan.id).set(plan.toJson());
    } catch (e) {
      debugPrint('Error saving meal plan: $e');
    }
  }

  static Stream<dynamic> trackOrderDriverLocation(String orderId) {
    // Stream driver location and status from order_tracking collection.
    // Returns a Map with {lat, lng, status, updatedAt} or null if not available.
    return _firestore.collection('order_tracking').doc(orderId).snapshots().map((doc) {
      if (!doc.exists) return null;
      final data = doc.data();
      if (data == null) return null;
      final lat = data['driverLat'];
      final lng = data['driverLng'];
      return {
        'lat': (lat is num) ? lat.toDouble() : null,
        'lng': (lng is num) ? lng.toDouble() : null,
        'status': data['status'] as String? ?? 'pending',
        'updatedAt': data['updatedAt'],
      };
    });
  }

  static Future<Map<String, dynamic>?> getHealthDataForDate(String userId, DateTime date) async {
    // Simple stub - return null for now
    return null;
  }
}
