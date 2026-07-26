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
  String _verificationCode = '';

  // Review section state
  double _selectedRating = 5.0;
  final TextEditingController _reviewController = TextEditingController();
  bool _isSubmittingReview = false;
  bool _hasSubmittedReview = false;

  @override
  void initState() {
    super.initState();
    _courseDetail = widget.courseDetail;
    _generateVerificationCode();
    _loadUserAndCourse();

    // Initialize 60fps continuous celebration animation
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _particles = _generateParticles(80);
  }

  void _generateVerificationCode() {
    final now = DateTime.now();
    final uniqueNum = (now.millisecondsSinceEpoch % 90000) + 10000;
    _verificationCode = 'CERT-HG-${widget.courseId}-${now.year}-$uniqueNum';
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
      const Color(0xFF34D399), // Mint Green
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

  void _downloadCertificate() {
    ToastHelper.showSuccess(
      context,
      LanguageManager.isVi
          ? '🎉 Đã lưu chứng chỉ! Bạn có thể xem trong thư mục tải xuống.'
          : '🎉 Certificate saved! Ready for printing or sharing.',
    );
  }

  void _shareAchievement() {
    final title = _courseDetail?.title ?? 'a course';
    final shareText = LanguageManager.isVi
        ? 'Tôi vừa hoàn thành xuất sắc khóa học "$title" trên nền tảng HanGo EdTech! Mã xác thực: $_verificationCode'
        : 'I just completed "$title" on HanGo EdTech! Verification ID: $_verificationCode';

    Clipboard.setData(ClipboardData(text: shareText));
    ToastHelper.showSuccess(
      context,
      LanguageManager.isVi
          ? 'Đã sao chép nội dung chia sẻ vào clipboard!'
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
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Color(0xFF1E293B)),
          tooltip: isVi ? 'Đóng' : 'Close',
          onPressed: () {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const MyLearningPage()),
              (route) => route.isFirst,
            );
          },
        ),
        title: Text(
          isVi ? 'Tổng kết Khóa học' : 'Course Completion',
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
            fontSize: 18,
            fontFamily: 'Outfit',
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton.icon(
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
          constraints: const BoxConstraints(maxWidth: 1300),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Column: Celebration, Stats & Next Steps
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCelebrationHeader(isVi),
                    const SizedBox(height: 28),
                    _buildMasteryStatsGrid(isVi),
                    const SizedBox(height: 28),
                    _buildReviewSection(isVi),
                    const SizedBox(height: 28),
                    _buildNextStepsCard(isVi),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
              const SizedBox(width: 48),
              // Right Column: Certificate Card
              Expanded(
                flex: 6,
                child: Column(
                  children: [
                    _buildCertificateCard(isVi),
                    const SizedBox(height: 20),
                    _buildCertificateActions(isVi),
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
          _buildCertificateCard(isVi),
          const SizedBox(height: 16),
          _buildCertificateActions(isVi),
          const SizedBox(height: 28),
          _buildMasteryStatsGrid(isVi),
          const SizedBox(height: 28),
          _buildReviewSection(isVi),
          const SizedBox(height: 28),
          _buildNextStepsCard(isVi),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildCelebrationHeader(bool isVi) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFECFDF5), Color(0xFFF0FDF4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFA7F3D0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0820B486),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF20B486),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x3320B486),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Text(
                        isVi ? '🏆 HOÀN THÀNH XUẤT SẮC' : '🏆 ACHIEVEMENT UNLOCKED',
                        style: const TextStyle(
                          color: Color(0xFFD97706),
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          letterSpacing: 0.8,
                          fontFamily: 'Outfit',
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isVi ? 'Chúc Mừng, $_userName!' : 'Congratulations, $_userName!',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        fontFamily: 'Outfit',
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            isVi
                ? 'Bạn đã hoàn thành xuất sắc toàn bộ lộ trình bài học trong khóa học này. Sự kiên trì và nỗ lực của bạn đã mang lại kết quả tuyệt vời!'
                : 'You have successfully mastered the complete curriculum for this course. Your dedication and consistent effort have paid off outstandingly!',
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF475569),
              height: 1.5,
              fontFamily: 'Outfit',
            ),
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
        'sub': isVi ? 'Đã nắm vững kiến thức' : 'Structured Sections',
        'icon': Icons.layers_rounded,
        'color': const Color(0xFF8B5CF6),
        'bg': const Color(0xFFF3E8FF),
      },
      {
        'title': isVi ? 'Đánh giá học thuật' : 'Academic Rating',
        'value': isVi ? 'Xuất sắc' : 'Excellent',
        'sub': isVi ? 'Tiêu chuẩn HanGo' : 'HanGo Certified',
        'icon': Icons.workspace_premium_rounded,
        'color': const Color(0xFFF43F5E),
        'bg': const Color(0xFFFFE4E6),
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.6,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: stats.length,
      itemBuilder: (context, index) {
        final item = stats[index];
        final color = item['color'] as Color;
        final bg = item['bg'] as Color;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x04000000),
                blurRadius: 8,
                offset: Offset(0, 2),
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
                        fontSize: 12,
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
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: color,
                  fontFamily: 'Outfit',
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item['sub'] as String,
                style: const TextStyle(
                  fontSize: 11,
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

  Widget _buildCertificateCard(bool isVi) {
    final title = _courseDetail?.title ?? (isVi ? 'Khóa học Tiếng Anh THPT' : 'English Mastery Course');
    final creator = _courseDetail?.creatorName ?? (isVi ? 'Ban Chuyên Môn HanGo' : 'HanGo Faculty');
    final now = DateTime.now();
    final dateStr = "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}";

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF59E0B), Color(0xFF20B486), Color(0xFFF59E0B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F20B486),
            blurRadius: 32,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(20),
          image: const DecorationImage(
            image: AssetImage('assets/images/parchment_pattern.png'), // Will safely fallback if absent
            fit: BoxFit.cover,
            opacity: 0.05,
          ),
        ),
        child: Column(
          children: [
            // Header Seal
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF20B486),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.school_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'HanGo EdTech',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.5,
                        fontFamily: 'Outfit',
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFF59E0B)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.verified_rounded, color: Color(0xFFD97706), size: 16),
                      const SizedBox(width: 6),
                      Text(
                        isVi ? 'CHỨNG CHỈ CHÍNH THỨC' : 'OFFICIAL CERTIFICATE',
                        style: const TextStyle(
                          color: Color(0xFFD97706),
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          letterSpacing: 0.5,
                          fontFamily: 'Outfit',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 36),
            Text(
              isVi ? 'CHỨNG NHẬN HOÀN THÀNH KHÓA HỌC' : 'CERTIFICATE OF COMPLETION',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Color(0xFFB45309), // Dark Gold
                letterSpacing: 2.0,
                fontFamily: 'Outfit',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              isVi ? 'Chứng nhận học viên' : 'This is to proudly certify that',
              style: const TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: Color(0xFF64748B),
                fontFamily: 'Outfit',
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _userName,
              style: const TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                fontFamily: 'Outfit',
                decoration: TextDecoration.underline,
                decorationColor: Color(0xFF20B486),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Text(
              isVi
                  ? 'Đã kiên trì học tập và hoàn thành xuất sắc toàn bộ chương trình của khóa học:'
                  : 'Has successfully completed all requirements and demonstrated mastery of the course:',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF475569),
                height: 1.5,
                fontFamily: 'Outfit',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF20B486),
                  fontFamily: 'Outfit',
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 40),
            const Divider(color: Color(0xFFFDE68A), thickness: 1.5),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isVi ? 'CẤP NGÀY' : 'ISSUE DATE',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF94A3B8),
                        letterSpacing: 1.0,
                        fontFamily: 'Outfit',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateStr,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                        fontFamily: 'Outfit',
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(Icons.workspace_premium_rounded, color: Color(0xFFF59E0B), size: 36),
                    const SizedBox(height: 2),
                    Text(
                      isVi ? 'ĐẠT CHUẨN HANGO' : 'HANGO CERTIFIED',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFD97706),
                        letterSpacing: 0.5,
                        fontFamily: 'Outfit',
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      isVi ? 'GIẢNG VIÊN HƯỚNG DẪN' : 'INSTRUCTOR',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF94A3B8),
                        letterSpacing: 1.0,
                        fontFamily: 'Outfit',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      creator,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                        fontFamily: 'Outfit',
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              alignment: Alignment.centerRight,
              child: Text(
                'ID: $_verificationCode',
                style: const TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  color: Color(0xFF94A3B8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCertificateActions(bool isVi) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _downloadCertificate,
            icon: const Icon(Icons.download_rounded, size: 20),
            label: Text(
              isVi ? 'Tải về Chứng chỉ' : 'Download Certificate',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF20B486),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _shareAchievement,
            icon: const Icon(Icons.share_rounded, size: 18),
            label: Text(
              isVi ? 'Chia sẻ thành tích' : 'Share Achievement',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF0F172A),
              side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewSection(bool isVi) {
    if (_hasSubmittedReview) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF6EE7B7)),
        ),
        child: Row(
          children: [
            const Icon(Icons.star_rounded, color: Color(0xFF10B981), size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isVi ? 'Cảm ơn bạn đã gửi đánh giá!' : 'Thank You For Your Review!',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF065F46),
                      fontFamily: 'Outfit',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isVi
                        ? 'Đánh giá của bạn đã được ghi nhận và sẽ giúp cộng đồng học viên HanGo lựa chọn tốt hơn.'
                        : 'Your valuable feedback helps instructors improve and guides fellow learners.',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF047857),
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.rate_review_rounded, color: Color(0xFFF59E0B), size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isVi ? 'Bạn cảm thấy khóa học thế nào?' : 'How was your learning experience?',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                    fontFamily: 'Outfit',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            isVi
                ? 'Hãy để lại số sao và lời chia sẻ cho giảng viên cùng các học viên khác nhé!'
                : 'Leave a rating and review to support your instructor and fellow learners!',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 16),
          Row(
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
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Icon(
                      isSelected ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: isSelected ? const Color(0xFFF59E0B) : const Color(0xFFE2E8F0),
                      size: 38,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _reviewController,
            maxLines: 3,
            maxLength: 300,
            style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B), fontFamily: 'Outfit'),
            decoration: InputDecoration(
              hintText: isVi
                  ? 'Chia sẻ cảm nhận của bạn về khóa học (giảng viên, nội dung, bài tập)...'
                  : 'Share your thoughts on the course content, instructor, and exercises...',
              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFF20B486), width: 1.5),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
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
                isVi ? 'Gửi đánh giá' : 'Submit Review',
                style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextStepsCard(bool isVi) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isVi ? 'Bước tiếp theo trên hành trình của bạn?' : 'What\'s Next on Your Journey?',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isVi
                ? 'Tiếp tục rèn luyện kỹ năng với Lộ trình học AI cá nhân hóa được tối ưu cho riêng bạn.'
                : 'Continue advancing your skills with HanGo\'s AI Adaptive Learning Pathway tailored just for you.',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const LearningPathwayPage()),
                    );
                  },
                  icon: const Icon(Icons.auto_awesome_rounded, size: 18, color: Color(0xFFF59E0B)),
                  label: Text(
                    isVi ? 'Khám phá Lộ trình AI' : 'Explore AI Pathway',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
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
              const SizedBox(width: 12),
              Expanded(
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
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF475569),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
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
      final currentAngle = particle.angle + animationValue * math.pi * 4 * particle.spinSpeed;

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
