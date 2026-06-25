class TaskActivityModel {
  final int id;
  final int taskId;
  final int userId;
  final String userName;
  final String action;
  final String? details;
  final DateTime timestamp;

  TaskActivityModel({
    required this.id,
    required this.taskId,
    required this.userId,
    required this.userName,
    required this.action,
    this.details,
    required this.timestamp,
  });

  factory TaskActivityModel.fromJson(Map<String, dynamic> json) {
    return TaskActivityModel(
      id: json['id'],
      taskId: json['taskId'],
      userId: json['userId'],
      userName: json['userName'] ?? 'Unknown User',
      action: json['action'] ?? '',
      details: json['details'],
      timestamp: json['timestamp'] != null ? DateTime.parse(json['timestamp']) : DateTime.now(),
    );
  }
}
