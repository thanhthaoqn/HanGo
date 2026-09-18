import 'package:flutter_test/flutter_test.dart';
import 'package:hango/routes/app_routes.dart';

void main() {
  group('AppRoutes Configuration Tests', () {
    test('AppRoutes constants are correctly configured', () {
      expect(AppRoutes.home, '/');
      expect(AppRoutes.courses, '/courses');
      expect(AppRoutes.exams, '/exams');
      expect(AppRoutes.pathway, '/pathway');
      expect(AppRoutes.cart, '/cart');
      expect(AppRoutes.courseDetail, '/courses/:id');
      expect(AppRoutes.login, '/login');
      expect(AppRoutes.admin, '/admin');
      expect(AppRoutes.trainer, '/trainer');
    });
  });
}
