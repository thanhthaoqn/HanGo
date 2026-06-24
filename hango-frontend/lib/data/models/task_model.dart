class CreatorTaskModel {
  final int creatorTaskId;
  final int creatorId;
  final String creatorName;
  final String status;
  final String? submissionNotes;
  final DateTime? submittedAt;
  final int? reviewerId;
  final String? reviewerName;
  final String? reviewComment;
  final DateTime? reviewedAt;

  CreatorTaskModel({
    required this.creatorTaskId,
    required this.creatorId,
    required this.creatorName,
    required this.status,
    this.submissionNotes,
    this.submittedAt,
    this.reviewerId,
    this.reviewerName,
    this.reviewComment,
    this.reviewedAt,
  });

  factory CreatorTaskModel.fromJson(Map<String, dynamic> json) {
    return CreatorTaskModel(
      creatorTaskId: json['creatorTaskId'] ?? 0,
      creatorId: json['creatorId'] ?? 0,
      creatorName: json['creatorName'] ?? '',
      status: json['status'] ?? 'ASSIGNED',
      submissionNotes: json['submissionNotes'],
      submittedAt: json['submittedAt'] != null ? DateTime.parse(json['submittedAt']) : null,
      reviewerId: json['reviewerId'],
      reviewerName: json['reviewerName'],
      reviewComment: json['reviewComment'],
      reviewedAt: json['reviewedAt'] != null ? DateTime.parse(json['reviewedAt']) : null,
    );
  }
}

class TaskModel {
  final int id;
  final int leadId;
  final String leadName;
  final String title;
  final String description;
  final String? type;
  final DateTime dueDate;
  final DateTime createdAt;
  final List<CreatorTaskModel> assignees;

  TaskModel({
    required this.id,
    required this.leadId,
    required this.leadName,
    required this.title,
    required this.description,
    this.type,
    required this.dueDate,
    required this.createdAt,
    required this.assignees,
  });

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id: json['id'] ?? 0,
      leadId: json['leadId'] ?? 0,
      leadName: json['leadName'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      type: json['type'],
      dueDate: json['dueDate'] != null 
          ? DateTime.parse(json['dueDate']) 
          : DateTime.now(),
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : DateTime.now(),
      assignees: (json['assignees'] as List<dynamic>?)
              ?.map((e) => CreatorTaskModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
