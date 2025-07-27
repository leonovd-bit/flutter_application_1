import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/review.dart';

class ReviewService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'reviews';

  // Submit a review
  static Future<bool> submitReview({
    required String orderId,
    required String userId,
    required int rating,
    required String comment,
  }) async {
    try {
      final review = Review(
        id: _firestore.collection(_collection).doc().id,
        orderId: orderId,
        userId: userId,
        rating: rating,
        comment: comment,
        createdAt: DateTime.now(),
      );

      await _firestore.collection(_collection).doc(review.id).set(review.toMap());
      return true;
    } catch (e) {
      print('Error submitting review: $e');
      return false;
    }
  }

  // Check if review exists for order
  static Future<bool> hasReviewForOrder(String orderId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('orderId', isEqualTo: orderId)
          .limit(1)
          .get();

      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking review: $e');
      return false;
    }
  }

  // Get reviews for user
  static Future<List<Review>> getUserReviews(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => Review.fromMap(doc.data()))
          .toList();
    } catch (e) {
      print('Error getting user reviews: $e');
      return [];
    }
  }
}
