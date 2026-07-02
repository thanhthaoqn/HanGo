class TrainerTaskModel {
  final int id;
  final int taskId;
  final String taskContent;
  final DateTime deadline;
  final String type;
  final String status;

  TrainerTaskModel({
    required this.id,
    required this.taskId,
    required this.taskContent,
    required this.deadline,
    required this.type,
    required this.status,
  });

  factory TrainerTaskModel.fromJson(Map<String, dynamic> json) {
    return TrainerTaskModel(
      id: json['id'],
      taskId: json['taskId'],
      taskContent: json['taskContent'],
      deadline: DateTime.parse(json['deadline']),
      type: json['type'],
      status: json['status'],
    );
  }
}
