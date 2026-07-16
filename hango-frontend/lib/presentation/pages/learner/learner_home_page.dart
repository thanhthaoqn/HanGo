import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/repositories/course_repository.dart';
import '../../../domain/model/course.dart';
import '../../../domain/entities/exam.dart';
import '../../../data/repositories/exam_repository.dart';
import '../login_page.dart';
import '../register_page.dart';
import '../exam/list_exams_page.dart';
import '../exam/exam_detail_history_page.dart';
import '../course/list_courses_page.dart';
import '../course/course_detail_page.dart';
import '../../widgets/shared_header.dart';
import '../../../utils/language_manager.dart';
import '../../widgets/shared_footer.dart';
import 'learning_pathway_page.dart';
import '../exam/take_exam_page.dart';
import '../trainer/trainer_dashboard_page.dart';
import '../trainer/onboarding/trainer_type_selection_page.dart';
import '../trainer/onboarding/trainer_onboarding_status_page.dart';
import '../../../data/services/trainer_onboarding_service.dart';
import '../../../utils/toast_helper.dart';

class LearnerHomePage extends StatefulWidget {
  const LearnerHomePage({super.key});

  @override
  State<LearnerHomePage> createState() => _LearnerHomePageState();
}

class _LearnerHomePageState extends State<LearnerHomePage> {
  final _authService = AuthService();
  final _courseRepository = CourseRepository();
  final _examRepository = ExamRepository();

  String _userFullName = 'Learner';
  String _userEmail = '';
  String _userInitials = 'L';

  // State variables for active tabs
  String _activeCourseTab =
      'featured'; // 'featured' | 'in_progress' | 'completed'
  String _activeExamTab = 'featured'; // 'featured' | 'completed'

  List<Course> _courses = [];
  List<Exam> _exams = [];
  bool _isLoadingCourses = true;
  bool _isLoadingExams = true;

  Timer? _bannerTimer;
  int _currentBannerIndex = 0;

  void _startBannerTimer() {
    _bannerTimer?.cancel();
    _bannerTimer = Timer.periodic(const Duration(seconds: 7), (timer) {
      if (mounted) {
        setState(() {
          _currentBannerIndex = (_currentBannerIndex + 1) % 2;
        });
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _fetchCourses();
    _fetchExams();
    _startBannerTimer();
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    super.dispose();
  }

  // Fetch logged in user info from SharedPreferences
  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final fullName = prefs.getString('user_fullname') ?? 'Learner';
    final email = prefs.getString('user_email') ?? '';
    final userId = prefs.getInt('user_id') ?? 0;

    String initials = 'L';
    if (fullName.trim().isNotEmpty) {
      final parts = fullName.trim().split(' ');
      if (parts.isNotEmpty) {
        initials = parts.last[0].toUpperCase();
      }
    }

    setState(() {
      _userFullName = fullName;
      _userEmail = email;
      _userInitials = initials;
    });

    if (userId != 0) {
      final showOnboardingKey = 'show_onboarding_for_$userId';
      final showOnboarding = prefs.getBool(showOnboardingKey) ?? false;
      if (showOnboarding) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showOnboardingPopup(userId, showOnboardingKey);
        });
      }
    }
  }

  void _handleTeachingClick() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    
    if (token == null) {
      await prefs.setBool('redirect_to_trainer_onboarding', true);
      await prefs.setString('preselected_register_role', 'TRAINER');
      if (mounted) {
        ToastHelper.show(context, LanguageManager.isVi ? 'Vui lòng đăng ký tài khoản giảng viên để bắt đầu' : 'Please register a trainer account to start');
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const RegisterPage()),
        );
      }
      return;
    }

    final roles = prefs.getStringList('user_roles') ?? [];
    final isTrainer = roles.any((r) => r.toUpperCase().contains('TRAINER'));

    if (!isTrainer) {
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const TrainerTypeSelectionPage()),
        );
      }
    } else {
      _checkStatusAndRoute();
    }
  }

  void _checkStatusAndRoute() async {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF28B79B)),
      ),
    );

    try {
      final onboardingService = TrainerOnboardingService();
      final result = await onboardingService.getTrainerProfile();
      
      if (mounted) {
        Navigator.pop(context); // Close loading
      }

      if (result['success'] == true) {
        final profile = result['data'];
        final status = profile['status'] ?? 'PENDING_VERIFICATION';

        if (status == 'VERIFIED') {
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const TrainerDashboardPage()),
            );
          }
        } else {
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => TrainerOnboardingStatusPage(initialProfile: profile)),
            );
          }
        }
      } else {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const TrainerTypeSelectionPage()),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ToastHelper.showError(context, 'Lỗi kết nối máy chủ');
      }
    }
  }

  void _showOnboardingPopup(int userId, String showOnboardingKey) {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 12,
          backgroundColor: Colors.white,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Celebration Icon
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Color(0xFFE6F4EA),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.celebration_rounded,
                    color: Color(0xFF28B79B),
                    size: 36,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Welcome to HanGo!',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Since this is your first time logging in, what activity would you like to start with today?',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                
                // Two Option Cards
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Option 1: Practice Test (Thi thử)
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool(showOnboardingKey, false);
                            if (!mounted) return;
                            Navigator.pop(ctx); // Close dialog

                            // Show a loading indicator
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (loadingCtx) => const Center(
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF28B79B)),
                                ),
                              ),
                            );

                            try {
                              final exams = await _examRepository.fetchExams(status: 'PUBLISHED');
                              
                              if (!mounted) return;
                              Navigator.pop(context); // Close loading indicator

                              if (exams.isNotEmpty) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => TakeExamPage(exam: exams.first),
                                  ),
                                );
                              } else {
                                // Fallback exam
                                final fallbackExam = Exam(
                                  id: '1',
                                  title: 'Đề thi thử Tốt nghiệp THPT Quốc Gia môn Tiếng Anh',
                                  description: 'Bài thi khảo sát năng lực Tiếng Anh dành cho học sinh chuẩn bị thi THPT Quốc Gia.',
                                  creatorName: 'Bộ Giáo Dục và Đào Tạo',
                                  questionCount: 40,
                                  durationMinutes: 50,
                                  rating: 5.0,
                                  learnerCountFormatted: '152k Learner',
                                );
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => TakeExamPage(exam: fallbackExam),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (!mounted) return;
                              Navigator.pop(context); // Close loading indicator
                              
                              // Fallback exam in case of network/API error
                              final fallbackExam = Exam(
                                id: '1',
                                title: 'Đề thi thử Tốt nghiệp THPT Quốc Gia môn Tiếng Anh',
                                description: 'Bài thi khảo sát năng lực Tiếng Anh dành cho học sinh chuẩn bị thi THPT Quốc Gia.',
                                creatorName: 'Bộ Giáo Dục và Đào Tạo',
                                questionCount: 40,
                                durationMinutes: 50,
                                rating: 5.0,
                                learnerCountFormatted: '152k Learner',
                              );
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => TakeExamPage(exam: fallbackExam),
                                ),
                              );
                            }
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              borderRadius: BorderRadius.circular(16),
                              color: const Color(0xFFF8FAFC),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFEFF6FF),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.assignment_outlined,
                                    color: Colors.blueAccent,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Practice Exams',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E293B),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Take mock exams designed to match the official exam structure',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF64748B),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Option 2: Courses (Học khóa học)
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool(showOnboardingKey, false);
                            if (!mounted) return;
                            Navigator.pop(ctx); // Close dialog
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const ListCoursesPage()),
                            );
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              borderRadius: BorderRadius.circular(16),
                              color: const Color(0xFFF8FAFC),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFECFDF5),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.school_outlined,
                                    color: Color(0xFF10B981),
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Study Courses',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E293B),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Learn systematic knowledge and practice with exercises',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF64748B),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
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

  // Load courses depending on selected tab
  Future<void> _fetchCourses() async {
    setState(() {
      _isLoadingCourses = true;
    });
    try {
      String filterType = 'ALL';
      if (_activeCourseTab == 'in_progress') {
        filterType = 'IN_PROGRESS';
      } else if (_activeCourseTab == 'completed') {
        filterType = 'COMPLETED';
      }
      final courses = await _courseRepository.fetchCourses(
        filterType: filterType,
      );
      final cleanCourses = courses.where((c) {
        final title = c.title.toLowerCase();
        final cat = c.category.toLowerCase();
        return !title.contains('ielts') && !title.contains('toeic') &&
               !title.contains('giao tiếp') && !title.contains('communication') &&
               !title.contains('chứng chỉ') && !cat.contains('ielts') &&
               !cat.contains('toeic') && !cat.contains('giao tiếp') &&
               !cat.contains('communication') && !cat.contains('chứng chỉ');
      }).toList();
      setState(() {
        _courses = cleanCourses;
        _isLoadingCourses = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingCourses = false;
      });
    }
  }

  // Load exams depending on selected tab
  Future<void> _fetchExams() async {
    setState(() {
      _isLoadingExams = true;
    });
    try {
      final exams = await _examRepository.fetchExams(
        status: _activeExamTab == 'featured' ? 'PUBLISHED' : _activeExamTab,
      );
      setState(() {
        _exams = exams;
        _isLoadingExams = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingExams = false;
      });
    }
  }

  // Handle user logout
  void _handleLogout() async {
    await _authService.logout();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;

    return ValueListenableBuilder<bool>(
      valueListenable: LanguageManager.isVietnamese,
      builder: (context, isVi, child) {
        return Scaffold(
          backgroundColor: const Color(0xFFF9FAFB),
          appBar: SharedHeader(isDesktop: isDesktop, activeTab: ''),
          drawer: isDesktop ? null : _buildDrawer(context),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Hero Banner (Edge-to-edge)
                _buildHeroBanner(isDesktop),

                // Main Content Area (centered with max width for clean desktop layouts)
                Center(
                  child: Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 1440),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),

                        // 2. Courses Section
                        _buildCoursesSection(isDesktop),
                        const SizedBox(height: 60),

                        // 3. Exams Section
                        _buildExamsSection(isDesktop),
                        const SizedBox(height: 60),

                        // 4. Trở thành giảng viên Section
                        _buildTeacherSection(isDesktop),
                        const SizedBox(height: 60),

                        // 5. Testimonial Section
                        _buildTestimonialSection(isDesktop),
                        const SizedBox(height: 60),

                        // 6. CTA Banner
                        _buildCtaBannerSection(isDesktop),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),

                // 7. Footer
                SharedFooter(isDesktop: isDesktop),
              ],
            ),
          ),
        );
      },
    );
  }

  // Adaptive drawer for mobile layouts
  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFF28B79B)),
            accountName: Text(
              _userFullName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            accountEmail: Text(_userEmail),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                _userInitials,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF28B79B),
                ),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Exams'),
            onTap: () {
              Navigator.pop(context); // close drawer
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ListExamsPage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.school_outlined),
            title: const Text('Courses'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ListCoursesPage(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.route_outlined),
            title: const Text('Learning Pathway'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const LearningPathwayPage(),
                ),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text(
              'Log Out',
              style: TextStyle(color: Colors.redAccent),
            ),
            onTap: () {
              Navigator.pop(context);
              _handleLogout();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeroBanner(bool isDesktop) {
    final isVi = LanguageManager.isVi;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 800),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      child: _currentBannerIndex == 0
          ? _buildStudentHeroBanner(isDesktop, isVi)
          : _buildTeacherHeroBanner(isDesktop, isVi),
    );
  }

  Widget _buildStudentHeroBanner(bool isDesktop, bool isVi) {
    return Container(
      key: const ValueKey('student_hero_banner'),
      width: double.infinity,
      color: const Color(0xFF135D4E),
      child: Stack(
        children: [
          // Layer 1: Background Image
          Positioned.fill(
            child: Image.network(
              'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?q=80&w=1200',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: const Color(0xFF135D4E),
              ),
            ),
          ),

          // Layer 2: Dark Overlay Gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.85),
                    Colors.black.withOpacity(0.55),
                    Colors.black.withOpacity(0.2),
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
                vertical: isDesktop ? 60.0 : 36.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Sparkles Tag
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF28B79B).withOpacity(0.2),
                      border: Border.all(color: const Color(0xFF28B79B), width: 1.5),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.auto_awesome_rounded,
                          size: 14,
                          color: Color(0xFF28B79B),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isVi ? 'Học tiếng Anh cùng giáo viên giỏi' : 'Learn English with top teachers',
                          style: const TextStyle(
                            color: Color(0xFF28B79B),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Outfit',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Main Title
                  Text(
                    isVi ? 'Giỏi tiếng Anh,\nmở lối tương lai.' : 'Master English,\nopen your future.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isDesktop ? 42 : 28,
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                      fontFamily: 'Outfit',
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Description
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 650),
                    child: Text(
                      isVi
                          ? 'Khóa học từ giáo viên hàng đầu và kho đề thi THPTQG miễn phí — tất cả trong một nền tảng hiện đại, dễ dùng. Bạn cũng có thể trở thành giảng viên và tạo khóa học của riêng mình.'
                          : 'Courses from top teachers and free exam prep — all in a modern, easy-to-use platform. You can also become a teacher and create your own courses.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: isDesktop ? 15 : 13,
                        height: 1.5,
                        fontFamily: 'Outfit',
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Action Buttons
                  Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    children: [
                      // Orange filled button
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ListCoursesPage(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF05A22),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 8,
                          shadowColor: const Color(0xFFF05A22).withOpacity(0.4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isVi ? 'Khám phá khóa học' : 'Explore courses',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Outfit',
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_rounded, size: 16),
                          ],
                        ),
                      ),

                      // Outlined button
                      OutlinedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ListExamsPage(),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white, width: 1.5),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.assignment_outlined, size: 16, color: Colors.white),
                            const SizedBox(width: 8),
                            Text(
                              isVi ? 'Luyện đề miễn phí' : 'Practice exams free',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Outfit',
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 36),

                  // Stats Row
                  Wrap(
                    spacing: 48,
                    runSpacing: 16,
                    children: [
                      _buildHeroStat('50+', isVi ? 'Khóa học' : 'Courses'),
                      _buildHeroStat('2.000+', isVi ? 'Học viên' : 'Learners'),
                      _buildHeroStat('30+', isVi ? 'Đề thi miễn phí' : 'Free exams'),
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

  Widget _buildTeacherHeroBanner(bool isDesktop, bool isVi) {
    return Container(
      key: const ValueKey('teacher_hero_banner'),
      width: double.infinity,
      color: const Color(0xFF0F172A), // Slate 900 for modern dark theme
      child: Stack(
        children: [
          // Layer 1: Background Image
          Positioned.fill(
            child: Image.network(
              'https://images.unsplash.com/photo-1524178232363-1fb2b075b655?q=80&w=1200',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: const Color(0xFF0F172A),
              ),
            ),
          ),

          // Layer 2: Dark Overlay Gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.85),
                    Colors.black.withOpacity(0.55),
                    Colors.black.withOpacity(0.2),
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
                vertical: isDesktop ? 60.0 : 36.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Sparkles Tag
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF28B79B).withOpacity(0.2),
                      border: Border.all(color: const Color(0xFF28B79B), width: 1.5),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.school_rounded,
                          size: 14,
                          color: Color(0xFF28B79B),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isVi ? 'Trở thành đối tác giảng dạy cùng HanGo' : 'Become a teaching partner with HanGo',
                          style: const TextStyle(
                            color: Color(0xFF28B79B),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Outfit',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Main Title
                  Text(
                    isVi ? 'Trở thành giảng viên,\nchia sẻ tri thức.' : 'Become a teacher,\nshare your knowledge.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isDesktop ? 42 : 28,
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                      fontFamily: 'Outfit',
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Description
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 650),
                    child: Text(
                      isVi
                          ? 'Đồng hành cùng hàng ngàn học viên trên khắp cả nước. Xây dựng thương hiệu cá nhân, tạo khóa học chất lượng và tối ưu hóa thu nhập bền vững từ chuyên môn của bạn.'
                          : 'Onboard and teach thousands of learners nationwide. Build your personal brand, create quality courses, and maximize your earnings from your expertise.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: isDesktop ? 15 : 13,
                        height: 1.5,
                        fontFamily: 'Outfit',
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Action Buttons
                  Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    children: [
                      // Teal filled button
                      ElevatedButton(
                        onPressed: _handleTeachingClick,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF28B79B),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 8,
                          shadowColor: const Color(0xFF28B79B).withOpacity(0.4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isVi ? 'Đăng ký dạy ngay' : 'Apply to teach',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Outfit',
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_rounded, size: 16),
                          ],
                        ),
                      ),

                      // Outlined button
                      OutlinedButton(
                        onPressed: () {
                          _showTrainerInfoDialog(context, isVi);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white, width: 1.5),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: Text(
                          isVi ? 'Tìm hiểu thêm' : 'Learn more',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Outfit',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 36),

                  // Stats Row
                  Wrap(
                    spacing: 48,
                    runSpacing: 16,
                    children: [
                      _buildHeroStat('100%', isVi ? 'Tự do thời gian' : 'Flexible hours'),
                      _buildHeroStat('24/7', isVi ? 'AI hỗ trợ chấm thi' : 'AI Grading Assistant'),
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

  void _showTrainerInfoDialog(BuildContext context, bool isVi) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.school_rounded, color: Color(0xFF28B79B), size: 28),
              const SizedBox(width: 12),
              Text(
                isVi ? 'Trở thành giảng viên' : 'Become a Trainer',
                style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isVi
                    ? 'HanGo luôn chào đón những nhà giáo dục đầy nhiệt huyết và năng lực. Khi tham gia cùng chúng tôi, bạn sẽ nhận được:'
                    : 'HanGo welcomes passionate and qualified educators. By joining us, you will enjoy:',
                style: const TextStyle(fontSize: 14, height: 1.4, fontFamily: 'Outfit'),
              ),
              const SizedBox(height: 16),
              _buildBulletItem(Icons.trending_up_rounded, isVi ? 'Thu nhập hấp dẫn & tối ưu hóa thu nhập bền vững' : 'Attractive income & sustainable revenue optimization'),
              _buildBulletItem(Icons.rocket_launch_rounded, isVi ? 'Hệ thống hỗ trợ AI tự động thiết kế đề thi và lộ trình học' : 'AI-driven test creation & personalized pathways'),
              _buildBulletItem(Icons.verified_user_rounded, isVi ? 'Tự do quản lý thương hiệu cá nhân và học viên' : 'Total freedom to build your personal brand'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                isVi ? 'Đóng' : 'Close',
                style: const TextStyle(color: Color(0xFF64748B), fontFamily: 'Outfit'),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _handleTeachingClick();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF28B79B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                isVi ? 'Đăng ký ngay' : 'Apply Now',
                style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBulletItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF28B79B), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: Color(0xFF475569), fontFamily: 'Outfit'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroStat(String number, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          number,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            fontFamily: 'Outfit',
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.85),
            fontSize: 13,
            fontWeight: FontWeight.w400,
            fontFamily: 'Outfit',
          ),
        ),
      ],
    );
  }

  // ----------------------------------------------------
  // Courses Section
  // ----------------------------------------------------
  Map<String, dynamic> _getCourseTheme(Course course) {
    final title = course.title.toLowerCase();
    if (title.contains('ielts')) {
      return {
        'color': const Color(0xFF28B79B),
        'icon': Icons.stars_rounded,
        'tagColor': const Color(0xFFE6FFFA),
        'textColor': const Color(0xFF137333),
        'category': 'IELTS',
      };
    } else if (title.contains('giao tiếp') || title.contains('communication') || title.contains('phản xạ')) {
      return {
        'color': const Color(0xFFF97316),
        'icon': Icons.record_voice_over_rounded,
        'tagColor': const Color(0xFFFFF7ED),
        'textColor': const Color(0xFFC2410C),
        'category': 'Giao tiếp',
      };
    } else if (title.contains('toeic')) {
      return {
        'color': const Color(0xFF8B5CF6),
        'icon': Icons.headphones_rounded,
        'tagColor': const Color(0xFFF3E8FF),
        'textColor': const Color(0xFF6D28D9),
        'category': 'TOEIC',
      };
    } else {
      return {
        'color': const Color(0xFF0EA5E9),
        'icon': Icons.menu_book_rounded,
        'tagColor': const Color(0xFFE0F2FE),
        'textColor': const Color(0xFF0369A1),
        'category': 'Ngữ pháp',
      };
    }
  }

  String _getCoursePrice(Course course) {
    final title = course.title.toLowerCase();
    if (title.contains('ngữ pháp') || title.contains('grammar') || course.id % 4 == 0) {
      return 'Miễn phí';
    }
    final prices = ['699.000đ', '899.000đ', '1.290.000đ', '1.500.000đ'];
    return prices[course.id % prices.length];
  }

  int _getCourseLessonsCount(Course course) {
    return 15 + (course.id * 7) % 30;
  }

  Widget _buildCoursesSection(bool isDesktop) {
    final isVi = LanguageManager.isVi;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isVi ? 'BÁN CHẠY NHẤT' : 'BEST SELLER',
          style: const TextStyle(
            color: Color(0xFF28B79B),
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
            fontFamily: 'Outfit',
          ),
        ),
        const SizedBox(height: 8),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isVi ? 'Khóa học tiếng Anh nổi bật' : 'Featured English Courses',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      fontFamily: 'Outfit',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isVi
                        ? 'Đứng lớp bởi các giáo viên giàu kinh nghiệm — ôn thi THPTQG.'
                        : 'Taught by experienced teachers — high school exam prep.',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF64748B),
                      fontFamily: 'Outfit',
                    ),
                  ),
                ],
              ),
            ),
            if (isDesktop)
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ListCoursesPage()),
                  );
                },
                icon: const Icon(Icons.grid_view_rounded, size: 16, color: Color(0xFF28B79B)),
                label: Text(
                  isVi ? 'Xem tất cả' : 'View all',
                  style: const TextStyle(
                    color: Color(0xFF28B79B),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    fontFamily: 'Outfit',
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF28B79B), width: 1.5),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 24),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildTabSelector(
                      isVi ? 'Khóa học nổi bật' : 'Featured',
                      active: _activeCourseTab == 'featured',
                      onTap: () {
                        setState(() => _activeCourseTab = 'featured');
                        _fetchCourses();
                      },
                    ),
                    const SizedBox(width: 24),
                    _buildTabSelector(
                      isVi ? 'Đang học' : 'In progress',
                      active: _activeCourseTab == 'in_progress',
                      onTap: () {
                        setState(() => _activeCourseTab = 'in_progress');
                        _fetchCourses();
                      },
                    ),
                    const SizedBox(width: 24),
                    _buildTabSelector(
                      isVi ? 'Đã hoàn thành' : 'Completed',
                      active: _activeCourseTab == 'completed',
                      onTap: () {
                        setState(() => _activeCourseTab = 'completed');
                        _fetchCourses();
                      },
                    ),
                  ],
                ),
              ),
            ),
            if (!isDesktop)
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ListCoursesPage(),
                    ),
                  );
                },
                child: Row(
                  children: [
                    Text(
                      isVi ? 'Tất cả' : 'All',
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        fontFamily: 'Outfit',
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward, size: 14, color: Color(0xFF6B7280)),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),

        _isLoadingCourses
            ? const SizedBox(
                height: 220,
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF28B79B),
                    ),
                  ),
                ),
              )
            : _courses.isEmpty
            ? SizedBox(
                height: 220,
                child: Center(
                  child: Text(
                    isVi
                        ? 'Không có khóa học nào thuộc danh mục này.'
                        : 'No courses found in this category.',
                    style: const TextStyle(color: Color(0xFF6B7280), fontFamily: 'Outfit'),
                  ),
                ),
              )
            : isDesktop
            ? GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 20,
                  mainAxisSpacing: 20,
                  childAspectRatio: isDesktop ? 0.85 : 0.85,
                ),
                itemCount: _courses.length,
                itemBuilder: (context, index) {
                  return _buildCourseCard(_courses[index]);
                },
              )
            : SizedBox(
                height: 360,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _courses.length,
                  itemBuilder: (context, index) {
                    return Container(
                      width: 280,
                      margin: const EdgeInsets.only(right: 16),
                      child: _buildCourseCard(_courses[index]),
                    );
                  },
                ),
              ),
      ],
    );
  }

  String _getTeacherSalutation(String name) {
    final lowerName = name.toLowerCase();
    final femaleKeywords = [
      'thị', 'linh', 'thảo', 'trang', 'hoa', 'mai', 'phương', 'hương', 'hạnh',
      'nga', 'yến', 'lan', 'nhi', 'ngọc', 'anh', 'vy', 'quỳnh', 'tuyết',
      'hồng', 'diệp', 'oanh', 'trà', 'liên', 'dung', 'huyền', 'kim', 'chi'
    ];
    for (final keyword in femaleKeywords) {
      if (lowerName.contains(keyword)) {
        return 'Ms. $name';
      }
    }
    return 'Mr. $name';
  }

  String _getOriginalPrice(String currentPrice) {
    if (currentPrice == 'Miễn phí') return '';
    if (currentPrice.contains('699')) return '999.000đ';
    if (currentPrice.contains('899')) return '1.290.000đ';
    if (currentPrice.contains('1.290')) return '1.800.000đ';
    return '2.100.000đ';
  }

  Widget _buildCourseCardHeaderPlaceholder(Map<String, dynamic> theme) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned(
          right: -20,
          bottom: -20,
          child: Icon(
            theme['icon'] as IconData,
            size: 90,
            color: Colors.white.withOpacity(0.12),
          ),
        ),
        Icon(
          theme['icon'] as IconData,
          size: 42,
          color: Colors.white,
        ),
      ],
    );
  }

  Widget _buildCourseCard(Course course) {
    final isVi = LanguageManager.isVi;
    final theme = _getCourseTheme(course);
    final priceStr = _getCoursePrice(course);
    final originalPriceStr = _getOriginalPrice(priceStr);
    final isFree = priceStr == 'Miễn phí';
    final displayPrice = isFree ? (isVi ? 'Miễn phí' : 'Free') : priceStr;
    final teacherName = _getTeacherSalutation(course.creatorName);
    final bool isBestSeller = course.id % 2 != 0;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CourseDetailPage(courseId: course.id),
            ),
          );
        },
        child: HoverableCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 140,
                decoration: BoxDecoration(
                  color: theme['color'] as Color,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: course.thumbnailUrl.isNotEmpty
                            ? Image.network(
                                course.thumbnailUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    _buildCourseCardHeaderPlaceholder(theme),
                              )
                            : _buildCourseCardHeaderPlaceholder(theme),
                      ),
                      if (isFree)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF97316),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isVi ? 'MIỄN PHÍ' : 'FREE',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Outfit',
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        course.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                          fontFamily: 'Outfit',
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        teacherName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                          fontFamily: 'Outfit',
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            course.stars.toStringAsFixed(1).replaceAll('.', ','),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFB45309),
                              fontFamily: 'Outfit',
                            ),
                          ),
                          const SizedBox(width: 4),
                          Row(
                            children: List.generate(5, (index) {
                              return Icon(
                                Icons.star_rounded,
                                size: 14,
                                color: index < course.stars.floor()
                                    ? const Color(0xFFF59E0B)
                                    : const Color(0xFFE2E8F0),
                              );
                            }),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '(${course.learnerCount})',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                              fontFamily: 'Outfit',
                            ),
                          ),
                        ],
                      ),
                      if (_activeCourseTab != 'featured') ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isVi ? 'Tiến độ' : 'Progress',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontFamily: 'Outfit'),
                            ),
                            Text(
                              '${course.progressPercentage.toStringAsFixed(0)}%',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF28B79B),
                                fontFamily: 'Outfit',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: course.progressPercentage / 100.0,
                            minHeight: 4,
                            backgroundColor: const Color(0xFFF1F5F9),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF28B79B),
                            ),
                          ),
                        ),
                      ],
                      const Spacer(),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            displayPrice,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isFree ? const Color(0xFF28B79B) : const Color(0xFF0F172A),
                              fontFamily: 'Outfit',
                            ),
                          ),
                          if (!isFree) ...[
                            const SizedBox(width: 8),
                            Text(
                              originalPriceStr,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF94A3B8),
                                decoration: TextDecoration.lineThrough,
                                fontFamily: 'Outfit',
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDifficultyBadge(String difficulty) {
    Color bg;
    Color fg;
    String displayText = difficulty;

    switch (difficulty.toLowerCase()) {
      case 'advanced':
      case 'hard':
        bg = const Color(0xFFFEF2F2);
        fg = const Color(0xFFEF4444);
        displayText = 'Nâng cao';
        break;
      case 'intermediate':
      case 'medium':
        bg = const Color(0xFFFFF7ED);
        fg = const Color(0xFFF97316);
        displayText = 'Trung cấp';
        break;
      case 'basic':
      case 'beginer':
      case 'easy':
      default:
        bg = const Color(0xFFF0FDF4);
        fg = const Color(0xFF22C55E);
        displayText = 'Cơ bản';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        displayText,
        style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
      ),
    );
  }

  // ----------------------------------------------------
  // Exams Section
  // ----------------------------------------------------
  Widget _buildExamsSection(bool isDesktop) {
    final isVi = LanguageManager.isVi;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 36.0 : 20.0,
        vertical: 36.0,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFE6FFFA).withOpacity(0.3),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isVi ? '100% MIỄN PHÍ' : '100% FREE',
            style: const TextStyle(
              color: Color(0xFF28B79B),
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isVi ? 'Luyện đề thi THPTQG Tiếng Anh' : 'High School English Exam Prep',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        fontFamily: 'Outfit',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isVi
                          ? 'Kho đề thi chính thức và đề minh họa các năm — làm bài online, chấm điểm tự động, xem lịch sử.'
                          : 'Official mock exams from past years — practice online, auto-graded with history tracking.',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF64748B),
                        fontFamily: 'Outfit',
                      ),
                    ),
                  ],
                ),
              ),
              if (isDesktop)
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ListExamsPage()),
                    );
                  },
                  icon: const Icon(Icons.assignment_outlined, size: 16, color: Color(0xFF28B79B)),
                  label: Text(
                    isVi ? 'Xem tất cả đề' : 'View all exams',
                    style: const TextStyle(
                      color: Color(0xFF28B79B),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      fontFamily: 'Outfit',
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF28B79B), width: 1.5),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                children: [
                  _buildTabSelector(
                    isVi ? 'Đề thi nổi bật' : 'Featured',
                    active: _activeExamTab == 'featured',
                    onTap: () {
                      setState(() => _activeExamTab = 'featured');
                      _fetchExams();
                    },
                  ),
                  const SizedBox(width: 24),
                  _buildTabSelector(
                    isVi ? 'Đã hoàn thành' : 'Completed',
                    active: _activeExamTab == 'completed',
                    onTap: () {
                      setState(() => _activeExamTab = 'completed');
                      _fetchExams();
                    },
                  ),
                ],
              ),
              if (!isDesktop)
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ListExamsPage(),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      Text(
                        isVi ? 'Tất cả đề' : 'All exams',
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          fontFamily: 'Outfit',
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward, size: 14, color: Color(0xFF6B7280)),
                    ],
                  ),
                ),
          ],
        ),
        const SizedBox(height: 20),

        _isLoadingExams
            ? const SizedBox(
                height: 220,
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF28B79B),
                    ),
                  ),
                ),
              )
            : _exams.isEmpty
            ? SizedBox(
                height: 220,
                child: Center(
                  child: Text(
                    isVi
                        ? 'Không có đề thi nào thuộc danh mục này.'
                        : 'No exams found in this category.',
                    style: const TextStyle(color: Color(0xFF6B7280), fontFamily: 'Outfit'),
                  ),
                ),
              )
            : isDesktop
            ? GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 20,
                  mainAxisSpacing: 20,
                  childAspectRatio: isDesktop ? 1.45 : 0.85,
                ),
                itemCount: _exams.length,
                itemBuilder: (context, index) {
                  return _buildExamCard(_exams[index]);
                },
              )
            : SizedBox(
                height: 180,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _exams.length,
                  itemBuilder: (context, index) {
                    return Container(
                      width: 260,
                      margin: const EdgeInsets.only(right: 16),
                      child: _buildExamCard(_exams[index]),
                    );
                  },
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildExamCard(Exam exam) {
    final isVi = LanguageManager.isVi;
    final isMinhHoa = exam.title.toLowerCase().contains('minh họa') || exam.title.toLowerCase().contains('minh hoa');

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ExamDetailHistoryPage(exam: exam),
          ),
        );
      },
      child: HoverableCard(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6FFFA),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 12,
                          color: Color(0xFF28B79B),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isMinhHoa
                              ? (isVi ? 'Đề minh họa' : 'Mock exam')
                              : (isVi ? 'Đề chính thức' : 'Official exam'),
                          style: const TextStyle(
                            color: Color(0xFF137333),
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Outfit',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Expanded(
                child: Text(
                  exam.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                    fontFamily: 'Outfit',
                    height: 1.3,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  const Icon(
                    Icons.menu_book_outlined,
                    size: 14,
                    color: Color(0xFF64748B),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isVi ? '${exam.questionCount} câu hỏi' : '${exam.questionCount} questions',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                      fontFamily: 'Outfit',
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.timer_outlined,
                    size: 14,
                    color: Color(0xFF64748B),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isVi ? '${exam.durationMinutes} phút' : '${exam.durationMinutes} mins',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                      fontFamily: 'Outfit',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Tab Header Selector Widget
  Widget _buildTabSelector(
    String title, {
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: active ? const Color(0xFF28B79B) : const Color(0xFF9CA3AF),
            ),
          ),
          const SizedBox(height: 4),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 3,
            width: active ? 40 : 0,
            decoration: BoxDecoration(
              color: const Color(0xFF28B79B),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------
  // Value Proposition / Key Features Section
  // ----------------------------------------------------
  Widget _buildTeacherSection(bool isDesktop) {
    final isVi = LanguageManager.isVi;
    final listItems = isVi
        ? [
            'Chia sẻ doanh thu minh bạch',
            'Tiếp cận thêm nhiều học viên',
            'Công cụ dựng khóa học dễ dùng',
          ]
        : [
            'Transparent revenue sharing',
            'Reach more student learners',
            'Easy-to-use course builder tool',
          ];

    final leftContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          isVi ? 'DÀNH CHO GIÁO VIÊN' : 'FOR TEACHERS',
          style: const TextStyle(
            color: Color(0xFFA7F3D0),
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
            fontFamily: 'Outfit',
          ),
        ),
        const SizedBox(height: 12),
        Text(
          isVi ? 'Trở thành giảng viên trên HanGo' : 'Become an instructor on HanGo',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
            fontFamily: 'Outfit',
          ),
        ),
        const SizedBox(height: 12),
        Text(
          isVi
              ? 'Chia sẻ kiến thức, xây dựng hồ sơ giảng dạy và có thêm thu nhập từ khóa học của bạn.'
              : 'Share knowledge, build your teaching profile, and earn revenue from your courses.',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            height: 1.5,
            fontFamily: 'Outfit',
          ),
        ),
        const SizedBox(height: 24),
        ...listItems.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  size: 12,
                  color: Color(0xFF28B79B),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                item,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Outfit',
                ),
              ),
            ],
          ),
        )).toList(),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _handleTeachingClick,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF05A22),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            elevation: 4,
            shadowColor: const Color(0xFFF05A22).withOpacity(0.3),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isVi ? 'Bắt đầu giảng dạy' : 'Start teaching today',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_rounded, size: 16),
            ],
          ),
        ),
      ],
    );

    final rightContent = Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 380),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Color(0xFFE6FFFA),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.school_rounded,
                    color: Color(0xFF28B79B),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isVi ? 'Dạy học cùng HanGo' : 'Teach with HanGo',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                          fontFamily: 'Outfit',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isVi ? 'Đăng ký nhanh, bắt đầu trong vài phút' : 'Fast sign-up, start in minutes',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                          fontFamily: 'Outfit',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: Color(0xFFE2E8F0)),
            const SizedBox(height: 16),
            ...listItems.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline_rounded,
                    size: 16,
                    color: Color(0xFF28B79B),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(
                        color: Color(0xFF4B5563),
                        fontSize: 13,
                        fontFamily: 'Outfit',
                      ),
                    ),
                  ),
                ],
              ),
            )).toList(),
          ],
        ),
      ),
    );

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF28B79B),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF28B79B).withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 48.0 : 24.0,
        vertical: 48.0,
      ),
      child: isDesktop
          ? Row(
              children: [
                Expanded(flex: 3, child: leftContent),
                const SizedBox(width: 48),
                Expanded(flex: 2, child: rightContent),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                leftContent,
                const SizedBox(height: 36),
                rightContent,
              ],
            ),
    );
  }

  Widget _buildTestimonialSection(bool isDesktop) {
    final isVi = LanguageManager.isVi;
    final testimonials = isVi
        ? [
            {
              'stars': 5,
              'quote': 'Nhờ kho đề thi THPTQG miễn phí và bài giảng chi tiết, em tăng từ 6 lên 9 điểm Tiếng Anh chỉ trong một học kỳ!',
              'initials': 'V',
              'avatarColor': const Color(0xFFE6F4EA),
              'textColor': const Color(0xFF137333),
              'name': 'Vũ Đức Thắng',
              'sub': 'Học sinh lớp 12 · Hà Nội',
            },
            {
              'stars': 5,
              'quote': 'Em thích nhất là phần luyện đề thi thử có giải thích đáp án chi tiết bằng AI, giúp em tự học ở nhà cực kỳ hiệu quả.',
              'initials': 'Đ',
              'avatarColor': const Color(0xFFFFF7ED),
              'textColor': const Color(0xFFC2410C),
              'name': 'Đặng Khánh Linh',
              'sub': 'Học sinh lớp 12 · TP.HCM',
            },
            {
              'stars': 5,
              'quote': 'Khóa học được sắp xếp khoa học, giáo viên tâm huyết giúp mình học từ vựng chuyên ngành cực nhanh. Giao diện mượt và đẹp.',
              'initials': 'H',
              'avatarColor': const Color(0xFFF3E8FF),
              'textColor': const Color(0xFF6D28D9),
              'name': 'Hoàng Nam',
              'sub': 'Người đi làm · Đà Nẵng',
            },
          ]
        : [
            {
              'stars': 5,
              'quote': 'Thanks to the free mock exams and detailed explanations, my score improved from 6 to 9 in just one semester!',
              'initials': 'V',
              'avatarColor': const Color(0xFFE6F4EA),
              'textColor': const Color(0xFF137333),
              'name': 'Vu Duc Thang',
              'sub': 'Grade 12 Student · Hanoi',
            },
            {
              'stars': 5,
              'quote': 'I love the mock exam practice with detailed AI-driven answer explanations. It makes self-study at home incredibly effective!',
              'initials': 'D',
              'avatarColor': const Color(0xFFFFF7ED),
              'textColor': const Color(0xFFC2410C),
              'name': 'Dang Khanh Linh',
              'sub': 'Grade 12 Student · HCMC',
            },
            {
              'stars': 5,
              'quote': 'Well-organized structure, dedicated instructors who helped me learn professional vocabulary rapidly. Interface is smooth and gorgeous.',
              'initials': 'H',
              'avatarColor': const Color(0xFFF3E8FF),
              'textColor': const Color(0xFF6D28D9),
              'name': 'Hoang Nam',
              'sub': 'Working Professional · Danang',
            },
          ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          isVi ? 'CẢM NHẬN HỌC VIÊN' : 'LEARNER TESTIMONIALS',
          style: const TextStyle(
            color: Color(0xFF28B79B),
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
            fontFamily: 'Outfit',
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isVi ? 'Được học viên tin tưởng' : 'Trusted by our students',
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
            fontFamily: 'Outfit',
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isVi
              ? 'Dành cho học sinh ôn thi THPT Quốc Gia.'
              : 'For high school students preparing for THPTQG exams.',
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF64748B),
            fontFamily: 'Outfit',
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 36),

        isDesktop
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: testimonials.map((t) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: _buildTestimonialCard(t),
                  ),
                )).toList(),
              )
            : Column(
                children: testimonials.map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildTestimonialCard(t),
                )).toList(),
              ),
      ],
    );
  }

  Widget _buildTestimonialCard(Map<String, dynamic> t) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(t['stars'] as int, (index) => const Icon(
              Icons.star_rounded,
              size: 18,
              color: Color(0xFFFBBF24),
            )),
          ),
          const SizedBox(height: 16),

          Text(
            '"${t['quote']}"',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF334155),
              height: 1.5,
              fontFamily: 'Outfit',
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: t['avatarColor'] as Color,
                child: Text(
                  t['initials'] as String,
                  style: TextStyle(
                    color: t['textColor'] as Color,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    fontFamily: 'Outfit',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t['name'] as String,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                        fontFamily: 'Outfit',
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      t['sub'] as String,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF64748B),
                        fontFamily: 'Outfit',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCtaBannerSection(bool isDesktop) {
    final isVi = LanguageManager.isVi;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1E8D77),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E8D77).withOpacity(0.15),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 48.0 : 24.0,
        vertical: 36.0,
      ),
      child: isDesktop
          ? Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isVi ? 'Sẵn sàng chinh phục tiếng Anh?' : 'Ready to master English?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Outfit',
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isVi
                            ? 'Bắt đầu miễn phí hôm nay — không cần thẻ tín dụng.'
                            : 'Get started for free today — no credit card required.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 14,
                          fontFamily: 'Outfit',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                _buildCtaButton(),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isVi ? 'Sẵn sàng chinh phục tiếng Anh?' : 'Ready to master English?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Outfit',
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isVi
                      ? 'Bắt đầu miễn phí hôm nay — không cần thẻ tín dụng.'
                      : 'Get started for free today — no credit card required.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 13,
                    fontFamily: 'Outfit',
                  ),
                ),
                const SizedBox(height: 20),
                _buildCtaButton(),
              ],
            ),
    );
  }

  Widget _buildCtaButton() {
    final isVi = LanguageManager.isVi;
    return ElevatedButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ListCoursesPage()),
        );
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFF05A22),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        elevation: 6,
        shadowColor: const Color(0xFFF05A22).withOpacity(0.3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isVi ? 'Học thử miễn phí' : 'Start learning free',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.rocket_launch, size: 16),
        ],
      ),
    );
  }
}

// ----------------------------------------------------
// Custom Visual Components / Hover & Draw
// ----------------------------------------------------

// Custom Laptop + Graduation Cap drawing for Hero illustration
class HeroIllustrationWidget extends StatelessWidget {
  const HeroIllustrationWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      height: 180,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Glowing radial light behind
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE6FFFA).withOpacity(0.2),
                  blurRadius: 40,
                  spreadRadius: 20,
                ),
              ],
            ),
          ),

          // Laptop structure
          Positioned(
            bottom: 40,
            child: Column(
              children: [
                // Screen
                Container(
                  width: 130,
                  height: 85,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF475569),
                      width: 3,
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: 115,
                      height: 70,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.code,
                            color: Color(0xFF28B79B),
                            size: 18,
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: 50,
                            height: 3,
                            color: const Color(0xFF334155),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            width: 30,
                            height: 3,
                            color: const Color(0xFF334155),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Keyboard Base
                Container(
                  width: 154,
                  height: 8,
                  decoration: BoxDecoration(
                    color: const Color(0xFF64748B),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Laptop stand base lip
                Container(
                  width: 36,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: Color(0xFF475569),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(4),
                      bottomRight: Radius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Graduation Cap floating above screen
          Positioned(
            top: 22,
            right: 48,
            child: Transform.rotate(
              angle: -0.15,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // Cap Base (Underneath circle)
                  Positioned(
                    bottom: -8,
                    child: Container(
                      width: 22,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF59E0B),
                        borderRadius: BorderRadius.all(
                          Radius.elliptical(11, 6),
                        ),
                      ),
                    ),
                  ),

                  // Cap Top diamond
                  Transform(
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.002)
                      ..rotateX(0.7),
                    alignment: FractionalOffset.center,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFBBF24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Tassel
                  Positioned(
                    right: 4,
                    top: 24,
                    child: CustomPaint(
                      size: const Size(10, 20),
                      painter: TasselPainter(),
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

class TasselPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFEF4444)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(5, 5, 5, 12);
    canvas.drawPath(path, paint);

    final brush = Paint()
      ..color = const Color(0xFFEF4444)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(5, 14), 2.5, brush);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Stateful hoverable card wrapper that scales up and intensifies border on mouse hover
class HoverableCard extends StatefulWidget {
  final Widget child;
  const HoverableCard({super.key, required this.child});

  @override
  State<HoverableCard> createState() => _HoverableCardState();
}

class _HoverableCardState extends State<HoverableCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: _isHovered
            ? (Matrix4.identity()
                ..translate(0, -6, 0)
                ..scale(1.02))
            : Matrix4.identity(),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isHovered
                ? const Color(0xFF28B79B)
                : const Color(0xFFE5E7EB),
            width: _isHovered ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: _isHovered
                  ? const Color(0x1A28B79B)
                  : const Color(0x0A000000),
              blurRadius: _isHovered ? 12 : 6,
              offset: _isHovered ? const Offset(0, 8) : const Offset(0, 3),
            ),
          ],
        ),
        child: widget.child,
      ),
    );
  }
}
