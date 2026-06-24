class AiCoursePathwayResponse {
  const AiCoursePathwayResponse({
    required this.generatedBy,
    required this.headline,
    required this.summary,
    required this.weaknessAreas,
    required this.recommendedCourses,
    required this.actionSteps,
  });

  final String generatedBy;
  final String headline;
  final String summary;
  final List<AiWeaknessArea> weaknessAreas;
  final List<AiRecommendedCourse> recommendedCourses;
  final List<String> actionSteps;

  factory AiCoursePathwayResponse.fromJson(Map<String, dynamic> json) {
    return AiCoursePathwayResponse(
      generatedBy: json['generatedBy'] as String? ?? 'UNKNOWN',
      headline: json['headline'] as String? ?? 'AI Learning Pathway',
      summary: json['summary'] as String? ?? '',
      weaknessAreas: (json['weaknessAreas'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(AiWeaknessArea.fromJson)
          .toList(),
      recommendedCourses: (json['recommendedCourses'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(AiRecommendedCourse.fromJson)
          .toList(),
      actionSteps: (json['actionSteps'] as List? ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}

class AiWeaknessArea {
  const AiWeaknessArea({
    required this.area,
    required this.severity,
    required this.evidence,
    required this.keywords,
  });

  final String area;
  final String severity; // HIGH, MEDIUM, LOW
  final String evidence;
  final List<String> keywords;

  factory AiWeaknessArea.fromJson(Map<String, dynamic> json) {
    return AiWeaknessArea(
      area: json['area'] as String? ?? '',
      severity: json['severity'] as String? ?? 'MEDIUM',
      evidence: json['evidence'] as String? ?? '',
      keywords: (json['keywords'] as List? ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}

class AiRecommendedCourse {
  const AiRecommendedCourse({
    required this.courseId,
    required this.title,
    required this.categoryName,
    required this.difficultyName,
    this.rating,
    this.learnersCount,
    this.thumbnailUrl,
    required this.reason,
    required this.priority,
  });

  final int courseId;
  final String title;
  final String categoryName;
  final String difficultyName;
  final double? rating;
  final int? learnersCount;
  final String? thumbnailUrl;
  final String reason;
  final int priority;

  factory AiRecommendedCourse.fromJson(Map<String, dynamic> json) {
    return AiRecommendedCourse(
      courseId: (json['courseId'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ?? 'Khóa học',
      categoryName: json['categoryName'] as String? ?? '',
      difficultyName: json['difficultyName'] as String? ?? '',
      rating: (json['rating'] as num?)?.toDouble(),
      learnersCount: (json['learnersCount'] as num?)?.toInt(),
      thumbnailUrl: json['thumbnailUrl'] as String?,
      reason: json['reason'] as String? ?? '',
      priority: (json['priority'] as num?)?.toInt() ?? 99,
    );
  }
}
