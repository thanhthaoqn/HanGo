import '../../domain/model/course.dart';
import '../../domain/model/exam.dart';

class CourseService {
  // Mock Course database matching the mockup and SQL seeds
  final List<Course> _mockCourses = [
    // Featured Courses
    const Course(
      id: 1,
      title: 'Passage Arrangement',
      category: 'Reading Comprehension',
      creatorName: 'Nguyen Xuan Thinh',
      stars: 5.0,
      difficulty: 'Hard',
      learnerCount: '152k Learner',
      thumbnailUrl: 'https://images.unsplash.com/photo-1456513080510-7bf3a84b82f8?q=80&w=600',
      status: 'featured',
    ),
    const Course(
      id: 2,
      title: 'Information Gap Filling',
      category: 'Core Grammar',
      creatorName: 'Nguyen Xuan Thinh',
      stars: 5.0,
      difficulty: 'Medium',
      learnerCount: '152k Learner',
      thumbnailUrl: 'https://images.unsplash.com/photo-1546410531-bb4caa6b424d?q=80&w=600',
      status: 'featured',
    ),
    const Course(
      id: 3,
      title: 'Reading Comprehension',
      category: 'Reading Comprehension',
      creatorName: 'Nguyen Xuan Thinh',
      stars: 5.0,
      difficulty: 'Beginer',
      learnerCount: '152k Learner',
      thumbnailUrl: 'https://images.unsplash.com/photo-1456513080510-7bf3a84b82f8?q=80&w=600',
      status: 'featured',
    ),
    const Course(
      id: 4,
      title: 'Speed Grammar to 8+',
      category: 'Core Grammar',
      creatorName: 'Nguyen Xuan Thinh',
      stars: 5.0,
      difficulty: 'Beginer',
      learnerCount: '152k Learner',
      thumbnailUrl: 'https://images.unsplash.com/photo-1546410531-bb4caa6b424d?q=80&w=600',
      status: 'featured',
    ),
    
    // In Progress Courses
    const Course(
      id: 5,
      title: 'National High School Graduation Exam Prep - Basic Grammar',
      category: 'Core Grammar',
      creatorName: 'Nguyen Xuan Thinh',
      stars: 4.8,
      difficulty: 'Medium',
      learnerCount: '85k Learner',
      thumbnailUrl: 'https://images.unsplash.com/photo-1546410531-bb4caa6b424d?q=80&w=600',
      status: 'in_progress',
    ),
    const Course(
      id: 6,
      title: 'Advanced English Reading Techniques for National Exam',
      category: 'Reading Comprehension',
      creatorName: 'Luong Thi Thanh Thao',
      stars: 4.9,
      difficulty: 'Hard',
      learnerCount: '64k Learner',
      thumbnailUrl: 'https://images.unsplash.com/photo-1456513080510-7bf3a84b82f8?q=80&w=600',
      status: 'in_progress',
    ),

    // Completed Courses
    const Course(
      id: 7,
      title: 'Basic Tenses and Vocabulary Quick-Review',
      category: 'Topic-based Vocabulary',
      creatorName: 'Luong Thi Thanh Thao',
      stars: 4.7,
      difficulty: 'Easy',
      learnerCount: '120k Learner',
      thumbnailUrl: 'https://images.unsplash.com/photo-1457369804613-52c61a468e7d?q=80&w=600',
      status: 'completed',
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
