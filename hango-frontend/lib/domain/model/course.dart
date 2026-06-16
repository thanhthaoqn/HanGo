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
  });
}
