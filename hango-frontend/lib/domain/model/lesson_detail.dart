class LessonComment {
  final int id;
  final int userId;
  final String userName;
  final String? userAvatar;
  final String content;
  final String createdAt;
  final int? parentCommentId;
  final int likeCount;
  final bool isLiked;
  final String status;

  LessonComment({
    required this.id,
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.content,
    required this.createdAt,
    this.parentCommentId,
    this.likeCount = 0,
    this.isLiked = false,
    this.status = 'APPROVED',
  });

  factory LessonComment.fromJson(Map<String, dynamic> json) {
    return LessonComment(
      id: json['id'],
      userId: json['userId'] ?? 0,
      userName: json['userName'] ?? 'Unknown',
      userAvatar: json['userAvatar'],
      content: json['content'] ?? '',
      createdAt: json['createdAt'] ?? '',
      parentCommentId: json['parentCommentId'],
      likeCount: json['likeCount'] ?? 0,
      isLiked: json['isLiked'] as bool? ?? false,
      status: json['status'] ?? 'APPROVED',
    );
  }
}

class QuizQuestion {
  final int id;
  final String? passage;
  final String questionText;
  final String? explanation;
  final List<String> options;
  final int correctIndex;

  QuizQuestion({
    required this.id,
    this.passage,
    required this.questionText,
    this.explanation,
    required this.options,
    required this.correctIndex,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    var optionsList = List<String>.from(json['options'] ?? []);
    return QuizQuestion(
      id: json['id'] ?? 0,
      passage: json['passage'],
      questionText: json['questionText'] ?? '',
      explanation: json['explanation'],
      options: optionsList,
      correctIndex: json['correctIndex'] ?? 0,
    );
  }
}

class LessonDetail {
  final int id;
  final String title;
  final String content;
  final int? sectionId;
  final int? courseId;
  final List<LessonComment> comments;
  final List<QuizQuestion> questions;
  final bool isCompleted;
  final int? estimatedTime;
  final String? lessonCode;
  final int? mediaDurationSeconds;
  final int? mediaSizeBytes;
  final int? estimatedTimeMinutes;
  final String? learningObjectives;
  final String? mediaFileUrl;
  final String? mediaType;

  LessonDetail({
    required this.id,
    required this.title,
    required this.content,
    this.sectionId,
    this.courseId,
    required this.comments,
    required this.questions,
    this.isCompleted = false,
    this.estimatedTime,
    this.lessonCode,
    this.mediaDurationSeconds,
    this.mediaSizeBytes,
    this.estimatedTimeMinutes,
    this.learningObjectives,
    this.mediaFileUrl,
    this.mediaType,
  });

  factory LessonDetail.fromJson(Map<String, dynamic> json) {
    var commentsList = json['comments'] as List? ?? [];
    List<LessonComment> comments = commentsList.map((i) => LessonComment.fromJson(i)).toList();

    var questionsList = json['questions'] as List? ?? [];
    List<QuizQuestion> questions = questionsList.map((i) => QuizQuestion.fromJson(i)).toList();

    return LessonDetail(
      id: json['id'],
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      sectionId: json['sectionId'],
      courseId: json['courseId'],
      comments: comments,
      questions: questions,
      isCompleted: json['isCompleted'] as bool? ?? false,
      estimatedTime: json['estimatedTime'] as int?,
      lessonCode: json['lessonCode'] as String?,
      mediaDurationSeconds: json['mediaDurationSeconds'] as int?,
      mediaSizeBytes: json['mediaSizeBytes'] as int?,
      estimatedTimeMinutes: json['estimatedTimeMinutes'] as int?,
      learningObjectives: json['learningObjectives'] as String?,
      mediaFileUrl: json['mediaFileUrl'] as String?,
      mediaType: json['mediaType'] as String?,
    );
  }
}
