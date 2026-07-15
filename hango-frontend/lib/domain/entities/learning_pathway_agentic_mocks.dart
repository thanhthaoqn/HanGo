// Agentic frontend mock helpers for FE-11 (Recommendation)
// English-only UI. No backend dependency.

enum NodeType { normal, fastTrackSkipped, detourRemedial, merged }

enum ScheduleStatus { onTrack, atRisk, behind, completed }

class PathwayNodeReroute {
  final NodeType nodeType;
  final String? rerouteReason;
  final bool isOptional;
  final DateTime? skippedAt;
  final int? parentNodeId;

  const PathwayNodeReroute({
    required this.nodeType,
    this.rerouteReason,
    this.isOptional = false,
    this.skippedAt,
    this.parentNodeId,
  });

  factory PathwayNodeReroute.fromJson(Map<String, dynamic> json) {
    final rawNodeType = (json['node_type'] ?? json['nodeType'] ?? 'NORMAL')
        .toString();
    final nodeType = _parseNodeType(rawNodeType);

    final rawIsOptional = json['is_optional'] ?? json['isOptional'];
    final isOptional = rawIsOptional is bool
        ? rawIsOptional
        : (rawIsOptional == null
              ? false
              : rawIsOptional.toString().toLowerCase() == 'true');

    DateTime? parsedDate;
    final rawSkippedAt = json['skipped_at'] ?? json['skippedAt'];
    if (rawSkippedAt is String && rawSkippedAt.isNotEmpty) {
      parsedDate = DateTime.tryParse(rawSkippedAt);
    }

    final parentNodeIdRaw = json['parent_node_id'] ?? json['parentNodeId'];
    final parentNodeId = parentNodeIdRaw is int
        ? parentNodeIdRaw
        : int.tryParse(parentNodeIdRaw.toString() ?? '');

    return PathwayNodeReroute(
      nodeType: nodeType,
      rerouteReason: json['reroute_reason'] ?? json['rerouteReason'],
      isOptional: isOptional,
      skippedAt: parsedDate,
      parentNodeId: parentNodeId,
    );
  }

  Map<String, dynamic> toJson() => {
    'nodeType': nodeType.name,
    'rerouteReason': rerouteReason,
    'isOptional': isOptional,
    'skippedAt': skippedAt?.toIso8601String(),
    'parentNodeId': parentNodeId,
  };

  static NodeType _parseNodeType(String raw) {
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
}

class PathwayNodeSchedule {
  final DateTime? startDate;
  final DateTime? deadline;
  final int? estimatedHours;
  final ScheduleStatus scheduleStatus;

  const PathwayNodeSchedule({
    this.startDate,
    this.deadline,
    this.estimatedHours,
    required this.scheduleStatus,
  });

  factory PathwayNodeSchedule.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
      return null;
    }

    final startDate = parseDate(json['start_date'] ?? json['startDate']);
    final deadline = parseDate(json['deadline']);
    final estimatedHoursRaw = json['estimated_hours'] ?? json['estimatedHours'];

    final estimatedHours = estimatedHoursRaw is int
        ? estimatedHoursRaw
        : int.tryParse(estimatedHoursRaw?.toString() ?? '');

    final rawStatus =
        (json['schedule_status'] ?? json['scheduleStatus'] ?? 'ON_TRACK')
            .toString();
    final scheduleStatus = _parseScheduleStatus(rawStatus);

    return PathwayNodeSchedule(
      startDate: startDate,
      deadline: deadline,
      estimatedHours: estimatedHours,
      scheduleStatus: scheduleStatus,
    );
  }

  Map<String, dynamic> toJson() => {
    'startDate': startDate?.toIso8601String(),
    'deadline': deadline?.toIso8601String(),
    'estimatedHours': estimatedHours,
    'scheduleStatus': scheduleStatus.name,
  };

  static ScheduleStatus _parseScheduleStatus(String raw) {
    switch (raw.trim().toUpperCase()) {
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
}
