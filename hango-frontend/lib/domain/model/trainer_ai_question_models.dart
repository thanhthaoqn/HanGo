class TrainerAiGenerateResponse {
  final String mode; // SINGLE | MULTIPLE
  final List<TrainerAiSingleQuestion>? questions;
  final TrainerAiMultipleGroup? group;

  TrainerAiGenerateResponse({required this.mode, this.questions, this.group});

  factory TrainerAiGenerateResponse.fromJson(Map<String, dynamic> json) {
    return TrainerAiGenerateResponse(
      mode: json['mode'] as String,
      questions: (json['questions'] as List?)
          ?.map(
            (e) => TrainerAiSingleQuestion.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
      group: json['group'] == null
          ? null
          : TrainerAiMultipleGroup.fromJson(
              json['group'] as Map<String, dynamic>,
            ),
    );
  }
}

class TrainerAiSingleQuestion {
  final String questionText;
  final String explanation;
  final int categoryId;
  final int difficultyId;
  final List<TrainerAiOption> options;

  TrainerAiSingleQuestion({
    required this.questionText,
    required this.explanation,
    required this.categoryId,
    required this.difficultyId,
    required this.options,
  });

  factory TrainerAiSingleQuestion.fromJson(Map<String, dynamic> json) {
    return TrainerAiSingleQuestion(
      questionText: json['questionText'] as String,
      explanation: (json['explanation'] ?? '') as String,
      categoryId: (json['categoryId'] as num).toInt(),
      difficultyId: (json['difficultyId'] as num).toInt(),
      options: (json['options'] as List)
          .map((e) => TrainerAiOption.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class TrainerAiMultipleGroup {
  final String passageText;
  final String explanation;
  final int categoryId;
  final int difficultyId;
  final List<TrainerAiSubQuestion> subQuestions;

  TrainerAiMultipleGroup({
    required this.passageText,
    required this.explanation,
    required this.categoryId,
    required this.difficultyId,
    required this.subQuestions,
  });

  factory TrainerAiMultipleGroup.fromJson(Map<String, dynamic> json) {
    return TrainerAiMultipleGroup(
      passageText: json['passageText'] as String,
      explanation: (json['explanation'] ?? '') as String,
      categoryId: (json['categoryId'] as num).toInt(),
      difficultyId: (json['difficultyId'] as num).toInt(),
      subQuestions: (json['subQuestions'] as List)
          .map((e) => TrainerAiSubQuestion.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class TrainerAiSubQuestion {
  final String questionText;
  final String explanation;
  final List<TrainerAiOption> options;

  TrainerAiSubQuestion({
    required this.questionText,
    required this.explanation,
    required this.options,
  });

  factory TrainerAiSubQuestion.fromJson(Map<String, dynamic> json) {
    return TrainerAiSubQuestion(
      questionText: json['questionText'] as String,
      explanation: (json['explanation'] ?? '') as String,
      options: (json['options'] as List)
          .map((e) => TrainerAiOption.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class TrainerAiOption {
  final String optionText;
  final bool isCorrect;

  TrainerAiOption({required this.optionText, required this.isCorrect});

  factory TrainerAiOption.fromJson(Map<String, dynamic> json) {
    return TrainerAiOption(
      optionText: json['optionText'] as String,
      isCorrect: (json['isCorrect'] as bool?) ?? false,
    );
  }
}
