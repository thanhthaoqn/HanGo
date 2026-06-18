import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/services/auth_service.dart';
import '../login_page.dart';

class TrainerDashboardPage extends StatefulWidget {
  const TrainerDashboardPage({super.key});

  @override
  State<TrainerDashboardPage> createState() => _TrainerDashboardPageState();
}

class _TrainerDashboardPageState extends State<TrainerDashboardPage> {
  final _authService = AuthService();
  
  // Trainer Profile info
  String _trainerName = 'Trainer';
  String _trainerEmail = '';
  String _trainerInitials = 'T';
  
  // Navigation
  int _selectedMenuIndex = 0; // 0: Dashboard, 1: Courses, 2: Exam, 3: Learner, 4: Question Bank, 5: Task
  
  // Dashboard stats
  bool _isLoadingDashboard = true;
  int _coursesCount = 0;
  int _learnersCount = 0;
  int _examsCount = 0;
  List<dynamic> _coursesList = [];
  
  // Pagination
  int _coursesPage = 0;
  int _coursesTotalPages = 1;

  String get apiBaseUrl {
    final authUrl = AuthService.baseUrl;
    return authUrl.replaceAll('/auth', ''); // e.g. http://localhost:8080/api
  }

  @override
  void initState() {
    super.initState();
    _loadTrainerInfo();
    _fetchDashboardData();
  }

  Future<void> _loadTrainerInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final fullName = prefs.getString('user_fullname') ?? 'Trainer';
    final email = prefs.getString('user_email') ?? '';
    
    String initials = 'T';
    if (fullName.trim().isNotEmpty) {
      final parts = fullName.trim().split(' ');
      if (parts.isNotEmpty) {
        initials = parts.last[0].toUpperCase();
      }
    }

    setState(() {
      _trainerName = fullName;
      _trainerEmail = email;
      _trainerInitials = initials;
    });
  }

  Future<void> _fetchDashboardData() async {
    setState(() {
      _isLoadingDashboard = true;
    });

    try {
      final token = await _authService.getToken();
      if (token == null) {
        debugPrint('No auth token found');
        setState(() {
          _isLoadingDashboard = false;
        });
        return;
      }

      final url = Uri.parse('$apiBaseUrl/v1/trainer/dashboard?page=$_coursesPage&size=6');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _coursesCount = data['coursesCount'] ?? 0;
          _learnersCount = data['learnersCount'] ?? 0;
          _examsCount = data['examsCount'] ?? 0;
          _coursesList = data['courses'] ?? [];
          _coursesTotalPages = data['totalPages'] ?? 1;
          _isLoadingDashboard = false;
        });
      } else {
        setState(() {
          _isLoadingDashboard = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load dashboard data: ${response.body}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingDashboard = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading dashboard: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _handleLogout() async {
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
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Slate 50
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 1024;
          return Row(
            children: [
              if (isDesktop)
                Container(
                  width: 240,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(right: BorderSide(color: Color(0xFFE5E7EB))),
                  ),
                  child: _buildSidebarContent(context),
                ),
              Expanded(
                child: Column(
                  children: [
                    _buildHeader(context, isDesktop),
                    Expanded(
                      child: _buildMainContent(isDesktop),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      drawer: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 1024) return const SizedBox();
          return Drawer(
            child: _buildSidebarContent(context, isMobileDrawer: true),
          );
        },
      ),
    );
  }

  // ------------------------------------------------------------------------
  // HEADER
  // ------------------------------------------------------------------------
  Widget _buildHeader(BuildContext context, bool isDesktop) {
    String title = 'Dashboard';
    if (_selectedMenuIndex == 1) {
      title = 'Courses';
    } else if (_selectedMenuIndex == 2) {
      title = 'Exam';
    } else if (_selectedMenuIndex == 3) {
      title = 'Learner';
    } else if (_selectedMenuIndex == 4) {
      title = 'Question Bank';
    } else if (_selectedMenuIndex == 5) {
      title = 'Task';
    }

    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (!isDesktop)
                IconButton(
                  icon: const Icon(Icons.menu, color: Color(0xFF4B5563)),
                  onPressed: () {
                    Scaffold.of(context).openDrawer();
                  },
                ),
              if (!isDesktop) const SizedBox(width: 8),
              
              const Icon(Icons.chevron_right, size: 14, color: Color(0xFF9CA3AF)),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF28B79B),
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Outfit',
                ),
              ),
            ],
          ),
          
          Row(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_none_outlined, color: Color(0xFF4B5563), size: 26),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('No new notifications'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              
              PopupMenuButton<String>(
                onSelected: (val) {
                  if (val == 'logout') {
                    _handleLogout();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Settings under development for $_trainerName')),
                    );
                  }
                },
                offset: const Offset(0, 50),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE6FFFA),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            _trainerInitials,
                            style: const TextStyle(
                              color: Color(0xFF28B79B),
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              fontFamily: 'Outfit',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _trainerName,
                        style: const TextStyle(
                          color: Color(0xFF1F2937),
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          fontFamily: 'Outfit',
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.keyboard_arrow_down, size: 16, color: Color(0xFF4B5563)),
                    ],
                  ),
                ),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    enabled: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _trainerName,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1F2937), fontFamily: 'Outfit'),
                        ),
                        Text(
                          _trainerEmail,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontFamily: 'Outfit'),
                        ),
                        const Divider(),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'settings',
                    child: Row(
                      children: [
                        Icon(Icons.settings_outlined, size: 20),
                        SizedBox(width: 8),
                        Text('Settings', style: TextStyle(fontFamily: 'Outfit')),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(Icons.logout, size: 20, color: Colors.redAccent),
                        SizedBox(width: 8),
                        Text('Log Out', style: TextStyle(color: Colors.redAccent, fontFamily: 'Outfit')),
                      ],
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

  // ------------------------------------------------------------------------
  // SIDEBAR
  // ------------------------------------------------------------------------
  Widget _buildSidebarContent(BuildContext context, {bool isMobileDrawer = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
          child: Image.network(
            'https://res.cloudinary.com/diqekap4o/image/upload/v1781621071/logo_ayqvq4.png',
            height: 48,
            alignment: Alignment.centerLeft,
            errorBuilder: (context, error, stackTrace) {
              return Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE6FFFA),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.school, size: 20, color: Color(0xFF28B79B)),
                  ),
                  const SizedBox(width: 10),
                  RichText(
                    text: const TextSpan(
                      text: 'Han',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                        fontFamily: 'Outfit',
                      ),
                      children: [
                        TextSpan(
                          text: 'Go',
                          style: TextStyle(
                            color: Color(0xFF28B79B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                _buildSidebarMenuItem(
                  index: 0,
                  icon: Icons.grid_view_outlined,
                  title: 'Dashboard',
                  isMobileDrawer: isMobileDrawer,
                ),
                const SizedBox(height: 8),
                _buildSidebarMenuItem(
                  index: 1,
                  icon: Icons.menu_book_outlined,
                  title: 'Courses',
                  isMobileDrawer: isMobileDrawer,
                ),
                const SizedBox(height: 8),
                _buildSidebarMenuItem(
                  index: 2,
                  icon: Icons.assignment_outlined,
                  title: 'Exam',
                  isMobileDrawer: isMobileDrawer,
                ),
                const SizedBox(height: 8),
                _buildSidebarMenuItem(
                  index: 3,
                  icon: Icons.people_outline,
                  title: 'Learner',
                  isMobileDrawer: isMobileDrawer,
                ),
                const SizedBox(height: 8),
                _buildSidebarMenuItem(
                  index: 4,
                  icon: Icons.format_list_bulleted_outlined,
                  title: 'Question Bank',
                  isMobileDrawer: isMobileDrawer,
                ),
                const SizedBox(height: 8),
                _buildSidebarMenuItem(
                  index: 5,
                  icon: Icons.task_alt_outlined,
                  title: 'Task',
                  isMobileDrawer: isMobileDrawer,
                ),
                const Spacer(),
                const Divider(color: Color(0xFFE5E7EB)),
                const SizedBox(height: 12),
                _buildSidebarBottomItem(
                  icon: Icons.help_outline,
                  title: 'Help Center',
                  onTap: () {
                    if (isMobileDrawer) Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Opening Help Center...')),
                    );
                  },
                ),
                const SizedBox(height: 8),
                _buildSidebarBottomItem(
                  icon: Icons.logout,
                  title: 'Logout',
                  onTap: () {
                    if (isMobileDrawer) Navigator.pop(context);
                    _handleLogout();
                  },
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSidebarMenuItem({
    required int index,
    required IconData icon,
    required String title,
    required bool isMobileDrawer,
  }) {
    final isSelected = _selectedMenuIndex == index;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedMenuIndex = index;
          });
          if (index == 0) {
            _fetchDashboardData();
          }
          if (isMobileDrawer) {
            Navigator.pop(context);
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF28B79B) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : const Color(0xFF4B5563),
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF4B5563),
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  fontFamily: 'Outfit',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarBottomItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFF4B5563), size: 20),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF4B5563),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Outfit',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------------
  // MAIN BODY SWITCHER
  // ------------------------------------------------------------------------
  Widget _buildMainContent(bool isDesktop) {
    switch (_selectedMenuIndex) {
      case 0:
        return _buildDashboardTab(isDesktop);
      default:
        return _buildPlaceholderTab();
    }
  }

  Widget _buildPlaceholderTab() {
    String title = 'Feature';
    if (_selectedMenuIndex == 1) {
      title = 'Courses';
    } else if (_selectedMenuIndex == 2) {
      title = 'Exam';
    } else if (_selectedMenuIndex == 3) {
      title = 'Learner';
    } else if (_selectedMenuIndex == 4) {
      title = 'Question Bank';
    } else if (_selectedMenuIndex == 5) {
      title = 'Task';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.construction_outlined, size: 64, color: const Color(0x8028B79B)),
          const SizedBox(height: 16),
          Text(
            '$title section is under construction',
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF6B7280),
              fontFamily: 'Outfit',
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------------
  // DASHBOARD TAB
  // ------------------------------------------------------------------------
  Widget _buildDashboardTab(bool isDesktop) {
    if (_isLoadingDashboard) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF28B79B),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dashboard',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Welcome back, check your stats for today.',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF6B7280),
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 24),

          // Overview Header Tab
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.only(bottom: 8),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Color(0xFF28B79B), width: 2),
                      ),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.bar_chart, size: 16, color: Color(0xFF28B79B)),
                        SizedBox(width: 6),
                        Text(
                          'Overview',
                          style: TextStyle(
                            color: Color(0xFF28B79B),
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Outfit',
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 1, color: Color(0xFFE5E7EB)),
            ],
          ),
          const SizedBox(height: 24),

          // Stats Cards
          LayoutBuilder(
            builder: (context, cardConstraints) {
              final width = cardConstraints.maxWidth;
              if (width >= 768) {
                return Row(
                  children: [
                    Expanded(
                      child: _buildStatsCard(
                        title: 'Courses',
                        value: '$_coursesCount',
                        subtext: 'Total courses created',
                        icon: Icons.menu_book_outlined,
                        backgroundColor: const Color(0xFFEFF6FF),
                        iconColor: const Color(0xFF2563EB),
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: _buildStatsCard(
                        title: 'Learner',
                        value: '$_learnersCount',
                        subtext: 'Students enrolled in your courses',
                        icon: Icons.people_outline,
                        backgroundColor: const Color(0xFFECFDF5),
                        iconColor: const Color(0xFF059669),
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: _buildStatsCard(
                        title: 'Exam',
                        value: '$_examsCount',
                        subtext: 'Total exam created',
                        icon: Icons.help_center_outlined,
                        backgroundColor: const Color(0xFFFFFBEB),
                        iconColor: const Color(0xFFD97706),
                      ),
                    ),
                  ],
                );
              } else {
                return Column(
                  children: [
                    _buildStatsCard(
                      title: 'Courses',
                      value: '$_coursesCount',
                      subtext: 'Total courses created',
                      icon: Icons.menu_book_outlined,
                      backgroundColor: const Color(0xFFEFF6FF),
                      iconColor: const Color(0xFF2563EB),
                    ),
                    const SizedBox(height: 16),
                    _buildStatsCard(
                      title: 'Learner',
                      value: '$_learnersCount',
                      subtext: 'Students enrolled in your courses',
                      icon: Icons.people_outline,
                      backgroundColor: const Color(0xFFECFDF5),
                      iconColor: const Color(0xFF059669),
                    ),
                    const SizedBox(height: 16),
                    _buildStatsCard(
                      title: 'Exam',
                      value: '$_examsCount',
                      subtext: 'Total exam created',
                      icon: Icons.help_center_outlined,
                      backgroundColor: const Color(0xFFFFFBEB),
                      iconColor: const Color(0xFFD97706),
                    ),
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 40),

          // Your Courses Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Your Courses',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                  fontFamily: 'Outfit',
                ),
              ),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedMenuIndex = 1;
                    });
                  },
                  child: Row(
                    children: const [
                      Text(
                        'View all',
                        style: TextStyle(
                          color: Color(0xFF28B79B),
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Outfit',
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.chevron_right, size: 16, color: Color(0xFF28B79B)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Courses List
          if (_coursesList.isEmpty)
            _buildEmptyCoursesState()
          else
            Column(
              children: [
                ..._coursesList.map((course) => _buildCourseItemCard(course)),
                const SizedBox(height: 24),
                _buildPaginationBar(),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildStatsCard({
    required String title,
    required String value,
    required String subtext,
    required IconData icon,
    required Color backgroundColor,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: iconColor,
                    fontFamily: 'Outfit',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                    fontFamily: 'Outfit',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtext,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                    fontFamily: 'Outfit',
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: backgroundColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseItemCard(Map<String, dynamic> course) {
    final title = course['title'] ?? 'Untitled Course';
    final learnersCount = course['learnersCount'] ?? 0;
    final lessonsCount = course['lessonsCount'] ?? 0;
    final thumbnailUrl = course['thumbnailUrl'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 48,
              height: 48,
              color: const Color(0xFFE6FFFA),
              child: thumbnailUrl != null && thumbnailUrl.toString().isNotEmpty
                  ? Image.network(
                      thumbnailUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.menu_book, color: Color(0xFF28B79B), size: 24),
                    )
                  : const Icon(Icons.menu_book, color: Color(0xFF28B79B), size: 24),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                    fontFamily: 'Outfit',
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.people_outline, size: 14, color: Color(0xFF6B7280)),
                    const SizedBox(width: 4),
                    Text(
                      '$learnersCount Learners',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                        fontFamily: 'Outfit',
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text('•', style: TextStyle(color: Color(0xFF6B7280))),
                    const SizedBox(width: 12),
                    const Icon(Icons.book_outlined, size: 14, color: Color(0xFF6B7280)),
                    const SizedBox(width: 4),
                    Text(
                      '$lessonsCount lesson${lessonsCount == 1 ? "" : "s"}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                        fontFamily: 'Outfit',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Opening course: $title')),
              );
            },
            icon: Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Color(0xFFF3F4F6),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_forward, size: 16, color: Color(0xFF4B5563)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCoursesState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.menu_book_outlined, size: 48, color: const Color(0x8028B79B)),
          const SizedBox(height: 12),
          const Text(
            'No courses created yet.',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF6B7280),
              fontFamily: 'Outfit',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: _coursesPage > 0
              ? () {
                  setState(() {
                    _coursesPage--;
                  });
                  _fetchDashboardData();
                }
              : null,
          icon: const Icon(Icons.chevron_left),
          color: const Color(0xFF28B79B),
        ),
        const SizedBox(width: 8),
        Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            color: Color(0xFF28B79B),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '${_coursesPage + 1}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontFamily: 'Outfit',
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: _coursesPage < _coursesTotalPages - 1
              ? () {
                  setState(() {
                    _coursesPage++;
                  });
                  _fetchDashboardData();
                }
              : null,
          icon: const Icon(Icons.chevron_right),
          color: const Color(0xFF28B79B),
        ),
      ],
    );
  }
}
