class CourseRecommendation {
  const CourseRecommendation({
    required this.courseId,
    required this.courseTitle,
    required this.courseDescription,
    required this.targetSkill,
    required this.reason,
    required this.currentAccuracy,
  });

  final int courseId;
  final String courseTitle;
  final String courseDescription;
  final String targetSkill;
  final String reason;
  final double currentAccuracy;

  factory CourseRecommendation.fromJson(Map<String, dynamic> json) {
    return CourseRecommendation(
      courseId: (json['courseId'] as num?)?.toInt() ?? 0,
      courseTitle: json['courseTitle'] as String? ?? 'Khóa học',
      courseDescription: json['courseDescription'] as String? ?? '',
      targetSkill: json['targetSkill'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
      currentAccuracy: (json['currentAccuracy'] as num?)?.toDouble() ?? 0,
    );
  }
}
