class Exam {
  final String id;
  final String title;
  final String description;
  final String status;
  final String creatorName;
  final int questionCount;
  final int durationMinutes;
  final double rating;
  final String learnerCountFormatted;

  Exam({
    required this.id,
    required this.title,
    this.description = '',
    this.status = 'ACTIVE',
    required this.creatorName,
    required this.questionCount,
    required this.durationMinutes,
    required this.rating,
    required this.learnerCountFormatted,
  });
}
