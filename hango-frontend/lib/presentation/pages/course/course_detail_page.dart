import 'package:flutter/material.dart';
import '../../../data/repositories/course_repository.dart';
import '../../../domain/model/course_detail.dart';
import '../../../domain/model/course_review_summary.dart';
import '../../../data/services/auth_service.dart';
import '../../widgets/shared_header.dart';
import '../login_page.dart';
import 'review_tab.dart';
import 'lesson_detail_page.dart';

class CourseDetailPage extends StatefulWidget {
  final int courseId;

  const CourseDetailPage({Key? key, required this.courseId}) : super(key: key);

  @override
  State<CourseDetailPage> createState() => _CourseDetailPageState();
}

class _CourseDetailPageState extends State<CourseDetailPage>
    with SingleTickerProviderStateMixin {
  final CourseRepository _repository = CourseRepository();
  late Future<CourseDetail> _courseDetailFuture;
  late TabController _tabController;
  bool _isEnrolling = false;
  bool _isUnenrolling = false;

  @override
  void initState() {
    super.initState();
    _courseDetailFuture = _repository.fetchCourseDetail(widget.courseId);
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _enroll(CourseDetail course) async {
    final authService = AuthService();
    final isLoggedIn = await authService.isLoggedIn();
    if (!isLoggedIn) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
      return;
    }

    setState(() {
      _isEnrolling = true;
    });
    try {
      await _repository.enrollCourse(course.id);
      if (!mounted) return;

      // Show top right snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'You have successfully joined the course ${course.title}',
          ),
          backgroundColor: const Color(0xFF28B79B),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).size.height - 100,
            right: 20,
            left: MediaQuery.of(context).size.width > 600
                ? MediaQuery.of(context).size.width - 400
                : 20,
          ),
        ),
      );

      setState(() {
        _courseDetailFuture = _repository.fetchCourseDetail(widget.courseId);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to enroll: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).size.height - 100,
            right: 20,
            left: MediaQuery.of(context).size.width > 600
                ? MediaQuery.of(context).size.width - 400
                : 20,
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isEnrolling = false;
        });
      }
    }
  }

  void _showUnenrollConfirmDialog(CourseDetail course) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Cancel Enrollment'),
          content: Text(
            'Are you sure you want to cancel your enrollment for ${course.title}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('No', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _unenroll(course);
              },
              child: const Text(
                'Yes, Cancel',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  void _unenroll(CourseDetail course) async {
    setState(() {
      _isUnenrolling = true;
    });
    try {
      await _repository.unenrollCourse(course.id);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'You have successfully canceled your enrollment.',
          ),
          backgroundColor: const Color(0xFF28B79B),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).size.height - 100,
            right: 20,
            left: MediaQuery.of(context).size.width > 600
                ? MediaQuery.of(context).size.width - 400
                : 20,
          ),
        ),
      );

      setState(() {
        _courseDetailFuture = _repository.fetchCourseDetail(widget.courseId);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to cancel enrollment: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).size.height - 100,
            right: 20,
            left: MediaQuery.of(context).size.width > 600
                ? MediaQuery.of(context).size.width - 400
                : 20,
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUnenrolling = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: SharedHeader(isDesktop: isDesktop, activeTab: 'Courses'),
      body: FutureBuilder<CourseDetail>(
        future: _courseDetailFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF28B79B)),
            );
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData) {
            return const Center(child: Text('Course not found.'));
          }

          final course = snapshot.data!;
          return SingleChildScrollView(
            child: Column(
              children: [
                Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Back Button
                        InkWell(
                          onTap: () {
                            Navigator.pop(context);
                          },
                          hoverColor: Colors.transparent,
                          splashColor: Colors.transparent,
                          highlightColor: Colors.transparent,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.arrow_back_ios,
                                  size: 14,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Back to Courses',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        _buildBanner(course, isDesktop),
                        const SizedBox(height: 32),

                        if (isDesktop)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 2,
                                child: _buildMainContent(course),
                              ),
                              const SizedBox(width: 32),
                              Expanded(
                                flex: 1,
                                child: _buildEnrollCard(course),
                              ),
                            ],
                          )
                        else
                          Column(
                            children: [
                              _buildEnrollCard(course),
                              const SizedBox(height: 32),
                              _buildMainContent(course),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
                _buildFooter(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBanner(CourseDetail course, bool isDesktop) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 48.0 : 24.0,
        vertical: 48.0,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF209D84), Color(0xFF135D4E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Courses > ${course.title}',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Text(
            course.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 24,
            runSpacing: 12,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.person, color: Colors.white, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'Trainer: ${course.creatorName}',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.people, color: Colors.white, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    '${course.learnersCount} Learners',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.bar_chart, color: Colors.white, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'Level: ${course.difficultyName}',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    '${course.rating}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(CourseDetail course) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF28B79B),
          unselectedLabelColor: Colors.grey.shade600,
          indicatorColor: const Color(0xFF28B79B),
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.normal,
            fontSize: 15,
          ),
          indicatorWeight: 3,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Introduce'),
            Tab(text: 'Syllabus'),
            Tab(text: 'Review'),
          ],
        ),
        const SizedBox(height: 24),
        SizedBox(
          height:
              1000, // Or use constraints/Sliver to let it size automatically
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildIntroduceTab(course),
              _buildSyllabusTab(course),
              FutureBuilder<CourseReviewSummary>(
                future: _repository.fetchCourseReviews(widget.courseId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF28B79B),
                      ),
                    );
                  } else if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  } else if (!snapshot.hasData) {
                    return const Center(child: Text('No reviews available.'));
                  }
                  return ReviewTab(summary: snapshot.data!);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIntroduceTab(CourseDetail course) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (course.description != null && course.description!.isNotEmpty)
            Text(
              course.description!,
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF4B5563),
                height: 1.6,
              ),
            ),
          const SizedBox(height: 32),
          const Text(
            'After completing this course, you will be able to:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 16),
          if (course.objectives != null && course.objectives!.isNotEmpty)
            ...course.objectives!.split('\n').map((obj) {
              final trimmed = obj.trim();
              if (trimmed.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Color(0xFF28B79B),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        trimmed,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Color(0xFF4B5563),
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList()
          else
            const Text(
              'No objectives defined.',
              style: TextStyle(color: Colors.grey),
            ),
        ],
      ),
    );
  }

  IconData _getLessonIcon(String? itemType) {
    if (itemType == null) return Icons.menu_book_outlined;
    switch (itemType.toLowerCase()) {
      case 'learning':
        return Icons.menu_book_outlined;
      case 'practice':
        return Icons.assignment_outlined;
      case 'quiz':
        return Icons.quiz_outlined;
      default:
        return Icons.menu_book_outlined;
    }
  }

  Widget _buildSyllabusTab(CourseDetail course) {
    if (course.sessions.isEmpty) {
      return const Text(
        'No syllabus available.',
        style: TextStyle(color: Colors.grey),
      );
    }

    int totalSessions = course.sessions.length;
    int totalLessons = course.sessions.fold(
      0,
      (sum, session) => sum + session.lessons.length,
    );

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Course content',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
              Text(
                '$totalSessions Sessions • $totalLessons Lessons',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: course.sessions.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final session = course.sessions[index];
                return ExpansionTile(
                  title: Row(
                    children: [
                      Text(
                        'Session ${index + 1}',
                        style: const TextStyle(
                          color: Color(0xFF28B79B),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        session.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                    ],
                  ),
                  trailing: Text(
                    '${session.lessons.length} lessons',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                  children: session.lessons.map((lesson) {
                    final itemType = lesson.itemType?.toLowerCase();
                    final isExercise =
                        itemType == 'quiz' || itemType == 'practice';
                    return InkWell(
                      onTap: course.isEnrolled
                          ? () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => LessonDetailPage(
                                    courseId: course.id,
                                    lessonId: lesson.id,
                                  ),
                                ),
                              );
                            }
                          : () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Please enroll in the course to view this lesson.',
                                  ),
                                ),
                              );
                            },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        color: Colors.transparent,
                        child: Row(
                          children: [
                            Icon(
                              _getLessonIcon(lesson.itemType),
                              size: 18,
                              color: course.isEnrolled
                                  ? const Color(0xFF28B79B)
                                  : Colors.grey,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                lesson.title,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: course.isEnrolled
                                      ? const Color(0xFF4B5563)
                                      : Colors.grey.shade500,
                                ),
                              ),
                            ),
                            if (isExercise)
                              TextButton(
                                onPressed: course.isEnrolled
                                    ? () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                LessonDetailPage(
                                                  courseId: course.id,
                                                  lessonId: lesson.id,
                                                  startQuizImmediately: true,
                                                ),
                                          ),
                                        );
                                      }
                                    : null,
                                child: Text(
                                  'Try Now',
                                  style: TextStyle(
                                    color: course.isEnrolled
                                        ? const Color(0xFF28B79B)
                                        : Colors.grey,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnrollCard(CourseDetail course) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF28B79B),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Free',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Course includes:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 16),
          _buildIncludeItem(
            Icons.library_books,
            '${course.sessions.length} Detailed Sessions',
          ),
          _buildIncludeItem(
            Icons.article_outlined,
            '${course.sessions.fold(0, (sum, s) => sum + s.lessons.length)} Detailed Lessons',
          ),
          _buildIncludeItem(Icons.quiz_outlined, 'Practice Quizzes'),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: course.isEnrolled
                  ? () {
                      if (course.sessions.isNotEmpty &&
                          course.sessions.first.lessons.isNotEmpty) {
                        final firstLessonId =
                            course.sessions.first.lessons.first.id;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => LessonDetailPage(
                              courseId: course.id,
                              lessonId: firstLessonId,
                            ),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('No lessons available yet.'),
                          ),
                        );
                      }
                    }
                  : () => _enroll(course),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF28B79B),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: _isEnrolling
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      course.isEnrolled ? 'Study Now' : 'Enroll now',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          if (course.isEnrolled) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _isUnenrolling
                    ? null
                    : () => _showUnenrollConfirmDialog(course),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: Colors.redAccent),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isUnenrolling
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.redAccent,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Cancel Enrollment',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIncludeItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF28B79B)),
          const SizedBox(width: 12),
          Text(
            text,
            style: const TextStyle(fontSize: 14, color: Color(0xFF4B5563)),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      color: const Color(0xFFF6FBF9),
      padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 40.0),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.school, color: Color(0xFF38B29E)),
                        SizedBox(width: 8),
                        Text(
                          'HanGo',
                          style: TextStyle(
                            color: Color(0xFF38B29E),
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'The leading digital coaching platform for high school students aiming for distinction in the THPTQG English National Exam.',
                      style: TextStyle(color: Colors.black54, height: 1.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 40),
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'LEARNING',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 16),
                    Text('Mock Tests', style: TextStyle(color: Colors.black54)),
                  ],
                ),
              ),
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'SUPPORT',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Learner FAQ',
                      style: TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
          const Divider(color: Colors.black12),
          const SizedBox(height: 20),
          const Text(
            '© 2024 HanGo. Built for academic excellence.',
            style: TextStyle(color: Colors.black54, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
