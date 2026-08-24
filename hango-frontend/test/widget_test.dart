import 'package:flutter_test/flutter_test.dart';
import 'package:hango/domain/model/course.dart';

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

    test('Course.fromJson ignores known unavailable remote thumbnails', () {
      final course = Course.fromJson({
        'id': 43,
        'title': 'Course with unavailable thumbnail',
        'thumbnailUrl':
            'https://images.unsplash.com/photo-1455390582262-044cdead27d8?auto=format&fit=crop&w=600&q=80',
      });

      expect(course.thumbnailUrl, isEmpty);
    });
  });
}
