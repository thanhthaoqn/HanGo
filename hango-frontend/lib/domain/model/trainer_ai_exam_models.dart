class TrainerExamChatMessage {
  final String role; // "user" or "model"
  final String text;

  TrainerExamChatMessage({required this.role, required this.text});

  Map<String, dynamic> toJson() {
    return {
      'role': role,
      'text': text,
    };
  }
}

class TrainerAiExamGenerateResponse {
  final String title;
  final String description;
  final int durationMinutes;
  final double passingScore;
  final int expectedQuestionCount;
  final List<TrainerAiExamBlock> blocks;

  TrainerAiExamGenerateResponse({
    required this.title,
    required this.description,
    required this.durationMinutes,
    required this.passingScore,
    required this.expectedQuestionCount,
    required this.blocks,
  });

  factory TrainerAiExamGenerateResponse.fromJson(Map<String, dynamic> json) {
    return TrainerAiExamGenerateResponse(
      title: json['title'] as String? ?? 'AI Generated Exam',
      description: json['description'] as String? ?? '',
      durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 60,
      passingScore: (json['passingScore'] as num?)?.toDouble() ?? 50.0,
      expectedQuestionCount: (json['expectedQuestionCount'] as num?)?.toInt() ?? 10,
      blocks: (json['blocks'] as List?)
              ?.map((e) => TrainerAiExamBlock.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class TrainerAiExamBlock {
  final bool isQuestionGroup;
  final String passageText;
  final int categoryId;
  final int? skillParamId;
  final int difficultyId;
  final List<TrainerAiExamSingleQuestion> questions;

  TrainerAiExamBlock({
    required this.isQuestionGroup,
    required this.passageText,
    required this.categoryId,
    this.skillParamId,
    required this.difficultyId,
    required this.questions,
  });

  factory TrainerAiExamBlock.fromJson(Map<String, dynamic> json) {
    return TrainerAiExamBlock(
      isQuestionGroup: (json['isQuestionGroup'] as bool?) ?? false,
      passageText: json['passageText'] as String? ?? '',
      categoryId: (json['categoryId'] as num?)?.toInt() ?? 1,
      skillParamId: (json['skillParamId'] as num?)?.toInt(),
      difficultyId: (json['difficultyId'] as num?)?.toInt() ?? 14, // Easy default
      questions: (json['questions'] as List?)
              ?.map((e) => TrainerAiExamSingleQuestion.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class TrainerAiExamSingleQuestion {
  final String questionText;
  final String explanation;
  final int categoryId;
  final int difficultyId;
  final List<TrainerAiExamOption> options;

  TrainerAiExamSingleQuestion({
    required this.questionText,
    required this.explanation,
    required this.categoryId,
    required this.difficultyId,
    required this.options,
  });

  factory TrainerAiExamSingleQuestion.fromJson(Map<String, dynamic> json) {
    return TrainerAiExamSingleQuestion(
      questionText: json['questionText'] as String? ?? '',
      explanation: json['explanation'] as String? ?? '',
      categoryId: (json['categoryId'] as num?)?.toInt() ?? 1,
      difficultyId: (json['difficultyId'] as num?)?.toInt() ?? 14,
      options: (json['options'] as List?)
              ?.map((e) => TrainerAiExamOption.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class TrainerAiExamOption {
  final String optionText;
  final bool isCorrect;

  TrainerAiExamOption({required this.optionText, required this.isCorrect});

  factory TrainerAiExamOption.fromJson(Map<String, dynamic> json) {
    return TrainerAiExamOption(
      optionText: json['optionText'] as String? ?? '',
      isCorrect: (json['isCorrect'] as bool?) ?? false,
    );
  }
}
