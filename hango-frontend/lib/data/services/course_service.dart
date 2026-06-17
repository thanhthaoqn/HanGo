import '../../domain/model/course.dart';
import '../../domain/model/exam.dart';

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
      difficulty: 'Medium',
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
      difficulty: 'Hard',
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
      difficulty: 'Hard',
      learnerCount: '0 Learner',
      thumbnailUrl: 'https://images.unsplash.com/photo-1457369804613-52c61a468e7d?q=80&w=600',
      status: 'draft',
    ),
  ];

  // Mock Exam database matching mockup
  final List<Exam> _mockExams = [
    // Featured Exams
    const Exam(
      id: 1,
      title: 'Đề thi thử tốt nghiệp THPT năm 2025 - Sở GD&ĐT Hà Tĩnh',
      creatorName: 'Nguyen Xuan Thinh',
      sentencesCount: 40,
      durationMinutes: 50,
      stars: 5.0,
      learnerCount: '252k Learner',
      status: 'featured',
    ),
    const Exam(
      id: 2,
      title: 'Đề Thi Thử Tốt Nghiệp THPT - Chuyên Trần Phú, Hải Phòng',
      creatorName: 'Luong Thi Thanh Thao',
      sentencesCount: 40,
      durationMinutes: 50,
      stars: 5.0,
      learnerCount: '252k Learner',
      status: 'featured',
    ),
    const Exam(
      id: 3,
      title: 'Đề Thi Thử Tốt Nghiệp THPT - Bộ Giáo Dục Và Đào Tạo',
      creatorName: 'Nguyen Viet Hoang',
      sentencesCount: 40,
      durationMinutes: 50,
      stars: 5.0,
      learnerCount: '252k Learner',
      status: 'featured',
    ),
    const Exam(
      id: 4,
      title: 'Đề Thi Thử Tốt Nghiệp THPT - Sở GD&ĐT Đồng Nai',
      creatorName: 'Nguyen Xuan Thinh',
      sentencesCount: 40,
      durationMinutes: 50,
      stars: 5.0,
      learnerCount: '252k Learner',
      status: 'featured',
    ),

    // Completed Exams
    const Exam(
      id: 5,
      title: 'Đề thi thử tốt nghiệp THPT năm 2024 - Sở GD&ĐT Hà Nội',
      creatorName: 'Nguyen Xuan Thinh',
      sentencesCount: 50,
      durationMinutes: 60,
      stars: 4.9,
      learnerCount: '312k Learner',
      status: 'completed',
    ),
    const Exam(
      id: 6,
      title: 'Đề Thi Thử Tốt Nghiệp THPT - Chuyên Lê Hồng Phong, TP.HCM',
      creatorName: 'Luong Thi Thanh Thao',
      sentencesCount: 50,
      durationMinutes: 60,
      stars: 4.8,
      learnerCount: '198k Learner',
      status: 'completed',
    ),
  ];

  // Fetch courses by status
  Future<List<Course>> getCourses(String status) async {
    await Future.delayed(const Duration(milliseconds: 300)); // Simulate API delay
    return _mockCourses.where((c) => c.status == status).toList();
  }

  // Fetch exams by status
  Future<List<Exam>> getExams(String status) async {
    await Future.delayed(const Duration(milliseconds: 300)); // Simulate API delay
    return _mockExams.where((e) => e.status == status).toList();
  }
}
