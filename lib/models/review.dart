class Review {
  final String id;
  final String orderId;
  final String userId;
  final int rating; // 1-5 stars
  final String comment;
  final DateTime createdAt;

  Review({
    required this.id,
    required this.orderId,
    required this.userId,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'orderId': orderId,
      'userId': userId,
      'rating': rating,
      'comment': comment,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Review.fromMap(Map<String, dynamic> map) {
    return Review(
      id: map['id'] ?? '',
      orderId: map['orderId'] ?? '',
      userId: map['userId'] ?? '',
      rating: map['rating'] ?? 1,
      comment: map['comment'] ?? '',
      createdAt: DateTime.parse(map['createdAt']),
    );
  }
}
