import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/subscription.dart';

class SubscriptionService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'subscriptions';

  // Create subscription
  static Future<String> createSubscription(Subscription subscription) async {
    try {
      final docRef = await _firestore.collection(_collection).add(subscription.toMap());
      await docRef.update({'id': docRef.id});
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create subscription: $e');
    }
  }

  // Get user subscription
  static Future<Subscription?> getUserSubscription(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .where('status', whereIn: [
            SubscriptionStatus.active.toString(),
            SubscriptionStatus.pastDue.toString(),
          ])
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return Subscription.fromMap(querySnapshot.docs.first.data());
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get user subscription: $e');
    }
  }

  // Get subscription by ID
  static Future<Subscription?> getSubscription(String subscriptionId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(subscriptionId).get();
      if (doc.exists && doc.data() != null) {
        return Subscription.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get subscription: $e');
    }
  }

  // Update subscription
  static Future<void> updateSubscription(Subscription subscription) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(subscription.id)
          .update(subscription.copyWith(updatedAt: DateTime.now()).toMap());
    } catch (e) {
      throw Exception('Failed to update subscription: $e');
    }
  }

  // Update subscription status
  static Future<void> updateSubscriptionStatus(
    String subscriptionId,
    SubscriptionStatus status,
  ) async {
    try {
      await _firestore.collection(_collection).doc(subscriptionId).update({
        'status': status.toString(),
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to update subscription status: $e');
    }
  }

  // Cancel subscription
  static Future<void> cancelSubscription(String subscriptionId) async {
    try {
      await _firestore.collection(_collection).doc(subscriptionId).update({
        'status': SubscriptionStatus.canceled.toString(),
        'endDate': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to cancel subscription: $e');
    }
  }

  // Get all user subscriptions (including canceled ones)
  static Future<List<Subscription>> getAllUserSubscriptions(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => Subscription.fromMap(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to get all user subscriptions: $e');
    }
  }

  // Check if user has active subscription
  static Future<bool> hasActiveSubscription(String userId) async {
    try {
      final subscription = await getUserSubscription(userId);
      return subscription?.status.isActive ?? false;
    } catch (e) {
      return false;
    }
  }

  // Stream user subscription
  static Stream<Subscription?> streamUserSubscription(String userId) {
    return _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .where('status', whereIn: [
          SubscriptionStatus.active.toString(),
          SubscriptionStatus.pastDue.toString(),
        ])
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        return Subscription.fromMap(snapshot.docs.first.data());
      }
      return null;
    });
  }

  // Update payment method
  static Future<void> updatePaymentMethod(
    String subscriptionId,
    PaymentMethod paymentMethod,
  ) async {
    try {
      await _firestore.collection(_collection).doc(subscriptionId).update({
        'paymentMethod': paymentMethod.toMap(),
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to update payment method: $e');
    }
  }

  // Update Stripe subscription ID
  static Future<void> updateStripeSubscriptionId(
    String subscriptionId,
    String stripeSubscriptionId,
  ) async {
    try {
      await _firestore.collection(_collection).doc(subscriptionId).update({
        'stripeSubscriptionId': stripeSubscriptionId,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to update Stripe subscription ID: $e');
    }
  }

  // Update Stripe customer ID
  static Future<void> updateStripeCustomerId(
    String subscriptionId,
    String stripeCustomerId,
  ) async {
    try {
      await _firestore.collection(_collection).doc(subscriptionId).update({
        'stripeCustomerId': stripeCustomerId,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to update Stripe customer ID: $e');
    }
  }
}
