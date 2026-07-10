enum NodeStatus {
  locked,
  inProgress,
  completed,
}

class PathwayNode {
  final int step;
  final int courseId;
  final String courseTitle;
  final List<String> tags;
  final NodeStatus status;
  final String reasonWhy;
  final int progressPercent;
  final String? skillType;
  final int totalLessons;
  final int completedLessons;

  PathwayNode({
    required this.step,
    required this.courseId,
    required this.courseTitle,
    required this.tags,
    required this.status,
    required this.reasonWhy,
    this.progressPercent = 0,
    this.skillType,
    this.totalLessons = 0,
    this.completedLessons = 0,
  });

  factory PathwayNode.fromJson(Map<String, dynamic> json) {
    NodeStatus parseStatus(String statusStr) {
      switch (statusStr.trim().toUpperCase()) {
        case 'IN_PROGRESS':
          return NodeStatus.inProgress;
        case 'COMPLETED':
          return NodeStatus.completed;
        case 'LOCKED':
        default:
          return NodeStatus.locked;
      }
    }

    final rawCourseId = json['course_id'] ?? json['courseId'];

    return PathwayNode(
      step: json['step'] is int ? json['step'] as int : int.tryParse('${json['step']}') ?? 0,
      courseId: rawCourseId is int ? rawCourseId : int.tryParse('$rawCourseId') ?? 0,
      courseTitle: json['course_title'] ?? json['courseTitle'] ?? 'Course Title',
      tags: List<String>.from(json['tags'] ?? []),
      status: parseStatus('${json['status']}'),
      reasonWhy: json['reason_why'] ?? json['reasonWhy'] ?? '',
      progressPercent: json['progress_percent'] ?? json['progressPercent'] ?? 0,
      skillType: json['skill_type'] ?? json['skillType'],
      totalLessons: json['total_lessons'] ?? json['totalLessons'] ?? 0,
      completedLessons: json['completed_lessons'] ?? json['completedLessons'] ?? 0,
    );
  }
}

class LearningPathway {
  final int pathwayId;
  final String roadmapId;
  final String mentorSummary;
  final List<PathwayNode> nodes;
  final List<String> weakSkills;
  final int totalSteps;
  final int completedSteps;

  LearningPathway({
    required this.pathwayId,
    required this.roadmapId,
    required this.mentorSummary,
    required this.nodes,
    this.weakSkills = const [],
    this.totalSteps = 0,
    this.completedSteps = 0,
  });

  int get overallProgressPercent {
    if (totalSteps == 0) return 0;
    return (completedSteps / totalSteps * 100).round();
  }

  factory LearningPathway.fromJson(Map<String, dynamic> json) {
    final rawPathwayId = json['pathway_id'] ?? json['pathwayId'];

    return LearningPathway(
      pathwayId: rawPathwayId is int ? rawPathwayId : int.tryParse('$rawPathwayId') ?? 0,
      roadmapId: json['roadmap_id'] ?? json['roadmapId'] ?? '',
      mentorSummary: json['mentor_summary'] ?? json['mentorSummary'] ?? '',
      nodes: (json['nodes'] as List)
          .map((nodeJson) => PathwayNode.fromJson(nodeJson as Map<String, dynamic>))
          .toList(),
      weakSkills: List<String>.from(json['weak_skills'] ?? json['weakSkills'] ?? []),
      totalSteps: json['total_steps'] ?? json['totalSteps'] ?? 0,
      completedSteps: json['completed_steps'] ?? json['completedSteps'] ?? 0,
    );
  }
}
