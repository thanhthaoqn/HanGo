class CourseLesson {
  final int id;
  final String title;
  final int orderIndex;
  final String? itemType;
  final int? examId;
  final int? questionCount;

  CourseLesson({
    required this.id,
    required this.title,
    required this.orderIndex,
    this.itemType,
    this.examId,
    this.questionCount,
  });

  factory CourseLesson.fromJson(Map<String, dynamic> json) {
    return CourseLesson(
      id: json['id'] as int,
      title: json['title'] as String,
      orderIndex: json['orderIndex'] as int,
      itemType: json['itemType'] as String?,
      examId: json['examId'] as int?,
      questionCount: json['questionCount'] as int?,
    );
  }
}

class CourseSession {
  final int id;
  final String title;
  final int orderIndex;
  final List<CourseLesson> lessons;

  CourseSession({
    required this.id,
    required this.title,
    required this.orderIndex,
    required this.lessons,
  });

  factory CourseSession.fromJson(Map<String, dynamic> json) {
    var list = json['lessons'] as List? ?? [];
    List<CourseLesson> lessonsList = list.map((i) => CourseLesson.fromJson(i)).toList();

    return CourseSession(
      id: json['id'] as int,
      title: json['title'] as String,
      orderIndex: json['orderIndex'] as int,
      lessons: lessonsList,
    );
  }
}

class CourseDetail {
  final int id;
  final String title;
  final String creatorName;
  final String difficultyName;
  final double rating;
  final int learnersCount;
  final String? description;
  final String? objectives;
  final bool isEnrolled;
  final List<CourseSession> sessions;

  CourseDetail({
    required this.id,
    required this.title,
    required this.creatorName,
    required this.difficultyName,
    required this.rating,
    required this.learnersCount,
    this.description,
    this.objectives,
    required this.isEnrolled,
    required this.sessions,
  });

  factory CourseDetail.fromJson(Map<String, dynamic> json) {
    var list = json['sessions'] as List? ?? [];
    List<CourseSession> sessionsList = list.map((i) => CourseSession.fromJson(i)).toList();

    return CourseDetail(
      id: json['id'] as int,
      title: json['title'] as String,
      creatorName: json['creatorName'] as String? ?? 'Unknown',
      difficultyName: json['difficultyName'] as String? ?? 'Unknown',
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      learnersCount: json['learnersCount'] as int? ?? 0,
      description: json['description'] as String?,
      objectives: json['objectives'] as String?,
      isEnrolled: json['isEnrolled'] as bool? ?? false,
      sessions: sessionsList,
    );
  }

  CourseDetail copyWith({
    int? id,
    String? title,
    String? creatorName,
    String? difficultyName,
    double? rating,
    int? learnersCount,
    String? description,
    String? objectives,
    bool? isEnrolled,
    List<CourseSession>? sessions,
  }) {
    return CourseDetail(
      id: id ?? this.id,
      title: title ?? this.title,
      creatorName: creatorName ?? this.creatorName,
      difficultyName: difficultyName ?? this.difficultyName,
      rating: rating ?? this.rating,
      learnersCount: learnersCount ?? this.learnersCount,
      description: description ?? this.description,
      objectives: objectives ?? this.objectives,
      isEnrolled: isEnrolled ?? this.isEnrolled,
      sessions: sessions ?? this.sessions,
    );
  }
}
