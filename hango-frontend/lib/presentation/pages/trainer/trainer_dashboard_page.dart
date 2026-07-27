import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../utils/config.dart';
import '../../../data/services/auth_service.dart';
import '../../../utils/toast_helper.dart';
import '../../widgets/trainer/trainer_sidebar.dart';
import '../login_page.dart';
import 'trainer_courses_page.dart';
import 'trainer_profile_page.dart';

class TrainerDashboardPage extends StatefulWidget {
  final bool isEmbedded;
  const TrainerDashboardPage({super.key, this.isEmbedded = false});

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

  int _coursesCount = 0;
  int _examsCount = 0;
  int _learnersCount = 0;
  double _totalRevenue = 0.0;
  double _averageRating = 0.0;
  List<dynamic> _coursesList = [];
  List<dynamic> _recentActivities = [];
  List<dynamic> _monthlyRevenues = [];
  String _selectedChartPeriod = '1Y';

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
        {'id': 1, 'title': 'IELTS Intensive 7.0+', 'learnersCount': 120, 'lessonsCount': 24, 'thumbnailUrl': null},
        {'id': 2, 'title': 'Business English Advanced', 'learnersCount': 85, 'lessonsCount': 16, 'thumbnailUrl': null},
      ];
      _recentActivities = [
        {'type': 'ENROLLMENT', 'action': 'New student enrolled in', 'target': 'IELTS Intensive 7.0+', 'time': '2 hours ago'},
        {'type': 'RATING', 'action': 'New 5-star review on', 'target': 'Business English', 'time': '5 hours ago'},
        {'type': 'PAYMENT', 'action': 'Sold course', 'target': 'Grammar Masterclass', 'time': '1 day ago'},
      ];
      _monthlyRevenues = List.generate(12, (index) => {'month': index + 1, 'revenue': index * 1.5});
    });
  }

  String _formatCurrency(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M đ';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}K đ';
    }
    return '${amount.toStringAsFixed(0)} đ';
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

    if (widget.isEmbedded) {
      return _buildBodyContent(context, isDesktop, size);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: !isDesktop ? const Drawer(child: TrainerSidebar(activeIndex: 0)) : null,
      body: Row(
        children: [
          if (isDesktop) const SizedBox(width: 260, child: TrainerSidebar(activeIndex: 0)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(context, !isDesktop),
                Expanded(child: _buildBodyContent(context, isDesktop, size)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBodyContent(BuildContext context, bool isDesktop, Size size) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF20B486)));
    }
    return SingleChildScrollView(
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
              Expanded(flex: 2, child: _buildChartSection()),
              if (isDesktop) const SizedBox(width: 24),
              if (isDesktop) Expanded(flex: 1, child: _buildRecentActivitySection()),
            ],
          ),
          if (!isDesktop) ...[const SizedBox(height: 32), _buildRecentActivitySection()],
          const SizedBox(height: 32),
          _buildCoursesSection(),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool showMenuButton) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0)))),
      child: Row(
        children: [
          if (showMenuButton) ...[
            IconButton(icon: const Icon(Icons.menu_rounded, color: Color(0xFF4B5563)), onPressed: () => Scaffold.of(context).openDrawer()),
            const SizedBox(width: 12),
          ],
          const Text('Trainer Dashboard', style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.w700, fontSize: 18, fontFamily: 'Outfit')),
          const Spacer(),
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(icon: const Icon(Icons.notifications_outlined, color: Color(0xFF64748B), size: 24), onPressed: () => ToastHelper.show(context, 'No new notifications')),
              Positioned(top: 14, right: 14, child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle))),
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
        const PopupMenuItem(value: 'profile', child: Row(children: [Icon(Icons.person_outline, size: 18, color: Color(0xFF64748B)), SizedBox(width: 12), Text('My Profile', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w500))])),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'logout', child: Row(children: [Icon(Icons.logout, size: 18, color: Color(0xFFEF4444)), SizedBox(width: 12), Text('Logout', style: TextStyle(fontFamily: 'Outfit', color: Color(0xFFEF4444), fontWeight: FontWeight.w500))])),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE2E8F0)), borderRadius: BorderRadius.circular(24)),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(color: Color(0xFFE2F9F3), shape: BoxShape.circle),
              alignment: Alignment.center,
              child: _trainerAvatarUrl.isNotEmpty
                  ? ClipOval(
                      child: Image.network(_trainerAvatarUrl, width: 32, height: 32, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => Text(_trainerInitials, style: const TextStyle(color: Color(0xFF20B486), fontWeight: FontWeight.bold, fontSize: 14))),
                    )
                  : Text(_trainerInitials, style: const TextStyle(color: Color(0xFF20B486), fontWeight: FontWeight.bold, fontSize: 14)),
            ),
            const SizedBox(width: 8),
            Text(_trainerName, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1E293B), fontSize: 14, fontFamily: 'Outfit')),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF1E293B)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.15), blurRadius: 24, offset: const Offset(0, 10))],
        border: Border.all(color: const Color(0xFF334155).withValues(alpha: 0.5), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_errorMessage.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFFCA5A5))),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text('$_errorMessage. Showing offline/mock data.', style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13, fontFamily: 'Outfit', fontWeight: FontWeight.w500))),
                ],
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFF20B486).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFF20B486).withValues(alpha: 0.4))),
                      child: const Text('COMMAND CENTER • LIVE', style: TextStyle(color: Color(0xFF34D399), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2, fontFamily: 'Outfit')),
                    ),
                    const SizedBox(height: 12),
                    Text('Welcome back, $_trainerName!', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white, fontFamily: 'Outfit', letterSpacing: -0.5)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildWelcomeStatBadge('Courses', '$_coursesCount', const Color(0xFF34D399)),
                        const SizedBox(width: 8),
                        _buildWelcomeStatBadge('Exams', '$_examsCount', const Color(0xFF60A5FA)),
                        const SizedBox(width: 8),
                        _buildWelcomeStatBadge('Learners', '$_learnersCount', const Color(0xFFA78BFA)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text('Here is your training ecosystem performance and learner engagement overview.', style: TextStyle(fontSize: 15, color: Color(0xFF94A3B8), fontFamily: 'Outfit')),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              InkWell(
                onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const TrainerCoursesPage())),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF20B486), Color(0xFF159971)]),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: const Color(0xFF20B486).withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6))],
                  ),
                  child: const Text('Manage Courses', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14, fontFamily: 'Outfit')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeStatBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.3))),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 12, fontFamily: 'Outfit', color: Color(0xFFE2E8F0)),
          children: [TextSpan(text: '$value ', style: TextStyle(fontWeight: FontWeight.w800, color: color)), TextSpan(text: label)],
        ),
      ),
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
      childAspectRatio: 1.85,
      children: [
        _buildPremiumCard(title: 'Total Revenue', value: _formatCurrency(_totalRevenue), trend: '+12.5%', accentColor: const Color(0xFF20B486), subtitle: 'vs last month'),
        _buildPremiumCard(title: 'Total Learners', value: '$_learnersCount', trend: '+5.2%', accentColor: const Color(0xFF3B82F6), subtitle: 'active students'),
        _buildPremiumCard(title: 'Active Courses', value: '$_coursesCount', trend: '0.0%', accentColor: const Color(0xFF8B5CF6), subtitle: 'published modules'),
        _buildPremiumCard(title: 'Avg Rating', value: _averageRating.toStringAsFixed(1), trend: '+0.1', accentColor: const Color(0xFFF59E0B), subtitle: 'out of 5.0 stars'),
      ],
    );
  }

  Widget _buildPremiumCard({required String title, required String value, required String trend, required Color accentColor, required String subtitle}) {
    bool isPositive = trend.startsWith('+');
    return _HoverCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle, boxShadow: [BoxShadow(color: accentColor.withValues(alpha: 0.5), blurRadius: 6)]),
                  ),
                  const SizedBox(width: 10),
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF64748B), fontFamily: 'Outfit')),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: isPositive ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(20)),
                child: Text(trend, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isPositive ? const Color(0xFF15803D) : const Color(0xFF475569), fontFamily: 'Outfit')),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), fontFamily: 'Outfit', letterSpacing: -1.0)),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500, fontFamily: 'Outfit')),
        ],
      ),
    );
  }

  Widget _buildChartSection() {
    return _HoverCard(
      padding: const EdgeInsets.all(24),
      child: SizedBox(
        height: 380,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Revenue Analytics', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), fontFamily: 'Outfit')), SizedBox(height: 4), Text('Monthly earning progression', style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontFamily: 'Outfit'))]),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: ['1M', '3M', '6M', '1Y'].map((period) {
                      final isSelected = _selectedChartPeriod == period;
                      return InkWell(
                        onTap: () => setState(() => _selectedChartPeriod = period),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: isSelected ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))] : null,
                          ),
                          child: Text(period, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500, color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B), fontFamily: 'Outfit')),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Expanded(
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 1, getDrawingHorizontalLine: (value) => FlLine(color: const Color(0xFFF1F5F9), strokeWidth: 1)),
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
                          const style = TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w600, fontSize: 12, fontFamily: 'Outfit');
                          String text = switch (value.toInt()) { 0 => 'Jan', 2 => 'Mar', 4 => 'May', 6 => 'Jul', 8 => 'Sep', 10 => 'Nov', _ => '' };
                          return SideTitleWidget(meta: meta, child: Text(text, style: style));
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, interval: 1, reservedSize: 42, getTitlesWidget: (value, meta) => Text('${value.toInt()}M', style: const TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w600, fontSize: 12, fontFamily: 'Outfit')))),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: 0, maxX: 11, minY: 0,
                  maxY: _monthlyRevenues.isEmpty ? 6 : (_monthlyRevenues.map((e) => ((e['revenue'] as num) / 1000000).toDouble()).reduce((a, b) => a > b ? a : b) + 2),
                  lineBarsData: [
                    LineChartBarData(
                      spots: _monthlyRevenues.isEmpty ? const [FlSpot(0, 1), FlSpot(1, 1.5), FlSpot(2, 1.4), FlSpot(3, 3.4), FlSpot(4, 2), FlSpot(5, 2.2), FlSpot(6, 1.8), FlSpot(7, 4), FlSpot(8, 3.8), FlSpot(9, 4.5), FlSpot(10, 4.2), FlSpot(11, 5.5)] : _monthlyRevenues.map((e) => FlSpot((e['month'] as num).toDouble() - 1, ((e['revenue'] as num) / 1000000).toDouble())).toList(),
                      isCurved: true,
                      curveSmoothness: 0.35,
                      gradient: const LinearGradient(colors: [Color(0xFF20B486), Color(0xFF10B981)]),
                      barWidth: 3.5,
                      isStrokeCapRound: true,
                      dotData: FlDotData(show: false),
                      belowBarData: BarAreaData(show: true, gradient: LinearGradient(colors: [const Color(0xFF20B486).withValues(alpha: 0.25), const Color(0xFF20B486).withValues(alpha: 0.0)], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivitySection() {
    return _HoverCard(
      padding: const EdgeInsets.all(24),
      child: SizedBox(
        height: 380,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Recent Activity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), fontFamily: 'Outfit')),
            const SizedBox(height: 6),
            const Text('Real-time student actions', style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontFamily: 'Outfit')),
            const SizedBox(height: 24),
            Expanded(
              child: _recentActivities.isEmpty
                  ? const Center(child: Text('No recent activity', style: TextStyle(color: Color(0xFF94A3B8), fontFamily: 'Outfit')))
                  : ListView.builder(
                      itemCount: _recentActivities.length,
                      itemBuilder: (context, index) {
                        final act = _recentActivities[index];
                        final isLast = index == _recentActivities.length - 1;
                        final type = act['type'];
                        final tag = type == 'PAYMENT' ? 'PAYMENT' : (type == 'ENROLLMENT' ? 'ENROLL' : (type == 'RATING' ? 'REVIEW' : 'INFO'));
                        final color = type == 'PAYMENT' ? const Color(0xFF0D9488) : (type == 'ENROLLMENT' ? const Color(0xFF2563EB) : (type == 'RATING' ? const Color(0xFFD97706) : const Color(0xFF64748B)));
                        return _buildTimelineItem(act['action'] ?? '', act['target'] ?? '', act['time'] ?? '', tag, color, isLast);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineItem(String action, String target, String time, String tag, Color color, bool isLast) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(width: 10, height: 10, margin: const EdgeInsets.only(top: 4), decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2), boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 4)])),
              if (!isLast) Expanded(child: Container(width: 2, color: const Color(0xFFF1F5F9))),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)), child: Text(tag, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color, fontFamily: 'Outfit', letterSpacing: 0.5))),
                      const Spacer(),
                      Text(time, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontFamily: 'Outfit', fontWeight: FontWeight.w500)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(fontSize: 13, color: Color(0xFF475569), fontFamily: 'Outfit', height: 1.4),
                      children: [TextSpan(text: '$action '), TextSpan(text: target, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0F172A)))],
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

  Widget _buildCoursesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Your Top Courses', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), fontFamily: 'Outfit')), SizedBox(height: 4), Text('Highest enrollment and learner activity', style: TextStyle(fontSize: 14, color: Color(0xFF64748B), fontFamily: 'Outfit'))]),
            InkWell(
              onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const TrainerCoursesPage())),
              borderRadius: BorderRadius.circular(12),
              child: const Padding(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8), child: Text('View all courses →', style: TextStyle(color: Color(0xFF20B486), fontWeight: FontWeight.w700, fontSize: 14, fontFamily: 'Outfit'))),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _coursesList.isEmpty
            ? Container(
                padding: const EdgeInsets.symmetric(vertical: 48),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFE2E8F0))),
                child: const Column(children: [Text('No courses created yet', style: TextStyle(color: Color(0xFF64748B), fontSize: 15, fontWeight: FontWeight.w600, fontFamily: 'Outfit')), SizedBox(height: 4), Text('Start building your first curriculum to see analytics here.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontFamily: 'Outfit'))]),
              )
            : ListView.builder(
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
    final int learners = (course['learnersCount'] ?? 0) as int;
    final int versions = (course['versionsCount'] ?? 1) as int;
    final thumbnail = course['thumbnailUrl'] ?? '';
    final double maxReference = _learnersCount > 0 ? _learnersCount.toDouble() : 150.0;
    final double popularityRatio = (learners / maxReference).clamp(0.05, 1.0);

    return _HoverCard(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const TrainerCoursesPage())),
      child: Row(
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(16)),
            alignment: Alignment.center,
            child: thumbnail.toString().isNotEmpty
                ? ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.network(thumbnail, width: 80, height: 80, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => Text(title.isNotEmpty ? title[0].toUpperCase() : 'C', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Color(0xFF64748B), fontFamily: 'Outfit'))))
                : Text(title.isNotEmpty ? title[0].toUpperCase() : 'C', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Color(0xFF64748B), fontFamily: 'Outfit')),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A), fontFamily: 'Outfit')),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(20)), child: Text('$learners Students', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF2563EB), fontFamily: 'Outfit'))),
                    const SizedBox(width: 8),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(20)), child: Text('$versions Versions', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569), fontFamily: 'Outfit'))),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: popularityRatio, backgroundColor: const Color(0xFFF1F5F9), valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF20B486)), minHeight: 6))),
                    const SizedBox(width: 12),
                    Text('Engagement ${(popularityRatio * 100).toStringAsFixed(0)}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B), fontFamily: 'Outfit')),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HoverCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const _HoverCard({required this.child, this.onTap, this.padding, this.margin});

  @override
  State<_HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<_HoverCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          margin: widget.margin,
          padding: widget.padding ?? const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _isHovered ? const Color(0xFF20B486).withValues(alpha: 0.5) : const Color(0xFFF1F5F9), width: 1.5),
            boxShadow: [BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: _isHovered ? 0.07 : 0.02), blurRadius: _isHovered ? 24 : 16, offset: const Offset(0, 8))],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
