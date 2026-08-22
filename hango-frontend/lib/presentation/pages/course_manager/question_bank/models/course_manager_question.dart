class CourseManagerQuestion {
  final int id;
  final String questionText;
  final String categoryName;
  final String? skillName;
  final String? groupTypeName;
  final String difficultyName;
  String status;
  final String creatorName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isGroup;
  final int? usageType;

  final String? displayNo;

  CourseManagerQuestion({
    required this.id,
    this.displayNo,
    required this.questionText,
    required this.categoryName,
    this.skillName,
    this.groupTypeName,
    required this.difficultyName,
    required this.status,
    required this.creatorName,
    required this.createdAt,
    required this.updatedAt,
    this.isGroup = false,
    this.usageType,
  });

  static DateTime _parseDate(dynamic dateData) {
    if (dateData == null) return DateTime.now();
    if (dateData is List && dateData.isNotEmpty) {
      try {
        return DateTime(
          dateData.length > 0 ? (dateData[0] as num).toInt() : 2000,
          dateData.length > 1 ? (dateData[1] as num).toInt() : 1,
          dateData.length > 2 ? (dateData[2] as num).toInt() : 1,
          dateData.length > 3 ? (dateData[3] as num).toInt() : 0,
          dateData.length > 4 ? (dateData[4] as num).toInt() : 0,
          dateData.length > 5 ? (dateData[5] as num).toInt() : 0,
        );
      } catch (e) {
        return DateTime.now();
      }
    }
    return DateTime.tryParse(dateData.toString()) ?? DateTime.now();
  }

  factory CourseManagerQuestion.fromJson(Map<String, dynamic> json) {
    return CourseManagerQuestion(
      id: json['id'] as int? ?? 0,
      questionText: json['questionText'] as String? ?? '',
      categoryName: json['categoryName'] as String? ?? 'Chưa phân loại',
      skillName: json['skillName'] as String?,
      groupTypeName: json['groupTypeName'] as String?,
      difficultyName: json['difficultyName'] as String? ?? 'Medium',
      status: json['status'] as String? ?? 'PRIVATE',
      creatorName: json['creatorName'] as String? ?? 'Unknown',
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(json['updatedAt']),
      isGroup: json['isGroup'] as bool? ?? false,
      usageType: json['usageType'] as int?,
    );
  }
}
