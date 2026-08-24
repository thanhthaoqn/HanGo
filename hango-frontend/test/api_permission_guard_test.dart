import 'package:flutter_test/flutter_test.dart';
import 'package:hango/data/repositories/exam_repository.dart';
import 'package:hango/utils/cart_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('API permission guards', () {
    test('trainer does not request learner exam-attempt history', () async {
      SharedPreferences.setMockInitialValues({
        'auth_token': 'trainer-token',
        'user_roles': ['ROLE_TRAINER', 'CREATE_EXAMS_TRAINER'],
      });

      final attempts = await ExamRepository().fetchMyExamAttempts();

      expect(attempts, isEmpty);
    });

    test('trainer session cannot use the learner cart API', () {
      final canUseRemoteCart = CartManager.canUseRemoteCartForSession(
        'trainer-token',
        ['ROLE_TRAINER', 'MANAGE_OWN_COURSES'],
      );

      expect(canUseRemoteCart, isFalse);
    });
  });
}
