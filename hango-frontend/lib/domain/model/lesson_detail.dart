class LessonComment {
  final int id;
  final int userId;
  final String userName;
  final String? userAvatar;
  final String content;
  final String createdAt;

  LessonComment({
    required this.id,
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.content,
    required this.createdAt,
  });

  factory LessonComment.fromJson(Map<String, dynamic> json) {
    return LessonComment(
      id: json['id'],
      userId: json['userId'] ?? 0,
      userName: json['userName'] ?? 'Unknown',
      userAvatar: json['userAvatar'],
      content: json['content'] ?? '',
      createdAt: json['createdAt'] ?? '',
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

  LessonDetail({
    required this.id,
    required this.title,
    required this.content,
    this.sectionId,
    this.courseId,
    required this.comments,
  });

  factory LessonDetail.fromJson(Map<String, dynamic> json) {
    var commentsList = json['comments'] as List? ?? [];
    List<LessonComment> comments = commentsList.map((i) => LessonComment.fromJson(i)).toList();

    return LessonDetail(
      id: json['id'],
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      sectionId: json['sectionId'],
      courseId: json['courseId'],
      comments: comments,
    );
  }
}
