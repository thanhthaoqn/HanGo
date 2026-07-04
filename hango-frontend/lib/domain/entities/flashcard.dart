class Flashcard {
  final String id;
  final String frontText; // Term
  final String backText;  // Definition
  bool isLearned;

  Flashcard({
    required this.id,
    required this.frontText,
    required this.backText,
    this.isLearned = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'frontText': frontText,
        'backText': backText,
        'isLearned': isLearned,
      };

  factory Flashcard.fromJson(Map<String, dynamic> json) => Flashcard(
        id: json['id'] as String,
        frontText: json['frontText'] as String,
        backText: json['backText'] as String,
        isLearned: json['isLearned'] as bool? ?? false,
      );

  Flashcard copyWith({
    String? id,
    String? frontText,
    String? backText,
    bool? isLearned,
  }) {
    return Flashcard(
      id: id ?? this.id,
      frontText: frontText ?? this.frontText,
      backText: backText ?? this.backText,
      isLearned: isLearned ?? this.isLearned,
    );
  }
}

class FlashcardCollection {
  final String id;
  final String title;
  final String description;
  final String creator;
  final int sentenceCount;
  final int durationMinutes;
  final double rating;
  final String learnerCount;
  final String? imageUrl;
  final List<Flashcard> flashcards;
  bool isRecent;
  bool isLearned;
  DateTime? lastStudiedAt;

  FlashcardCollection({
    required this.id,
    required this.title,
    required this.description,
    required this.creator,
    required this.sentenceCount,
    required this.durationMinutes,
    this.rating = 5.0,
    this.learnerCount = '0 Learner',
    this.imageUrl,
    required this.flashcards,
    this.isRecent = false,
    this.isLearned = false,
    this.lastStudiedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'creator': creator,
        'sentenceCount': sentenceCount,
        'durationMinutes': durationMinutes,
        'rating': rating,
        'learnerCount': learnerCount,
        'imageUrl': imageUrl,
        'flashcards': flashcards.map((f) => f.toJson()).toList(),
        'isRecent': isRecent,
        'isLearned': isLearned,
        'lastStudiedAt': lastStudiedAt?.toIso8601String(),
      };

  factory FlashcardCollection.fromJson(Map<String, dynamic> json) {
    return FlashcardCollection(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      creator: json['creator'] as String? ?? 'HanGo Creator',
      sentenceCount: json['sentenceCount'] as int? ?? 0,
      durationMinutes: json['durationMinutes'] as int? ?? 0,
      rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
      learnerCount: json['learnerCount'] as String? ?? '0 Learner',
      imageUrl: json['imageUrl'] as String?,
      flashcards: (json['flashcards'] as List<dynamic>?)
              ?.map((item) => Flashcard.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      isRecent: json['isRecent'] as bool? ?? false,
      isLearned: json['isLearned'] as bool? ?? false,
      lastStudiedAt: json['lastStudiedAt'] != null
          ? DateTime.tryParse(json['lastStudiedAt'] as String)
          : null,
    );
  }

  FlashcardCollection copyWith({
    String? id,
    String? title,
    String? description,
    String? creator,
    int? sentenceCount,
    int? durationMinutes,
    double? rating,
    String? learnerCount,
    String? imageUrl,
    List<Flashcard>? flashcards,
    bool? isRecent,
    bool? isLearned,
    DateTime? lastStudiedAt,
  }) {
    return FlashcardCollection(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      creator: creator ?? this.creator,
      sentenceCount: sentenceCount ?? this.sentenceCount,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      rating: rating ?? this.rating,
      learnerCount: learnerCount ?? this.learnerCount,
      imageUrl: imageUrl ?? this.imageUrl,
      flashcards: flashcards ?? this.flashcards,
      isRecent: isRecent ?? this.isRecent,
      isLearned: isLearned ?? this.isLearned,
      lastStudiedAt: lastStudiedAt ?? this.lastStudiedAt,
    );
  }
}
