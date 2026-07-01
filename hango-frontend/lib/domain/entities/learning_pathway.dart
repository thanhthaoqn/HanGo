enum NodeStatus {
  locked,
  inProgress,
  completed,
}

class PathwayNode {
  final int step;
  final String courseId;
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

    return PathwayNode(
      step: json['step'],
      courseId: json['course_id'],
      courseTitle: json['course_title'] ?? 'Course Title',
      tags: List<String>.from(json['tags'] ?? []),
      status: parseStatus(json['status']),
      reasonWhy: json['reason_why'],
      progressPercent: json['progress_percent'] ?? 0,
    );
  }
}

class LearningPathway {
  final String roadmapId;
  final String mentorSummary;
  final List<PathwayNode> nodes;

  LearningPathway({
    required this.roadmapId,
    required this.mentorSummary,
    required this.nodes,
  });

  factory LearningPathway.fromJson(Map<String, dynamic> json) {
    return LearningPathway(
      roadmapId: json['roadmap_id'],
      mentorSummary: json['mentor_summary'],
      nodes: (json['nodes'] as List)
          .map((nodeJson) => PathwayNode.fromJson(nodeJson))
          .toList(),
    );
  }
}
