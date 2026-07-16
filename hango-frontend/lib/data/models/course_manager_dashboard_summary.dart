class CourseManagerDashboardSummary {
  final int registeredUsersCount;
  final int activeCoursesCount;
  final int inactiveCoursesCount;
  final int examsCount;

  CourseManagerDashboardSummary({
    required this.registeredUsersCount,
    required this.activeCoursesCount,
    required this.inactiveCoursesCount,
    required this.examsCount,
  });

  factory CourseManagerDashboardSummary.fromJson(Map<String, dynamic> json) {
    return CourseManagerDashboardSummary(
      registeredUsersCount: json['registeredUsersCount'] ?? 0,
      activeCoursesCount: json['activeCoursesCount'] ?? 0,
      inactiveCoursesCount: json['inactiveCoursesCount'] ?? 0,
      examsCount: json['examsCount'] ?? 0,
    );
  }
}
