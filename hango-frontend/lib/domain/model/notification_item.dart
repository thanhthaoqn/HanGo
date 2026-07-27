class NotificationItem {
  final int id;
  final String type;
  final String title;
  final String message;
  final int? courseId;
  final String? courseTitle;
  final bool read;
  final DateTime? createdAt;

  NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    this.courseId,
    this.courseTitle,
    required this.read,
    this.createdAt,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'] as int,
      type: json['type'] as String? ?? '',
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      courseId: json['courseId'] as int?,
      courseTitle: json['courseTitle'] as String?,
      read: json['read'] as bool? ?? false,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'] as String) : null,
    );
  }
}
