import '../../domain/model/course.dart';

class CourseService {
  // Mock Course database matching the mockup and SQL seeds from database.env
  final List<Course> _mockCourses = [
    // Featured Courses
    const Course(
      id: 1,
      title: 'National High School Graduation Exam Prep - Basic Grammar',
      category: 'Core Grammar',
      creatorName: 'Nguyen Xuan Thinh',
      stars: 4.8, // From enrollments / mock
      difficulty: 'Basic',
      learnerCount: '85k Learner',
      thumbnailUrl: 'https://images.unsplash.com/photo-1546410531-bb4caa6b424d?q=80&w=600',
      status: 'featured',
    ),
    const Course(
      id: 2,
      title: 'Advanced English Reading Comprehension Techniques for the National Exam',
      category: 'Reading Comprehension',
      creatorName: 'Nguyen Xuan Thinh',
      stars: 4.9,
      difficulty: 'Advanced',
      learnerCount: '64k Learner',
      thumbnailUrl: 'https://images.unsplash.com/photo-1456513080510-7bf3a84b82f8?q=80&w=600',
      status: 'featured',
    ),
    // In Progress Courses
    const Course(
      id: 3,
      title: 'Conquering Advanced Vocabulary for the National High School Graduation Exam',
      category: 'Topic-based Vocabulary',
      creatorName: 'Nguyen Xuan Thinh',
      stars: 0.0,
      difficulty: 'Advanced',
      learnerCount: '0 Learner',
      thumbnailUrl: 'https://images.unsplash.com/photo-1457369804613-52c61a468e7d?q=80&w=600',
      status: 'draft',
    ),
  ];
  // Fetch courses by status
  Future<List<Course>> getCourses(String status) async {
    await Future.delayed(const Duration(milliseconds: 300)); // Simulate API delay
    return _mockCourses.where((c) => c.status == status).toList();
  }
}
