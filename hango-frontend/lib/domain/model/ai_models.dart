class AiConversation {
  const AiConversation({
    required this.id,
    required this.startedAt,
    required this.lessonId,
    required this.lessonTitle,
    required this.messages,
  });

  final int id;
  final DateTime? startedAt;
  final int lessonId;
  final String lessonTitle;
  final List<AiMessage> messages;

  factory AiConversation.fromJson(Map<String, dynamic> json) {
    final lesson = json['lesson'] is Map<String, dynamic>
        ? json['lesson'] as Map<String, dynamic>
        : const <String, dynamic>{};

    return AiConversation(
      id: (json['id'] as num?)?.toInt() ?? 0,
      startedAt: DateTime.tryParse(json['startedAt'] as String? ?? ''),
      lessonId: (lesson['id'] as num?)?.toInt() ?? 0,
      lessonTitle: lesson['title'] as String? ?? 'Bài học',
      messages: (json['messages'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(AiMessage.fromJson)
          .toList(),
    );
  }
}

class AiMessage {
  const AiMessage({
    required this.role,
    required this.content,
    this.createdAt,
    this.wasOutOfScope = false,
    this.suggestedQuestions = const [],
  });

  final String role;
  final String content;
  final DateTime? createdAt;
  final bool wasOutOfScope;
  final List<String> suggestedQuestions;

  factory AiMessage.fromJson(Map<String, dynamic> json) {
    final questionsJson = json['suggestedQuestions'] as List?;
    return AiMessage(
      role: json['role'] as String? ?? 'ASSISTANT',
      content: json['content'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      wasOutOfScope: json['wasOutOfScope'] as bool? ?? false,
      suggestedQuestions:
          questionsJson
              ?.whereType<String>()
              .where((e) => e.trim().isNotEmpty)
              .toList() ??
          const [],
    );
  }
}

class SendMessageResponse {
  const SendMessageResponse({
    required this.conversationId,
    required this.reply,
    required this.wasOutOfScope,
    this.suggestedQuestions = const [],
  });

  final int conversationId;
  final String reply;
  final bool wasOutOfScope;
  final List<String> suggestedQuestions;

  factory SendMessageResponse.fromJson(Map<String, dynamic> json) {
    final questionsJson = json['suggestedQuestions'] as List?;
    return SendMessageResponse(
      conversationId: (json['conversationId'] as num?)?.toInt() ?? 0,
      reply: json['reply'] as String? ?? '',
      wasOutOfScope: json['wasOutOfScope'] as bool? ?? false,
      suggestedQuestions:
          questionsJson
              ?.whereType<String>()
              .where((e) => e.trim().isNotEmpty)
              .toList() ??
          const [],
    );
  }
}
