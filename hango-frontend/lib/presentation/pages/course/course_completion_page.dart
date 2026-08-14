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

const String _hangoLogoUrl =
    'https://res.cloudinary.com/diqekap4o/image/upload/v1781621071/logo_ayqvq4.png';

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
  Map<String, dynamic>? _certificateData;

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

      final cert = await _courseRepository.fetchCertificate(widget.courseId);

      if (_courseDetail == null) {
        final fetched = await _courseRepository.fetchCourseDetail(
          widget.courseId,
        );
        if (mounted) {
          setState(() {
            _courseDetail = fetched;
            _certificateData = cert;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _certificateData = cert;
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

  void _shareAchievement() {
    final title =
        _certificateData?['courseTitle'] ?? _courseDetail?.title ?? 'a course';
    final credentialId = _certificateData?['credentialId'] ?? _achievementId;
    final shareText = LanguageManager.isVi
        ? 'Tôi vừa hoàn thành khóa học "$title" trên HanGo. Credential ID: $credentialId'
        : 'I just completed "$title" on HanGo. Credential ID: $credentialId';

    Clipboard.setData(ClipboardData(text: shareText));
    ToastHelper.showSuccess(
      context,
      LanguageManager.isVi
          ? 'Đã sao chép thông tin thành tích vào clipboard!'
          : 'Achievement details copied to clipboard!',
    );
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
        spinSpeed:
            (random.nextBool() ? 1 : -1) * (0.5 + random.nextDouble() * 1.5),
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
        ToastHelper.showError(context, e.toString().replaceFirst('Exception: ', ''));
      }
    }
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
                    builder: (context) =>
                        CourseDetailPage(courseId: widget.courseId),
                  ),
                );
              },
              icon: const Icon(
                Icons.menu_book_rounded,
                size: 18,
                color: Color(0xFF20B486),
              ),
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
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF20B486)),
                )
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
    final learnerName = _certificateData?['learnerName'] ?? _userName;
    final courseTitle =
        _certificateData?['courseTitle'] ??
        _courseDetail?.title ??
        (isVi ? 'Khóa học kiến thức chuyên sâu' : 'Mastery Learning Course');
    final credentialId = _certificateData?['credentialId'] ?? _achievementId;
    final trainerName = _certificateData?['trainerName'] ?? 'HanGo Trainer';
    final issuedAt = _certificateData?['issuedAt'] != null
        ? DateTime.tryParse(_certificateData!['issuedAt']) ?? DateTime.now()
        : DateTime.now();
    final dateStr = '${issuedAt.day}/${issuedAt.month}/${issuedAt.year}';

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 640;

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.14),
                blurRadius: 30,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFFFFEF7), Color(0xFFF8FAFC)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: CustomPaint(painter: CertificatePatternPainter()),
                ),
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: const Color(0xFF94A3B8),
                          width: 1.2,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.6),
                          width: 1,
                        ),
                      ),
                    ),
                  ),
                ),
                const Positioned(
                  top: 16,
                  left: 16,
                  child: _CertificateCorner(),
                ),
                const Positioned(
                  top: 16,
                  right: 16,
                  child: _CertificateCorner(turns: 1),
                ),
                const Positioned(
                  bottom: 16,
                  right: 16,
                  child: _CertificateCorner(turns: 2),
                ),
                const Positioned(
                  bottom: 16,
                  left: 16,
                  child: _CertificateCorner(turns: 3),
                ),
                if (!isCompact)
                  Positioned(
                    top: 0,
                    right: 54,
                    bottom: 58,
                    child: _CertificateRibbon(isCompact: false),
                  )
                else
                  Positioned(
                    top: 24,
                    left: 28,
                    right: 28,
                    child: _CertificateRibbon(isCompact: true),
                  ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    isCompact ? 30 : 54,
                    isCompact ? 122 : 48,
                    isCompact ? 30 : 240,
                    isCompact ? 224 : 150,
                  ),
                  child: Column(
                    crossAxisAlignment: isCompact
                        ? CrossAxisAlignment.center
                        : CrossAxisAlignment.start,
                    children: [
                      _buildCertificateLogoRow(isCompact),
                      SizedBox(height: isCompact ? 28 : 42),
                      Text(
                        'CERTIFICATE OF COMPLETION',
                        textAlign: isCompact
                            ? TextAlign.center
                            : TextAlign.left,
                        style: TextStyle(
                          fontSize: isCompact ? 23 : 30,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF0F172A),
                          letterSpacing: 2.2,
                          fontFamily: 'Outfit',
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        width: isCompact ? 108 : 132,
                        height: 3,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF20B486), Color(0xFFF59E0B)],
                          ),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        isVi
                            ? 'Chứng nhận học viên'
                            : 'This is to proudly certify that',
                        textAlign: isCompact
                            ? TextAlign.center
                            : TextAlign.left,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Color(0xFF64748B),
                          fontStyle: FontStyle.italic,
                          fontFamily: 'Outfit',
                        ),
                      ),
                      const SizedBox(height: 12),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: isCompact
                            ? Alignment.center
                            : Alignment.centerLeft,
                        child: Text(
                          learnerName,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: isCompact ? 39 : 48,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF111827),
                            fontFamily: 'Outfit',
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        isVi
                            ? 'đã hoàn thành xuất sắc khóa học'
                            : 'has successfully completed the course',
                        textAlign: isCompact
                            ? TextAlign.center
                            : TextAlign.left,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Color(0xFF64748B),
                          fontFamily: 'Outfit',
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        courseTitle,
                        maxLines: isCompact ? 3 : 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: isCompact
                            ? TextAlign.center
                            : TextAlign.left,
                        style: TextStyle(
                          fontSize: isCompact ? 22 : 26,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F766E),
                          fontFamily: 'Outfit',
                          height: 1.25,
                        ),
                      ),
                      SizedBox(height: isCompact ? 28 : 44),
                      if (isCompact)
                        Column(
                          children: [
                            _buildCertificateSeal(),
                            const SizedBox(height: 22),
                            _buildCertificateMeta(dateStr, credentialId, true),
                            const SizedBox(height: 22),
                            _buildCertificateSignature(trainerName, true),
                          ],
                        )
                      else
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: _buildCertificateMeta(
                                dateStr,
                                credentialId,
                                false,
                              ),
                            ),
                            _buildCertificateSeal(),
                            Expanded(
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: _buildCertificateSignature(
                                  trainerName,
                                  false,
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _buildCertificateContentFooter(isVi, isCompact),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCertificateLogoRow(bool isCompact) {
    return Row(
      mainAxisAlignment: isCompact
          ? MainAxisAlignment.center
          : MainAxisAlignment.start,
      children: [
        Container(
          width: 58,
          height: 58,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Image.network(
            _hangoLogoUrl,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.school_rounded, color: Color(0xFF20B486)),
          ),
        ),
        const SizedBox(width: 14),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'HanGo',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
                fontFamily: 'Outfit',
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Smart Language Self-Study Platform',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
                fontFamily: 'Outfit',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCertificateMeta(
    String dateStr,
    String credentialId,
    bool centered,
  ) {
    return Column(
      crossAxisAlignment: centered
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        const Text(
          'Issued Date',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Color(0xFF94A3B8),
            fontFamily: 'Outfit',
          ),
        ),
        const SizedBox(height: 5),
        Text(
          dateStr,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: Color(0xFF334155),
            fontFamily: 'Outfit',
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Credential ID',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Color(0xFF94A3B8),
            fontFamily: 'Outfit',
          ),
        ),
        const SizedBox(height: 5),
        SelectableText(
          credentialId,
          textAlign: centered ? TextAlign.center : TextAlign.left,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF475569),
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  Widget _buildCertificateSignature(String trainerName, bool centered) {
    return SizedBox(
      width: 190,
      child: Column(
        crossAxisAlignment: centered
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.end,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              trainerName,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 21,
                fontStyle: FontStyle.italic,
                color: Color(0xFF0F172A),
                fontFamily: 'Outfit',
              ),
            ),
          ),
          Container(
            width: 170,
            height: 1,
            margin: const EdgeInsets.symmetric(vertical: 7),
            color: const Color(0xFF94A3B8),
          ),
          const Text(
            'Course Instructor',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
              fontFamily: 'Outfit',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCertificateSeal() {
    return Container(
      width: 98,
      height: 98,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF7D6), Color(0xFFFBBF24)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0xFFD97706), width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.26),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Container(
        margin: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.48),
          border: Border.all(color: const Color(0xFF92400E), width: 1),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.workspace_premium_rounded, color: Color(0xFF92400E)),
            SizedBox(height: 3),
            Text(
              'VERIFIED',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: Color(0xFF92400E),
                fontFamily: 'Outfit',
              ),
            ),
            Text(
              'HanGo',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: Color(0xFF92400E),
                fontFamily: 'Outfit',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCertificateActions(bool isVi) {
    return Wrap(
      spacing: 16,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: [
        ElevatedButton.icon(
          onPressed: () {
            ToastHelper.showInfo(
              context,
              isVi
                  ? 'Tính năng tải PDF sẽ được bổ sung sau.'
                  : 'PDF download will be added later.',
            );
          },
          icon: const Icon(Icons.download_rounded),
          label: Text(isVi ? 'Tải PDF' : 'Download PDF'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF8FAFC),
            foregroundColor: const Color(0xFF1E293B),
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
            side: const BorderSide(color: Color(0xFFCBD5E1)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        ElevatedButton.icon(
          onPressed: _shareAchievement,
          icon: const Icon(Icons.share_rounded),
          label: Text(isVi ? 'Chia sẻ LinkedIn' : 'Share to LinkedIn'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0A66C2),
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCertificateDisclaimer(bool isVi) {
    return Text(
      isVi
          ? 'HanGo xác nhận học viên đã hoàn tất các bài học bắt buộc của khóa học này. Tổ chức hoặc nhà tuyển dụng có thể dùng Credential ID để đối chiếu khi tính năng xác minh công khai được bật.'
          : 'HanGo confirms the learner completed the required lessons for this course. Organizations may use the Credential ID for verification when public verification is enabled.',
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 10.5,
        height: 1.45,
        color: Color(0xFF94A3B8),
        fontFamily: 'Outfit',
      ),
    );
  }

  Widget _buildCertificateContentFooter(bool isVi, bool isCompact) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        isCompact ? 24 : 46,
        0,
        isCompact ? 24 : 46,
        isCompact ? 28 : 34,
      ),
      child: Column(
        children: [
          _buildCertificateActions(isVi),
          const SizedBox(height: 20),
          _buildCertificateDisclaimer(isVi),
        ],
      ),
    );
  }

  Widget _buildMasteryStatsGrid(bool isVi) {
    int totalLessons = 0;
    int totalSessions = 0;
    if (_courseDetail != null) {
      totalSessions = _courseDetail!.sessions.length;
      totalLessons = _courseDetail!.sessions.fold(
        0,
        (sum, s) => sum + s.lessons.length,
      );
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
        'value': totalLessons > 0
            ? '$totalLessons/$totalLessons'
            : (isVi ? 'Hoàn tất' : 'All Mastered'),
        'sub': isVi ? 'Toàn bộ nội dung' : 'Full Curriculum',
        'icon': Icons.play_lesson_rounded,
        'color': const Color(0xFFF59E0B),
        'bg': const Color(0xFFFFFBEB),
      },
      {
        'title': isVi ? 'Cấu trúc chương học' : 'Course Modules',
        'value': totalSessions > 0
            ? '$totalSessions ${isVi ? 'Chương' : 'Sessions'}'
            : (isVi ? 'Trọn gói' : 'Complete'),
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
                    child: Icon(
                      item['icon'] as IconData,
                      color: color,
                      size: 20,
                    ),
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
              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isVi
                        ? 'Cảm ơn bạn đã đánh giá!'
                        : 'Thank You For Your Feedback!',
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
                child: const Icon(
                  Icons.rate_review_rounded,
                  color: Color(0xFFF59E0B),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isVi
                          ? 'Cảm nhận của bạn về khóa học?'
                          : 'How was your learning experience?',
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        fontFamily: 'Outfit',
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isVi
                          ? 'Chia sẻ đánh giá để giúp cộng đồng phát triển'
                          : 'Leave a rating to guide future learners',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                        fontFamily: 'Outfit',
                      ),
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
                      isSelected
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: isSelected
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFFCBD5E1),
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
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFFD97706),
                fontFamily: 'Outfit',
              ),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _reviewController,
            maxLines: 4,
            maxLength: 350,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF1E293B),
              fontFamily: 'Outfit',
            ),
            decoration: InputDecoration(
              hintText: isVi
                  ? 'Viết cảm nhận của bạn về chất lượng giảng dạy, nội dung bài giảng, mức độ dễ hiểu và tính ứng dụng của khóa học...'
                  : 'Share your thoughts on the course structure, instructor explanations, and real-world usefulness...',
              hintStyle: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 13.5,
              ),
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
                borderSide: const BorderSide(
                  color: Color(0xFF20B486),
                  width: 1.5,
                ),
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
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded, size: 18),
                label: Text(
                  isVi ? 'Gửi đánh giá ngay' : 'Submit Feedback',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Outfit',
                    fontSize: 14.5,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
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
                child: const Icon(
                  Icons.explore_rounded,
                  color: Color(0xFF3B82F6),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isVi
                          ? 'Bước tiếp theo trên hành trình?'
                          : 'What\'s Next on Your Journey?',
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        fontFamily: 'Outfit',
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isVi
                          ? 'Duy trì nhịp độ học tập để bứt phá kỹ năng'
                          : 'Keep up your momentum and unlock new skills',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
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
                        MaterialPageRoute(
                          builder: (context) => const LearningPathwayPage(),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.auto_awesome_rounded,
                      size: 18,
                      color: Color(0xFFF59E0B),
                    ),
                    label: Text(
                      isVi ? 'Khám phá Lộ trình AI ➔' : 'Explore AI Pathway ➔',
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Outfit',
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
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
                        MaterialPageRoute(
                          builder: (context) => const MyLearningPage(),
                        ),
                        (route) => route.isFirst,
                      );
                    },
                    icon: const Icon(Icons.dashboard_rounded, size: 18),
                    label: Text(
                      isVi ? 'Về Bảng điều khiển' : 'My Learning Dashboard',
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Outfit',
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF475569),
                      side: const BorderSide(
                        color: Color(0xFFCBD5E1),
                        width: 1.5,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
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
      isVi
          ? 'Nắm vững kiến thức cốt lõi và tư duy hệ thống từ bài giảng'
          : 'Mastered core concepts and systematic thinking',
      isVi
          ? 'Hoàn thành 100% các bài trắc nghiệm và thực hành kỹ năng'
          : 'Completed 100% of quizzes and skill exercises',
      isVi
          ? 'Sẵn sàng áp dụng kiến thức vào thực tế và các khóa nâng cao'
          : 'Ready to apply knowledge to real-world scenarios',
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
              const Icon(
                Icons.lightbulb_rounded,
                color: Color(0xFF20B486),
                size: 22,
              ),
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
          ...takeaways.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.check_circle_outline_rounded,
                      color: Color(0xFF20B486),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: Color(0xFF475569),
                        height: 1.4,
                        fontFamily: 'Outfit',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CertificateRibbon extends StatelessWidget {
  final bool isCompact;

  const _CertificateRibbon({required this.isCompact});

  @override
  Widget build(BuildContext context) {
    if (isCompact) {
      return Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFE8F7F2), Color(0xFFF8FAFC)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.verified_rounded, color: Color(0xFF0F766E), size: 22),
            SizedBox(width: 10),
            Flexible(
              child: Text(
                'COURSE CERTIFICATE',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                  letterSpacing: 2,
                  fontFamily: 'Outfit',
                ),
              ),
            ),
          ],
        ),
      );
    }

    return ClipPath(
      clipper: _RibbonClipper(),
      child: Container(
        width: 164,
        padding: const EdgeInsets.fromLTRB(20, 80, 20, 92),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFE8F7F2), Color(0xFFF1F5F9)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            RotatedBox(
              quarterTurns: 1,
              child: Text(
                'COURSE CERTIFICATE',
                maxLines: 1,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                  letterSpacing: 3,
                  fontFamily: 'Outfit',
                ),
              ),
            ),
            SizedBox(height: 28),
            Icon(Icons.verified_rounded, color: Color(0xFF0F766E), size: 42),
          ],
        ),
      ),
    );
  }
}

class _CertificateCorner extends StatelessWidget {
  final int turns;

  const _CertificateCorner({this.turns = 0});

  @override
  Widget build(BuildContext context) {
    return RotatedBox(
      quarterTurns: turns,
      child: SizedBox(
        width: 28,
        height: 28,
        child: CustomPaint(painter: _CertificateCornerPainter()),
      ),
    );
  }
}

class _RibbonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height - 78)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(0, size.height - 78)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _CertificateCornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF94A3B8)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    final accentPaint = Paint()
      ..color = const Color(0xFFF59E0B)
      ..style = PaintingStyle.fill;

    canvas.drawPath(
      Path()
        ..moveTo(0, size.height)
        ..lineTo(0, 0)
        ..lineTo(size.width, 0),
      paint,
    );
    canvas.drawRect(const Rect.fromLTWH(5, 5, 6, 6), accentPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class CertificatePatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = const Color(0xFF20B486).withValues(alpha: 0.045)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final goldPaint = Paint()
      ..color = const Color(0xFFF59E0B).withValues(alpha: 0.065)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    final watermarkPaint = Paint()
      ..color = const Color(0xFF0F172A).withValues(alpha: 0.028)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (var i = 0; i < 8; i++) {
      final top = size.height * (0.2 + i * 0.075);
      final path = Path()
        ..moveTo(-40, top)
        ..cubicTo(
          size.width * 0.24,
          top - 42,
          size.width * 0.34,
          top + 46,
          size.width * 0.56,
          top,
        )
        ..cubicTo(
          size.width * 0.74,
          top - 36,
          size.width * 0.88,
          top + 34,
          size.width + 40,
          top - 8,
        );
      canvas.drawPath(path, linePaint);
    }

    canvas.drawCircle(
      Offset(size.width * 0.74, size.height * 0.44),
      math.min(size.width, size.height) * 0.22,
      watermarkPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.74, size.height * 0.44),
      math.min(size.width, size.height) * 0.16,
      watermarkPaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.06, size.height * 0.86)
        ..lineTo(size.width * 0.34, size.height * 0.86)
        ..moveTo(size.width * 0.66, size.height * 0.86)
        ..lineTo(size.width * 0.94, size.height * 0.86),
      goldPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
      final currentY =
          ((particle.y + animationValue * particle.speed) % 1.4 - 0.2) *
          size.height;
      final currentX =
          (particle.x +
              math.sin(
                    (animationValue * math.pi * 2) * particle.horizontalSpeed,
                  ) *
                  0.05) *
          size.width;
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
