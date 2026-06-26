import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/services/auth_service.dart';
import '../login_page.dart';
import 'trainer_courses_page.dart';
import 'question_bank/trainer_question_bank_page.dart';

class TrainerDashboardPage extends StatefulWidget {
  const TrainerDashboardPage({super.key});

  @override
  State<TrainerDashboardPage> createState() => _TrainerDashboardPageState();
}

class _TrainerDashboardPageState extends State<TrainerDashboardPage> {
  final _authService = AuthService();
  String _trainerName = 'Thảo';
  String _trainerInitials = 'T';
  bool _isLoading = true;
  String _errorMessage = '';

  // Stats
  int _coursesCount = 0;
  int _learnersCount = 0;
  int _examsCount = 0;
  List<dynamic> _coursesList = [];

  String get apiBaseUrl {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080/api/v1';
    }
    return 'http://localhost:8080/api/v1';
  }

  @override
  void initState() {
    super.initState();
    _loadTrainerInfo();
    _fetchDashboardData();
  }

  Future<void> _loadTrainerInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final fullName = prefs.getString('user_fullname') ?? 'Thảo';
    String initials = 'T';
    if (fullName.trim().isNotEmpty) {
      final parts = fullName.trim().split(' ');
      if (parts.isNotEmpty) {
        initials = parts.last[0].toUpperCase();
      }
    }
    setState(() {
      _trainerName = fullName;
      _trainerInitials = initials;
    });
  }

  Future<void> _fetchDashboardData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final token = await _authService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await http.get(
        Uri.parse('$apiBaseUrl/trainer/dashboard'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() {
          _coursesCount = (data['coursesCount'] ?? 0) as int;
          _learnersCount = (data['learnersCount'] ?? 0) as int;
          _examsCount = (data['examsCount'] ?? 0) as int;
          _coursesList = data['courses'] ?? [];
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load dashboard data: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error loading dashboard data: $e');
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
      _loadMockFallback();
    }
  }

  void _loadMockFallback() {
    // If backend isn't running or there is an issue, show nice mock data matching the screenshot
    setState(() {
      _coursesCount = 1;
      _learnersCount = 4;
      _examsCount = 1;
      _coursesList = [
        {
          'id': 1,
          'title': 'Grammar 8+',
          'learnersCount': 4,
          'lessonsCount': 1,
          'thumbnailUrl': null
        }
      ];
    });
  }

  void _handleLogout() async {
    await _authService.logout();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 1024;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Slate 50
      drawer: !isDesktop ? Drawer(child: _buildSidebar(context)) : null,
      body: Row(
        children: [
          if (isDesktop) SizedBox(width: 240, child: _buildSidebar(context)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(context, !isDesktop),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: _isLoading
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.only(top: 100.0),
                              child: CircularProgressIndicator(
                                color: Color(0xFF20B486),
                              ),
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildWelcomeSection(),
                              const SizedBox(height: 24),
                              _buildOverviewTabs(),
                              const SizedBox(height: 24),
                              _buildMetricCards(),
                              const SizedBox(height: 32),
                              _buildCoursesSection(),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE6FFFA),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.school,
                    size: 18,
                    color: Color(0xFF20B486),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'HanGo',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                    fontFamily: 'Outfit',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          // Sidebar menu items
          _buildSidebarItem(Icons.dashboard_outlined, 'Dashboard', isActive: true),
          _buildSidebarItem(Icons.book_outlined, 'Courses', onTap: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const TrainerCoursesPage()),
            );
          }),
          _buildSidebarItem(Icons.assignment_outlined, 'Exam'),
          _buildSidebarItem(Icons.people_outline, 'Learner'),
          _buildSidebarItem(Icons.question_answer_outlined, 'Question Bank', onTap: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const TrainerQuestionBankPage()),
            );
          }),
          _buildSidebarItem(Icons.task_alt_outlined, 'Task'),
          const Spacer(),
          const Divider(color: Color(0xFFE2E8F0)),
          const SizedBox(height: 12),
          _buildSidebarItem(Icons.help_outline, 'Help Center', onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Help Center is under construction')),
            );
          }),
          _buildSidebarItem(Icons.logout, 'Logout', color: Colors.redAccent, onTap: _handleLogout),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(IconData icon, String title, {bool isActive = false, Color? color, VoidCallback? onTap}) {
    final activeColor = const Color(0xFF20B486);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: InkWell(
        onTap: onTap ?? () {},
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isActive ? Colors.white : (color ?? const Color(0xFF4B5563)),
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  color: isActive ? Colors.white : (color ?? const Color(0xFF1F2937)),
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                  fontSize: 14,
                  fontFamily: 'Outfit',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool showMenuButton) {
    return Container(
      color: Colors.white,
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          if (showMenuButton) ...[
            IconButton(
              icon: const Icon(Icons.menu, color: Color(0xFF4B5563)),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
            const SizedBox(width: 12),
          ],
          // Breadcrumb
          Row(
            children: const [
              Icon(Icons.chevron_right, size: 16, color: Color(0xFF20B486)),
              SizedBox(width: 4),
              Text(
                'Dashboard',
                style: TextStyle(
                  color: Color(0xFF20B486),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  fontFamily: 'Outfit',
                ),
              ),
            ],
          ),
          const Spacer(),
          // Actions
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.notifications_none_outlined,
                  color: Color(0xFF4B5563),
                  size: 24,
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No new notifications')),
                  );
                },
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          // User profile widget
          Row(
            children: [
              Text(
                _trainerName,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                  fontSize: 14,
                  fontFamily: 'Outfit',
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: Color(0xFFE2F9F3),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  _trainerInitials,
                  style: const TextStyle(
                    color: Color(0xFF20B486),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    fontFamily: 'Outfit',
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF20B486),
                  shape: BoxShape.circle,
                ),
              )
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text(
          'Dashboard',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
            fontFamily: 'Outfit',
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Welcome back, check your stats for today.',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF64748B),
            fontFamily: 'Outfit',
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewTabs() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFF20B486), width: 2),
              ),
            ),
            child: Row(
              children: const [
                Icon(Icons.bar_chart, size: 18, color: Color(0xFF20B486)),
                SizedBox(width: 8),
                Text(
                  'Overview',
                  style: TextStyle(
                    color: Color(0xFF20B486),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
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

  Widget _buildMetricCards() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useRow = constraints.maxWidth > 768;

        final cards = [
          _buildMetricCard(
            title: 'Courses',
            value: '$_coursesCount',
            subtitle: 'Total courses created',
            icon: Icons.book_outlined,
            bgGradient: const LinearGradient(
              colors: [Color(0xFFF0F7FF), Color(0xFFDCEBFE)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            iconColor: const Color(0xFF2563EB),
            titleColor: const Color(0xFF1D4ED8),
            border: Border.all(color: const Color(0xFFBFDBFE), width: 1.5),
          ),
          _buildMetricCard(
            title: 'Learner',
            value: '$_learnersCount',
            subtitle: 'Students enrolled in your courses',
            icon: Icons.people_outline,
            bgGradient: const LinearGradient(
              colors: [Color(0xFFE6FDF9), Color(0xFFC1F8EB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            iconColor: const Color(0xFF0D9488),
            titleColor: const Color(0xFF0F766E),
            border: Border.all(color: const Color(0xFF99F6E4), width: 1.5),
          ),
          _buildMetricCard(
            title: 'Exam',
            value: '$_examsCount',
            subtitle: 'Total exam created',
            icon: Icons.assignment_outlined,
            bgGradient: const LinearGradient(
              colors: [Color(0xFFFFFBEB), Color(0xFFFEF08A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            iconColor: const Color(0xFFD97706),
            titleColor: const Color(0xFFB45309),
            border: Border.all(color: const Color(0xFFFDE047), width: 1.5),
          ),
        ];

        if (useRow) {
          return Row(
            children: [
              Expanded(child: cards[0]),
              const SizedBox(width: 16),
              Expanded(child: cards[1]),
              const SizedBox(width: 16),
              Expanded(child: cards[2]),
            ],
          );
        } else {
          return Column(
            children: [
              cards[0],
              const SizedBox(height: 16),
              cards[1],
              const SizedBox(height: 16),
              cards[2],
            ],
          );
        }
      },
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Gradient bgGradient,
    required Color iconColor,
    required Border border,
    required Color titleColor,
  }) {
    return Container(
      height: 125, // Fixed height makes them perfectly equal!
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: bgGradient,
        borderRadius: BorderRadius.circular(16),
        border: border,
        boxShadow: [
          BoxShadow(
            color: const Color.fromRGBO(0, 0, 0, 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center, // Center contents vertically
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                    fontFamily: 'Outfit',
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                    fontFamily: 'Outfit',
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF475569),
                    fontFamily: 'Outfit',
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color.fromRGBO(0, 0, 0, 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoursesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Your Courses',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
                fontFamily: 'Outfit',
              ),
            ),
            TextButton(
              onPressed: () {},
              child: Row(
                children: const [
                  Text(
                    'View all',
                    style: TextStyle(
                      color: Color(0xFF20B486),
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Outfit',
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.chevron_right, size: 16, color: Color(0xFF20B486)),
                ],
              ),
            ),
          ],
        ),
        if (_errorMessage.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Text(
              'Notice: $_errorMessage. Fallback data shown.',
              style: const TextStyle(
                color: Colors.orangeAccent,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                fontFamily: 'Outfit',
              ),
            ),
          ),
        const SizedBox(height: 16),
        if (_coursesList.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 48),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: const [
                Icon(Icons.folder_open, size: 48, color: Color(0xFF94A3B8)),
                SizedBox(height: 16),
                Text(
                  'No courses created yet',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Outfit',
                  ),
                ),
              ],
            ),
          )
        else
          ..._coursesList.map((course) => _buildCourseItem(course)),
        const SizedBox(height: 24),
        _buildPagination(),
      ],
    );
  }

  Widget _buildCourseItem(dynamic course) {
    final title = course['title'] ?? 'Untitled Course';
    final learners = course['learnersCount'] ?? 0;
    final lessons = course['lessonsCount'] ?? 0;
    final thumbnail = course['thumbnailUrl'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEFF2F5)),
        boxShadow: [
          BoxShadow(
            color: const Color.fromRGBO(0, 0, 0, 0.01),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Course icon/image container
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFE6FFFA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: thumbnail.toString().isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      thumbnail,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.school, color: Color(0xFF20B486), size: 24),
                    ),
                  )
                : const Icon(Icons.school, color: Color(0xFF20B486), size: 24),
          ),
          const SizedBox(width: 16),
          // Title & detail stats
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                    fontFamily: 'Outfit',
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.person_outline, size: 14, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 4),
                    Text(
                      '$learners Learners',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        fontFamily: 'Outfit',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        color: Color(0xFFCBD5E1),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.class_outlined, size: 14, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 4),
                    Text(
                      '$lessons lesson',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        fontFamily: 'Outfit',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Arrow button
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: const Icon(
              Icons.arrow_forward,
              color: Color(0xFF64748B),
              size: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPagination() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        InkWell(
          onTap: () {},
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.chevron_left, size: 16, color: Color(0xFF94A3B8)),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF20B486),
            shape: BoxShape.circle,
          ),
          child: const Text(
            '1',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontFamily: 'Outfit',
            ),
          ),
        ),
        const SizedBox(width: 8),
        InkWell(
          onTap: () {},
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.chevron_right, size: 16, color: Color(0xFF94A3B8)),
          ),
        ),
      ],
    );
  }
}
