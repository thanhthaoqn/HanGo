class CourseManagerQuestion {
  final int id;
  final String questionText;
  final String categoryName;
  final String? skillName;
  final String? groupTypeName;
  final String difficultyName;
  String status;
  final String creatorName;
  final DateTime? createdAt;
  final DateTime? updatedAt;
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
    this.createdAt,
    this.updatedAt,
    this.isGroup = false,
    this.usageType,
  });

  // Returns null (rather than DateTime.now()) when the backend sent no value -
  // legacy/imported questions can genuinely have no recorded created/updated
  // timestamp, and silently substituting "now" made every refresh recompute a
  // fresh-looking date for those rows, making an edit look like it had also
  // rewritten the original creation time.
  static DateTime? _parseDate(dynamic dateData) {
    if (dateData == null) return null;
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
        return null;
      }
    }
    return DateTime.tryParse(dateData.toString());
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
