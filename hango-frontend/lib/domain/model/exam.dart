class Exam {
  final int id;
  final String title;
  final String creatorName;
  final int sentencesCount;
  final int durationMinutes;
  final double stars;
  final String learnerCount;
  final String status; // 'featured' | 'completed'

  const Exam({
    required this.id,
    required this.title,
    required this.creatorName,
    required this.sentencesCount,
    required this.durationMinutes,
    required this.stars,
    required this.learnerCount,
    required this.status,
  });
}
