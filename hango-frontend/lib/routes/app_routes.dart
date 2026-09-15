class AppRoutes {
  // Learner shell tab routes
  static const String home = '/';
  static const String courses = '/courses';
  static const String exams = '/exams';
  static const String pathway = '/pathway';
  static const String myLearning = '/my-learning';
  static const String profile = '/profile';
  static const String cart = '/cart';

  // Detail routes
  static const String courseDetail = '/courses/:id';
  static const String courseLesson = '/courses/:courseId/lessons/:lessonId';
  static const String takeExam = '/take-exam/:id';
  static const String entryExam = '/entry-exam';
  static const String examResult = '/exam-results';

  // Auth routes
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String termsAndPrivacy = '/terms-and-privacy';

  // Role routes
  static const String admin = '/admin';
  static const String courseManager = '/course-manager';
  static const String trainer = '/trainer';
}
