class PermissionUtils {
  static bool isAdministrator(List<String> roles) {
    return roles.contains('ROLE_ADMINISTRATOR') ||
        roles.contains('ADMINISTRATOR');
  }

  static bool canEnrollAndLearn(List<String> roles) {
    return isAdministrator(roles) || roles.contains('ENROLL_AND_LEARN_COURSES');
  }

  static bool canAttemptQuizAndExam(List<String> roles) {
    return isAdministrator(roles) || roles.contains('ATTEMPT_QUIZ_AND_EXAM');
  }

  static bool canManageExamsAsCourseManager(List<String> roles) {
    return isAdministrator(roles) ||
        roles.contains('CREATE_AND_MANAGE_EXAMS_CM');
  }

  /// Guests may browse; logged-in users need the permission.
  static bool shouldShowEnrollUi(bool isLoggedIn, List<String> roles) {
    return !isLoggedIn || canEnrollAndLearn(roles);
  }

  /// Guests may browse; logged-in users need the permission.
  static bool shouldShowExamUi(bool isLoggedIn, List<String> roles) {
    return !isLoggedIn || canAttemptQuizAndExam(roles);
  }
}
