import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/meal_model_v3.dart';

class FirestoreServiceV3 {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collections
  static const String _usersCollection = 'users';
  static const String _mealPlansCollection = 'meal_plans';
  static const String _deliverySchedulesCollection = 'delivery_schedules';
  static const String _ordersCollection = 'orders';
  static const String _addressesCollection = 'addresses';
  static const String _healthDataCollection = 'health_data';
  static const String _subscriptionsCollection = 'subscriptions';

  // User Management
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
      });
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
      data['updatedAt'] = FieldValue.serverTimestamp();
      await _firestore.collection(_usersCollection).doc(userId).update(data);
    } catch (e) {
      throw Exception('Failed to update user profile: $e');
    }
  }

  // Meal Plan Management
  static Future<void> saveMealPlan(MealPlanModelV3 mealPlan) async {
    try {
      await _firestore
          .collection(_usersCollection)
          .doc(mealPlan.userId)
          .collection(_mealPlansCollection)
          .doc(mealPlan.id)
          .set(mealPlan.toFirestore());
    } catch (e) {
      throw Exception('Failed to save meal plan: $e');
    }
  }

  static Future<MealPlanModelV3?> getCurrentMealPlan(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .collection(_mealPlansCollection)
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return MealPlanModelV3.fromFirestore(querySnapshot.docs.first);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get current meal plan: $e');
    }
  }

  // Delivery Schedule Management
  static Future<void> saveDeliverySchedule(DeliveryScheduleModelV3 schedule) async {
    try {
      await _firestore
          .collection(_usersCollection)
          .doc(schedule.userId)
          .collection(_deliverySchedulesCollection)
          .doc(schedule.id)
          .set(schedule.toFirestore());
    } catch (e) {
      throw Exception('Failed to save delivery schedule: $e');
    }
  }

  static Future<List<DeliveryScheduleModelV3>> getActiveDeliverySchedules(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .collection(_deliverySchedulesCollection)
          .where('isActive', isEqualTo: true)
          .orderBy('weekStartDate', descending: false)
          .get();

      return querySnapshot.docs
          .map((doc) => DeliveryScheduleModelV3.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get delivery schedules: $e');
    }
  }

  // Address Management
  static Future<void> saveAddress(AddressModelV3 address) async {
    try {
      await _firestore
          .collection(_usersCollection)
          .doc(address.userId)
          .collection(_addressesCollection)
          .doc(address.id)
          .set(address.toFirestore());
    } catch (e) {
      throw Exception('Failed to save address: $e');
    }
  }

  static Future<List<AddressModelV3>> getUserAddresses(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .collection(_addressesCollection)
          .orderBy('isDefault', descending: true)
          .orderBy('createdAt', descending: false)
          .get();

      return querySnapshot.docs
          .map((doc) => AddressModelV3.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get user addresses: $e');
    }
  }

  static Future<void> setDefaultAddress(String userId, String addressId) async {
    try {
      final batch = _firestore.batch();

      // Remove default from all addresses
      final addressesSnapshot = await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .collection(_addressesCollection)
          .get();

      for (final doc in addressesSnapshot.docs) {
        batch.update(doc.reference, {'isDefault': false});
      }

      // Set new default
      final newDefaultRef = _firestore
          .collection(_usersCollection)
          .doc(userId)
          .collection(_addressesCollection)
          .doc(addressId);
      
      batch.update(newDefaultRef, {'isDefault': true});
      
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to set default address: $e');
    }
  }

  // Health Data Management
  static Future<void> saveHealthData({
    required String userId,
    required Map<String, dynamic> nutritionData,
    DateTime? date,
  }) async {
    try {
      final targetDate = date ?? DateTime.now();
      final dateString = '${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}';
      
      await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .collection(_healthDataCollection)
          .doc(dateString)
          .set({
        'userId': userId,
        'date': targetDate,
        'nutrition': nutritionData,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to save health data: $e');
    }
  }

  static Future<Map<String, dynamic>?> getHealthDataForDate(String userId, DateTime date) async {
    try {
      final dateString = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      
      final doc = await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .collection(_healthDataCollection)
          .doc(dateString)
          .get();

      return doc.exists ? doc.data() : null;
    } catch (e) {
      throw Exception('Failed to get health data: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getWeeklyHealthData(String userId, DateTime startDate) async {
    try {
      final endDate = startDate.add(const Duration(days: 7));
      
      final querySnapshot = await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .collection(_healthDataCollection)
          .where('date', isGreaterThanOrEqualTo: startDate)
          .where('date', isLessThan: endDate)
          .orderBy('date')
          .get();

      return querySnapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      throw Exception('Failed to get weekly health data: $e');
    }
  }

  // Order Management
  static Future<void> createOrder({
    required String userId,
    required String mealPlanId,
    required String deliveryScheduleId,
    required String addressId,
    required double totalAmount,
    required String paymentIntentId,
    required List<Map<String, dynamic>> meals,
  }) async {
    try {
      final orderId = _firestore.collection(_ordersCollection).doc().id;
      
      await _firestore.collection(_ordersCollection).doc(orderId).set({
        'id': orderId,
        'userId': userId,
        'mealPlanId': mealPlanId,
        'deliveryScheduleId': deliveryScheduleId,
        'addressId': addressId,
        'meals': meals,
        'totalAmount': totalAmount,
        'paymentIntentId': paymentIntentId,
        'status': 'confirmed',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'deliveryDate': null,
        'deliveredAt': null,
        'trackingNumber': null,
      });
    } catch (e) {
      throw Exception('Failed to create order: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getUserOrders(String userId, {int limit = 50}) async {
    try {
      final querySnapshot = await _firestore
          .collection(_ordersCollection)
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return querySnapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      throw Exception('Failed to get user orders: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getUpcomingOrders(String userId) async {
    try {
      final now = DateTime.now();
      final nextWeek = now.add(const Duration(days: 7));
      
      final querySnapshot = await _firestore
          .collection(_ordersCollection)
          .where('userId', isEqualTo: userId)
          .where('status', whereIn: ['confirmed', 'preparing', 'shipped'])
          .where('deliveryDate', isGreaterThanOrEqualTo: now)
          .where('deliveryDate', isLessThanOrEqualTo: nextWeek)
          .orderBy('deliveryDate')
          .get();

      return querySnapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      throw Exception('Failed to get upcoming orders: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getPastOrders(String userId) async {
    try {
      final now = DateTime.now();
      
      final querySnapshot = await _firestore
          .collection(_ordersCollection)
          .where('userId', isEqualTo: userId)
          .where('status', whereIn: ['delivered', 'cancelled', 'refunded'])
          .where('deliveryDate', isLessThan: now)
          .orderBy('deliveryDate', descending: true)
          .limit(50)
          .get();

      return querySnapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      throw Exception('Failed to get past orders: $e');
    }
  }

  // Subscription Management
  static Future<void> createSubscription({
    required String userId,
    required String mealPlanId,
    required String stripeSubscriptionId,
    required double monthlyAmount,
  }) async {
    try {
      await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .collection(_subscriptionsCollection)
          .doc(stripeSubscriptionId)
          .set({
        'id': stripeSubscriptionId,
        'userId': userId,
        'mealPlanId': mealPlanId,
        'stripeSubscriptionId': stripeSubscriptionId,
        'monthlyAmount': monthlyAmount,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'nextBillingDate': null,
        'cancelAtPeriodEnd': false,
      });
    } catch (e) {
      throw Exception('Failed to create subscription: $e');
    }
  }

  static Future<Map<String, dynamic>?> getActiveSubscription(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .collection(_subscriptionsCollection)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.data();
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get active subscription: $e');
    }
  }

  // Utility Methods
  static String? getCurrentUserId() {
    return _auth.currentUser?.uid;
  }

  static Future<void> deleteDocument(String collection, String documentId) async {
    try {
      await _firestore.collection(collection).doc(documentId).delete();
    } catch (e) {
      throw Exception('Failed to delete document: $e');
    }
  }

  static Stream<DocumentSnapshot> listenToUserProfile(String userId) {
    return _firestore.collection(_usersCollection).doc(userId).snapshots();
  }

  static Stream<QuerySnapshot> listenToUserOrders(String userId) {
    return _firestore
        .collection(_ordersCollection)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots();
  }
}
