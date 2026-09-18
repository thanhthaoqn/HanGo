class WeeklyEnrollment {
  final String weekLabel;
  final int count;

  WeeklyEnrollment({required this.weekLabel, required this.count});

  factory WeeklyEnrollment.fromJson(Map<String, dynamic> json) {
    return WeeklyEnrollment(
      weekLabel: json['weekLabel'] ?? '',
      count: json['count'] ?? 0,
    );
  }
}

class TopCourse {
  final int id;
  final String title;
  final String trainerName;
  final int enrollmentCount;
  final double? avgRating;

  TopCourse({
    required this.id,
    required this.title,
    required this.trainerName,
    required this.enrollmentCount,
    this.avgRating,
  });

  factory TopCourse.fromJson(Map<String, dynamic> json) {
    return TopCourse(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      trainerName: json['trainerName'] ?? '',
      enrollmentCount: json['enrollmentCount'] ?? 0,
      avgRating: json['avgRating']?.toDouble(),
    );
  }
}

class TopTrainer {
  final int id;
  final String fullName;
  final String? avatarUrl;
  final double avgRating;
  final int courseCount;
  final int totalEnrollments;

  TopTrainer({
    required this.id,
    required this.fullName,
    this.avatarUrl,
    required this.avgRating,
    required this.courseCount,
    required this.totalEnrollments,
  });

  factory TopTrainer.fromJson(Map<String, dynamic> json) {
    return TopTrainer(
      id: json['id'] ?? 0,
      fullName: json['fullName'] ?? '',
      avatarUrl: json['avatarUrl'],
      avgRating: (json['avgRating'] ?? 0).toDouble(),
      courseCount: json['courseCount'] ?? 0,
      totalEnrollments: json['totalEnrollments'] ?? 0,
    );
  }
}

class CourseManagerDashboardSummary {
  // Original KPI cards
  final int registeredUsersCount;
  final int activeCoursesCount;
  final int inactiveCoursesCount;
  final int examsCount;

  // Enhanced KPI cards
  final int pendingCoursesCount;
  final int pendingExamsCount;
  final int activeLearnerCount;
  final double avgCourseRating;

  // Pipeline counts
  final int draftCoursesCount;
  final int publishedCoursesCount;
  final int rejectedCoursesCount;
  final int hiddenCoursesCount;

  // Weekly deltas
  final double coursesGrowthPercent;
  final double learnersGrowthPercent;
  final double examsGrowthPercent;

  // Enrollment trend
  final List<WeeklyEnrollment> enrollmentTrend;

  // Top performers
  final List<TopCourse> topCoursesByEnrollment;
  final List<TopTrainer> topTrainersByRating;

  // Content quality
  final int coursesWithoutDescription;
  final int coursesWithFewLessons;
  final int examsWithoutQuestions;
  final double avgLessonsPerCourse;
  final int lowRatedCourses;

  // Course distribution by category
  final Map<String, int> coursesByCategory;

  CourseManagerDashboardSummary({
    required this.registeredUsersCount,
    required this.activeCoursesCount,
    required this.inactiveCoursesCount,
    required this.examsCount,
    required this.pendingCoursesCount,
    required this.pendingExamsCount,
    required this.activeLearnerCount,
    required this.avgCourseRating,
    required this.draftCoursesCount,
    required this.publishedCoursesCount,
    required this.rejectedCoursesCount,
    required this.hiddenCoursesCount,
    required this.coursesGrowthPercent,
    required this.learnersGrowthPercent,
    required this.examsGrowthPercent,
    required this.enrollmentTrend,
    required this.topCoursesByEnrollment,
    required this.topTrainersByRating,
    required this.coursesWithoutDescription,
    required this.coursesWithFewLessons,
    required this.examsWithoutQuestions,
    required this.avgLessonsPerCourse,
    required this.lowRatedCourses,
    required this.coursesByCategory,
  });

  factory CourseManagerDashboardSummary.fromJson(Map<String, dynamic> json) {
    return CourseManagerDashboardSummary(
      registeredUsersCount: json['registeredUsersCount'] ?? 0,
      activeCoursesCount: json['activeCoursesCount'] ?? 0,
      inactiveCoursesCount: json['inactiveCoursesCount'] ?? 0,
      examsCount: json['examsCount'] ?? 0,
      pendingCoursesCount: json['pendingCoursesCount'] ?? 0,
      pendingExamsCount: json['pendingExamsCount'] ?? 0,
      activeLearnerCount: json['activeLearnerCount'] ?? 0,
      avgCourseRating: (json['avgCourseRating'] ?? 0).toDouble(),
      draftCoursesCount: json['draftCoursesCount'] ?? 0,
      publishedCoursesCount: json['publishedCoursesCount'] ?? 0,
      rejectedCoursesCount: json['rejectedCoursesCount'] ?? 0,
      hiddenCoursesCount: json['hiddenCoursesCount'] ?? 0,
      coursesGrowthPercent: (json['coursesGrowthPercent'] ?? 0).toDouble(),
      learnersGrowthPercent: (json['learnersGrowthPercent'] ?? 0).toDouble(),
      examsGrowthPercent: (json['examsGrowthPercent'] ?? 0).toDouble(),
      enrollmentTrend: (json['enrollmentTrend'] as List<dynamic>?)
              ?.map((e) => WeeklyEnrollment.fromJson(e))
              .toList() ??
          [],
      topCoursesByEnrollment: (json['topCoursesByEnrollment'] as List<dynamic>?)
              ?.map((e) => TopCourse.fromJson(e))
              .toList() ??
          [],
      topTrainersByRating: (json['topTrainersByRating'] as List<dynamic>?)
              ?.map((e) => TopTrainer.fromJson(e))
              .toList() ??
          [],
      coursesWithoutDescription: json['coursesWithoutDescription'] ?? 0,
      coursesWithFewLessons: json['coursesWithFewLessons'] ?? 0,
      examsWithoutQuestions: json['examsWithoutQuestions'] ?? 0,
      avgLessonsPerCourse: (json['avgLessonsPerCourse'] ?? 0).toDouble(),
      lowRatedCourses: json['lowRatedCourses'] ?? 0,
      coursesByCategory: (json['coursesByCategory'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, (v as num).toInt())) ??
          {},
    );
  }
}

