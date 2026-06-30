class TaskActivityModel {
  final int id;
  final int taskId;
  final int userId;
  final String userName;
  final String actionType;
  final String? description;
  final DateTime createdAt;

  TaskActivityModel({
    required this.id,
    required this.taskId,
    required this.userId,
    required this.userName,
    required this.actionType,
    this.description,
    required this.createdAt,
  });

  factory TaskActivityModel.fromJson(Map<String, dynamic> json) {
    return TaskActivityModel(
      id: json['id'],
      taskId: json['taskId'],
      userId: json['userId'],
      userName: json['userName'] ?? 'Unknown',
      actionType: json['actionType'] ?? '',
      description: json['description'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}
