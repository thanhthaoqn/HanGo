class TrainerLeadTaskModel {
  final int id;
  final String taskContent;
  final String? assigneeName;
  final String? reviewerName;
  final String? type;
  final String? status;

  TrainerLeadTaskModel({
    required this.id,
    required this.taskContent,
    this.assigneeName,
    this.reviewerName,
    this.type,
    this.status,
  });

  factory TrainerLeadTaskModel.fromJson(Map<String, dynamic> json) {
    return TrainerLeadTaskModel(
      id: json['id'] as int,
      taskContent: json['taskContent'] as String? ?? '',
      assigneeName: json['assigneeName'] as String?,
      reviewerName: json['reviewerName'] as String?,
      type: json['type'] as String?,
      status: json['status'] as String?,
    );
  }
}
