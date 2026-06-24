import 'package:flutter/material.dart';
import '../../../data/repositories/course_repository.dart';
import '../../../domain/model/course_detail.dart';
import '../../../domain/model/course_review_summary.dart';
import '../../../data/services/auth_service.dart';
import '../../widgets/shared_header.dart';
import '../../widgets/shared_footer.dart';
import '../learner/learner_home_page.dart';
import '../login_page.dart';
import 'review_tab.dart';
import 'lesson_detail_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CourseDetailPage extends StatefulWidget {
  final int courseId;

  const CourseDetailPage({Key? key, required this.courseId}) : super(key: key);

  @override
  State<CourseDetailPage> createState() => _CourseDetailPageState();
}

class _CourseDetailPageState extends State<CourseDetailPage>
    with SingleTickerProviderStateMixin {
  final CourseRepository _repository = CourseRepository();
  CourseDetail? _courseDetail;
  bool _isLoading = true;
  String? _errorMessage;
  late TabController _tabController;
  late ScrollController _scrollController;
  late Future<CourseReviewSummary> _reviewsFuture;
  bool _isEnrolling = false;
  bool _isUnenrolling = false;

  final GlobalKey _introduceKey = GlobalKey();
  final GlobalKey _syllabusKey = GlobalKey();
  final GlobalKey _reviewKey = GlobalKey();
  bool _isScrollingToTab = false;

  int _currentUserId = 1;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserId();
    _loadCourseDetail();
    _tabController = TabController(length: 3, vsync: this);
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _reviewsFuture = _repository.fetchCourseReviews(widget.courseId);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _currentUserId = prefs.getInt('user_id') ?? 1;
      });
    }
  }

  void _onScroll() {
    if (_isScrollingToTab) return;
    if (!mounted) return;

    final introduceContext = _introduceKey.currentContext;
    final syllabusContext = _syllabusKey.currentContext;
    final reviewContext = _reviewKey.currentContext;

    if (introduceContext == null || syllabusContext == null || reviewContext == null) return;

    final introduceBox = introduceContext.findRenderObject() as RenderBox?;
    final syllabusBox = syllabusContext.findRenderObject() as RenderBox?;
    final reviewBox = reviewContext.findRenderObject() as RenderBox?;

    if (introduceBox == null || syllabusBox == null || reviewBox == null) return;

    final introduceY = introduceBox.localToGlobal(Offset.zero).dy;
    final syllabusY = syllabusBox.localToGlobal(Offset.zero).dy;
    final reviewY = reviewBox.localToGlobal(Offset.zero).dy;

    const double threshold = 200.0;

    int targetIndex = 0;
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 50) {
      targetIndex = 2;
    } else if (reviewY <= threshold) {
      targetIndex = 2;
    } else if (syllabusY <= threshold) {
      targetIndex = 1;
    } else {
      targetIndex = 0;
    }

    if (_tabController.index != targetIndex) {
      setState(() {
        _tabController.index = targetIndex;
      });
    }
  }

  void _scrollToSection(GlobalKey key, int tabIndex) async {
    final context = key.currentContext;
    if (context != null) {
      setState(() {
        _isScrollingToTab = true;
        _tabController.index = tabIndex;
      });

      await Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 300),
        alignment: 0.0,
        curve: Curves.easeInOut,
      );

      await Future.delayed(const Duration(milliseconds: 100));
      setState(() {
        _isScrollingToTab = false;
      });
    }
  }

  Future<void> _loadCourseDetail() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      final course = await _repository.fetchCourseDetail(widget.courseId);
      setState(() {
        _courseDetail = course;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _showNotification(String message, {bool isError = false}) {
    if (!mounted) return;
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isMobile = screenWidth < 600;
        return Positioned(
          top: 24,
          right: isMobile ? 16 : 24,
          left: isMobile ? 16 : null,
          child: Material(
            color: Colors.transparent,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: isMobile ? screenWidth - 32 : 400,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: isError ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isError ? const Color(0xFFFCA5A5) : const Color(0xFF34D399),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
                    color: isError ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      message,
                      style: TextStyle(
                        color: isError ? const Color(0xFF991B1B) : const Color(0xFF065F46),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 3), () {
      if (entry.mounted) {
        entry.remove();
      }
    });
  }

  Future<void> _deleteReview() async {
    try {
      await _repository.deleteCourseReview(widget.courseId);
      _showNotification('Review deleted successfully!');
      setState(() {
        _reviewsFuture = _repository.fetchCourseReviews(widget.courseId);
        _loadCourseDetail();
      });
    } catch (e) {
      _showNotification('Failed to delete review: $e', isError: true);
    }
  }

  void _showWriteReviewDialog({double? rating, String? content}) {
    double selectedRating = rating ?? 5.0;
    final contentController = TextEditingController(text: content);
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final ratingLabels = ['Terrible', 'Bad', 'Average', 'Good', 'Excellent'];
            final label = ratingLabels[selectedRating.round() - 1];

            final ratingColors = [
              { 'bg': const Color(0xFFFEF2F2), 'text': const Color(0xFFEF4444) }, // Terrible
              { 'bg': const Color(0xFFFFF7ED), 'text': const Color(0xFFF97316) }, // Bad
              { 'bg': const Color(0xFFFEF3C7), 'text': const Color(0xFFD97706) }, // Average
              { 'bg': const Color(0xFFECFDF5), 'text': const Color(0xFF10B981) }, // Good
              { 'bg': const Color(0xFFE6F4EA), 'text': const Color(0xFF0F9D58) }, // Excellent
            ];
            final colorConfig = ratingColors[(selectedRating.round() - 1).clamp(0, 4)];

            return Dialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              elevation: 12,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 450),
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          rating != null ? 'Edit Review' : 'Write a Review',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Container(
                          decoration: const BoxDecoration(
                            color: Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 20),
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(8),
                            splashRadius: 20,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Rating',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Row(
                          children: List.generate(5, (index) {
                            final starValue = index + 1.0;
                            final isSelected = starValue <= selectedRating;
                            return MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                onTap: () {
                                  setDialogState(() {
                                    selectedRating = starValue;
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  curve: Curves.easeOut,
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: Icon(
                                    isSelected ? Icons.star_rounded : Icons.star_outline_rounded,
                                    color: isSelected ? const Color(0xFFF59E0B) : const Color(0xFFE2E8F0),
                                    size: 44,
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(width: 12),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: colorConfig['bg'],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            label,
                            style: TextStyle(
                              color: colorConfig['text'],
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Review Content',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF475569),
                          ),
                        ),
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: contentController,
                          builder: (context, value, child) {
                            return Text(
                              '${value.text.length}/500',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF94A3B8),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: contentController,
                      maxLines: 4,
                      maxLength: 500,
                      style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
                      decoration: InputDecoration(
                        hintText: 'Share your experience with this course...',
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        counterText: "",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFF28B79B), width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.all(16),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: isSubmitting ? null : () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  if (contentController.text.trim().isEmpty) {
                                    _showNotification('Please write some content for your review', isError: true);
                                    return;
                                  }
                                  setDialogState(() {
                                    isSubmitting = true;
                                  });
                                  try {
                                    await _repository.submitCourseReview(
                                      widget.courseId,
                                      selectedRating,
                                      contentController.text.trim(),
                                    );
                                    Navigator.pop(context);
                                    _showNotification(
                                      rating != null
                                          ? 'Review updated successfully!'
                                          : 'Review submitted successfully!',
                                    );
                                    setState(() {
                                      _reviewsFuture = _repository.fetchCourseReviews(widget.courseId);
                                      _loadCourseDetail();
                                    });
                                  } catch (e) {
                                    setDialogState(() {
                                      isSubmitting = false;
                                    });
                                    _showNotification('Error: $e', isError: true);
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF28B79B),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: isSubmitting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Submit',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
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
      // Optimistic update to immediately reflect the state in UI without visual jumps
      _courseDetail = course.copyWith(
        isEnrolled: true,
        learnersCount: course.learnersCount + 1,
      );
    });
    try {
      await _repository.enrollCourse(course.id);
      if (!mounted) return;

      _showNotification('You have successfully joined the course ${course.title}');

      // Silently fetch fresh details in background to sync any other backend updates
      final updated = await _repository.fetchCourseDetail(widget.courseId);
      if (mounted) {
        setState(() {
          _courseDetail = updated;
        });
      }
    } catch (e) {
      if (!mounted) return;
      // Rollback optimistic update
      setState(() {
        _courseDetail = course;
      });
      _showNotification('Failed to enroll: $e', isError: true);
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
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 10,
          backgroundColor: Colors.white,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFEE2E2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFFEF4444),
                    size: 28,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Cancel Enrollment',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Are you sure you want to cancel your enrollment for ${course.title}?',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'No, Keep It',
                          style: TextStyle(
                            color: Color(0xFF475569),
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _unenroll(course);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEF4444),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Yes, Cancel',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _unenroll(CourseDetail course) async {
    setState(() {
      _isUnenrolling = true;
      // Optimistic update to immediately reflect the state in UI without visual jumps
      _courseDetail = course.copyWith(
        isEnrolled: false,
        learnersCount: (course.learnersCount - 1).clamp(0, 999999),
      );
    });
    try {
      await _repository.unenrollCourse(course.id);
      if (!mounted) return;

      _showNotification('You have successfully canceled your enrollment.');

      // Silently fetch fresh details in background to sync any other backend updates
      final updated = await _repository.fetchCourseDetail(widget.courseId);
      if (mounted) {
        setState(() {
          _courseDetail = updated;
        });
      }
    } catch (e) {
      if (!mounted) return;
      // Rollback optimistic update
      setState(() {
        _courseDetail = course;
      });
      _showNotification('Failed to cancel enrollment: $e', isError: true);
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
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF28B79B)),
            )
          : (_errorMessage != null)
              ? Center(child: Text('Error: $_errorMessage'))
              : (_courseDetail == null)
                  ? const Center(child: Text('Course not found.'))
                  : SingleChildScrollView(
                      controller: _scrollController,
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
                                      if (Navigator.canPop(context)) {
                                        Navigator.pop(context);
                                      } else {
                                        Navigator.pushAndRemoveUntil(
                                          context,
                                          MaterialPageRoute(builder: (context) => const LearnerHomePage()),
                                          (route) => false,
                                        );
                                      }
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

                                  _buildBanner(_courseDetail!, isDesktop),
                                  const SizedBox(height: 32),

                                  if (isDesktop)
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          flex: 2,
                                          child: _buildMainContent(_courseDetail!),
                                        ),
                                        const SizedBox(width: 32),
                                        Expanded(
                                          flex: 1,
                                          child: _buildEnrollCard(_courseDetail!),
                                        ),
                                      ],
                                    )
                                  else
                                    Column(
                                      children: [
                                        _buildEnrollCard(_courseDetail!),
                                        const SizedBox(height: 32),
                                        _buildMainContent(_courseDetail!),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          ),
                          SharedFooter(isDesktop: isDesktop),
                        ],
                      ),
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
          onTap: (index) {
            if (index == 0) {
              _scrollToSection(_introduceKey, 0);
            } else if (index == 1) {
              _scrollToSection(_syllabusKey, 1);
            } else if (index == 2) {
              _scrollToSection(_reviewKey, 2);
            }
          },
        ),
        const SizedBox(height: 24),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Introduce section
            Container(
              key: _introduceKey,
              child: _buildIntroduceTab(course),
            ),
            const SizedBox(height: 32),
            const Divider(color: Color(0xFFE2E8F0)),
            const SizedBox(height: 32),
            
            // Syllabus section
            Container(
              key: _syllabusKey,
              child: _buildSyllabusTab(course),
            ),
            const SizedBox(height: 32),
            const Divider(color: Color(0xFFE2E8F0)),
            const SizedBox(height: 32),
            
            // Review section
            Container(
              key: _reviewKey,
              child: FutureBuilder<CourseReviewSummary>(
                future: _reviewsFuture,
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
                  final reviews = snapshot.data!.reviews;
                  final hasReviewed = reviews.any((r) => r.userId == _currentUserId);
                  return ReviewTab(
                    summary: snapshot.data!,
                    showWriteReviewButton: course.isEnrolled && !hasReviewed,
                    onWriteReview: _showWriteReviewDialog,
                    currentUserId: _currentUserId,
                    onDeleteReview: _deleteReview,
                    onEditReview: (rating, content) =>
                        _showWriteReviewDialog(rating: rating, content: content),
                    isEnrolled: course.isEnrolled,
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildIntroduceTab(CourseDetail course) {
    return Column(
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

    return Column(
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
                            _showNotification(
                              'Please enroll in the course to view this lesson.',
                              isError: true,
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
                        _showNotification(
                          'No lessons available yet.',
                          isError: true,
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


}
