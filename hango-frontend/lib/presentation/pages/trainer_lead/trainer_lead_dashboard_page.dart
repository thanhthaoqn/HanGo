// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../data/models/trainer_lead_dashboard_stats_model.dart';
import '../../../data/services/auth_service.dart';
import '../login_page.dart';
import '../../widgets/trainer_lead_sidebar.dart';


class TrainerLeadDashboardPage extends StatefulWidget {
  const TrainerLeadDashboardPage({super.key});

  @override
  State<TrainerLeadDashboardPage> createState() => _TrainerLeadDashboardPageState();
}

class _TrainerLeadDashboardPageState extends State<TrainerLeadDashboardPage> {
  final _authService = AuthService();
  bool _isLoading = true;
  String _error = '';
  TrainerLeadDashboardStatsModel? _stats;
  final Dio _dio = Dio();

  String _activeMenu = 'Dashboard';
  String _userName = '';
  String _userEmail = '';
  String _userInitials = 'T';

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _fetchDashboardStats();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final fullName = prefs.getString('user_fullname') ?? 'Trainer Lead';
    final email = prefs.getString('user_email') ?? '';
    String initials = 'T';
    if (fullName.trim().isNotEmpty) {
      final parts = fullName.trim().split(' ');
      if (parts.isNotEmpty) {
        initials = parts.last[0].toUpperCase();
      }
    }
    if (mounted) {
      setState(() {
        _userName = fullName;
        _userEmail = email;
        _userInitials = initials;
      });
    }
  }

  Future<void> _fetchDashboardStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final response = await _dio.get(
        'http://localhost:8080/api/v1/trainer-lead/dashboard/stats',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        if (mounted) {
          setState(() {
            _stats = TrainerLeadDashboardStatsModel.fromJson(response.data);
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load dashboard stats: $e';
          _isLoading = false;
        });
      }
    }
  }

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
    final isDesktop = size.width > 960;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      drawer: isDesktop
          ? null
          : Drawer(
              child: TrainerLeadSidebar(
                activeMenu: _activeMenu,
                onMenuChanged: (menu) => setState(() => _activeMenu = menu),
                onLogout: _handleLogout,
                isMobileDrawer: true,
              ),
            ),
      body: Row(
        children: [
          // Sidebar for Desktop
          if (isDesktop)
            Container(
              width: 260,
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  right: BorderSide(color: Color(0xFFE5E7EB), width: 1),
                ),
              ),
              child: TrainerLeadSidebar(
                activeMenu: _activeMenu,
                onMenuChanged: (menu) => setState(() => _activeMenu = menu),
                onLogout: _handleLogout,
              ),
            ),

          // Main content area
          Expanded(
            child: Column(
              children: [
                // Top Header
                _buildHeader(context, isDesktop),

                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                    child: Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 1200),
                        child: _buildMainContent(isDesktop),
                      ),
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

  // ─────────────────────────────────────────────
  // HEADER
  // ─────────────────────────────────────────────
  Widget _buildHeader(BuildContext context, bool isDesktop) {
    return Container(
      height: 70,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Mobile hamburger OR breadcrumb
          if (!isDesktop)
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu, color: Color(0xFF4B5563)),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            )
          else
            Row(
              children: [
                const Icon(Icons.chevron_right, size: 14, color: Color(0xFF9CA3AF)),
                const SizedBox(width: 6),
                Text(
                  _activeMenu,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF28B79B),
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

          // Right: Notification + User profile
          Row(
            children: [
              // Notification Bell
              Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_none_outlined,
                        color: Color(0xFF4B5563), size: 26),
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

              // Profile Dropdown
              PopupMenuButton<String>(
                onSelected: (val) {
                  if (val == 'logout') _handleLogout();
                },
                offset: const Offset(0, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFFF1F5F9), width: 1),
                ),
                elevation: 10,
                color: Colors.white,
                shadowColor: Colors.black.withOpacity(0.08),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF28B79B), Color(0xFF1F9E84)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF28B79B).withOpacity(0.2),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              _userInitials,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                fontFamily: 'Outfit',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _userName,
                              style: const TextStyle(
                                color: Color(0xFF0F172A),
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                fontFamily: 'Outfit',
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.only(top: 2),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE6FFFA),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Trainer Lead',
                                style: TextStyle(
                                  color: Color(0xFF1F9E84),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 8,
                                  fontFamily: 'Outfit',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.keyboard_arrow_down_rounded,
                            size: 18, color: Color(0xFF64748B)),
                      ],
                    ),
                  ),
                ),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    enabled: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Color(0xFF28B79B), Color(0xFF1F9E84)],
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    _userInitials,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      fontFamily: 'Outfit',
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _userName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0F172A),
                                        fontSize: 14,
                                        fontFamily: 'Outfit',
                                      ),
                                    ),
                                    Text(
                                      _userEmail,
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
                          const SizedBox(height: 10),
                          const Divider(height: 1, color: Color(0xFFE2E8F0)),
                        ],
                      ),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'logout',
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFDE8E8),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.logout_rounded,
                              size: 18,
                              color: Colors.redAccent,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Log Out',
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              color: Colors.redAccent,
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
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

  // ─────────────────────────────────────────────
  // MAIN CONTENT SWITCHER
  // ─────────────────────────────────────────────
  Widget _buildMainContent(bool isDesktop) {
    switch (_activeMenu) {
      case 'Dashboard':
        return _buildDashboardTab(isDesktop);
      default:
        return Center(
          child: Text(
            '$_activeMenu — Coming soon',
            style: const TextStyle(
              fontSize: 18,
              color: Color(0xFF64748B),
              fontFamily: 'Outfit',
            ),
          ),
        );
    }
  }

  // ─────────────────────────────────────────────
  // DASHBOARD TAB
  // ─────────────────────────────────────────────
  Widget _buildDashboardTab(bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
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

        // Subtab indicator
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.only(bottom: 8),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Color(0xFF28B79B), width: 2.0),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.insert_chart_outlined, size: 18, color: Color(0xFF28B79B)),
                  SizedBox(width: 8),
                  Text(
                    'Overview',
                    style: TextStyle(
                      color: Color(0xFF28B79B),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      fontFamily: 'Outfit',
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
          ],
        ),
        const SizedBox(height: 24),

        // Error message
        if (_error.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Color(0xFFEF4444)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(_error,
                      style: const TextStyle(color: Color(0xFF991B1B))),
                ),
              ],
            ),
          ),

        if (_isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(color: Color(0xFF28B79B)),
            ),
          )
        else if (_stats != null)
          LayoutBuilder(
            builder: (context, constraints) {
              int crossAxisCount = 4;
              if (constraints.maxWidth < 600) {
                crossAxisCount = 1;
              } else if (constraints.maxWidth < 1200) {
                crossAxisCount = 2;
              }
              return GridView.count(
                crossAxisCount: crossAxisCount,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 24,
                mainAxisSpacing: 24,
                childAspectRatio: 1.5,
                children: [
                  _buildMetricCard(
                    title: 'REGISTERED\nUSERS',
                    value: _stats!.totalUsers
                        .toString()
                        .replaceAllMapped(
                            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                            (Match m) => '${m[1]},'),
                    iconBgColor: const Color(0xFFE6FFFA),
                    iconColor: const Color(0xFF28B79B),
                    iconData: Icons.trending_up,
                    bottomWidget: Row(
                      children: [
                        const Icon(Icons.arrow_upward,
                            size: 14, color: Color(0xFF28B79B)),
                        Text(
                          '+${_stats!.percentageIncrease}%',
                          style: const TextStyle(
                              color: Color(0xFF28B79B),
                              fontWeight: FontWeight.bold,
                              fontSize: 13),
                        ),
                        const SizedBox(width: 4),
                        const Text('vs last month',
                            style: TextStyle(
                                color: Color(0xFF64748B), fontSize: 12)),
                      ],
                    ),
                  ),
                  _buildMetricCard(
                    title: 'COURSES',
                    value: _stats!.totalCourses.toString(),
                    iconBgColor: const Color(0xFFF1F5F9),
                    iconColor: const Color(0xFF475569),
                    iconData: Icons.school_outlined,
                    bottomWidget: Row(
                      children: [
                        _buildStatusDot(
                            const Color(0xFF28B79B), '${_stats!.activeCourses}\nactive'),
                        const SizedBox(width: 24),
                        _buildStatusDot(
                            const Color(0xFFCBD5E1), '${_stats!.inactiveCourses}\ninactive'),
                      ],
                    ),
                  ),
                  _buildMetricCard(
                    title: 'ASSIGNED\nTASKS',
                    value: _stats!.assignedTasks.toString(),
                    iconBgColor: const Color(0xFFF1F5F9),
                    iconColor: const Color(0xFF475569),
                    iconData: Icons.assignment_outlined,
                    bottomWidget: const Row(
                      children: [
                        Icon(Icons.access_time, size: 14, color: Color(0xFF64748B)),
                        SizedBox(width: 6),
                        Text('Updated just now',
                            style: TextStyle(
                                color: Color(0xFF64748B), fontSize: 12)),
                      ],
                    ),
                  ),
                  _buildMetricCard(
                    title: 'PENDING\nAPPROVALS',
                    value: _stats!.pendingApprovals.toString().padLeft(2, '0'),
                    valueColor: const Color(0xFFEF4444),
                    iconBgColor: const Color(0xFFFEE2E2),
                    iconColor: const Color(0xFFEF4444),
                    iconData: Icons.assignment_late_outlined,
                    bottomWidget: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'URGENT',
                            style: TextStyle(
                                color: Color(0xFFB91C1C),
                                fontWeight: FontWeight.bold,
                                fontSize: 10),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text('Requiring attention',
                            style: TextStyle(
                                color: Color(0xFF64748B), fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    Color valueColor = const Color(0xFF0F172A),
    required Color iconBgColor,
    required Color iconColor,
    required IconData iconData,
    required Widget bottomWidget,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  height: 1.3,
                ),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(iconData, color: iconColor, size: 20),
              ),
            ],
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 36,
              fontWeight: FontWeight.bold,
              fontFamily: 'Outfit',
            ),
          ),
          bottomWidget,
        ],
      ),
    );
  }

  Widget _buildStatusDot(Color color, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 4),
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            color: Color(0xFF475569),
            fontSize: 13,
            fontWeight: FontWeight.w500,
            fontFamily: 'Consolas',
          ),
        ),
      ],
    );
  }
}
