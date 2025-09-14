import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/meal_model_v3.dart';
import 'dart:async';

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
      // Delete any existing user document to ensure a clean profile
      final userDoc = _firestore.collection(_usersCollection).doc(userId);
      final existing = await userDoc.get();
      if (existing.exists) {
        await userDoc.delete();
      }
      await userDoc.set({
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

  // Display helper: best-effort plan name resolution for the current user.
  // Order of preference:
  // 1) Active subscription.planName
  // 2) Active subscription.mealPlanId -> meal plan displayName/name
  // 3) Current meal plan (most recent active or recent)
  // 4) Next upcoming order.mealPlanId -> meal plan displayName/name
  // 5) Most recent order.mealPlanId -> meal plan displayName/name
  static Future<String?> getDisplayPlanName(String userId) async {
    // 1 & 2: Subscription based resolution
    try {
      final sub = await getActiveSubscription(userId);
      final subName = sub?['planName'] as String?;
      if (subName != null && subName.trim().isNotEmpty) {
        return subName.trim();
      }
      final subPlanId = sub?['mealPlanId'] as String?;
      if (subPlanId != null && subPlanId.trim().isNotEmpty) {
        final subPlan = await getMealPlanById(userId, subPlanId);
        if (subPlan != null) {
          final name = subPlan.displayName.isNotEmpty ? subPlan.displayName : subPlan.name;
          if (name.trim().isNotEmpty) return name.trim();
        }
      }
    } catch (_) {}

    // 3: Current meal plan
    try {
      final mealPlan = await getCurrentMealPlan(userId);
      if (mealPlan != null) {
        final name = mealPlan.displayName.isNotEmpty ? mealPlan.displayName : mealPlan.name;
        if (name.trim().isNotEmpty) return name.trim();
      }
    } catch (_) {}

    // 3.5: Onboarding/Signup fallback via SharedPreferences (saved during delivery schedule)
    try {
      final prefs = await SharedPreferences.getInstance();
      final prefDisplay = prefs.getString('selected_meal_plan_display_name');
      if (prefDisplay != null && prefDisplay.trim().isNotEmpty) {
        return prefDisplay.trim();
      }
      final prefName = prefs.getString('selected_meal_plan_name');
      if (prefName != null && prefName.trim().isNotEmpty) {
        return prefName.trim();
      }
    } catch (_) {}

    // 4: Next upcoming order
    try {
      final next = await getNextUpcomingOrder(userId);
      final orderPlanId = (next?['mealPlanId'] ?? '').toString();
      if (orderPlanId.isNotEmpty) {
        final plan = await getMealPlanById(userId, orderPlanId);
        if (plan != null) {
          final name = plan.displayName.isNotEmpty ? plan.displayName : plan.name;
          if (name.trim().isNotEmpty) return name.trim();
        }
      }
    } catch (_) {}

    // 5: Most recent order fallback
    try {
      final recent = await getUserOrders(userId, limit: 10);
      if (recent.isNotEmpty) {
        final first = recent.first;
        final planId = (first['mealPlanId'] ?? '').toString();
        if (planId.isNotEmpty) {
          final plan = await getMealPlanById(userId, planId);
          if (plan != null) {
            final name = plan.displayName.isNotEmpty ? plan.displayName : plan.name;
            if (name.trim().isNotEmpty) return name.trim();
          }
        }
      }
    } catch (_) {}

    return null; // Unknown, UI can show an ellipsis
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
        // Build update payload; avoid mutating the caller's map
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

  // Address Management (simple name/address pairs for lightweight use cases)
  static Future<List<Map<String, String>>> getUserAddressPairs(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .collection(_addressesCollection)
          .orderBy('createdAt', descending: false)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        final name = (data['name'] ?? '').toString();
        final address = (data['address'] ?? '').toString();
        return {'name': name, 'address': address};
      }).toList();
    } catch (e) {
      throw Exception('Failed to load addresses: $e');
    }
  }

  static Future<void> addUserAddressPair({
    required String userId,
    required String name,
    required String address,
  }) async {
    try {
      await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .collection(_addressesCollection)
          .add({
        'name': name,
        'address': address,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to add address: $e');
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
      debugPrint('[getCurrentMealPlan] V2 start for user=$userId');
      // Avoid composite index by fetching a reasonable number and filtering client-side
      final querySnapshot = await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .collection(_mealPlansCollection)
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();

      final docs = querySnapshot.docs;
      debugPrint('[getCurrentMealPlan] fetched docs=${docs.length}');
      if (docs.isEmpty) {
        debugPrint('[getCurrentMealPlan] no user plans; checking subscription fallback');
        // Fallback: resolve from active subscription if no meal plan docs exist yet
        try {
          final sub = await getActiveSubscription(userId);
          final subPlanId = (sub?['mealPlanId'] ?? '').toString().trim();
          final subPlanName = (sub?['planName'] ?? '').toString().trim();
          if (subPlanId.isNotEmpty || subPlanName.isNotEmpty) {
            final available = MealPlanModelV3.getAvailablePlans();
            final plan = available.firstWhere(
              (p) => p.id == subPlanId,
              orElse: () {
                final lname = subPlanName.toLowerCase();
                return available.firstWhere(
                  (p) => p.displayName.toLowerCase() == lname || p.name.toLowerCase() == lname,
                  orElse: () => available.first,
                );
              },
            );
            return plan;
          }
        } catch (_) {}
        return null;
      }

  // Prefer the most recent active plan; else the most recent plan
      QueryDocumentSnapshot<Map<String, dynamic>>? active;
      for (final d in docs) {
        final data = d.data();
        if ((data['isActive'] == true)) {
          active = d;
          break;
        }
      }
      final chosen = active ?? docs.first;
  debugPrint('[getCurrentMealPlan] returning plan doc id=${chosen.id} (active? ${active != null})');
      return MealPlanModelV3.fromFirestore(chosen);
    } catch (e) {
      throw Exception('Failed to get current meal plan: $e');
    }
  }

  static Future<MealPlanModelV3?> getMealPlanById(String userId, String mealPlanId) async {
    try {
      final doc = await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .collection(_mealPlansCollection)
          .doc(mealPlanId)
          .get();
      if (!doc.exists) return null;
      return MealPlanModelV3.fromFirestore(doc);
    } catch (e) {
      throw Exception('Failed to get meal plan by id: $e');
    }
  }

  // Activate the given meal plan for the user (and deactivate others)
  static Future<void> setActiveMealPlan(String userId, MealPlanModelV3 plan) async {
    try {
      debugPrint('[FirestoreServiceV3] Setting active meal plan ${plan.id} for user $userId');
      
      final userPlans = await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .collection(_mealPlansCollection)
          .limit(100)
          .get();

      debugPrint('[FirestoreServiceV3] Found ${userPlans.docs.length} existing meal plans');

      final batch = _firestore.batch();
      for (final d in userPlans.docs) {
        batch.update(d.reference, {'isActive': false, 'updatedAt': FieldValue.serverTimestamp()});
      }
      final planRef = _firestore
          .collection(_usersCollection)
          .doc(userId)
          .collection(_mealPlansCollection)
          .doc(plan.id);
      batch.set(planRef, {
        ...plan.toFirestore(),
        'userId': userId,
        'isActive': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      debugPrint('[FirestoreServiceV3] Committing batch write for meal plan');
      await batch.commit();

      debugPrint('[FirestoreServiceV3] Updating user profile with active plan');
      // Denormalize the active plan onto the user profile for quick lookups
      await _firestore.collection(_usersCollection).doc(userId).set({
        'currentMealPlanId': plan.id,
        'currentPlanName': plan.displayName.isNotEmpty ? plan.displayName : plan.name,
        'currentMealsPerDay': plan.mealsPerDay,
        'currentPricePerMeal': plan.pricePerMeal,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      debugPrint('[FirestoreServiceV3] Successfully set active meal plan');
    } catch (e) {
      debugPrint('[FirestoreServiceV3] Error setting active meal plan: $e');
      throw Exception('Failed to set active meal plan: $e');
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

  // Replace all active delivery schedules for a user with the provided set (batch, idempotent-ish)
  static Future<void> replaceActiveDeliverySchedules(String userId, List<DeliveryScheduleModelV3> schedules) async {
    try {
      final col = _firestore
          .collection(_usersCollection)
          .doc(userId)
          .collection(_deliverySchedulesCollection);

      // 1) Load current schedules (limit to a reasonable amount)
      final existing = await col.limit(200).get();

      // 2) Build batch to deactivate existing and upsert new
      final batch = _firestore.batch();
      for (final d in existing.docs) {
        final data = d.data();
        final wasActive = (data['isActive'] == true);
        if (wasActive) {
          batch.update(d.reference, {
            'isActive': false,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      for (final s in schedules) {
        final ref = col.doc(s.id);
        final payload = s.toFirestore();
        payload['isActive'] = true; // ensure active
        payload['updatedAt'] = FieldValue.serverTimestamp();
        payload['createdAt'] = FieldValue.serverTimestamp();
        batch.set(ref, payload, SetOptions(merge: true));
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to replace delivery schedules: $e');
    }
  }

  static Future<List<DeliveryScheduleModelV3>> getActiveDeliverySchedules(String userId) async {
    try {
      // Use single-field filter to avoid composite index requirement; sort client-side
      final querySnapshot = await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .collection(_deliverySchedulesCollection)
          .where('isActive', isEqualTo: true)
          .get();

      final items = querySnapshot.docs
          .map((doc) => DeliveryScheduleModelV3.fromFirestore(doc))
          .toList();
      items.sort((a, b) {
        final at = a.weekStartDate?.millisecondsSinceEpoch ?? 0;
        final bt = b.weekStartDate?.millisecondsSinceEpoch ?? 0;
        return at.compareTo(bt);
      });
      return items;
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
    // Use a single-field orderBy to avoid requiring a composite index.
    // We'll handle any preferred ordering (e.g., isDefault first) on the client side if needed.
    final querySnapshot = await _firestore
      .collection(_usersCollection)
      .doc(userId)
      .collection(_addressesCollection)
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

  static Future<void> deleteUserAddress(String userId, String addressId) async {
    try {
      await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .collection(_addressesCollection)
          .doc(addressId)
          .delete();
    } catch (e) {
      throw Exception('Failed to delete address: $e');
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

  static Future<void> updateOrderStatus({
    required String orderId,
    required OrderStatus status,
  }) async {
    try {
      await _firestore.collection(_ordersCollection).doc(orderId).update({
        'status': status.toString().split('.').last,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update order status: $e');
    }
  }

  static Future<void> updateOrderMeals({
    required String orderId,
    required List<MealModelV3> meals,
  }) async {
    try {
      await _firestore.collection(_ordersCollection).doc(orderId).update({
        'meals': meals.map((m) => m.toFirestore()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update order meals: $e');
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
      .where('deliveryDate', isGreaterThanOrEqualTo: now)
      .where('deliveryDate', isLessThanOrEqualTo: nextWeek)
      .orderBy('deliveryDate')
      .get();

    // Filter statuses client-side to avoid composite index requirement
    final valid = {'pending', 'confirmed', 'preparing', 'outfordelivery'};
    return querySnapshot.docs
      .map((doc) => doc.data())
      .where((data) => valid.contains((data['status'] ?? '').toString().toLowerCase()))
      .toList();
    } catch (e) {
      // Graceful fallback if a composite index isn't ready yet
      try {
        final now = DateTime.now();
        final nextWeek = now.add(const Duration(days: 7));
        final fallback = await _firestore
            .collection(_ordersCollection)
            .where('userId', isEqualTo: userId)
            .orderBy('createdAt', descending: true)
            .limit(150)
            .get();

        final valid = {'pending', 'confirmed', 'preparing', 'outfordelivery'};
        final items = fallback.docs.map((d) => d.data()).where((data) {
          final ts = data['deliveryDate'];
          final dt = ts is Timestamp
              ? ts.toDate()
              : DateTime.fromMillisecondsSinceEpoch((ts ?? 0) as int);
          final status = (data['status'] ?? '').toString().toLowerCase();
          return dt.isAfter(now) && dt.isBefore(nextWeek) && valid.contains(status);
        }).toList();

        // Sort ascending by deliveryDate to match original query
        items.sort((a, b) {
          DateTime ad, bd;
          final ats = a['deliveryDate'];
          final bts = b['deliveryDate'];
          ad = ats is Timestamp ? ats.toDate() : DateTime.fromMillisecondsSinceEpoch((ats ?? 0) as int);
          bd = bts is Timestamp ? bts.toDate() : DateTime.fromMillisecondsSinceEpoch((bts ?? 0) as int);
          return ad.compareTo(bd);
        });
        return items;
      } catch (_) {
        throw Exception('Failed to get upcoming orders: $e');
      }
    }
  }

  static Future<Map<String, dynamic>?> getNextUpcomingOrder(String userId) async {
    final now = DateTime.now();
    try {
      final querySnapshot = await _firestore
          .collection(_ordersCollection)
          .where('userId', isEqualTo: userId)
          .where('deliveryDate', isGreaterThanOrEqualTo: now)
          .orderBy('deliveryDate')
          .limit(1)
          .get();
      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.data();
      }
      return null;
    } catch (e) {
      // Fallback: fetch recent orders and pick the next by deliveryDate client-side
      try {
        final recent = await getUserOrders(userId, limit: 50);
        recent.sort((a, b) {
          final ad = (a['deliveryDate'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(a['deliveryDate'] ?? 0);
          final bd = (b['deliveryDate'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(b['deliveryDate'] ?? 0);
          return ad.compareTo(bd);
        });
        for (final o in recent) {
          final dt = (o['deliveryDate'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(o['deliveryDate'] ?? 0);
          final status = (o['status'] ?? '').toString().toLowerCase();
          if (dt.isAfter(now) && status != 'cancelled') {
            return o;
          }
        }
      } catch (_) {}
      return null;
    }
  }

  // Live driver location for an order. Expects documents under:
  // orders/{orderId}/tracking/current { lat: double, lng: double, updatedAt: TS }
  // If the doc or fields are missing, emits null.
  static Stream<_LatLng?> trackOrderDriverLocation(String orderId) {
    final ref = _firestore
        .collection(_ordersCollection)
        .doc(orderId)
        .collection('tracking')
        .doc('current');
    return ref.snapshots().map((doc) {
      if (!doc.exists) return null;
      final data = doc.data();
      if (data == null) return null;
      final lat = (data['lat'] as num?)?.toDouble();
      final lng = (data['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) return null;
      return _LatLng(lat, lng);
    });
  }

  // Replace the next upcoming order of a given meal type with a new meal.
  // Respects the 60-minute lock and skips terminal/out-for-delivery statuses.
  static Future<bool> replaceNextUpcomingOrderMealOfType({
    required String userId,
    required String mealType, // 'breakfast' | 'lunch' | 'dinner'
    required MealModelV3 newMeal,
  }) async {
    final now = DateTime.now();
    try {
      final querySnapshot = await _firestore
          .collection(_ordersCollection)
          .where('userId', isEqualTo: userId)
          .where('deliveryDate', isGreaterThanOrEqualTo: now)
          .orderBy('deliveryDate')
          .limit(10)
          .get();

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final status = (data['status'] ?? '').toString().toLowerCase();
        if (status == 'delivered' || status == 'cancelled' || status == 'outfordelivery') {
          continue;
        }
        final deliveryTs = data['estimatedDeliveryTime'] ?? data['deliveryDate'];
        final dt = deliveryTs is Timestamp
            ? deliveryTs.toDate()
            : DateTime.fromMillisecondsSinceEpoch((deliveryTs ?? 0) as int);
        // Enforce 60-min edit lock
        if (dt.difference(now).inMinutes <= 60) continue;

        final meals = (data['meals'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .toList();
        if (meals.isEmpty) {
          // If we cannot tell the type, skip this order
          continue;
        }
        final firstMealType = (meals.first['mealType'] ?? '').toString().toLowerCase();
        if (firstMealType != mealType.toLowerCase()) {
          continue;
        }

        // Update meals to the new single meal
        await doc.reference.update({
          'meals': [newMeal.toFirestore()],
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return true;
      }
      return false;
    } catch (e) {
      throw Exception('Failed to replace upcoming order meal: $e');
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
      // Graceful fallback while composite index builds: fetch recent by createdAt and filter client-side
      try {
        final now = DateTime.now();
        final recent = await _firestore
            .collection(_ordersCollection)
            .where('userId', isEqualTo: userId)
            .orderBy('createdAt', descending: true)
            .limit(200)
            .get();

        final allowed = {'delivered', 'cancelled', 'refunded'};
        final items = recent.docs.map((d) => d.data()).where((data) {
          final ts = data['deliveryDate'];
          final dt = ts is Timestamp
              ? ts.toDate()
              : DateTime.fromMillisecondsSinceEpoch((ts ?? 0) as int);
          final status = (data['status'] ?? '').toString().toLowerCase();
          return dt.isBefore(now) && allowed.contains(status);
        }).toList();

        // Sort to match server query and cap to 50
        items.sort((a, b) {
          DateTime ad, bd;
          final ats = a['deliveryDate'];
          final bts = b['deliveryDate'];
          ad = ats is Timestamp ? ats.toDate() : DateTime.fromMillisecondsSinceEpoch((ats ?? 0) as int);
          bd = bts is Timestamp ? bts.toDate() : DateTime.fromMillisecondsSinceEpoch((bts ?? 0) as int);
          return bd.compareTo(ad);
        });
        return items.take(50).toList();
      } catch (_) {
        throw Exception('Failed to get past orders: $e');
      }
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

  // Update the active subscription to reflect the chosen plan
  static Future<void> updateActiveSubscriptionPlan(String userId, MealPlanModelV3 plan) async {
    try {
      final col = _firestore
          .collection(_usersCollection)
          .doc(userId)
          .collection(_subscriptionsCollection);

      final snap = await col
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      if (snap.docs.isEmpty) {
        // No active subscription exists yet (e.g., manual/dev setup). Create a local active one.
        final localId = 'local';
        final ref = col.doc(localId);
        await ref.set({
          'id': localId,
          'userId': userId,
          'stripeSubscriptionId': localId,
          'status': 'active',
          'mealPlanId': plan.id,
          'planName': plan.displayName.isNotEmpty ? plan.displayName : plan.name,
          'monthlyAmount': plan.monthlyPrice,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'nextBillingDate': null,
          'cancelAtPeriodEnd': false,
        }, SetOptions(merge: true));
      } else {
        final ref = snap.docs.first.reference;
        await ref.set({
          'mealPlanId': plan.id,
          'planName': plan.displayName.isNotEmpty ? plan.displayName : plan.name,
          'monthlyAmount': plan.monthlyPrice,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      throw Exception('Failed to update subscription plan: $e');
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

  // Backup email helpers
  static Future<void> setBackupEmail(String userId, String? email) async {
    try {
      final Map<String, dynamic> update = {
        'backupEmail': (email ?? '').trim().isEmpty ? null : email!.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      await _firestore.collection(_usersCollection).doc(userId).set(update, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to set backup email: $e');
    }
  }

  static Future<String?> getBackupEmail(String userId) async {
    try {
      final doc = await _firestore.collection(_usersCollection).doc(userId).get();
      if (!doc.exists) return null;
      final data = doc.data();
      final v = data?['backupEmail'];
      return v is String && v.trim().isNotEmpty ? v.trim() : null;
    } catch (e) {
      throw Exception('Failed to get backup email: $e');
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

// Lightweight internal Point type for map streaming
class _LatLng {
  final double lat;
  final double lng;
  const _LatLng(this.lat, this.lng);
}
