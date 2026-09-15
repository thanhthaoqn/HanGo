import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hango/data/services/auth_service.dart';

void main() {
  group('AuthService.getStoredSession', () {
    setUp(() {
      AuthService.cachedFullName = null;
      AuthService.cachedEmail = null;
      AuthService.cachedAvatarUrl = null;
      AuthService.cachedRoles = null;
      AuthService.cachedIsLoggedIn = null;
    });

    test('returns null when no token is stored', () async {
      AuthService.cachedFullName = 'Stale User';
      AuthService.cachedRoles = ['ROLE_TRAINER'];
      AuthService.cachedIsLoggedIn = true;
      SharedPreferences.setMockInitialValues({});

      final session = await AuthService().getStoredSession();

      expect(session, isNull);
      expect(AuthService.cachedFullName, isNull);
      expect(AuthService.cachedRoles, isNull);
      expect(AuthService.cachedIsLoggedIn, isFalse);
    });

    test('returns null when the stored token is an empty string', () async {
      SharedPreferences.setMockInitialValues({'auth_token': ''});

      final session = await AuthService().getStoredSession();

      expect(session, isNull);
    });

    test(
      'rebuilds a session from the same keys AuthService.getToken()/saveSession() use',
      () async {
        SharedPreferences.setMockInitialValues({
          'auth_token': 'jwt-123',
          'user_id': 42,
          'user_fullname': 'Le Hoang',
          'user_email': 'hoang@hango.edu.vn',
          'user_roles': ['ROLE_COURSE_MANAGER', 'CREATE_AND_MANAGE_EXAMS_CM'],
        });

        final session = await AuthService().getStoredSession();

        expect(session, isNotNull);
        expect(session!.token, 'jwt-123');
        expect(session.userId, 42);
        expect(session.fullName, 'Le Hoang');
        expect(session.email, 'hoang@hango.edu.vn');
        expect(session.role, 'COURSE_MANAGER');
        expect(AuthService.cachedFullName, 'Le Hoang');
        expect(AuthService.cachedEmail, 'hoang@hango.edu.vn');
        expect(AuthService.cachedRoles, [
          'ROLE_COURSE_MANAGER',
          'CREATE_AND_MANAGE_EXAMS_CM',
        ]);
        expect(AuthService.cachedIsLoggedIn, isTrue);
      },
    );

    test('prioritizes ADMIN over other roles when present', () async {
      SharedPreferences.setMockInitialValues({
        'auth_token': 'jwt-abc',
        'user_roles': ['ROLE_ADMINISTRATOR', 'ROLE_COURSE_MANAGER'],
      });

      final session = await AuthService().getStoredSession();

      expect(session!.role, 'ADMIN');
    });

    test('treats a pure trainer role (no course-manager) as TRAINER', () async {
      SharedPreferences.setMockInitialValues({
        'auth_token': 'jwt-xyz',
        'user_roles': ['ROLE_TRAINER'],
      });

      final session = await AuthService().getStoredSession();

      expect(session!.role, 'TRAINER');
    });

    test(
      'falls back to LEARNER when roles list has no admin/manager/trainer role',
      () async {
        SharedPreferences.setMockInitialValues({
          'auth_token': 'jwt-learner',
          'user_roles': ['ROLE_LEARNER'],
        });

        final session = await AuthService().getStoredSession();

        expect(session!.role, 'LEARNER');
      },
    );
  });
}
