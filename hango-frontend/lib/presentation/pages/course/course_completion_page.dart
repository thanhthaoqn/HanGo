import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/repositories/course_repository.dart';
import '../../../domain/model/course_detail.dart';
import '../../../utils/language_manager.dart';
import '../../../utils/toast_helper.dart';
import '../learner/learning_pathway_page.dart';
import '../learner/my_learning_page.dart';
import 'course_detail_page.dart';

class CourseCompletionPage extends StatefulWidget {
  final int courseId;
  final CourseDetail? courseDetail;

  const CourseCompletionPage({
    super.key,
    required this.courseId,
    this.courseDetail,
  });

  @override
  State<CourseCompletionPage> createState() => _CourseCompletionPageState();
}

class _CourseCompletionPageState extends State<CourseCompletionPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _confettiController;
  late List<ConfettiParticle> _particles;
  final CourseRepository _courseRepository = CourseRepository();
  CourseDetail? _courseDetail;
  bool _isLoading = true;
  String _userName = 'Learner';
  String _achievementId = '';

  // Review section state
  double _selectedRating = 5.0;
  final TextEditingController _reviewController = TextEditingController();
  bool _isSubmittingReview = false;
  bool _hasSubmittedReview = false;

  @override
  void initState() {
    super.initState();
    _courseDetail = widget.courseDetail;
    _generateAchievementId();
    _loadUserAndCourse();

    // Initialize 60fps continuous celebration animation
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _particles = _generateParticles(80);
  }

  void _generateAchievementId() {
    final now = DateTime.now();
    final uniqueNum = (now.millisecondsSinceEpoch % 90000) + 10000;
    _achievementId = 'ACHIEVE-HG-${widget.courseId}-${now.year}-$uniqueNum';
  }

  Future<void> _loadUserAndCourse() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString('user_fullname');
      if (name != null && name.trim().isNotEmpty) {
        _userName = name;
      }

      if (_courseDetail == null) {
        final fetched = await _courseRepository.fetchCourseDetail(widget.courseId);
        if (mounted) {
          setState(() {
            _courseDetail = fetched;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ToastHelper.showError(context, 'Failed to load completion summary: $e');
      }
    }
  }

  List<ConfettiParticle> _generateParticles(int count) {
    final random = math.Random();
    final colors = [
      const Color(0xFF20B486), // Teal Green (Primary)
      const Color(0xFFF59E0B), // Gold / Amber
      const Color(0xFF10B981), // Emerald Green
      const Color(0xFF14B8A6), // Light Teal
      const Color(0xFFF43F5E), // Rose / Coral
      const Color(0xFF8B5CF6), // Purple
      const Color(0xFF3B82F6), // Blue
    ];

    return List.generate(count, (index) {
      return ConfettiParticle(
        x: random.nextDouble(),
        y: random.nextDouble() * 1.4 - 0.2,
        speed: 0.3 + random.nextDouble() * 0.7,
        horizontalSpeed: 0.5 + random.nextDouble() * 1.5,
        angle: random.nextDouble() * math.pi * 2,
        spinSpeed: (random.nextBool() ? 1 : -1) * (0.5 + random.nextDouble() * 1.5),
        color: colors[random.nextInt(colors.length)],
        shapeType: random.nextInt(3),
      );
    });
  }

  Future<void> _submitReview() async {
    if (_reviewController.text.trim().isEmpty) {
      ToastHelper.showError(
        context,
        LanguageManager.isVi
            ? 'Vui lòng nhập nội dung đánh giá'
            : 'Please enter review content',
      );
      return;
    }

    setState(() {
      _isSubmittingReview = true;
    });

    try {
      await _courseRepository.submitCourseReview(
        widget.courseId,
        _selectedRating,
        _reviewController.text.trim(),
      );

      if (mounted) {
        setState(() {
          _isSubmittingReview = false;
          _hasSubmittedReview = true;
        });
        ToastHelper.showSuccess(
          context,
          LanguageManager.isVi
              ? 'Cảm ơn bạn đã đánh giá khóa học!'
              : 'Thank you for your valuable review!',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmittingReview = false;
        });
        ToastHelper.showError(context, 'Error submitting review: $e');
      }
    }
  }

  void _shareAchievement() {
    final title = _courseDetail?.title ?? 'a course';
    final shareText = LanguageManager.isVi
        ? 'Tôi vừa hoàn thành xuất sắc khóa học "$title" trên nền tảng HanGo EdTech! 🚀'
        : 'I just completed "$title" on HanGo EdTech! 🚀';

    Clipboard.setData(ClipboardData(text: shareText));
    ToastHelper.showSuccess(
      context,
      LanguageManager.isVi
          ? 'Đã sao chép thông tin thành tích vào clipboard!'
          : 'Achievement details copied to clipboard!',
    );
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _reviewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isVi = LanguageManager.isVi;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: IconButton(
            icon: const Icon(Icons.close_rounded, color: Color(0xFF1E293B)),
            tooltip: isVi ? 'Đóng' : 'Close',
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const MyLearningPage()),
                (route) => route.isFirst,
              );
            },
          ),
        ),
        title: Text(
          isVi ? 'Chúc Mừng Hoàn Thành' : 'Course Completed',
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
            fontSize: 18,
            fontFamily: 'Outfit',
          ),
        ),
        centerTitle: true,
        actions: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: TextButton.icon(
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => CourseDetailPage(courseId: widget.courseId),
                  ),
                );
              },
              icon: const Icon(Icons.menu_book_rounded, size: 18, color: Color(0xFF20B486)),
              label: Text(
                isVi ? 'Xem lại bài học' : 'Review Course',
                style: const TextStyle(
                  color: Color(0xFF20B486),
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Outfit',
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Stack(
        children: [
          // Background Celebration Particle Layer
          AnimatedBuilder(
            animation: _confettiController,
            builder: (context, child) {
              return CustomPaint(
                painter: ConfettiPainter(_particles, _confettiController.value),
                size: Size.infinite,
              );
            },
          ),

          // Main Content
          _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF20B486)))
              : SafeArea(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 900;

                      if (isWide) {
                        return _buildWideLayout(isVi, constraints);
                      } else {
                        return _buildMobileLayout(isVi, constraints);
                      }
                    },
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildWideLayout(bool isVi, BoxConstraints constraints) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Column: Hero Celebration & Mastery Stats
              Expanded(
                flex: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCelebrationHeader(isVi),
                    const SizedBox(height: 28),
                    _buildMasteryStatsGrid(isVi),
                    const SizedBox(height: 28),
                    _buildNextStepsCard(isVi),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
              const SizedBox(width: 40),
              // Right Column: Gamified Feedback & Takeaways Card
              Expanded(
                flex: 5,
                child: Column(
                  children: [
                    _buildReviewSection(isVi),
                    const SizedBox(height: 24),
                    _buildTakeawaysCard(isVi),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout(bool isVi, BoxConstraints constraints) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCelebrationHeader(isVi),
          const SizedBox(height: 24),
          _buildMasteryStatsGrid(isVi),
          const SizedBox(height: 24),
          _buildReviewSection(isVi),
          const SizedBox(height: 24),
          _buildNextStepsCard(isVi),
          const SizedBox(height: 24),
          _buildTakeawaysCard(isVi),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildCelebrationHeader(bool isVi) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF20B486).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF20B486)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome_rounded, color: Color(0xFF34D399), size: 16),
                    const SizedBox(width: 8),
                    Text(
                      isVi ? '✨ HOÀN THÀNH XUẤT SẮC' : '✨ COURSE CONQUERED',
                      style: const TextStyle(
                        color: Color(0xFF34D399),
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        letterSpacing: 0.8,
                        fontFamily: 'Outfit',
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'ID: $_achievementId',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 38),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isVi ? 'Chúc Mừng, $_userName!' : 'Congratulations, $_userName!',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        fontFamily: 'Outfit',
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _courseDetail?.title ?? (isVi ? 'Khóa học kiến thức chuyên sâu' : 'Mastery Learning Course'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF34D399),
                        fontFamily: 'Outfit',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            isVi
                ? 'Sự kiên trì và nỗ lực của bạn đã đơm hoa kết trái. Bạn đã nắm vững toàn bộ kiến thức và kỹ năng từ khóa học này. Hãy tự hào về thành quả tuyệt vời của bản thân!'
                : 'Your dedication and consistent effort have paid off. You have mastered the comprehensive curriculum of this course. Take a moment to celebrate your personal growth!',
            style: TextStyle(
              fontSize: 14.5,
              color: Colors.white.withValues(alpha: 0.8),
              height: 1.6,
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: ElevatedButton.icon(
                  onPressed: _shareAchievement,
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: Text(
                    isVi ? 'Chia sẻ thành tích 🚀' : 'Share Achievement 🚀',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontFamily: 'Outfit', fontSize: 14),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF20B486),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMasteryStatsGrid(bool isVi) {
    int totalLessons = 0;
    int totalSessions = 0;
    if (_courseDetail != null) {
      totalSessions = _courseDetail!.sessions.length;
      totalLessons = _courseDetail!.sessions.fold(0, (sum, s) => sum + s.lessons.length);
    }

    final stats = [
      {
        'title': isVi ? 'Tiến độ hoàn thành' : 'Completion Status',
        'value': '100%',
        'sub': isVi ? 'Đạt chuẩn yêu cầu' : 'Mastery Achieved',
        'icon': Icons.check_circle_rounded,
        'color': const Color(0xFF20B486),
        'bg': const Color(0xFFECFDF5),
      },
      {
        'title': isVi ? 'Bài học hoàn tất' : 'Lessons Mastered',
        'value': totalLessons > 0 ? '$totalLessons/$totalLessons' : (isVi ? 'Hoàn tất' : 'All Mastered'),
        'sub': isVi ? 'Toàn bộ nội dung' : 'Full Curriculum',
        'icon': Icons.play_lesson_rounded,
        'color': const Color(0xFFF59E0B),
        'bg': const Color(0xFFFFFBEB),
      },
      {
        'title': isVi ? 'Cấu trúc chương học' : 'Course Modules',
        'value': totalSessions > 0 ? '$totalSessions ${isVi ? 'Chương' : 'Sessions'}' : (isVi ? 'Trọn gói' : 'Complete'),
        'sub': isVi ? 'Đã nắm vững' : 'Structured Sections',
        'icon': Icons.layers_rounded,
        'color': const Color(0xFF8B5CF6),
        'bg': const Color(0xFFF3E8FF),
      },
      {
        'title': isVi ? 'Đánh giá kỹ năng' : 'Skill Proficiency',
        'value': isVi ? 'Thành thạo' : 'Proficient',
        'sub': isVi ? 'Khả năng ứng dụng cao' : 'High Application Readiness',
        'icon': Icons.psychology_alt_rounded,
        'color': const Color(0xFF3B82F6),
        'bg': const Color(0xFFEFF6FF),
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.65,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: stats.length,
      itemBuilder: (context, index) {
        final item = stats[index];
        final color = item['color'] as Color;
        final bg = item['bg'] as Color;

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(item['icon'] as IconData, color: color, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item['title'] as String,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Outfit',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                item['value'] as String,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: color,
                  fontFamily: 'Outfit',
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item['sub'] as String,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFF94A3B8),
                  fontFamily: 'Outfit',
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReviewSection(bool isVi) {
    if (_hasSubmittedReview) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF6EE7B7)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF10B981).withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Color(0xFF10B981),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isVi ? 'Cảm ơn bạn đã đánh giá!' : 'Thank You For Your Feedback!',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF065F46),
                      fontFamily: 'Outfit',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isVi
                        ? 'Ý kiến đóng góp quý báu của bạn đã được ghi nhận, giúp nâng cao chất lượng bài giảng và hỗ trợ cộng đồng học viên HanGo.'
                        : 'Your valuable review helps instructors enhance the course material and guides fellow learners.',
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: Color(0xFF047857),
                      height: 1.4,
                      fontFamily: 'Outfit',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.rate_review_rounded, color: Color(0xFFF59E0B), size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isVi ? 'Cảm nhận của bạn về khóa học?' : 'How was your learning experience?',
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        fontFamily: 'Outfit',
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isVi ? 'Chia sẻ đánh giá để giúp cộng đồng phát triển' : 'Leave a rating to guide future learners',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontFamily: 'Outfit'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final starValue = index + 1.0;
              final isSelected = starValue <= _selectedRating;
              return MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedRating = starValue;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 6.0),
                    child: Icon(
                      isSelected ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: isSelected ? const Color(0xFFF59E0B) : const Color(0xFFCBD5E1),
                      size: 42,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              _selectedRating == 5.0
                  ? (isVi ? '⭐⭐⭐⭐⭐ Tuyệt vời!' : '⭐⭐⭐⭐⭐ Excellent!')
                  : _selectedRating >= 4.0
                      ? (isVi ? '⭐⭐⭐⭐ Rất tốt' : '⭐⭐⭐⭐ Very Good')
                      : _selectedRating >= 3.0
                          ? (isVi ? '⭐⭐⭐ Khá ổn' : '⭐⭐⭐ Good')
                          : (isVi ? 'Cần cải thiện thêm' : 'Needs Improvement'),
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFFD97706), fontFamily: 'Outfit'),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _reviewController,
            maxLines: 4,
            maxLength: 350,
            style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B), fontFamily: 'Outfit'),
            decoration: InputDecoration(
              hintText: isVi
                  ? 'Viết cảm nhận của bạn về chất lượng giảng dạy, nội dung bài giảng, mức độ dễ hiểu và tính ứng dụng của khóa học...'
                  : 'Share your thoughts on the course structure, instructor explanations, and real-world usefulness...',
              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFF20B486), width: 1.5),
              ),
              contentPadding: const EdgeInsets.all(18),
            ),
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: ElevatedButton.icon(
                onPressed: _isSubmittingReview ? null : _submitReview,
                icon: _isSubmittingReview
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send_rounded, size: 18),
                label: Text(
                  isVi ? 'Gửi đánh giá ngay' : 'Submit Feedback',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontFamily: 'Outfit', fontSize: 14.5),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextStepsCard(bool isVi) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.explore_rounded, color: Color(0xFF3B82F6), size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isVi ? 'Bước tiếp theo trên hành trình?' : 'What\'s Next on Your Journey?',
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        fontFamily: 'Outfit',
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isVi ? 'Duy trì nhịp độ học tập để bứt phá kỹ năng' : 'Keep up your momentum and unlock new skills',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontFamily: 'Outfit'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            isVi
                ? 'Hệ thống AI Adaptive Learning của HanGo đã chuẩn bị sẵn Lộ trình học tiếp theo phù hợp nhất với trình độ hiện tại của bạn. Khám phá ngay để không gián đoạn quá trình rèn luyện!'
                : 'HanGo\'s AI Adaptive Learning has curated your optimal next learning steps based on your current progress. Continue now to maintain your learning streak!',
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF475569),
              height: 1.5,
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const LearningPathwayPage()),
                      );
                    },
                    icon: const Icon(Icons.auto_awesome_rounded, size: 18, color: Color(0xFFF59E0B)),
                    label: Text(
                      isVi ? 'Khám phá Lộ trình AI ➔' : 'Explore AI Pathway ➔',
                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, fontFamily: 'Outfit'),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (context) => const MyLearningPage()),
                        (route) => route.isFirst,
                      );
                    },
                    icon: const Icon(Icons.dashboard_rounded, size: 18),
                    label: Text(
                      isVi ? 'Về Bảng điều khiển' : 'My Learning Dashboard',
                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, fontFamily: 'Outfit'),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF475569),
                      side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTakeawaysCard(bool isVi) {
    final takeaways = [
      isVi ? 'Nắm vững kiến thức cốt lõi và tư duy hệ thống từ bài giảng' : 'Mastered core concepts and systematic thinking',
      isVi ? 'Hoàn thành 100% các bài trắc nghiệm và thực hành kỹ năng' : 'Completed 100% of quizzes and skill exercises',
      isVi ? 'Sẵn sàng áp dụng kiến thức vào thực tế và các khóa nâng cao' : 'Ready to apply knowledge to real-world scenarios',
    ];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_rounded, color: Color(0xFF20B486), size: 22),
              const SizedBox(width: 10),
              Text(
                isVi ? 'Giá trị bạn đã nhận được' : 'Key Takeaways Achieved',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  fontFamily: 'Outfit',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...takeaways.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(Icons.check_circle_outline_rounded, color: Color(0xFF20B486), size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item,
                        style: const TextStyle(fontSize: 13.5, color: Color(0xFF475569), height: 1.4, fontFamily: 'Outfit'),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class ConfettiParticle {
  double x;
  double y;
  double speed;
  double horizontalSpeed;
  double angle;
  double spinSpeed;
  Color color;
  int shapeType;

  ConfettiParticle({
    required this.x,
    required this.y,
    required this.speed,
    required this.horizontalSpeed,
    required this.angle,
    required this.spinSpeed,
    required this.color,
    required this.shapeType,
  });
}

class ConfettiPainter extends CustomPainter {
  final List<ConfettiParticle> particles;
  final double animationValue;

  ConfettiPainter(this.particles, this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final paint = Paint()..style = PaintingStyle.fill;

    for (final particle in particles) {
      final currentY = ((particle.y + animationValue * particle.speed) % 1.4 - 0.2) * size.height;
      final currentX = (particle.x + math.sin((animationValue * math.pi * 2) * particle.horizontalSpeed) * 0.05) * size.width;
      final currentAngle = particle.angle + math.pi * 4 * particle.spinSpeed;

      canvas.save();
      canvas.translate(currentX, currentY);
      canvas.rotate(currentAngle);
      paint.color = particle.color;

      if (particle.shapeType == 0) {
        // Circle
        canvas.drawCircle(Offset.zero, 5.0, paint);
      } else if (particle.shapeType == 1) {
        // Ribbon / Rectangle
        canvas.drawRect(const Rect.fromLTWH(-6.0, -3.0, 12.0, 6.0), paint);
      } else {
        // Star / Diamond
        final path = Path();
        path.moveTo(0, -7);
        path.lineTo(3, -1);
        path.lineTo(7, 0);
        path.lineTo(3, 1);
        path.lineTo(0, 7);
        path.lineTo(-3, 1);
        path.lineTo(-7, 0);
        path.lineTo(-3, -1);
        path.close();
        canvas.drawPath(path, paint);
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant ConfettiPainter oldDelegate) => true;
}
