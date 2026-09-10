import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app_routes.dart';
import '../services/app_state.dart';
import '../presentation/pages/learner/learner_shell_page.dart';
import '../presentation/pages/learner/learner_home_page.dart';
import '../presentation/pages/course/list_courses_page.dart';
import '../presentation/pages/course/course_detail_page.dart';
import '../presentation/pages/course/lesson_detail_page.dart';
import '../presentation/pages/course/cart_page.dart';
import '../presentation/pages/exam/list_exams_page.dart';
import '../presentation/pages/learner/learning_pathway_page.dart';
import '../presentation/pages/learner/my_learning_page.dart';
import '../presentation/pages/learner/my_information_page.dart';
import '../presentation/pages/login_page.dart';
import '../presentation/pages/register_page.dart';
import '../presentation/pages/forgot_password_page.dart';
import '../presentation/pages/terms_and_privacy_page.dart';
import '../presentation/pages/admin/admin_dashboard_page.dart';
import '../presentation/pages/course_manager/course_manager_shell_page.dart';
import '../presentation/pages/trainer/trainer_route_gate.dart';

class AppRouter {
  static final GlobalKey<NavigatorState> rootNavigatorKey =
      GlobalKey<NavigatorState>();

  static GoRouter createRouter(AppState appState) {
    return GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: AppRoutes.home,
      refreshListenable: appState,
      redirect: (BuildContext context, GoRouterState state) {
        if (appState.isBooting) {
          return null;
        }

        final path = state.uri.path;
        final isAuthenticated = appState.isAuthenticated;
        final role = appState.session?.role;

        // Redirect authenticated users away from auth pages
        if (isAuthenticated) {
          if (path == AppRoutes.login || path == AppRoutes.register) {
            if (role == 'ADMIN') return AppRoutes.admin;
            if (role == 'COURSE_MANAGER') return AppRoutes.courseManager;
            if (role == 'TRAINER') return AppRoutes.trainer;
            return AppRoutes.home;
          }

          // If at root '/' on initial load, navigate to specific role dashboard
          if (path == AppRoutes.home) {
            if (role == 'ADMIN') return AppRoutes.admin;
            if (role == 'COURSE_MANAGER') return AppRoutes.courseManager;
            if (role == 'TRAINER') return AppRoutes.trainer;
          }

          // Role guard: prevent wrong dashboard URLs
          if (role == 'TRAINER') {
            if (path.startsWith(AppRoutes.admin) ||
                path.startsWith(AppRoutes.courseManager)) {
              return AppRoutes.trainer;
            }
          } else if (role == 'COURSE_MANAGER') {
            if (path.startsWith(AppRoutes.admin) ||
                path.startsWith(AppRoutes.trainer)) {
              return AppRoutes.courseManager;
            }
          } else if (role == 'ADMIN') {
            if (path.startsWith(AppRoutes.trainer) ||
                path.startsWith(AppRoutes.courseManager)) {
              return AppRoutes.admin;
            }
          } else if (role == 'LEARNER') {
            if (path.startsWith(AppRoutes.admin) ||
                path.startsWith(AppRoutes.courseManager) ||
                path.startsWith(AppRoutes.trainer)) {
              return AppRoutes.home;
            }
          }
        } else {
          // Unauthenticated users trying to access role dashboards get redirected to login
          if (path.startsWith(AppRoutes.admin) ||
              path.startsWith(AppRoutes.courseManager) ||
              path.startsWith(AppRoutes.trainer)) {
            return AppRoutes.login;
          }
        }

        return null;
      },
      routes: [
        // 1. Learner shell with IndexedStack branches
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return LearnerShellPage(navigationShell: navigationShell);
          },
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutes.home,
                  builder: (context, state) =>
                      const LearnerHomePage(isEmbedded: true),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutes.courses,
                  builder: (context, state) =>
                      const ListCoursesPage(isEmbedded: true),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutes.exams,
                  builder: (context, state) =>
                      const ListExamsPage(isEmbedded: true),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutes.pathway,
                  builder: (context, state) =>
                      const LearningPathwayPage(isEmbedded: true),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutes.myLearning,
                  builder: (context, state) =>
                      const MyLearningPage(isEmbedded: true),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutes.profile,
                  builder: (context, state) {
                    final tabStr = state.uri.queryParameters['tab'];
                    final tab = int.tryParse(tabStr ?? '') ?? 0;
                    return MyInformationPage(isEmbedded: true, initialTab: tab);
                  },
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutes.cart,
                  builder: (context, state) =>
                      const CartPage(isEmbedded: true),
                ),
              ],
            ),
          ],
        ),

        // 2. Top-level detail and content routes
        GoRoute(
          path: AppRoutes.courseDetail,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) {
            final idStr = state.pathParameters['id'];
            final id = int.tryParse(idStr ?? '') ?? 0;
            return CourseDetailPage(courseId: id);
          },
        ),
        GoRoute(
          path: AppRoutes.courseLesson,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) {
            final courseIdStr = state.pathParameters['courseId'];
            final lessonIdStr = state.pathParameters['lessonId'];
            final courseId = int.tryParse(courseIdStr ?? '') ?? 0;
            final lessonId = int.tryParse(lessonIdStr ?? '') ?? 0;
            return LessonDetailPage(courseId: courseId, lessonId: lessonId);
          },
        ),

        // 3. Auth routes
        GoRoute(
          path: AppRoutes.login,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => const LoginPage(),
        ),
        GoRoute(
          path: AppRoutes.register,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => const RegisterPage(),
        ),
        GoRoute(
          path: AppRoutes.forgotPassword,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => const ForgotPasswordPage(),
        ),
        GoRoute(
          path: AppRoutes.termsAndPrivacy,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) {
            final tabStr = state.uri.queryParameters['tab'];
            final tab = int.tryParse(tabStr ?? '') ?? 0;
            return TermsAndPrivacyPage(initialTab: tab);
          },
        ),

        // 4. Role Dashboards
        GoRoute(
          path: AppRoutes.admin,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => const AdminDashboardPage(),
        ),
        GoRoute(
          path: AppRoutes.courseManager,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => const CourseManagerShellPage(),
        ),
        GoRoute(
          path: AppRoutes.trainer,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => const TrainerRouteGate(),
        ),
      ],
      errorBuilder: (context, state) => Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.search_off_rounded,
                size: 64,
                color: Color(0xFF94A3B8),
              ),
              const SizedBox(height: 16),
              const Text(
                '404 - Không tìm thấy trang',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Đường dẫn ${state.uri.path} không tồn tại.',
                style: const TextStyle(color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF28B79B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => context.go(AppRoutes.home),
                icon: const Icon(Icons.home),
                label: const Text('Về trang chủ'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
