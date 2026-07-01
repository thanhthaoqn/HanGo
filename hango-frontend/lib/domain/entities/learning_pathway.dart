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

  PathwayNode({
    required this.step,
    required this.courseId,
    required this.courseTitle,
    required this.tags,
    required this.status,
    required this.reasonWhy,
    this.progressPercent = 0,
  });

  factory PathwayNode.fromJson(Map<String, dynamic> json) {
    NodeStatus parseStatus(String statusStr) {
      switch (statusStr) {
        case 'In_Progress':
          return NodeStatus.inProgress;
        case 'Completed':
          return NodeStatus.completed;
        case 'Locked':
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
    );
  }
}

class LearningPathway {
  final int pathwayId;
  final String roadmapId;
  final String mentorSummary;
  final List<PathwayNode> nodes;

  LearningPathway({
    required this.pathwayId,
    required this.roadmapId,
    required this.mentorSummary,
    required this.nodes,
  });

  factory LearningPathway.fromJson(Map<String, dynamic> json) {
    final rawPathwayId = json['pathway_id'] ?? json['pathwayId'];

    return LearningPathway(
      pathwayId: rawPathwayId is int ? rawPathwayId : int.tryParse('$rawPathwayId') ?? 0,
      roadmapId: json['roadmap_id'] ?? json['roadmapId'] ?? '',
      mentorSummary: json['mentor_summary'] ?? json['mentorSummary'] ?? '',
      nodes: (json['nodes'] as List)
          .map((nodeJson) => PathwayNode.fromJson(nodeJson as Map<String, dynamic>))
          .toList(),
    );
  }
}
