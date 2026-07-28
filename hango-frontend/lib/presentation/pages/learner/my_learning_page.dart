import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/shared_header.dart';
import '../../widgets/shared_footer.dart';
import '../../../data/repositories/course_repository.dart';
import '../../../data/repositories/exam_repository.dart';
import '../../../domain/model/course.dart';
import 'learning_pathway_page.dart';
import '../course/course_detail_page.dart';
import '../course/lesson_detail_page.dart';
import '../course/course_completion_page.dart';
import '../../../domain/model/course_detail.dart';
import '../../../utils/language_manager.dart';

class MyLearningPage extends StatefulWidget {
  const MyLearningPage({super.key});

  @override
  State<MyLearningPage> createState() => _MyLearningPageState();
}

class _MyLearningPageState extends State<MyLearningPage> {
  final _courseRepository = CourseRepository();
  final _examRepository = ExamRepository();

  List<Course> _inProgressCourses = [];
  List<Course> _completedCourses = [];
  List<Map<String, dynamic>> _recentAttempts = [];
  Map<int, int> _lastLessonIds = {};
  bool _isLoading = true;
  String _userName = 'Learner';
  bool _isVietnamese = true;

  // Exam history filters & pagination
  String _examSearchQuery = '';
  String _examStatusFilter = 'ALL'; // 'ALL', 'PASSED', 'FAILED'
  String _examSortBy =
      'LATEST'; // 'LATEST', 'OLDEST', 'HIGHEST_SCORE', 'LOWEST_SCORE'
  int _examCurrentPage = 1;
  final int _examPageSize = 5;

  double _parseScore(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString()) ?? 0.0;
  }

  List<Map<String, dynamic>> get _filteredExamAttempts {
    var list = List<Map<String, dynamic>>.from(_recentAttempts);

    // 1. Filter by Search Query
    if (_examSearchQuery.trim().isNotEmpty) {
      final query = _examSearchQuery.trim().toLowerCase();
      list = list.where((a) {
        final title =
            (a['examTitle'] ??
                    (_isVietnamese
                        ? 'Đề thi thử tốt nghiệp THPT'
                        : 'Mock Exam'))
                .toString()
                .toLowerCase();
        return title.contains(query);
      }).toList();
    }

    // 2. Filter by Status (Passed / Failed)
    if (_examStatusFilter == 'PASSED') {
      list = list.where((a) => _parseScore(a['score']) >= 6.0).toList();
    } else if (_examStatusFilter == 'FAILED') {
      list = list.where((a) => _parseScore(a['score']) < 6.0).toList();
    }

    // 3. Sort By
    list.sort((a, b) {
      if (_examSortBy == 'HIGHEST_SCORE') {
        return _parseScore(b['score']).compareTo(_parseScore(a['score']));
      } else if (_examSortBy == 'LOWEST_SCORE') {
        return _parseScore(a['score']).compareTo(_parseScore(b['score']));
      } else if (_examSortBy == 'OLDEST') {
        final dateA = (a['date'] ?? '').toString();
        final dateB = (b['date'] ?? '').toString();
        return dateA.compareTo(dateB);
      } else {
        // LATEST (Default)
        final dateA = (a['date'] ?? '').toString();
        final dateB = (b['date'] ?? '').toString();
        return dateB.compareTo(dateA);
      }
    });

    return list;
  }

  List<Map<String, dynamic>> get _paginatedExamAttempts {
    final filtered = _filteredExamAttempts;
    if (filtered.isEmpty) return [];
    final startIndex = (_examCurrentPage - 1) * _examPageSize;
    if (startIndex >= filtered.length) {
      return filtered.take(_examPageSize).toList();
    }
    return filtered.skip(startIndex).take(_examPageSize).toList();
  }

  int get _totalExamPages {
    final total = _filteredExamAttempts.length;
    if (total == 0) return 1;
    return (total / _examPageSize).ceil();
  }

  @override
  void initState() {
    super.initState();
    _isVietnamese = LanguageManager.isVi;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      _userName = prefs.getString('user_fullname') ?? 'Learner';

      // Load enrolled courses
      final inProgress = await _courseRepository.fetchCourses(
        filterType: 'IN_PROGRESS',
      );
      final completed = await _courseRepository.fetchCourses(
        filterType: 'COMPLETED',
      );

      // Load completed exams for history
      final attempts = await _examRepository.fetchMyExamAttempts();

      // Load last studied lesson IDs for in-progress courses
      final Map<int, int> lastLessonIds = {};
      for (final course in inProgress) {
        final lessonId = prefs.getInt('last_lesson_id_for_${course.id}');
        if (lessonId != null) {
          lastLessonIds[course.id] = lessonId;
        }
      }

      setState(() {
        _inProgressCourses = inProgress;
        _completedCourses = completed;
        _recentAttempts = attempts;
        _lastLessonIds = lastLessonIds;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 1024;

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: SharedHeader(isDesktop: isDesktop, activeTab: 'Learning'),
          body: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF28B79B)),
                )
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      // Header Section
                      _buildHeaderSection(isDesktop),

                      // Main Content Area
                      Center(
                        child: Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(maxWidth: 1200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 32,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 1. Top Teasers: Resume Learning & AI Pathway side-by-side on Desktop
                              if (isDesktop) ...[
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (_inProgressCourses.isNotEmpty) ...[
                                      Expanded(
                                        flex: 7,
                                        child: _buildResumeLearningCard(),
                                      ),
                                      const SizedBox(width: 24),
                                    ],
                                    Expanded(
                                      flex: _inProgressCourses.isNotEmpty ? 4 : 11,
                                      child: _buildAiPathwayCard(),
                                    ),
                                  ],
                                ),
                              ] else ...[
                                if (_inProgressCourses.isNotEmpty) ...[
                                  _buildResumeLearningCard(),
                                  const SizedBox(height: 24),
                                ],
                                _buildAiPathwayCard(),
                              ],
                              const SizedBox(height: 40),

                              // 2. Enrolled Courses Section (Full Width 100%)
                              Text(
                                _isVietnamese ? 'Khóa học của tôi' : 'My Courses',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                  fontFamily: 'Outfit',
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildCoursesTabs(),
                              const SizedBox(height: 40),

                              // 3. Mock Exam History Section (Full Width 100%)
                              Text(
                                _isVietnamese
                                    ? 'Lịch sử luyện đề THPT QG'
                                    : 'Mock Exam History',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                  fontFamily: 'Outfit',
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildExamHistoryList(),
                            ],
                          ),
                        ),
                      ),

                      // Footer
                      SharedFooter(isDesktop: isDesktop),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildHeaderSection(bool isDesktop) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1B5C58), Color(0xFF28B79B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: 24,
        vertical: isDesktop ? 48 : 32,
      ),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isVietnamese ? 'Hành trình học tập' : 'My Learning Dashboard',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  fontFamily: 'Outfit',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isVietnamese
                    ? 'Chào mừng trở lại, $_userName!'
                    : 'Welcome back, $_userName!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isDesktop ? 32 : 24,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Outfit',
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _isVietnamese
                    ? 'Tiếp tục hành trình chinh phục kỳ thi THPT Quốc Gia môn Tiếng Anh.'
                    : 'Track your courses, results, and recommendations in one place.',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  fontFamily: 'Outfit',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResumeLearningCard() {
    final Course course = _inProgressCourses.first;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.play_circle_fill_rounded,
                  color: Color(0xFF28B79B),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _isVietnamese ? 'HỌC TIẾP' : 'RESUME LEARNING',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B5C58),
                  letterSpacing: 1.1,
                  fontFamily: 'Outfit',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            course.title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            course.category,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF64748B),
              height: 1.4,
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: course.progressPercentage / 100.0,
                    backgroundColor: const Color(0xFFF1F5F9),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF28B79B),
                    ),
                    minHeight: 8,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${(course.progressPercentage).round()}%',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF64748B),
                  fontFamily: 'Outfit',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () async {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (ctx) => const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF28B79B),
                    ),
                  ),
                ),
              );

              try {
                final lastLessonId = _lastLessonIds[course.id];
                if (lastLessonId != null) {
                  if (!mounted) return;
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LessonDetailPage(
                        courseId: course.id,
                        lessonId: lastLessonId,
                      ),
                    ),
                  );
                  return;
                }

                final detail = await _courseRepository.fetchCourseDetail(
                  course.id,
                );
                if (!mounted) return;
                Navigator.pop(context);

                CourseLesson? targetLesson;
                for (final session in detail.sessions) {
                  for (final lesson in session.lessons) {
                    if (!lesson.isCompleted) {
                      targetLesson = lesson;
                      break;
                    }
                  }
                  if (targetLesson != null) break;
                }

                if (targetLesson == null && detail.sessions.isNotEmpty) {
                  final firstSession = detail.sessions.first;
                  if (firstSession.lessons.isNotEmpty) {
                    targetLesson = firstSession.lessons.first;
                  }
                }

                if (targetLesson != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LessonDetailPage(
                        courseId: course.id,
                        lessonId: targetLesson!.id,
                      ),
                    ),
                  );
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          CourseDetailPage(courseId: course.id),
                    ),
                  );
                }
              } catch (e) {
                if (!mounted) return;
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CourseDetailPage(courseId: course.id),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF28B79B),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _isVietnamese ? 'Tiếp tục bài học' : 'Continue learning',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    fontFamily: 'Outfit',
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_rounded, size: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoursesTabs() {
    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: const Color(0xFF28B79B),
            unselectedLabelColor: const Color(0xFF64748B),
            indicatorColor: const Color(0xFF28B79B),
            labelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontFamily: 'Outfit',
            ),
            tabs: [
              Tab(
                text: _isVietnamese
                    ? 'Đang học (${_inProgressCourses.length})'
                    : 'In Progress (${_inProgressCourses.length})',
              ),
              Tab(
                text: _isVietnamese
                    ? 'Đã hoàn thành (${_completedCourses.length})'
                    : 'Completed (${_completedCourses.length})',
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 335,
            child: TabBarView(
              children: [
                _buildCoursesListView(_inProgressCourses, false),
                _buildCoursesListView(_completedCourses, true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoursesListView(List<Course> courses, bool isCompleted) {
    if (courses.isEmpty) {
      return Center(
        child: Text(
          _isVietnamese
              ? (isCompleted
                    ? 'Chưa có khóa học nào hoàn thành.'
                    : 'Bạn chưa tham gia khóa học nào.')
              : (isCompleted
                    ? 'No completed courses yet.'
                    : 'You have no active courses.'),
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontFamily: 'Outfit',
          ),
        ),
      );
    }

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: courses.length,
      itemBuilder: (context, index) {
        final Course course = courses[index];
        return Container(
          width: 320,
          margin: const EdgeInsets.only(right: 16, bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x04000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: InkWell(
            onTap: () {
              if (isCompleted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        CourseCompletionPage(courseId: course.id),
                  ),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CourseDetailPage(courseId: course.id),
                  ),
                );
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCourseImage(course),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        course.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                          fontFamily: 'Outfit',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'By: ${course.creatorName}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                          fontFamily: 'Outfit',
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: isCompleted
                                    ? 1.0
                                    : (course.progressPercentage / 100.0),
                                backgroundColor: const Color(0xFFF1F5F9),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Color(0xFF28B79B),
                                ),
                                minHeight: 6,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isCompleted
                                ? '100%'
                                : '${(course.progressPercentage).round()}%',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF64748B),
                              fontFamily: 'Outfit',
                            ),
                          ),
                        ],
                      ),
                      if (isCompleted) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      CourseCompletionPage(courseId: course.id),
                                ),
                              );
                            },
                            icon: const Icon(
                              Icons.workspace_premium_rounded,
                              size: 16,
                            ),
                            label: Text(
                              _isVietnamese
                                  ? 'Xem Chứng Chỉ'
                                  : 'View Certificate',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Outfit',
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF20B486),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCourseImage(Course course) {
    if (course.thumbnailUrl.isNotEmpty) {
      return SizedBox(
        height: 140,
        width: double.infinity,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          child: Image.network(
            course.thumbnailUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                _buildPlaceholderImage(course),
          ),
        ),
      );
    }
    return _buildPlaceholderImage(course);
  }

  Widget _buildPlaceholderImage(Course course) {
    return Container(
      height: 140,
      width: double.infinity,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        gradient: LinearGradient(
          colors: [Color(0xFF32C6A9), Color(0xFF279E87)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              course.category,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                height: 1.3,
                fontFamily: 'Outfit',
              ),
            ),
          ),
          Positioned(
            bottom: -15,
            right: -10,
            child: Icon(
              Icons.school,
              size: 80,
              color: Colors.white.withValues(alpha: 0.2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExamHistoryList() {
    if (_recentAttempts.isEmpty) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.history_rounded,
                size: 40,
                color: Color(0xFF94A3B8),
              ),
              const SizedBox(height: 12),
              Text(
                _isVietnamese
                    ? 'Bạn chưa thực hiện bài thi thử THPT QG nào.'
                    : 'You haven\'t completed any mock exams yet.',
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontFamily: 'Outfit',
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Filter & Search Bar
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // Search Box
            SizedBox(
              width: 260,
              height: 42,
              child: TextField(
                onChanged: (val) {
                  setState(() {
                    _examSearchQuery = val;
                    _examCurrentPage = 1;
                  });
                },
                decoration: InputDecoration(
                  hintText: _isVietnamese
                      ? 'Tìm kiếm đề thi...'
                      : 'Search mock exams...',
                  hintStyle: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 13,
                    fontFamily: 'Outfit',
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    size: 18,
                    color: Color(0xFF64748B),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 0,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: Color(0xFF28B79B),
                      width: 1.5,
                    ),
                  ),
                ),
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF0F172A),
                  fontFamily: 'Outfit',
                ),
              ),
            ),
            // Status Filter Dropdown
            Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _examStatusFilter,
                  icon: const Icon(
                    Icons.filter_list_rounded,
                    size: 18,
                    color: Color(0xFF64748B),
                  ),
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Outfit',
                  ),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _examStatusFilter = val;
                        _examCurrentPage = 1;
                      });
                    }
                  },
                  items: [
                    DropdownMenuItem(
                      value: 'ALL',
                      child: Text(
                        _isVietnamese ? 'Tất cả kết quả' : 'All Results',
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'PASSED',
                      child: Text(
                        _isVietnamese ? 'Đạt (>= 6.0)' : 'Passed (>= 6.0)',
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'FAILED',
                      child: Text(
                        _isVietnamese ? 'Chưa đạt (< 6.0)' : 'Below 6.0',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Sort By Dropdown
            Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _examSortBy,
                  icon: const Icon(
                    Icons.sort_rounded,
                    size: 18,
                    color: Color(0xFF64748B),
                  ),
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Outfit',
                  ),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _examSortBy = val;
                        _examCurrentPage = 1;
                      });
                    }
                  },
                  items: [
                    DropdownMenuItem(
                      value: 'LATEST',
                      child: Text(_isVietnamese ? 'Mới nhất' : 'Latest Date'),
                    ),
                    DropdownMenuItem(
                      value: 'OLDEST',
                      child: Text(_isVietnamese ? 'Cũ nhất' : 'Oldest Date'),
                    ),
                    DropdownMenuItem(
                      value: 'HIGHEST_SCORE',
                      child: Text(
                        _isVietnamese ? 'Điểm cao nhất' : 'Highest Score',
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'LOWEST_SCORE',
                      child: Text(
                        _isVietnamese ? 'Điểm thấp nhất' : 'Lowest Score',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 2. Paginated List / Empty Filter State
        if (_filteredExamAttempts.isEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.search_off_rounded,
                    size: 36,
                    color: Color(0xFF94A3B8),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _isVietnamese
                        ? 'Không tìm thấy bài thi nào phù hợp với bộ lọc.'
                        : 'No mock exams found matching your filters.',
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontFamily: 'Outfit',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ] else ...[
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _paginatedExamAttempts.length,
            itemBuilder: (context, index) {
              final attempt = _paginatedExamAttempts[index];
              final examTitle =
                  attempt['examTitle'] ??
                  (_isVietnamese ? 'Đề thi thử tốt nghiệp THPT' : 'Mock Exam');
              final scoreVal = _parseScore(attempt['score']);
              final scoreText = scoreVal.toStringAsFixed(1);
              final isPassed = scoreVal >= 6.0;
              final date = attempt['date'] ?? '';
              final attemptNumber = attempt['attemptNumber'] ?? 1;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x04000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isPassed
                          ? const Color(0xFFE6F7F4)
                          : const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isPassed
                          ? Icons.assignment_turned_in_rounded
                          : Icons.assignment_late_rounded,
                      color: isPassed
                          ? const Color(0xFF28B79B)
                          : const Color(0xFFEF4444),
                      size: 24,
                    ),
                  ),
                  title: Text(
                    examTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                      fontFamily: 'Outfit',
                    ),
                  ),
                  subtitle: Text(
                    _isVietnamese
                        ? 'Lần thi: $attemptNumber · Ngày nộp: $date'
                        : 'Attempt: $attemptNumber · Submitted: $date',
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontFamily: 'Outfit',
                      fontSize: 13,
                    ),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isPassed
                          ? const Color(0xFFE6F4EA)
                          : const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isPassed
                            ? const Color(0xFF34D399).withValues(alpha: 0.3)
                            : const Color(0xFFF87171).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      '$scoreText / 10',
                      style: TextStyle(
                        color: isPassed
                            ? const Color(0xFF137333)
                            : const Color(0xFFB91C1C),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        fontFamily: 'Outfit',
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          // 3. Pagination Controls
          if (_totalExamPages > 1) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _isVietnamese
                      ? 'Hiển thị ${(_examCurrentPage - 1) * _examPageSize + 1} - ${((_examCurrentPage) * _examPageSize).clamp(1, _filteredExamAttempts.length)} của ${_filteredExamAttempts.length} lượt thi'
                      : 'Showing ${(_examCurrentPage - 1) * _examPageSize + 1} - ${((_examCurrentPage) * _examPageSize).clamp(1, _filteredExamAttempts.length)} of ${_filteredExamAttempts.length} attempts',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                    fontFamily: 'Outfit',
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: _examCurrentPage > 1
                          ? () {
                              setState(() {
                                _examCurrentPage--;
                              });
                            }
                          : null,
                      icon: const Icon(Icons.chevron_left_rounded),
                      color: const Color(0xFF28B79B),
                      disabledColor: const Color(0xFFCBD5E1),
                      tooltip: _isVietnamese ? 'Trang trước' : 'Previous Page',
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$_examCurrentPage / $_totalExamPages',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Color(0xFF0F172A),
                          fontFamily: 'Outfit',
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _examCurrentPage < _totalExamPages
                          ? () {
                              setState(() {
                                _examCurrentPage++;
                              });
                            }
                          : null,
                      icon: const Icon(Icons.chevron_right_rounded),
                      color: const Color(0xFF28B79B),
                      disabledColor: const Color(0xFFCBD5E1),
                      tooltip: _isVietnamese ? 'Trang sau' : 'Next Page',
                    ),
                  ],
                ),
              ],
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildAiPathwayCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF28B79B).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome, color: Color(0xFF28B79B), size: 14),
                SizedBox(width: 6),
                Text(
                  'AI POWERED',
                  style: TextStyle(
                    color: Color(0xFF28B79B),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _isVietnamese ? 'Lộ trình học đề xuất' : 'AI Learning Pathway',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _isVietnamese
                ? 'Lộ trình học thông minh dựa trên kết quả phân tích điểm yếu luyện đề.'
                : 'Personalized study node tree optimized based on your weak skill types.',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.5,
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LearningPathwayPage(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF28B79B),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              child: Text(
                _isVietnamese ? 'Xem lộ trình đề xuất' : 'View AI Pathway',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  fontFamily: 'Outfit',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
