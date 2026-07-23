import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../utils/config.dart';
import '../../../data/services/auth_service.dart';
import '../login_page.dart';
import '../learner/learner_home_page.dart';
import 'trainer_courses_page.dart';
import 'trainer_exams_page.dart';
import '../../../utils/toast_helper.dart';
import 'question_bank/trainer_question_bank_page.dart';
import 'trainer_profile_page.dart';

class TrainerDashboardPage extends StatefulWidget {
  const TrainerDashboardPage({super.key});

  @override
  State<TrainerDashboardPage> createState() => _TrainerDashboardPageState();
}

class _TrainerDashboardPageState extends State<TrainerDashboardPage> {
  final _authService = AuthService();
  String _trainerName = 'Trainer';
  String _trainerInitials = 'T';
  String _trainerAvatarUrl = '';
  bool _isLoading = true;
  String _errorMessage = '';

  // Stats
  int _coursesCount = 0;
  int _examsCount = 0;
  int _learnersCount = 0;
  double _totalRevenue = 0.0;
  double _averageRating = 0.0;
  List<dynamic> _coursesList = [];
  List<dynamic> _recentActivities = [];
  List<dynamic> _monthlyRevenues = [];

  String get apiBaseUrl => EnvConfig.v1BaseUrl;

  @override
  void initState() {
    super.initState();
    _loadTrainerInfo();
    _fetchDashboardData();
  }

  Future<void> _loadTrainerInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final fullName = prefs.getString('user_fullname') ?? 'Trainer';
    final avatarUrl = prefs.getString('user_avatar_url') ?? '';
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
      _trainerAvatarUrl = avatarUrl;
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
          _totalRevenue = (data['totalRevenue'] ?? 0.0).toDouble();
          _averageRating = (data['averageRating'] ?? 0.0).toDouble();
          _coursesList = data['courses'] ?? [];
          _recentActivities = data['recentActivities'] ?? [];
          _monthlyRevenues = data['monthlyRevenues'] ?? [];
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
    setState(() {
      _coursesCount = 12;
      _learnersCount = 428;
      _examsCount = 5;
      _totalRevenue = 15000000.0;
      _averageRating = 4.8;
      _coursesList = [
        {
          'id': 1,
          'title': 'IELTS Intensive 7.0+',
          'learnersCount': 120,
          'lessonsCount': 24,
          'thumbnailUrl': null,
        },
        {
          'id': 2,
          'title': 'Business English Advanced',
          'learnersCount': 85,
          'lessonsCount': 16,
          'thumbnailUrl': null,
        },
      ];
      _recentActivities = [
        {'type': 'ENROLLMENT', 'action': 'New student enrolled in', 'target': 'IELTS Intensive 7.0+', 'time': '2 hours ago'},
        {'type': 'RATING', 'action': 'New 5-star review on', 'target': 'Business English', 'time': '5 hours ago'},
        {'type': 'PAYMENT', 'action': 'Sold course', 'target': 'Grammar Masterclass', 'time': '1 day ago'},
      ];
      _monthlyRevenues = List.generate(12, (index) => {'month': index + 1, 'revenue': index * 1.5});
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

  String _formatCurrency(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M đ';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}K đ';
    }
    return '${amount.toStringAsFixed(0)} đ';
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 1024;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: !isDesktop ? Drawer(child: _buildSidebar(context)) : null,
      body: Row(
        children: [
          if (isDesktop) SizedBox(width: 260, child: _buildSidebar(context)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(context, !isDesktop),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFF20B486)))
                      : SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildWelcomeSection(),
                              const SizedBox(height: 32),
                              _buildMetricCards(size.width),
                              const SizedBox(height: 32),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: _buildChartSection(),
                                  ),
                                  if (isDesktop) const SizedBox(width: 24),
                                  if (isDesktop)
                                    Expanded(
                                      flex: 1,
                                      child: _buildRecentActivitySection(),
                                    ),
                                ],
                              ),
                              if (!isDesktop) const SizedBox(height: 32),
                              if (!isDesktop) _buildRecentActivitySection(),
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
          InkWell(
            onTap: () => Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const LearnerHomePage()),
              (route) => false,
            ),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF20B486), Color(0xFF159971)]),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.school, size: 20, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'HanGo',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                      fontFamily: 'Outfit',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 40),
          _buildSidebarItem(Icons.dashboard_rounded, 'Dashboard', isActive: true),
          _buildSidebarItem(Icons.library_books_rounded, 'Courses', onTap: () {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const TrainerCoursesPage()));
          }),
          _buildSidebarItem(Icons.assignment_rounded, 'Exams', onTap: () {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const TrainerExamsPage()));
          }),
          _buildSidebarItem(Icons.people_alt_rounded, 'Learners'),
          _buildSidebarItem(Icons.quiz_rounded, 'Question Bank', onTap: () {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const TrainerQuestionBankPage()));
          }),
          _buildSidebarItem(Icons.person_rounded, 'Profile', onTap: () {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const TrainerProfilePage()));
          }),
          const Spacer(),
          const Divider(color: Color(0xFFE2E8F0)),
          const SizedBox(height: 12),
          _buildSidebarItem(Icons.logout_rounded, 'Logout', color: const Color(0xFFEF4444), onTap: _handleLogout),
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
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isActive ? activeColor.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isActive ? activeColor : (color ?? const Color(0xFF64748B)),
                size: 22,
              ),
              const SizedBox(width: 16),
              Text(
                title,
                style: TextStyle(
                  color: isActive ? activeColor : (color ?? const Color(0xFF334155)),
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
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

  Widget _buildHeader(BuildContext context, bool showMenuButton) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: const Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          if (showMenuButton) ...[
            IconButton(
              icon: const Icon(Icons.menu_rounded, color: Color(0xFF4B5563)),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
            const SizedBox(width: 12),
          ],
          const Text(
            'Trainer Dashboard',
            style: TextStyle(
              color: Color(0xFF1E293B),
              fontWeight: FontWeight.w700,
              fontSize: 18,
              fontFamily: 'Outfit',
            ),
          ),
          const Spacer(),
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined, color: Color(0xFF64748B), size: 24),
                onPressed: () => ToastHelper.show(context, 'No new notifications'),
              ),
              Positioned(
                top: 14,
                right: 14,
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
          _buildProfileMenu(),
        ],
      ),
    );
  }

  Widget _buildProfileMenu() {
    return PopupMenuButton<String>(
      onSelected: (val) {
        if (val == 'profile') {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const TrainerProfilePage()));
        } else if (val == 'logout') {
          _handleLogout();
        }
      },
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'profile',
          child: Row(
            children: const [
              Icon(Icons.person_outline, size: 18, color: Color(0xFF64748B)),
              SizedBox(width: 12),
              Text('My Profile', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'logout',
          child: Row(
            children: const [
              Icon(Icons.logout, size: 18, color: Color(0xFFEF4444)),
              SizedBox(width: 12),
              Text('Logout', style: TextStyle(fontFamily: 'Outfit', color: Color(0xFFEF4444), fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(color: Color(0xFFE2F9F3), shape: BoxShape.circle),
              alignment: Alignment.center,
              child: _trainerAvatarUrl.isNotEmpty
                  ? ClipOval(
                      child: Image.network(
                        _trainerAvatarUrl,
                        width: 32,
                        height: 32,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Text(
                          _trainerInitials,
                          style: const TextStyle(color: Color(0xFF20B486), fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    )
                  : Text(
                      _trainerInitials,
                      style: const TextStyle(color: Color(0xFF20B486), fontWeight: FontWeight.bold, fontSize: 14),
                    ),
            ),
            const SizedBox(width: 8),
            Text(
              _trainerName,
              style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1E293B), fontSize: 14, fontFamily: 'Outfit'),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_errorMessage.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFCA5A5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$_errorMessage. Showing offline/mock data.',
                    style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13, fontFamily: 'Outfit'),
                  ),
                ),
              ],
            ),
          ),
        Text(
          'Welcome back, $_trainerName! 👋',
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
            fontFamily: 'Outfit',
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Here is what\'s happening with your courses today.',
          style: TextStyle(
            fontSize: 15,
            color: Color(0xFF64748B),
            fontFamily: 'Outfit',
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCards(double width) {
    int crossAxisCount = width > 1200 ? 4 : (width > 800 ? 2 : 1);
    
    return GridView.count(
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: 20,
      mainAxisSpacing: 20,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.8, // Reduced from 2.2 to prevent bottom overflow
      children: [
        _buildPremiumCard(
          title: 'Total Revenue',
          value: _formatCurrency(_totalRevenue),
          trend: '+12.5%',
          icon: Icons.account_balance_wallet_rounded,
          gradient: const LinearGradient(colors: [Color(0xFF20B486), Color(0xFF159971)]),
        ),
        _buildPremiumCard(
          title: 'Total Learners',
          value: '$_learnersCount',
          trend: '+5.2%',
          icon: Icons.group_rounded,
          gradient: const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF2563EB)]),
        ),
        _buildPremiumCard(
          title: 'Active Courses',
          value: '$_coursesCount',
          trend: '0.0%',
          icon: Icons.menu_book_rounded,
          gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)]),
        ),
        _buildPremiumCard(
          title: 'Avg Rating',
          value: _averageRating.toStringAsFixed(1),
          trend: '+0.1',
          icon: Icons.star_rounded,
          gradient: const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFD97706)]),
        ),
      ],
    );
  }

  Widget _buildPremiumCard({
    required String title,
    required String value,
    required String trend,
    required IconData icon,
    required Gradient gradient,
  }) {
    bool isPositive = trend.startsWith('+');
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: gradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                      fontFamily: 'Outfit',
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  fontFamily: 'Outfit',
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isPositive ? const Color(0xFFDCFCE7) : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isPositive ? Icons.trending_up_rounded : Icons.trending_flat_rounded,
                          size: 14,
                          color: isPositive ? const Color(0xFF16A34A) : const Color(0xFF6B7280),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          trend,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isPositive ? const Color(0xFF16A34A) : const Color(0xFF6B7280),
                            fontFamily: 'Outfit',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'vs last month',
                    style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontFamily: 'Outfit'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChartSection() {
    return Container(
      height: 380,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 20,
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
              const Text(
                'Revenue Overview',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1E293B), fontFamily: 'Outfit'),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: const [
                    Text('This Year', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569), fontFamily: 'Outfit')),
                    SizedBox(width: 4),
                    Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF64748B)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 1,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: const Color(0xFFF1F5F9),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        const style = TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w500, fontSize: 12, fontFamily: 'Outfit');
                        String text = '';
                        switch (value.toInt()) {
                          case 0: text = 'Jan'; break;
                          case 2: text = 'Mar'; break;
                          case 4: text = 'May'; break;
                          case 6: text = 'Jul'; break;
                          case 8: text = 'Sep'; break;
                          case 10: text = 'Nov'; break;
                        }
                        return SideTitleWidget(meta: meta, child: Text(text, style: style));
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      reservedSize: 42,
                      getTitlesWidget: (value, meta) {
                        return Text('${value.toInt()}M', style: const TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w500, fontSize: 12, fontFamily: 'Outfit'));
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: 11,
                minY: 0,
                maxY: _monthlyRevenues.isEmpty 
                    ? 6 
                    : (_monthlyRevenues.map((e) => ((e['revenue'] as num) / 1000000).toDouble()).reduce((a, b) => a > b ? a : b) + 2),
                lineBarsData: [
                  LineChartBarData(
                    spots: _monthlyRevenues.isEmpty
                        ? const [
                            FlSpot(0, 1), FlSpot(1, 1.5), FlSpot(2, 1.4), FlSpot(3, 3.4),
                            FlSpot(4, 2), FlSpot(5, 2.2), FlSpot(6, 1.8), FlSpot(7, 4),
                            FlSpot(8, 3.8), FlSpot(9, 4.5), FlSpot(10, 4.2), FlSpot(11, 5.5),
                          ]
                        : _monthlyRevenues.map((e) {
                            return FlSpot((e['month'] as num).toDouble() - 1, ((e['revenue'] as num) / 1000000).toDouble());
                          }).toList(),
                    isCurved: true,
                    gradient: const LinearGradient(colors: [Color(0xFF20B486), Color(0xFF3B82F6)]),
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF20B486).withOpacity(0.2),
                          const Color(0xFF3B82F6).withOpacity(0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
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

  Widget _buildRecentActivitySection() {
    return Container(
      height: 380,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Activity',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1E293B), fontFamily: 'Outfit'),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _recentActivities.isEmpty
                ? const Center(
                    child: Text('No recent activity', style: TextStyle(color: Color(0xFF94A3B8), fontFamily: 'Outfit')),
                  )
                : ListView.builder(
                    itemCount: _recentActivities.length,
                    itemBuilder: (context, index) {
                      final act = _recentActivities[index];
                      IconData icon = Icons.info_outline;
                      Color color = const Color(0xFF64748B);
                      if (act['type'] == 'PAYMENT') {
                        icon = Icons.attach_money_rounded;
                        color = const Color(0xFF20B486);
                      } else if (act['type'] == 'ENROLLMENT') {
                        icon = Icons.person_add_alt_1_rounded;
                        color = const Color(0xFF3B82F6);
                      } else if (act['type'] == 'RATING') {
                        icon = Icons.star_rounded;
                        color = const Color(0xFFF59E0B);
                      }
                      return _buildActivityItem(act['action'] ?? '', act['target'] ?? '', act['time'] ?? '', icon, color);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(String action, String target, String time, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 14, color: Color(0xFF334155), fontFamily: 'Outfit'),
                    children: [
                      TextSpan(text: '$action '),
                      TextSpan(text: target, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(time, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontFamily: 'Outfit')),
              ],
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
              'Your Top Courses',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                fontFamily: 'Outfit',
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const TrainerCoursesPage())),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF20B486),
                textStyle: const TextStyle(fontWeight: FontWeight.w700, fontFamily: 'Outfit'),
              ),
              child: Row(
                children: const [
                  Text('View all'),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded, size: 16),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_coursesList.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 48),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: const [
                Icon(Icons.folder_open_rounded, size: 48, color: Color(0xFF94A3B8)),
                SizedBox(height: 16),
                Text(
                  'No courses created yet',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 15, fontWeight: FontWeight.w500, fontFamily: 'Outfit'),
                ),
              ],
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _coursesList.length > 5 ? 5 : _coursesList.length,
            itemBuilder: (context, index) => _buildCourseItem(_coursesList[index]),
          ),
      ],
    );
  }

  Widget _buildCourseItem(dynamic course) {
    final title = course['title'] ?? 'Untitled Course';
    final learners = course['learnersCount'] ?? 0;
    final thumbnail = course['thumbnailUrl'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
            ),
            child: thumbnail.toString().isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      thumbnail,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.menu_book_rounded, color: Color(0xFF94A3B8), size: 32),
                    ),
                  )
                : const Icon(Icons.menu_book_rounded, color: Color(0xFF94A3B8), size: 32),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                    fontFamily: 'Outfit',
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.people_alt_rounded, size: 14, color: Color(0xFF3B82F6)),
                          const SizedBox(width: 6),
                          Text(
                            '$learners Students',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF2563EB), fontFamily: 'Outfit'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.layers_rounded, size: 14, color: Color(0xFF6B7280)),
                          const SizedBox(width: 6),
                          Text(
                            '${course['versionsCount'] ?? 1} Versions',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4B5563), fontFamily: 'Outfit'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF64748B), size: 16),
          ),
        ],
      ),
    );
  }
}
