class AiHealth {
  const AiHealth({
    required this.available,
    required this.message,
    required this.chatModel,
    required this.embeddingModel,
  });

  final bool available;
  final String message;
  final String chatModel;
  final String embeddingModel;

  factory AiHealth.fromJson(Map<String, dynamic> json) {
    return AiHealth(
      available: json['available'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      chatModel: json['chatModel'] as String? ?? '',
      embeddingModel: json['embeddingModel'] as String? ?? '',
    );
  }
}
