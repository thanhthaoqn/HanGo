enum NodeStatus { locked, inProgress, completed }

enum NodeType { normal, fastTrackSkipped, detourRemedial, merged }

enum ScheduleStatus { onTrack, atRisk, behind, completed }

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

  // Agentic upgrade metadata (optional; FE mock compatible)
  final NodeType nodeType;
  final String? rerouteReason;
  final bool isOptional;
  final DateTime? skippedAt;
  final int? parentNodeId;

  // Smart time-boxing metadata
  final DateTime? startDate;
  final DateTime? deadline;
  final int? estimatedHours;
  final ScheduleStatus? scheduleStatus;

  // Multi-goal merging metadata
  final List<String>? sourceGoalLabels;
  final String? mergeReason;

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
    this.nodeType = NodeType.normal,
    this.rerouteReason,
    this.isOptional = false,
    this.skippedAt,
    this.parentNodeId,
    this.startDate,
    this.deadline,
    this.estimatedHours,
    this.scheduleStatus,
    this.sourceGoalLabels,
    this.mergeReason,
  });

  PathwayNode copyWith({
    int? step,
    int? courseId,
    String? courseTitle,
    List<String>? tags,
    NodeStatus? status,
    String? reasonWhy,
    int? progressPercent,
    String? skillType,
    int? totalLessons,
    int? completedLessons,
    NodeType? nodeType,
    String? rerouteReason,
    bool? isOptional,
    DateTime? skippedAt,
    int? parentNodeId,
    DateTime? startDate,
    DateTime? deadline,
    int? estimatedHours,
    ScheduleStatus? scheduleStatus,
    List<String>? sourceGoalLabels,
    String? mergeReason,
  }) {
    return PathwayNode(
      step: step ?? this.step,
      courseId: courseId ?? this.courseId,
      courseTitle: courseTitle ?? this.courseTitle,
      tags: tags ?? this.tags,
      status: status ?? this.status,
      reasonWhy: reasonWhy ?? this.reasonWhy,
      progressPercent: progressPercent ?? this.progressPercent,
      skillType: skillType ?? this.skillType,
      totalLessons: totalLessons ?? this.totalLessons,
      completedLessons: completedLessons ?? this.completedLessons,
      nodeType: nodeType ?? this.nodeType,
      rerouteReason: rerouteReason ?? this.rerouteReason,
      isOptional: isOptional ?? this.isOptional,
      skippedAt: skippedAt ?? this.skippedAt,
      parentNodeId: parentNodeId ?? this.parentNodeId,
      startDate: startDate ?? this.startDate,
      deadline: deadline ?? this.deadline,
      estimatedHours: estimatedHours ?? this.estimatedHours,
      scheduleStatus: scheduleStatus ?? this.scheduleStatus,
      sourceGoalLabels: sourceGoalLabels ?? this.sourceGoalLabels,
      mergeReason: mergeReason ?? this.mergeReason,
    );
  }

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

    NodeType parseNodeType(String raw) {
      switch (raw.trim().toUpperCase()) {
        case 'FAST_TRACK_SKIPPED':
          return NodeType.fastTrackSkipped;
        case 'DETOUR_REMEDIAL':
          return NodeType.detourRemedial;
        case 'MERGED':
          return NodeType.merged;
        case 'NORMAL':
        default:
          return NodeType.normal;
      }
    }

    ScheduleStatus? parseScheduleStatus(dynamic raw) {
      if (raw == null) return null;
      final s = raw.toString();
      switch (s.trim().toUpperCase()) {
        case 'AT_RISK':
          return ScheduleStatus.atRisk;
        case 'BEHIND':
          return ScheduleStatus.behind;
        case 'COMPLETED':
          return ScheduleStatus.completed;
        case 'ON_TRACK':
        default:
          return ScheduleStatus.onTrack;
      }
    }

    DateTime? parseDate(dynamic v) {
      if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
      return null;
    }

    final rawCourseId = json['course_id'] ?? json['courseId'];

    final rawNodeType = json['node_type'] ?? json['nodeType'] ?? 'NORMAL';
    final rawSchedule = json['schedule_status'] ?? json['scheduleStatus'];

    final rawIsOptional = json['is_optional'] ?? json['isOptional'];
    final isOptional = rawIsOptional is bool
        ? rawIsOptional
        : (rawIsOptional == null
              ? false
              : rawIsOptional.toString().toLowerCase() == 'true');

    final parentRaw = json['parent_node_id'] ?? json['parentNodeId'];
    final parentNodeId = parentRaw is int
        ? parentRaw
        : int.tryParse(parentRaw?.toString() ?? '');

    final estimatedRaw = json['estimated_hours'] ?? json['estimatedHours'];
    final estimatedHours = estimatedRaw is int
        ? estimatedRaw
        : int.tryParse(estimatedRaw?.toString() ?? '');

    return PathwayNode(
      step: json['step'] is int
          ? json['step'] as int
          : int.tryParse('${json['step']}') ?? 0,
      courseId: rawCourseId is int
          ? rawCourseId
          : int.tryParse('$rawCourseId') ?? 0,
      courseTitle:
          json['course_title'] ?? json['courseTitle'] ?? 'Course Title',
      tags: List<String>.from(json['tags'] ?? []),
      status: parseStatus('${json['status']}'),
      reasonWhy: json['reason_why'] ?? json['reasonWhy'] ?? '',
      progressPercent: json['progress_percent'] ?? json['progressPercent'] ?? 0,
      skillType: json['skill_type'] ?? json['skillType'],
      totalLessons: json['total_lessons'] ?? json['totalLessons'] ?? 0,
      completedLessons:
          json['completed_lessons'] ?? json['completedLessons'] ?? 0,
      nodeType: parseNodeType('${rawNodeType}'),
      rerouteReason: json['reroute_reason'] ?? json['rerouteReason'],
      isOptional: isOptional,
      skippedAt: parseDate(json['skipped_at'] ?? json['skippedAt']),
      parentNodeId: parentNodeId,
      startDate: parseDate(json['start_date'] ?? json['startDate']),
      deadline: parseDate(json['deadline']),
      estimatedHours: estimatedHours,
      scheduleStatus: parseScheduleStatus(rawSchedule),
      sourceGoalLabels: json['source_goal_labels'] != null || json['sourceGoalLabels'] != null
          ? List<String>.from(json['source_goal_labels'] ?? json['sourceGoalLabels'] ?? [])
          : null,
      mergeReason: json['merge_reason'] ?? json['mergeReason'],
    );
  }

  Map<String, dynamic> toJson() {
    String formatNodeType(NodeType type) {
      switch (type) {
        case NodeType.fastTrackSkipped:
          return 'FAST_TRACK_SKIPPED';
        case NodeType.detourRemedial:
          return 'DETOUR_REMEDIAL';
        case NodeType.merged:
          return 'MERGED';
        case NodeType.normal:
        default:
          return 'NORMAL';
      }
    }

    String formatStatus(NodeStatus s) {
      switch (s) {
        case NodeStatus.completed:
          return 'COMPLETED';
        case NodeStatus.inProgress:
          return 'IN_PROGRESS';
        case NodeStatus.locked:
        default:
          return 'LOCKED';
      }
    }

    return {
      'step': step,
      'course_id': courseId,
      'course_title': courseTitle,
      'tags': tags,
      'status': formatStatus(status),
      'reason_why': reasonWhy,
      'progress_percent': progressPercent,
      'node_type': formatNodeType(nodeType),
    };
  }
}

class PathwayRerouteSuggestion {
  final NodeType nodeType;
  final String? rerouteReason;
  final bool canSkip;
  final String? blockedReason;

  PathwayRerouteSuggestion({
    required this.nodeType,
    this.rerouteReason,
    this.canSkip = false,
    this.blockedReason,
  });

  factory PathwayRerouteSuggestion.fromJson(Map<String, dynamic> json) {
    NodeType parseNodeType(String raw) {
      switch (raw.trim().toUpperCase()) {
        case 'FAST_TRACK_SKIPPED':
          return NodeType.fastTrackSkipped;
        case 'DETOUR_REMEDIAL':
          return NodeType.detourRemedial;
        case 'MERGED':
          return NodeType.merged;
        case 'NORMAL':
        default:
          return NodeType.normal;
      }
    }

    final rawNodeType = json['node_type'] ?? json['nodeType'] ?? 'NORMAL';
    return PathwayRerouteSuggestion(
      nodeType: parseNodeType(rawNodeType),
      rerouteReason: json['reroute_reason'] ?? json['rerouteReason'],
      canSkip: json['can_skip'] ?? json['canSkip'] ?? false,
      blockedReason: json['blocked_reason'] ?? json['blockedReason'],
    );
  }
}



class LearningPathway {
  final PathwayRerouteSuggestion? pendingRerouteSuggestion;
  final int pathwayId;

  final String roadmapId;
  final String mentorSummary;
  final List<PathwayNode> nodes;
  final List<String> weakSkills;
  final int totalSteps;
  final int completedSteps;
  final List<String> suggestedActions; // <--- New field

  // Smart time-boxing metadata
  final String? goalName;
  final String? targetDate;
  final int? hoursPerWeek;
  final ScheduleStatus? scheduleStatus;

  LearningPathway({
    this.pendingRerouteSuggestion,
    required this.pathwayId,
    required this.roadmapId,
    required this.mentorSummary,
    required this.nodes,
    this.weakSkills = const [],
    this.totalSteps = 0,
    this.completedSteps = 0,
    this.suggestedActions = const [],
    this.goalName,
    this.targetDate,
    this.hoursPerWeek,
    this.scheduleStatus,
  });

  LearningPathway copyWith({
    PathwayRerouteSuggestion? pendingRerouteSuggestion,
    int? pathwayId,
    String? roadmapId,
    String? mentorSummary,
    List<PathwayNode>? nodes,
    List<String>? weakSkills,
    int? totalSteps,
    int? completedSteps,
    List<String>? suggestedActions,
    String? goalName,
    String? targetDate,
    int? hoursPerWeek,
    ScheduleStatus? scheduleStatus,
  }) {
    return LearningPathway(
      pendingRerouteSuggestion:
          pendingRerouteSuggestion ?? this.pendingRerouteSuggestion,
      pathwayId: pathwayId ?? this.pathwayId,
      roadmapId: roadmapId ?? this.roadmapId,
      mentorSummary: mentorSummary ?? this.mentorSummary,
      nodes: nodes ?? this.nodes,
      weakSkills: weakSkills ?? this.weakSkills,
      totalSteps: totalSteps ?? this.totalSteps,
      completedSteps: completedSteps ?? this.completedSteps,
      suggestedActions: suggestedActions ?? this.suggestedActions,
      goalName: goalName ?? this.goalName,
      targetDate: targetDate ?? this.targetDate,
      hoursPerWeek: hoursPerWeek ?? this.hoursPerWeek,
      scheduleStatus: scheduleStatus ?? this.scheduleStatus,
    );
  }

  int get overallProgressPercent {
    if (totalSteps == 0) return 0;
    return (completedSteps / totalSteps * 100).round();
  }

  factory LearningPathway.fromJson(Map<String, dynamic> json) {
    ScheduleStatus? parseScheduleStatus(dynamic raw) {
      if (raw == null) return null;
      final s = raw.toString();
      switch (s.trim().toUpperCase()) {
        case 'AT_RISK':
          return ScheduleStatus.atRisk;
        case 'BEHIND':
          return ScheduleStatus.behind;
        case 'COMPLETED':
          return ScheduleStatus.completed;
        case 'ON_TRACK':
        default:
          return ScheduleStatus.onTrack;
      }
    }

    final rawPathwayId = json['pathway_id'] ?? json['pathwayId'];
    final rawSchedule = json['schedule_status'] ?? json['scheduleStatus'];

    return LearningPathway(
      pendingRerouteSuggestion: json['pending_reroute_suggestion'] != null || json['pendingRerouteSuggestion'] != null
          ? PathwayRerouteSuggestion.fromJson(json['pending_reroute_suggestion'] ?? json['pendingRerouteSuggestion'])
          : null,
      pathwayId: rawPathwayId is int
          ? rawPathwayId
          : int.tryParse('$rawPathwayId') ?? 0,
      roadmapId: json['roadmap_id'] ?? json['roadmapId'] ?? '',
      mentorSummary: json['mentor_summary'] ?? json['mentorSummary'] ?? '',
      nodes: (json['nodes'] as List)
          .map(
            (nodeJson) =>
                PathwayNode.fromJson(nodeJson as Map<String, dynamic>),
          )
          .toList(),
      weakSkills: List<String>.from(
        json['weak_skills'] ?? json['weakSkills'] ?? [],
      ),
      totalSteps: json['total_steps'] ?? json['totalSteps'] ?? 0,
      completedSteps: json['completed_steps'] ?? json['completedSteps'] ?? 0,
      suggestedActions: List<String>.from(
        json['suggested_actions'] ?? json['suggestedActions'] ?? [],
      ),
      goalName: json['goal_name'] ?? json['goalName'],
      targetDate: json['target_date'] ?? json['targetDate'],
      hoursPerWeek: json['hours_per_week'] ?? json['hoursPerWeek'],
      scheduleStatus: parseScheduleStatus(rawSchedule),
    );
  }
}
