class TrainerQuestion {
  final int id;
  final String questionText;
  final String categoryName;
  final String difficultyName;
  final String status;
  final String creatorName;
  final DateTime createdAt;
  final DateTime updatedAt;

  TrainerQuestion({
    required this.id,
    required this.questionText,
    required this.categoryName,
    required this.difficultyName,
    required this.status,
    required this.creatorName,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TrainerQuestion.fromJson(Map<String, dynamic> json) {
    return TrainerQuestion(
      id: json['id'] as int? ?? 0,
      questionText: json['questionText'] as String? ?? '',
      categoryName: json['categoryName'] as String? ?? 'Chưa phân loại',
      difficultyName: json['difficultyName'] as String? ?? 'Medium',
      status: json['status'] as String? ?? 'DRAFT',
      creatorName: json['creatorName'] as String? ?? 'Unknown',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
    );
  }
}
