// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/course_service.dart';
import '../../../domain/model/course.dart';
import '../../../domain/entities/exam.dart';
import '../../../data/repositories/exam_repository.dart';
import '../login_page.dart';
import '../exam/list_exams_page.dart';
import '../course/list_courses_page.dart';
import '../course/course_detail_page.dart';
import '../../widgets/shared_header.dart';

class LearnerHomePage extends StatefulWidget {
  const LearnerHomePage({super.key});

  @override
  State<LearnerHomePage> createState() => _LearnerHomePageState();
}

class _LearnerHomePageState extends State<LearnerHomePage> {
  final _authService = AuthService();
  final _courseService = CourseService();
  final _examRepository = ExamRepository();

  String _userFullName = 'Learner';
  String _userEmail = '';
  String _userInitials = 'L';

  // State variables for active tabs
  String _activeCourseTab = 'featured'; // 'featured' | 'in_progress' | 'completed'
  String _activeExamTab = 'featured'; // 'featured' | 'completed'

  List<Course> _courses = [];
  List<Exam> _exams = [];
  bool _isLoadingCourses = true;
  bool _isLoadingExams = true;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _fetchCourses();
    _fetchExams();
  }

  // Fetch logged in user info from SharedPreferences
  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final fullName = prefs.getString('user_fullname') ?? 'Learner';
    final email = prefs.getString('user_email') ?? '';
    
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
  }

  // Load courses depending on selected tab
  Future<void> _fetchCourses() async {
    setState(() {
      _isLoadingCourses = true;
    });
    try {
      final courses = await _courseService.getCourses(_activeCourseTab);
      setState(() {
        _courses = courses;
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
      final exams = await _examRepository.fetchExams(status: _activeExamTab == 'featured' ? 'PUBLISHED' : _activeExamTab);
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

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: SharedHeader(isDesktop: isDesktop, activeTab: ''),
      drawer: isDesktop ? null : _buildDrawer(context),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Main Content Area (centered with max width for clean desktop layouts)
            Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 1200),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Hero Banner
                    _buildHeroBanner(isDesktop),
                    const SizedBox(height: 40),

                    // 2. Courses Section
                    _buildCoursesSection(isDesktop),
                    const SizedBox(height: 40),

                    // 3. Exams Section
                    _buildExamsSection(isDesktop),
                    const SizedBox(height: 60),

                    // 4. Platform Value Proposition Section
                    _buildFeaturesSection(isDesktop),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
            
            // 5. Footer
            _buildFooter(isDesktop),
          ],
        ),
      ),
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
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF28B79B)),
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
                MaterialPageRoute(
                  builder: (context) => const ListExamsPage(),
                ),
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
            leading: const Icon(Icons.style_outlined),
            title: const Text('Flashcard'),
            onTap: () => Navigator.pop(context),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text('Log Out', style: TextStyle(color: Colors.redAccent)),
            onTap: () {
              Navigator.pop(context);
              _handleLogout();
            },
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------
  // Hero Banner Section
  // ----------------------------------------------------
  Widget _buildHeroBanner(bool isDesktop) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF209D84), // Teal
            Color(0xFF135D4E), // Deep Teal
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A28B79B),
            blurRadius: 15,
            offset: Offset(0, 6),
          )
        ],
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 48.0 : 24.0,
        vertical: isDesktop ? 48.0 : 36.0,
      ),
      child: Row(
        children: [
          // Left Content
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'A smart exam preparation platform with course suggestions, a question bank structured according to the Ministry of Education and Training\'s standards, and in-depth AI-assisted learning.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w400,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 36),
                
                // Stats Row
                Wrap(
                  spacing: 48,
                  runSpacing: 16,
                  children: [
                    _buildHeroStat('40,000+', 'Students trust and use it'),
                    _buildHeroStat('50+', 'Awesome practice test'),
                  ],
                ),
              ],
            ),
          ),

          // Right Graphic Illustration (Only on desktop to avoid crowding)
          if (isDesktop)
            Expanded(
              flex: 2,
              child: Center(
                child: HeroIllustrationWidget(),
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
            fontSize: 26,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 13,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  // ----------------------------------------------------
  // Courses Section
  // ----------------------------------------------------
  Widget _buildCoursesSection(bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tabs & Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Custom Tabs
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildTabSelector('Featured Courses', active: _activeCourseTab == 'featured', onTap: () {
                      setState(() => _activeCourseTab = 'featured');
                      _fetchCourses();
                    }),
                    const SizedBox(width: 16),
                    _buildTabSelector('In Progress', active: _activeCourseTab == 'in_progress', onTap: () {
                      setState(() => _activeCourseTab = 'in_progress');
                      _fetchCourses();
                    }),
                    const SizedBox(width: 16),
                    _buildTabSelector('Completed', active: _activeCourseTab == 'completed', onTap: () {
                      setState(() => _activeCourseTab = 'completed');
                      _fetchCourses();
                    }),
                  ],
                ),
              ),
            ),
            
            // See All Text Link
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ListCoursesPage()),
                );
              },
              child: const Row(
                children: [
                  Text(
                    'See All',
                    style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward, size: 14, color: Color(0xFF6B7280)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Courses Display
        _isLoadingCourses
            ? const SizedBox(
                height: 220,
                child: Center(
                  child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF28B79B))),
                ),
              )
            : _courses.isEmpty
                ? const SizedBox(
                    height: 220,
                    child: Center(
                      child: Text(
                        'No courses available in this category.',
                        style: TextStyle(color: Color(0xFF6B7280)),
                      ),
                    ),
                  )
                : isDesktop
                    ? GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          crossAxisSpacing: 20,
                          mainAxisSpacing: 20,
                          childAspectRatio: 0.85,
                        ),
                        itemCount: _courses.length,
                        itemBuilder: (context, index) {
                          return _buildCourseCard(_courses[index]);
                        },
                      )
                    : SizedBox(
                        height: 250,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _courses.length,
                          itemBuilder: (context, index) {
                            return Container(
                              width: 250,
                              margin: const EdgeInsets.only(right: 16),
                              child: _buildCourseCard(_courses[index]),
                            );
                          },
                        ),
                      ),
      ],
    );
  }

  // Course Card Builder
  Widget _buildCourseCard(Course course) {
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
              // Top Colored Section
              Container(
                height: 100,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF28B79B), Color(0xFF1E8D77)],
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Stack(
                  children: [
                    // Text category watermark/title
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(
                        course.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    
                    // Mortarboard watermark icon on bottom right
                    Positioned(
                      bottom: -10,
                      right: -10,
                      child: Icon(
                        Icons.school,
                        size: 68,
                        color: Colors.white.withOpacity(0.12),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Bottom Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        course.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Created By: ${course.creatorName}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          // Gold stars
                          ...List.generate(5, (index) {
                            return const Icon(
                              Icons.star,
                              size: 12,
                              color: Color(0xFFFBBF24),
                            );
                          }),
                          const SizedBox(width: 4),
                          Text(
                            course.learnerCount,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      
                      // Difficulty Tag
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildDifficultyBadge(course.difficulty),
                        ],
                      ),
                    ],
                  ),
                ),
              )
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
        displayText = 'Advanced';
        break;
      case 'intermediate':
      case 'medium':
        bg = const Color(0xFFFFF7ED);
        fg = const Color(0xFFF97316);
        displayText = 'Intermediate';
        break;
      case 'basic':
      case 'beginer':
      case 'easy':
      default:
        bg = const Color(0xFFF0FDF4);
        fg = const Color(0xFF22C55E);
        displayText = 'Basic';
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
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ----------------------------------------------------
  // Exams Section
  // ----------------------------------------------------
  Widget _buildExamsSection(bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              children: [
                _buildTabSelector('Featured Exams', active: _activeExamTab == 'featured', onTap: () {
                  setState(() => _activeExamTab = 'featured');
                  _fetchExams();
                }),
                const SizedBox(width: 16),
                _buildTabSelector('Completed', active: _activeExamTab == 'completed', onTap: () {
                  setState(() => _activeExamTab = 'completed');
                  _fetchExams();
                }),
              ],
            ),
            
            // See All Text Link
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ListExamsPage()),
                );
              },
              child: const Row(
                children: [
                  Text(
                    'See All',
                    style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward, size: 14, color: Color(0xFF6B7280)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Exams Grid
        _isLoadingExams
            ? const SizedBox(
                height: 220,
                child: Center(
                  child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF28B79B))),
                ),
              )
            : _exams.isEmpty
                ? const SizedBox(
                    height: 220,
                    child: Center(
                      child: Text(
                        'No exams available in this category.',
                        style: TextStyle(color: Color(0xFF6B7280)),
                      ),
                    ),
                  )
                : isDesktop
                    ? GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          crossAxisSpacing: 20,
                          mainAxisSpacing: 20,
                          childAspectRatio: 0.85,
                        ),
                        itemCount: _exams.length,
                        itemBuilder: (context, index) {
                          return _buildExamCard(_exams[index]);
                        },
                      )
                    : SizedBox(
                        height: 250,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _exams.length,
                          itemBuilder: (context, index) {
                            return Container(
                              width: 250,
                              margin: const EdgeInsets.only(right: 16),
                              child: _buildExamCard(_exams[index]),
                            );
                          },
                        ),
                      ),
      ],
    );
  }

  // Exam Card Builder
  Widget _buildExamCard(Exam exam) {
    return HoverableCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Card Header with Banner Style
          Container(
            height: 100,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1E8D77), Color(0xFF0F5A47)],
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Text(
                    exam.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                  ),
                ),
                
                // Mortarboard watermark icon
                Positioned(
                  bottom: -10,
                  right: -10,
                  child: Icon(
                    Icons.assignment_outlined,
                    size: 68,
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
              ],
            ),
          ),
          
          // Card Body
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exam.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Created By: ${exam.creatorName}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                  const Spacer(),
                  
                  // Question / Sentence count & time duration details
                  Row(
                    children: [
                      const Icon(Icons.menu_book_outlined, size: 13, color: Color(0xFF6B7280)),
                      const SizedBox(width: 4),
                      Text(
                        '${exam.questionCount} sentences',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                      ),
                      const Spacer(),
                      const Icon(Icons.timer_outlined, size: 13, color: Color(0xFF6B7280)),
                      const SizedBox(width: 4),
                      Text(
                        '${exam.durationMinutes} minute',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  // Stars and learner count
                  Row(
                    children: [
                      ...List.generate(5, (index) {
                        return Icon(
                          Icons.star,
                          size: 12,
                          color: index < (exam.rating).floor() 
                              ? const Color(0xFFFBBF24) 
                              : Colors.grey.shade300,
                        );
                      }),
                      const SizedBox(width: 4),
                      Text(
                        exam.learnerCountFormatted,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF9CA3AF),
                        ),
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

  // Tab Header Selector Widget
  Widget _buildTabSelector(String title, {required bool active, required VoidCallback onTap}) {
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
  Widget _buildFeaturesSection(bool isDesktop) {
    return Column(
      children: [
        const Center(
          child: Text(
            'HanGO - Your personalized English learning platform',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
        ),
        const SizedBox(height: 32),
        
        // Features list
        isDesktop
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildFeatureCard(
                      'Personalized learning with AI technology.',
                      'HanGO integrates advanced AI to automatically grade assignments and provide detailed, real-time feedback. The system helps you identify mistakes, understand how to improve, and adjust your learning path to optimize your own learning performance.',
                      'https://images.unsplash.com/photo-1526374965328-7f61d4dc18c5?q=80&w=400',
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: _buildFeatureCard(
                      'A free learning platform for everyone.',
                      'HanGO is committed to providing equal learning opportunities for everyone. You can access high-quality courses and learning pathways completely free of charge.',
                      'https://images.unsplash.com/photo-1522202176988-66273c2fd55f?q=80&w=400',
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: _buildFeatureCard(
                      'Absolute flexibility Retake the course anytime',
                      'With HanGO, you are in control of your learning pace. All lectures, materials, and assignments are stored, allowing you to review lessons, revise knowledge, or continue your learning journey anywhere, anytime you need.',
                      'https://images.unsplash.com/photo-1506784983877-45594efa4cbe?q=80&w=400',
                    ),
                  ),
                ],
              )
            : Column(
                children: [
                  _buildFeatureCard(
                    'Personalized learning with AI technology.',
                    'HanGO integrates advanced AI to automatically grade assignments and provide detailed, real-time feedback. The system helps you identify mistakes, understand how to improve, and adjust your learning path to optimize your own learning performance.',
                    'https://images.unsplash.com/photo-1526374965328-7f61d4dc18c5?q=80&w=400',
                  ),
                  const SizedBox(height: 20),
                  _buildFeatureCard(
                    'A free learning platform for everyone.',
                    'HanGO is committed to providing equal learning opportunities for everyone. You can access high-quality courses and learning pathways completely free of charge.',
                    'https://images.unsplash.com/photo-1522202176988-66273c2fd55f?q=80&w=400',
                  ),
                  const SizedBox(height: 20),
                  _buildFeatureCard(
                    'Absolute flexibility Retake the course anytime',
                    'With HanGO, you are in control of your learning pace. All lectures, materials, and assignments are stored, allowing you to review lessons, revise knowledge, or continue your learning journey anywhere, anytime you need.',
                    'https://images.unsplash.com/photo-1506784983877-45594efa4cbe?q=80&w=400',
                  ),
                ],
              ),
      ],
    );
  }

  // Feature Card Builder
  Widget _buildFeatureCard(String title, String description, String imageUrl) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4).withOpacity(0.4), // ultra light mint
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6FFFA), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Illustration / Image
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
            child: SizedBox(
              height: 180,
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: const Color(0xFFE6FFFA),
                  child: const Icon(Icons.image_outlined, size: 50, color: Color(0xFF28B79B)),
                ),
              ),
            ),
          ),
          
          // Text Details
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F5A47),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF4B5563),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  // ----------------------------------------------------
  // Footer Section
  // ----------------------------------------------------
  Widget _buildFooter(bool isDesktop) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFE6FFFA).withOpacity(0.3),
        border: const Border(top: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              // Column structures
              isDesktop
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Logo & Statement
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Image.network(
                                'https://res.cloudinary.com/diqekap4o/image/upload/v1781621071/logo_ayqvq4.png',
                                height: 36,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) => const Text(
                                  'HanGo',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1F2937),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'The leading digital coaching platform for high school students aiming for distinction in the THPTQG English National Exam.',
                                style: TextStyle(
                                  color: Color(0xFF6B7280),
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildSocialRow(),
                            ],
                          ),
                        ),
                        const SizedBox(width: 48),
                        
                        // Learning Column
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'LEARNING',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                              ),
                              const SizedBox(height: 16),
                              _buildFooterLink('Mock Tests'),
                              _buildFooterLink('Vocabulary Sets'),
                              _buildFooterLink('Grammar Courses'),
                            ],
                          ),
                        ),
                        
                        // Support Column
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'SUPPORT',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                              ),
                              const SizedBox(height: 16),
                              _buildFooterLink('Learner FAQ'),
                              _buildFooterLink('Privacy Policy'),
                              _buildFooterLink('Terms of Service'),
                            ],
                          ),
                        )
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Image.network(
                          'https://res.cloudinary.com/diqekap4o/image/upload/v1781621071/logo_ayqvq4.png',
                          height: 36,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'The leading digital coaching platform for high school students aiming for distinction in the THPTQG English National Exam.',
                          style: TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildSocialRow(),
                        const SizedBox(height: 32),
                        const Text(
                          'LEARNING',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                        ),
                        const Divider(),
                        _buildFooterLink('Mock Tests'),
                        _buildFooterLink('Vocabulary Sets'),
                        _buildFooterLink('Grammar Courses'),
                        const SizedBox(height: 24),
                        const Text(
                          'SUPPORT',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                        ),
                        const Divider(),
                        _buildFooterLink('Learner FAQ'),
                        _buildFooterLink('Privacy Policy'),
                        _buildFooterLink('Terms of Service'),
                      ],
                    ),
              
              const SizedBox(height: 32),
              const Divider(color: Color(0xFFE5E7EB)),
              const SizedBox(height: 16),
              const Text(
                '© 2026 HanGo Platform. All rights reserved.',
                style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooterLink(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: InkWell(
        onTap: () {},
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF6B7280),
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildSocialRow() {
    return Row(
      children: [
        _buildSocialIcon(Icons.language),
        const SizedBox(width: 8),
        _buildSocialIcon(Icons.share),
      ],
    );
  }

  Widget _buildSocialIcon(IconData icon) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Center(
        child: Icon(
          icon,
          size: 16,
          color: const Color(0xFF28B79B),
        ),
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
                )
              ]
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
                    border: Border.all(color: const Color(0xFF475569), width: 3),
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
                          const Icon(Icons.code, color: Color(0xFF28B79B), size: 18),
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
                        borderRadius: BorderRadius.all(Radius.elliptical(11, 6)),
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
                          )
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
            ? (Matrix4.identity()..translate(0, -6, 0)..scale(1.02))
            : Matrix4.identity(),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isHovered ? const Color(0xFF28B79B) : const Color(0xFFE5E7EB),
            width: _isHovered ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: _isHovered 
                  ? const Color(0x1A28B79B) 
                  : const Color(0x0A000000),
              blurRadius: _isHovered ? 12 : 6,
              offset: _isHovered ? const Offset(0, 8) : const Offset(0, 3),
            )
          ],
        ),
        child: widget.child,
      ),
    );
  }
}
