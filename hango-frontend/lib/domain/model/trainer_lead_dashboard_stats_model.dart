class TrainerLeadDashboardStatsModel {
  final int registeredUsers;
  final double userGrowthPercentage;
  final int totalCourses;
  final int activeCourses;
  final int inactiveCourses;
  final int assignedTasks;
  final int pendingApprovals;

  TrainerLeadDashboardStatsModel({
    required this.registeredUsers,
    required this.userGrowthPercentage,
    required this.totalCourses,
    required this.activeCourses,
    required this.inactiveCourses,
    required this.assignedTasks,
    required this.pendingApprovals,
  });

  factory TrainerLeadDashboardStatsModel.fromJson(Map<String, dynamic> json) {
    return TrainerLeadDashboardStatsModel(
      registeredUsers: json['registeredUsers'] ?? 0,
      userGrowthPercentage: (json['userGrowthPercentage'] ?? 0).toDouble(),
      totalCourses: json['totalCourses'] ?? 0,
      activeCourses: json['activeCourses'] ?? 0,
      inactiveCourses: json['inactiveCourses'] ?? 0,
      assignedTasks: json['assignedTasks'] ?? 0,
      pendingApprovals: json['pendingApprovals'] ?? 0,
    );
  }
}
