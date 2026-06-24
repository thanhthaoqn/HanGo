class Exam {
  const Exam({
    required this.id,
    required this.title,
    required this.durationMinutes,
    required this.status,
    required this.questions,
  });

  final int id;
  final String title;
  final int durationMinutes;
  final String status;
  final List<Question> questions;

  factory Exam.fromJson(Map<String, dynamic> json) {
    return Exam(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ?? 'Đề thi',
      durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? '',
      questions: (json['questions'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(Question.fromJson)
          .toList(),
    );
  }
}

class Question {
  const Question({
    required this.id,
    required this.content,
    required this.skillType,
    required this.difficulty,
    required this.explanation,
    required this.options,
  });

  final int id;
  final String content;
  final String skillType;
  final String difficulty;
  final String? explanation;
  final List<QuestionOption> options;

  factory Question.fromJson(Map<String, dynamic> json) {
    final options = (json['options'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(QuestionOption.fromJson)
        .toList()
      ..sort((a, b) => a.label.compareTo(b.label));

    return Question(
      id: (json['id'] as num?)?.toInt() ?? 0,
      content: json['content'] as String? ?? '',
      skillType: json['skillType'] as String? ?? '',
      difficulty: json['difficulty'] as String? ?? '',
      explanation: json['explanation'] as String?,
      options: options,
    );
  }
}

class QuestionOption {
  const QuestionOption({
    required this.id,
    required this.label,
    required this.content,
  });

  final int id;
  final String label;
  final String content;

  factory QuestionOption.fromJson(Map<String, dynamic> json) {
    return QuestionOption(
      id: (json['id'] as num?)?.toInt() ?? 0,
      label: json['label'] as String? ?? '',
      content: json['content'] as String? ?? '',
    );
  }
}

class ExamAttempt {
  const ExamAttempt({
    required this.id,
    required this.status,
    required this.startedAt,
    this.submittedAt,
    this.score,
    this.exam,
  });

  final int id;
  final String status;
  final DateTime? startedAt;
  final DateTime? submittedAt;
  final double? score;
  final Exam? exam;

  factory ExamAttempt.fromJson(Map<String, dynamic> json) {
    return ExamAttempt(
      id: (json['id'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? '',
      startedAt: DateTime.tryParse(json['startedAt'] as String? ?? ''),
      submittedAt: DateTime.tryParse(json['submittedAt'] as String? ?? ''),
      score: (json['score'] as num?)?.toDouble(),
      exam: json['exam'] is Map<String, dynamic>
          ? Exam.fromJson(json['exam'] as Map<String, dynamic>)
          : null,
    );
  }
}

class ExamResult {
  const ExamResult({
    required this.examResultId,
    required this.totalScore,
    required this.totalQuestions,
    required this.correctCount,
    required this.skillBreakdowns,
    required this.weakSkills,
  });

  final int examResultId;
  final double totalScore;
  final int totalQuestions;
  final int correctCount;
  final List<SkillBreakdown> skillBreakdowns;
  final List<String> weakSkills;

  factory ExamResult.fromJson(Map<String, dynamic> json) {
    return ExamResult(
      examResultId: (json['examResultId'] as num?)?.toInt() ?? 0,
      totalScore: (json['totalScore'] as num?)?.toDouble() ?? 0,
      totalQuestions: (json['totalQuestions'] as num?)?.toInt() ?? 0,
      correctCount: (json['correctCount'] as num?)?.toInt() ?? 0,
      skillBreakdowns: (json['skillBreakdowns'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(SkillBreakdown.fromJson)
          .toList(),
      weakSkills:
          (json['weakSkills'] as List? ?? const []).map((e) => '$e').toList(),
    );
  }
}

class SkillBreakdown {
  const SkillBreakdown({
    required this.skillType,
    required this.totalQuestions,
    required this.correctCount,
    required this.accuracyPercentage,
  });

  final String skillType;
  final int totalQuestions;
  final int correctCount;
  final double accuracyPercentage;

  factory SkillBreakdown.fromJson(Map<String, dynamic> json) {
    return SkillBreakdown(
      skillType: json['skillType'] as String? ?? '',
      totalQuestions: (json['totalQuestions'] as num?)?.toInt() ?? 0,
      correctCount: (json['correctCount'] as num?)?.toInt() ?? 0,
      accuracyPercentage: (json['accuracyPercentage'] as num?)?.toDouble() ?? 0,
    );
  }
}
