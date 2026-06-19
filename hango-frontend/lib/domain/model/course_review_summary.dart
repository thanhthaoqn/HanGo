class CourseReviewSummary {
  final double averageRating;
  final int totalRatings;
  final Map<String, int> ratingCounts;
  final List<CourseReview> reviews;

  CourseReviewSummary({
    required this.averageRating,
    required this.totalRatings,
    required this.ratingCounts,
    required this.reviews,
  });

  factory CourseReviewSummary.fromJson(Map<String, dynamic> json) {
    var list = json['reviews'] as List? ?? [];
    List<CourseReview> reviewsList = list.map((i) => CourseReview.fromJson(i)).toList();
    
    // Convert Map<String, dynamic> to Map<String, int>
    Map<String, int> counts = {};
    if (json['ratingCounts'] != null) {
      json['ratingCounts'].forEach((key, value) {
        counts[key.toString()] = value as int;
      });
    }

    return CourseReviewSummary(
      averageRating: (json['averageRating'] ?? 0).toDouble(),
      totalRatings: json['totalRatings'] ?? 0,
      ratingCounts: counts,
      reviews: reviewsList,
    );
  }
}

class CourseReview {
  final int id;
  final String userName;
  final String userInitial;
  final int rating;
  final String content;
  final String? createdAt; // ISO string

  CourseReview({
    required this.id,
    required this.userName,
    required this.userInitial,
    required this.rating,
    required this.content,
    this.createdAt,
  });

  factory CourseReview.fromJson(Map<String, dynamic> json) {
    return CourseReview(
      id: json['id'] ?? 0,
      userName: json['userName'] ?? 'unknown',
      userInitial: json['userInitial'] ?? 'U',
      rating: json['rating'] ?? 0,
      content: json['content'] ?? '',
      createdAt: json['createdAt'],
    );
  }
}
