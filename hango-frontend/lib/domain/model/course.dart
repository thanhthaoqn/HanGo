class Course {
  final int id;
  final String title;
  final String category;
  final String creatorName;
  final double stars;
  final String difficulty;
  final String learnerCount;
  final String thumbnailUrl;
  final String status; // 'featured' | 'in_progress' | 'completed'
  final double progressPercentage;

  const Course({
    required this.id,
    required this.title,
    required this.category,
    required this.creatorName,
    required this.stars,
    required this.difficulty,
    required this.learnerCount,
    required this.thumbnailUrl,
    required this.status,
    required this.progressPercentage,
  });

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      id: json['id'],
      title: json['title'] ?? '',
      category: json['categoryName'] ?? '',
      creatorName: json['creatorName'] ?? '',
      stars: (json['rating'] ?? 0.0).toDouble(),
      difficulty: json['difficultyName'] ?? 'Medium',
      learnerCount: '${json['learnersCount'] ?? 0}',
      thumbnailUrl: json['thumbnailUrl'] ?? '',
      status: 'featured',
      progressPercentage: (json['progressPercentage'] ?? 0.0).toDouble(),
    );
  }
}
