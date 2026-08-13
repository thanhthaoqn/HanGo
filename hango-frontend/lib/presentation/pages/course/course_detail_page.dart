import 'package:flutter/material.dart';
import '../../../data/repositories/course_repository.dart';
import '../../../domain/model/course_detail.dart';
import '../../../domain/model/course.dart';
import '../../../domain/model/course_review_summary.dart';
import '../../../data/services/auth_service.dart';
import '../../widgets/shared_header.dart';
import '../../widgets/shared_footer.dart';
import '../learner/learner_home_page.dart';
import '../login_page.dart';
import 'review_tab.dart';
import 'lesson_detail_page.dart';
import 'course_completion_page.dart';
import 'cart_page.dart';
import '../../../utils/cart_manager.dart';
import '../../../utils/language_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../utils/toast_helper.dart';
import '../../widgets/payment_qr_dialog.dart';

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
  bool _isSwitchingVersion = false;
  bool _isInCart = false;
  bool _dismissedVersionBanner = false;

  int _currentUserId = 1;
  bool _canEnroll = true;
  bool _canRateAndComment = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserId();
    _loadCourseDetail();
    _checkCartStatus();
    _isInCart = CartManager.cartCoursesNotifier.value.any((c) => c.id == widget.courseId);
    CartManager.cartCoursesNotifier.addListener(_onCartChanged);
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
    _scrollController = ScrollController();
    _reviewsFuture = _repository.fetchCourseReviews(widget.courseId);
  }

  void _onCartChanged() {
    if (!mounted) return;
    final isNowInCart = CartManager.cartCoursesNotifier.value.any((c) => c.id == widget.courseId);
    if (isNowInCart != _isInCart) {
      setState(() {
        _isInCart = isNowInCart;
      });
    }
  }

  @override
  void dispose() {
    CartManager.cartCoursesNotifier.removeListener(_onCartChanged);
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final roles = prefs.getStringList('user_roles') ?? [];
    if (mounted) {
      setState(() {
        _currentUserId = prefs.getInt('user_id') ?? 1;
        _canEnroll = roles.contains('ENROLL_AND_LEARN_COURSES') || roles.contains('ROLE_ADMINISTRATOR');
        _canRateAndComment = roles.contains('RATE_AND_COMMENT') || roles.contains('ROLE_ADMINISTRATOR');
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

  Future<void> _switchToNewVersion() async {
    if (_courseDetail == null || _courseDetail!.latestPublishedCourseId == null)
      return;

    setState(() {
      _isSwitchingVersion = true;
    });

    try {
      await _repository.switchCourseVersion(_courseDetail!.id);
      if (!mounted) return;

      _showNotification(
        'Switch to new version successfully! Learning progress has been synchronized.',
      );

      // Reload course detail to reflect new version
      final updated = await _repository.fetchCourseDetail(widget.courseId);
      if (mounted) {
        setState(() {
          _courseDetail = updated;
        });
      }
    } catch (e) {
      if (!mounted) return;
      _showNotification('Error switching version: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isSwitchingVersion = false;
        });
      }
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
                color: isError
                    ? const Color(0xFFFEF2F2)
                    : const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isError
                      ? const Color(0xFFFCA5A5)
                      : const Color(0xFF34D399),
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
                    isError
                        ? Icons.error_outline_rounded
                        : Icons.check_circle_outline_rounded,
                    color: isError
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF10B981),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      message,
                      style: TextStyle(
                        color: isError
                            ? const Color(0xFF991B1B)
                            : const Color(0xFF065F46),
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
      try {
        entry.remove();
      } catch (_) {}
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
            final ratingLabels = [
              'Terrible',
              'Bad',
              'Average',
              'Good',
              'Excellent',
            ];
            final label = ratingLabels[selectedRating.round() - 1];

            final ratingColors = [
              {
                'bg': const Color(0xFFFEF2F2),
                'text': const Color(0xFFEF4444),
              }, // Terrible
              {
                'bg': const Color(0xFFFFF7ED),
                'text': const Color(0xFFF97316),
              }, // Bad
              {
                'bg': const Color(0xFFFEF3C7),
                'text': const Color(0xFFD97706),
              }, // Average
              {
                'bg': const Color(0xFFECFDF5),
                'text': const Color(0xFF10B981),
              }, // Good
              {
                'bg': const Color(0xFFE6F4EA),
                'text': const Color(0xFF0F9D58),
              }, // Excellent
            ];
            final colorConfig =
                ratingColors[(selectedRating.round() - 1).clamp(0, 4)];

            return Dialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              elevation: 12,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
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
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Color(0xFF64748B),
                              size: 20,
                            ),
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
                                    isSelected
                                        ? Icons.star_rounded
                                        : Icons.star_outline_rounded,
                                    color: isSelected
                                        ? const Color(0xFFF59E0B)
                                        : const Color(0xFFE2E8F0),
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
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
                          'Review Content (Optional)',
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
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF1E293B),
                      ),
                      decoration: InputDecoration(
                        hintText: 'Share your experience with this course...',
                        hintStyle: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 13,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        counterText: "",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                            width: 1,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                            width: 1,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFF28B79B),
                            width: 1.5,
                          ),
                        ),
                        contentPadding: const EdgeInsets.all(16),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: isSubmitting
                              ? null
                              : () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: isSubmitting
                              ? null
                              : () async {
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
                                      _reviewsFuture = _repository
                                          .fetchCourseReviews(widget.courseId);
                                      _loadCourseDetail();
                                    });
                                  } catch (e) {
                                    setDialogState(() {
                                      isSubmitting = false;
                                    });
                                    _showNotification(
                                      'Error: $e',
                                      isError: true,
                                    );
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF28B79B),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 14,
                            ),
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
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
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
      },
    );
  }

  void _enroll(CourseDetail course) async {
    if (!_canEnroll) {
      _showNotification('Enrollment is not available for your role.', isError: true);
      return;
    }
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
    _showEnrollConfirmDialog(course);
  }

  void _showEnrollConfirmDialog(CourseDetail course) {
    if (!_canEnroll) {
      _showNotification('Enrollment is not available for your role.', isError: true);
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
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
                    color: Color(0xFFE6F4EA),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.help_outline_rounded,
                    color: Color(0xFF28B79B),
                    size: 28,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Confirm Enrollment',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Would you like to enroll in "${course.title}" and start learning?',
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
                          'Cancel',
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
                          _proceedWithEnrollment(course);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF28B79B),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Yes, Enroll',
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

  void _proceedWithEnrollment(CourseDetail course) async {
    if (!_canEnroll) {
      _showNotification('Enrollment is not available for your role.', isError: true);
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

      _showNotification(
        'You have successfully joined the course ${course.title}',
      );

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



  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: SharedHeader(
        isDesktop: isDesktop, 
        activeTab: 'Courses',
        showBackButton: Navigator.canPop(context),
      ),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_courseDetail!.hasNewVersionAvailable)
                    _buildVersionBanner(_courseDetail!, isDesktop),
                  _buildBanner(_courseDetail!, isDesktop),
                  Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 1440),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 32,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
    final hasImage =
        course.thumbnailUrl != null && course.thumbnailUrl!.isNotEmpty;

    return Container(
      width: double.infinity,
      color: const Color(0xFF135D4E),
      child: Stack(
        children: [
          // Layer 1: Background Image
          if (hasImage)
            Positioned.fill(
              child: Image.network(
                course.thumbnailUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    Container(color: const Color(0xFF135D4E)),
              ),
            ),

          // Layer 2: Dark Overlay Gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.85),
                    Colors.black.withOpacity(0.65),
                    Colors.black.withOpacity(0.35),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
            ),
          ),

          // Layer 3: Foreground Content
          Center(
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 1440),
              padding: EdgeInsets.symmetric(
                horizontal: 20,
                vertical: isDesktop ? 64.0 : 36.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back button / Breadcrumb
                  InkWell(
                    onTap: () {
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      } else {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LearnerHomePage(),
                          ),
                          (route) => false,
                        );
                      }
                    },
                    hoverColor: Colors.transparent,
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 13,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Courses > ${course.title}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Outfit',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    course.title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isDesktop ? 36 : 24,
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                      fontFamily: 'Outfit',
                    ),
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 24,
                    runSpacing: 12,
                    children: [
                      _buildBannerStatItem(
                        Icons.person_outline_rounded,
                        'Trainer: ${course.creatorName}',
                      ),
                      _buildBannerStatItem(
                        Icons.people_outline_rounded,
                        '${course.learnersCount} Learners',
                      ),
                      _buildBannerStatItem(
                        Icons.bar_chart_rounded,
                        'Level: ${course.difficultyName}',
                      ),
                      _buildBannerStatItem(
                        Icons.star_rounded,
                        '${course.rating}',
                        iconColor: Colors.amber,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBannerStatItem(
    IconData icon,
    String text, {
    Color iconColor = Colors.white70,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: iconColor, size: 18),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            color: Color(0xE5FFFFFF),
            fontSize: 14,
            fontWeight: FontWeight.w500,
            fontFamily: 'Outfit',
          ),
        ),
      ],
    );
  }

  Widget _buildMainContent(CourseDetail course) {
    bool isCompleted = false;
    if (course.isEnrolled && course.sessions.isNotEmpty) {
      final totalLessons = course.sessions.fold(0, (sum, s) => sum + s.lessons.length);
      final completedLessons = course.sessions.fold(0, (sum, s) => sum + s.lessons.where((l) => l.isCompleted).length);
      if (totalLessons > 0 && completedLessons == totalLessons) {
        isCompleted = true;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isCompleted) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 24),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFECFDF5), Color(0xFFFEF3C7)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF6EE7B7)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0F20B486),
                  blurRadius: 16,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 16,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Color(0xFF20B486),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.emoji_events_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            LanguageManager.isVi ? '🎉 Khóa học đã hoàn thành!' : '🎉 You\'ve Completed This Course!',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                              fontFamily: 'Outfit',
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            LanguageManager.isVi
                                ? 'Chúc mừng bạn đã hoàn thành xuất sắc toàn bộ bài học. Hãy xem chứng chỉ và tổng kết học tập nhé!'
                                : 'Congratulations on mastering all lessons! View your official certificate and summary.',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF475569),
                              fontFamily: 'Outfit',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => CourseCompletionPage(
                          courseId: course.id,
                          courseDetail: course,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.workspace_premium_rounded, size: 18),
                  label: Text(
                    LanguageManager.isVi ? 'Xem Chứng Chỉ' : 'View Certificate',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF20B486),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ],
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
          tabAlignment: TabAlignment.center,
          tabs: const [
            Tab(text: 'Introduction'),
            Tab(text: 'Syllabus'),
            Tab(text: 'Trainer'),
            Tab(text: 'Review'),
          ],
          onTap: (index) {
            setState(() {
              _tabController.index = index;
            });
          },
        ),
        const SizedBox(height: 24),
        if (_tabController.index == 0)
          _buildIntroduceTab(course)
        else if (_tabController.index == 1)
          _buildSyllabusTab(course)
        else if (_tabController.index == 2)
          _buildTrainerTab(course)
        else
          FutureBuilder<CourseReviewSummary>(
            future: _reviewsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFF28B79B)),
                );
              } else if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              } else if (!snapshot.hasData) {
                return const Center(child: Text('No reviews available.'));
              }
              final reviews = snapshot.data!.reviews;
              final hasReviewed = reviews.any(
                (r) => r.userId == _currentUserId,
              );
              return ReviewTab(
                summary: snapshot.data!,
                showWriteReviewButton: _canRateAndComment && course.isEnrolled && !hasReviewed,
                onWriteReview: _showWriteReviewDialog,
                currentUserId: _currentUserId,
                onDeleteReview: _canRateAndComment ? _deleteReview : null,
                onEditReview: _canRateAndComment
                    ? (rating, content) =>
                        _showWriteReviewDialog(rating: rating, content: content)
                    : null,
                isEnrolled: course.isEnrolled,
              );
            },
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
              'Syllabus',
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
                                  cameFromCourseDetail: true,
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
                          if (lesson.estimatedTime != null) ...[
                            Text(
                              '${lesson.estimatedTime} mins',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                                fontFamily: 'Outfit',
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
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
                                                cameFromCourseDetail: true,
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

  Future<void> _checkCartStatus() async {
    final inMemory = CartManager.cartCoursesNotifier.value.any((c) => c.id == widget.courseId);
    if (inMemory) {
      if (mounted) {
        setState(() {
          _isInCart = true;
        });
      }
      return;
    }
    final cart = await CartManager.getCartIds();
    if (mounted) {
      setState(() {
        _isInCart = cart.contains(widget.courseId.toString());
      });
    }
  }

  Future<void> _addToCart() async {
    final isVi = LanguageManager.isVi;
    if (_courseDetail == null) return;

    // 1. Optimistic UI update (0ms lag)
    setState(() {
      _isInCart = true;
    });
    _showNotification(isVi ? 'Đã thêm vào giỏ hàng thành công!' : 'Added to cart successfully!');

    // 2. Convert detail to Course object and sync optimistically
    final detail = _courseDetail!;
    final courseObj = Course(
      id: detail.id,
      title: detail.title,
      category: detail.difficultyName,
      creatorName: detail.creatorName,
      stars: detail.rating,
      difficulty: detail.difficultyName,
      learnerCount: '${detail.learnersCount}',
      thumbnailUrl: detail.thumbnailUrl ?? '',
      status: 'featured',
      progressPercentage: 0.0,
      price: detail.price,
    );

    await CartManager.addToCart(courseObj);
  }

  String _getCoursePrice(CourseDetail course) {
    if (course.price <= 0) {
      return 'Miễn phí';
    }
    final formatted = course.price
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        );
    return '$formattedđ';
  }

  String _getOriginalPrice(String currentPrice) {
    if (currentPrice == 'Miễn phí') return '';
    try {
      final clean = currentPrice.replaceAll(RegExp(r'[^0-9]'), '');
      if (clean.isEmpty) return '';
      final val = double.parse(clean);
      final original = val * 1.3;
      final formatted = original
          .toStringAsFixed(0)
          .replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (m) => '${m[1]}.',
          );
      return '$formattedđ';
    } catch (_) {
      return '';
    }
  }

  /// Trả về giá số (VND) để truyền vào PaymentQrDialog
  double _getCourseNumericPrice(CourseDetail course) {
    return course.price;
  }

  Widget _buildTrainerTab(CourseDetail course) {
    final isVi = LanguageManager.isVi;
    final trainerName = course.creatorName;
    final String initials = trainerName.isNotEmpty
        ? trainerName.trim().split(' ').last[0].toUpperCase()
        : 'T';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: const Color(0xFFE6F4EA),
                child: Text(
                  initials,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF28B79B),
                    fontFamily: 'Outfit',
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trainerName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                        fontFamily: 'Outfit',
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE6FFFA),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isVi
                            ? 'Giáo viên Tiếng Anh tại HanGo'
                            : 'English Trainer at HanGo',
                        style: const TextStyle(
                          color: Color(0xFF137333),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Outfit',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(color: Color(0xFFE2E8F0)),
          const SizedBox(height: 20),

          Text(
            isVi ? 'Giới thiệu' : 'About the Trainer',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isVi
                ? 'Giáo viên ôn thi THPT Quốc Gia giàu kinh nghiệm, tốt nghiệp chuyên ngành Ngôn ngữ Anh. Với phương pháp giảng dạy hiện đại, trực quan và tập trung vào bản chất, thầy/cô đã hỗ trợ hàng ngàn học sinh cải thiện điểm số vượt bậc.'
                : 'An experienced high school exam preparation instructor holding a degree in English Linguistics. Utilizing modern, visual, and conceptual teaching methodologies, they have successfully helped thousands of students achieve dramatic score improvements.',
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF4B5563),
              height: 1.6,
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 24),

          Text(
            isVi ? 'Kinh nghiệm & Bằng cấp' : 'Experience & Qualifications',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 12),
          _buildTrainerQualificationItem(
            Icons.school_rounded,
            isVi
                ? 'Cử nhân/Thạc sĩ chuyên ngành Sư phạm tiếng Anh / Ngôn ngữ Anh.'
                : 'Bachelor/Master of English Pedagogy or English Linguistics.',
          ),
          _buildTrainerQualificationItem(
            Icons.workspace_premium_rounded,
            isVi
                ? 'Chứng chỉ IELTS 8.0+ hoặc chứng chỉ giảng dạy tiếng Anh quốc tế (TESOL, CELTA).'
                : 'IELTS 8.0+ score or internationally recognized English Teaching Certificates (TESOL, CELTA).',
          ),
          _buildTrainerQualificationItem(
            Icons.trending_up_rounded,
            isVi
                ? 'Hơn 5 năm giảng dạy thực chiến và ôn luyện học sinh thi THPT Quốc Gia môn Tiếng Anh.'
                : '5+ years of active high school English exam preparation and teaching experience.',
          ),
        ],
      ),
    );
  }

  Widget _buildTrainerQualificationItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF28B79B)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF4B5563),
                height: 1.4,
                fontFamily: 'Outfit',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnrollCard(CourseDetail course) {
    bool isCompleted = false;
    if (course.isEnrolled && course.sessions.isNotEmpty) {
      final totalLessons = course.sessions.fold(0, (sum, s) => sum + s.lessons.length);
      final completedLessons = course.sessions.fold(0, (sum, s) => sum + s.lessons.where((l) => l.isCompleted).length);
      if (totalLessons > 0 && completedLessons == totalLessons) {
        isCompleted = true;
      }
    }

    final priceStr = _getCoursePrice(course);
    final isFree = priceStr == 'Miễn phí';
    final originalPriceStr = _getOriginalPrice(priceStr);

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Price Display Section
          if (isFree)
            const Text(
              'Free',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Color(0xFF28B79B),
                fontFamily: 'Outfit',
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      priceStr,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        fontFamily: 'Outfit',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      originalPriceStr,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF94A3B8),
                        decoration: TextDecoration.lineThrough,
                        fontFamily: 'Outfit',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Save 30%',
                    style: TextStyle(
                      color: Color(0xFFEF4444),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Outfit',
                    ),
                  ),
                ),
              ],
            ),

          const SizedBox(height: 24),
          const Divider(color: Color(0xFFF1F5F9)),
          const SizedBox(height: 16),

          const Text(
            'Course includes:',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 16),
          _buildIncludeItem(
            Icons.library_books_outlined,
            '${course.sessions.length} Detailed Sessions',
          ),
          _buildIncludeItem(
            Icons.article_outlined,
            '${course.sessions.fold(0, (sum, s) => sum + s.lessons.length)} Detailed Lessons',
          ),
          _buildIncludeItem(Icons.quiz_outlined, 'Practice Quizzes'),

          const SizedBox(height: 28),

          if (course.isEnrolled) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
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
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF28B79B),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Study Now',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Outfit',
                  ),
                ),
              ),
            ),
            if (isCompleted) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CourseCompletionPage(
                          courseId: course.id,
                          courseDetail: course,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.workspace_premium_rounded, size: 18, color: Color(0xFFD97706)),
                  label: Text(
                    LanguageManager.isVi ? 'Xem Chứng Chỉ' : 'View Certificate',
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Outfit',
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFF59E0B), width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],

          ] else ...[
            // Buy / Enroll Buttons Section
            if (!_canEnroll) ...[
              SizedBox(
                width: double.infinity,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Center(
                    child: Text(
                      'Enrollment not available for your role',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Outfit',
                      ),
                    ),
                  ),
                ),
              ),
            ] else if (isFree) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _enroll(course),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF28B79B),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
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
                      : const Text(
                          'Enroll now',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Outfit',
                          ),
                        ),
                ),
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final authService = AuthService();
                    final isLoggedIn = await authService.isLoggedIn();
                    if (!isLoggedIn) {
                      if (!mounted) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LoginPage(),
                        ),
                      );
                      return;
                    }
                    // Mở dialog thanh toán VNPay QR
                    if (!mounted) return;
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => PaymentQrDialog(
                        courseId: course.id,
                        courseTitle: course.title,
                        price: _getCourseNumericPrice(course),
                        onPaymentSuccess: () {
                          setState(() {
                            _courseDetail = _courseDetail!.copyWith(
                              isEnrolled: true,
                            );
                          });
                          _showNotification(
                            '🎉 Payment successful! Course unlocked.',
                          );
                          _loadCourseDetail();
                        },
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF05A22),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Buy Now',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Outfit',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _isInCart
                      ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const CartPage(),
                            ),
                          );
                        }
                      : _addToCart,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(
                      color: Color(0xFF28B79B),
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    LanguageManager.isVi
                        ? (_isInCart ? 'Xem giỏ hàng' : 'Thêm vào giỏ hàng')
                        : (_isInCart ? 'Go to Cart' : 'Add to Cart'),
                    style: const TextStyle(
                      color: Color(0xFF28B79B),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Outfit',
                    ),
                  ),
                ),
              ),
            ],
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

  Widget _buildVersionBanner(CourseDetail course, bool isDesktop) {
    if (_dismissedVersionBanner) return const SizedBox.shrink();
    final isVi = LanguageManager.isVi;
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFFF3E0), Color(0xFFFFE0B2)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: 24,
        vertical: isDesktop ? 16 : 12,
      ),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1440),
          child: Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: Color(0xFFE65100),
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isVi
                          ? 'New version available!'
                          : 'New version available!',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFBF360C),
                        fontFamily: 'Outfit',
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isVi
                          ? 'The trainer has updated the course to ${course.latestPublishedVersion ?? "a new version"}. You can switch to the latest version to access updated content.'
                          : 'The trainer has updated the course to ${course.latestPublishedVersion ?? "a new version"}. You can switch to the latest version to access updated content.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFBF360C),
                        fontFamily: 'Outfit',
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              TextButton(
                onPressed: () {
                  setState(() {
                    _dismissedVersionBanner = true;
                  });
                },
                child: Text(
                  isVi ? 'Later' : 'Later',
                  style: const TextStyle(
                    color: Color(0xFFBF360C),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    fontFamily: 'Outfit',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _isSwitchingVersion ? null : _switchToNewVersion,
                icon: _isSwitchingVersion
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.swap_horiz_rounded, size: 18),
                label: Text(
                  isVi ? 'Update Now' : 'Update Now',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    fontFamily: 'Outfit',
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE65100),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
