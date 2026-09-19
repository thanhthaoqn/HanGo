import 'package:flutter_test/flutter_test.dart';
import 'package:hango/domain/model/course.dart';
import 'package:hango/domain/model/course_detail.dart';

void main() {
  group('Course Model Tests', () {
    test('Course.fromJson parses JSON correctly', () {
      final json = {
        'id': 42,
        'title': 'Test Course',
        'categoryName': 'Grammar',
        'creatorName': 'Trainer',
        'rating': 4.5,
        'difficultyName': 'Advanced',
        'learnersCount': 100,
        'thumbnailUrl': 'https://example.com/thumb.png',
      };

      final course = Course.fromJson(json);

      expect(course.id, 42);
      expect(course.title, 'Test Course');
      expect(course.category, 'Grammar');
      expect(course.creatorName, 'Trainer');
      expect(course.stars, 4.5);
      expect(course.difficulty, 'Advanced');
      expect(course.learnerCount, '100');
      expect(course.thumbnailUrl, 'https://example.com/thumb.png');
    });

    test('CourseDetail.fromJson parses trainerBio and trainerCertificates correctly', () {
      final json = {
        'id': 101,
        'title': 'English Grammar Mastery',
        'creatorName': 'hoàng Van I',
        'difficultyName': 'Intermediate',
        'rating': 4.8,
        'learnersCount': 250,
        'price': 350000.0,
        'isEnrolled': true,
        'trainerBio': 'Giảng viên chuyên ngữ với 7 năm kinh nghiệm.',
        'trainerCertificates': [
          'Bằng Cử nhân Sư phạm Tiếng Anh',
          'IELTS 8.5 Certificate',
          'TESOL Master Certificate',
        ],
        'sessions': [],
      };

      final detail = CourseDetail.fromJson(json);

      expect(detail.id, 101);
      expect(detail.creatorName, 'hoàng Van I');
      expect(detail.trainerBio, 'Giảng viên chuyên ngữ với 7 năm kinh nghiệm.');
      expect(detail.trainerCertificates, hasLength(3));
      expect(detail.trainerCertificates[0], 'Bằng Cử nhân Sư phạm Tiếng Anh');
      expect(detail.trainerCertificates[1], 'IELTS 8.5 Certificate');
      expect(detail.trainerCertificates[2], 'TESOL Master Certificate');
    });
  });
}

