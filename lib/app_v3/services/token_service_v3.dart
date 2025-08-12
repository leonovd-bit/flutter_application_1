import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class TokenServiceV3 {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static const double tokenPriceUsd = 13.0;

  // Returns current token balance for the signed-in user
  static Future<int> getBalance() async {
    final user = _auth.currentUser;
    if (user == null) return 0;
    final doc = await _db.collection('users').doc(user.uid).get();
    return (doc.data()?['mealTokens'] as int?) ?? 0;
  }

  // Stream token balance for real-time updates
  static Stream<int> balanceStream() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(0);
    return _db.collection('users').doc(user.uid).snapshots().map((s) => (s.data()?['mealTokens'] as int?) ?? 0);
  }

  // Purchase tokens (payment should be handled via Stripe on backend). This only records the result.
  static Future<bool> recordPurchase({required int quantity, required String paymentIntentId}) async {
    final user = _auth.currentUser;
    if (user == null) return false;
    try {
      final userRef = _db.collection('users').doc(user.uid);
      await _db.runTransaction((tx) async {
        final snap = await tx.get(userRef);
        final current = (snap.data()?['mealTokens'] as int?) ?? 0;
        final lifetimePurchased = (snap.data()?['lifetimeTokensPurchased'] as int?) ?? 0;
        tx.update(userRef, {
          'mealTokens': current + quantity,
          'lifetimeTokensPurchased': lifetimePurchased + quantity,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      await _db.collection('token_purchases').add({
        'userId': user.uid,
        'quantity': quantity,
        'pricePerToken': tokenPriceUsd,
        'totalAmount': tokenPriceUsd * quantity,
        'paymentIntentId': paymentIntentId,
        'status': 'completed',
        'createdAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e, st) {
      debugPrint('[TokenServiceV3] recordPurchase error: $e\n$st');
      return false;
    }
  }

  // Use tokens for an order
  static Future<bool> useTokens({required String orderId, int tokens = 1}) async {
    final user = _auth.currentUser;
    if (user == null) return false;
    try {
      final userRef = _db.collection('users').doc(user.uid);
      await _db.runTransaction((tx) async {
        final snap = await tx.get(userRef);
        final current = (snap.data()?['mealTokens'] as int?) ?? 0;
        final lifetimeUsed = (snap.data()?['lifetimeTokensUsed'] as int?) ?? 0;
        if (current < tokens) {
          throw Exception('INSUFFICIENT_TOKENS');
        }
        tx.update(userRef, {
          'mealTokens': current - tokens,
          'lifetimeTokensUsed': lifetimeUsed + tokens,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      await _db.collection('token_usage').add({
        'userId': user.uid,
        'orderId': orderId,
        'tokensUsed': tokens,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e, st) {
      debugPrint('[TokenServiceV3] useTokens error: $e\n$st');
      return false;
    }
  }
}
