class TaskModel {
  final int id;
  final String content;
  final int assignedById;
  final String assignedByName;
  final int assignedToId;
  final String assignedToName;
  final String type;
  final String status;
  final DateTime deadline;
  final DateTime createdAt;

  TaskModel({
    required this.id,
    required this.content,
    required this.assignedById,
    required this.assignedByName,
    required this.assignedToId,
    required this.assignedToName,
    required this.type,
    required this.status,
    required this.deadline,
    required this.createdAt,
  });

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id: json['id'] ?? 0,
      content: json['content'] ?? '',
      assignedById: json['assignedById'] ?? 0,
      assignedByName: json['assignedByName'] ?? '',
      assignedToId: json['assignedToId'] ?? 0,
      assignedToName: json['assignedToName'] ?? '',
      type: json['type'] ?? 'QUIZ',
      status: json['status'] ?? 'ASSIGNED',
      deadline: json['deadline'] != null 
          ? DateTime.parse(json['deadline']) 
          : DateTime.now(),
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : DateTime.now(),
    );
  }
}
