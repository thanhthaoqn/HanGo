// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../data/models/trainer_lead_dashboard_stats_model.dart';
import '../../../data/services/auth_service.dart';
import '../login_page.dart';
import '../../widgets/trainer_lead_sidebar.dart';
import 'trainer_lead_task_page.dart';


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
  String _userAvatarUrl = '';

  // ── Profile tab state ──────────────────────────────────────────────────────
  bool _isLoadingProfile = false;
  final _profileNameController = TextEditingController();
  final _profileEmailController = TextEditingController();
  final _profileUsernameController = TextEditingController();
  final _profilePhoneController = TextEditingController();
  final _profileAvatarController = TextEditingController();
  String _profileGender = 'Male';
  final _profileDobController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _fetchDashboardStats();
  }

  @override
  void dispose() {
    _profileNameController.dispose();
    _profileEmailController.dispose();
    _profileUsernameController.dispose();
    _profilePhoneController.dispose();
    _profileAvatarController.dispose();
    _profileDobController.dispose();
    super.dispose();
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

  // ── Profile methods ──────────────────────────────────────────────────────

  void _initProfileFields() {
    _profileNameController.text = _userName;
    _profileEmailController.text = _userEmail;
    _profileUsernameController.text = _userEmail.split('@').first;
    _profilePhoneController.text = '';
    _profileAvatarController.text = _userAvatarUrl;
    _profileGender = 'Male';
    _profileDobController.text = '';
    _fetchUserProfile();
  }

  Future<void> _fetchUserProfile() async {
    setState(() => _isLoadingProfile = true);
    try {
      final res = await _authService.getProfile();
      if (res['success'] == true) {
        final data = res['data'];
        if (mounted) {
          setState(() {
            _userName = data['fullName'] ?? _userName;
            _userEmail = data['email'] ?? _userEmail;
            _userAvatarUrl = data['avatarUrl'] ?? '';

            _profileNameController.text = _userName;
            _profileEmailController.text = _userEmail;
            _profileUsernameController.text = _userEmail.split('@').first;
            _profilePhoneController.text = data['phoneNumber'] ?? '';
            _profileAvatarController.text = _userAvatarUrl;
            _profileGender = data['gender'] ?? 'Male';

            if (data['dateOfBirth'] != null) {
              try {
                final parts = data['dateOfBirth'].toString().split('-');
                if (parts.length == 3) {
                  _profileDobController.text = '${parts[2]}/${parts[1]}/${parts[0]}';
                }
              } catch (_) {
                _profileDobController.text = '';
              }
            } else {
              _profileDobController.text = '';
            }

            if (_userName.trim().isNotEmpty) {
              final parts = _userName.trim().split(' ');
              if (parts.isNotEmpty) {
                _userInitials = parts.last[0].toUpperCase();
              }
            }
            _isLoadingProfile = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingProfile = false);
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
      if (mounted) setState(() => _isLoadingProfile = false);
    }
  }

  Future<void> _saveProfileChanges() async {
    setState(() => _isLoadingProfile = true);
    try {
      String? formattedDob;
      if (_profileDobController.text.isNotEmpty) {
        final parts = _profileDobController.text.split('/');
        if (parts.length == 3) {
          formattedDob = '${parts[2]}-${parts[1]}-${parts[0]}';
        }
      }

      final profileData = {
        'fullName': _profileNameController.text.trim(),
        'email': _profileEmailController.text.trim(),
        'phoneNumber': _profilePhoneController.text.trim(),
        'avatarUrl': _profileAvatarController.text.trim(),
        'gender': _profileGender,
        if (formattedDob != null) 'dateOfBirth': formattedDob,
      };

      final res = await _authService.updateProfile(profileData);
      if (res['success'] == true) {
        final data = res['data'];
        if (mounted) {
          setState(() {
            _userName = data['fullName'] ?? _userName;
            _userEmail = data['email'] ?? _userEmail;
            _userAvatarUrl = data['avatarUrl'] ?? '';
            if (_userName.trim().isNotEmpty) {
              final parts = _userName.trim().split(' ');
              if (parts.isNotEmpty) {
                _userInitials = parts.last[0].toUpperCase();
              }
            }
            _isLoadingProfile = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile updated successfully!'),
              backgroundColor: Color(0xFF28B79B),
            ),
          );
        }
      } else {
        if (mounted) {
          setState(() => _isLoadingProfile = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update profile: ${res['message']}'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingProfile = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showAvatarEditDialog() {
    final controller = TextEditingController(text: _profileAvatarController.text);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Avatar URL',
            style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter image URL',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B7280))),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _profileAvatarController.text = controller.text;
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF28B79B)),
            child: const Text('OK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── Dashboard stats ─────────────────────────────────────────────────────────

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
  // HEADER (Admin-style)
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

          // Right: Notification Bell + Profile Dropdown
          Row(
            children: [
              // Notification Bell with Badge
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

              // Profile Avatar and Name Dropdown
              PopupMenuButton<String>(
                onSelected: (val) {
                  if (val == 'logout') {
                    _handleLogout();
                  } else if (val == 'profile') {
                    _initProfileFields();
                    setState(() => _activeMenu = 'Profile');
                  }
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
                  // ── User info header (disabled) ──────────────────────
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
                  // ── Profile Settings ─────────────────────────────────
                  PopupMenuItem(
                    value: 'profile',
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE6FFFA),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.person_outline_rounded,
                              size: 18,
                              color: Color(0xFF28B79B),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Profile Settings',
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              color: Color(0xFF1E293B),
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // ── Log Out ──────────────────────────────────────────
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
      case 'Profile':
        return _buildProfileTab(isDesktop);
      case 'Task':
        return const TrainerLeadTaskPage();
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

  // ─────────────────────────────────────────────
  // PROFILE TAB
  // ─────────────────────────────────────────────
  Widget _buildProfileTab(bool isDesktop) {
    if (_isLoadingProfile) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40.0),
          child: CircularProgressIndicator(color: Color(0xFF28B79B)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Breadcrumb
        Row(
          children: const [
            Icon(Icons.chevron_right, size: 16, color: Color(0xFF28B79B)),
            SizedBox(width: 4),
            Text(
              'Profile',
              style: TextStyle(
                color: Color(0xFF28B79B),
                fontSize: 13,
                fontWeight: FontWeight.bold,
                fontFamily: 'Outfit',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Title
        const Text(
          'Profile',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
            fontFamily: 'Outfit',
          ),
        ),
        const SizedBox(height: 24),

        // Main Card
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Avatar & Name ────────────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF1F2937), width: 2),
                        ),
                        child: _profileAvatarController.text.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(45),
                                child: Image.network(
                                  _profileAvatarController.text,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Center(
                                    child: Text(
                                      _userInitials,
                                      style: const TextStyle(
                                        color: Color(0xFF28B79B),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 32,
                                        fontFamily: 'Outfit',
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            : Center(
                                child: Text(
                                  _userInitials,
                                  style: const TextStyle(
                                    color: Color(0xFF28B79B),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 32,
                                    fontFamily: 'Outfit',
                                  ),
                                ),
                              ),
                      ),
                      // Edit button overlay
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _showAvatarEditDialog,
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: const BoxDecoration(
                              color: Color(0xFF28B79B),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.edit, color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _userName,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F2937),
                            fontFamily: 'Outfit',
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE6FFFA),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Trainer Lead',
                            style: TextStyle(
                              color: Color(0xFF1F9E84),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              fontFamily: 'Outfit',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // ── Form Grid ────────────────────────────────────────────
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 600;
                  return Column(
                    children: [
                      // Row 1: FullName & Username
                      _buildFormRow(
                        isWide,
                        _buildTextFieldNoIcon('Full Name', _profileNameController),
                        _buildTextFieldNoIcon(
                          'Username',
                          _profileUsernameController,
                          onChanged: (val) {
                            final emailVal = _profileEmailController.text.trim();
                            final parts = emailVal.split('@');
                            final domain = parts.length > 1 ? parts.last : 'hango.edu.vn';
                            _profileEmailController.text = '${val.trim()}@$domain';
                          },
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Row 2: Email & Phone
                      _buildFormRow(
                        isWide,
                        _buildTextFieldWithEmailIcon(
                          'Email',
                          _profileEmailController,
                          onChanged: (val) {
                            final parts = val.trim().split('@');
                            if (parts.isNotEmpty) {
                              _profileUsernameController.text = parts.first;
                            }
                          },
                        ),
                        _buildTextFieldNoIcon('Phone Number', _profilePhoneController),
                      ),
                      const SizedBox(height: 24),

                      // Row 3: Date of Birth & Gender
                      _buildFormRow(
                        isWide,
                        _buildDatePickerField(context),
                        _buildGenderRadioGroup(),
                      ),
                      const SizedBox(height: 24),

                      // Row 4: Role display
                      _buildFormRow(
                        isWide,
                        _buildRoleDisplayBox('Role', 'Trainer Lead'),
                        const SizedBox(),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 40),
              const Divider(color: Color(0xFFE5E7EB)),
              const SizedBox(height: 24),

              // ── Action Buttons ───────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _saveProfileChanges,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                      side: const BorderSide(color: Color(0xFF28B79B)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text(
                      'Update',
                      style: TextStyle(
                        color: Color(0xFF28B79B),
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () => setState(() => _activeMenu = 'Dashboard'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF28B79B),
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Back',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Outfit',
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Form helper widgets ──────────────────────────────────────────────────

  Widget _buildFormRow(bool isWide, Widget left, Widget right) {
    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: left),
          const SizedBox(width: 24),
          Expanded(child: right),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [left, const SizedBox(height: 20), right],
    );
  }

  Widget _buildTextFieldNoIcon(
    String label,
    TextEditingController controller, {
    bool enabled = true,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
                fontFamily: 'Outfit')),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          enabled: enabled,
          onChanged: onChanged,
          style: const TextStyle(fontFamily: 'Outfit', fontSize: 15),
          decoration: InputDecoration(
            filled: true,
            fillColor: enabled ? Colors.white : const Color(0xFFF3F4F6),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF28B79B), width: 1.5)),
          ),
        ),
      ],
    );
  }

  Widget _buildTextFieldWithEmailIcon(
    String label,
    TextEditingController controller, {
    bool enabled = true,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
                fontFamily: 'Outfit')),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          enabled: enabled,
          onChanged: onChanged,
          style: const TextStyle(fontFamily: 'Outfit', fontSize: 15),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF9CA3AF), size: 20),
            filled: true,
            fillColor: enabled ? Colors.white : const Color(0xFFF3F4F6),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF28B79B), width: 1.5)),
          ),
        ),
      ],
    );
  }

  Widget _buildRoleDisplayBox(String label, String roleName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
                fontFamily: 'Outfit')),
        const SizedBox(height: 8),
        Container(
          height: 48,
          width: double.infinity,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFEEF2FF),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
          ),
          child: Text(
            roleName,
            style: const TextStyle(
                color: Color(0xFF3F51B5),
                fontWeight: FontWeight.bold,
                fontSize: 15,
                fontFamily: 'Outfit'),
          ),
        ),
      ],
    );
  }

  Widget _buildGenderRadioGroup() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Gender',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
                fontFamily: 'Outfit')),
        const SizedBox(height: 8),
        Row(
          children: [
            GestureDetector(
              onTap: () => setState(() => _profileGender = 'Female'),
              child: Row(
                children: [
                  Radio<String>(
                    value: 'Female',
                    groupValue: _profileGender,
                    activeColor: const Color(0xFF28B79B),
                    onChanged: (val) {
                      if (val != null) setState(() => _profileGender = val);
                    },
                  ),
                  const Text('Female', style: TextStyle(fontFamily: 'Outfit', fontSize: 15)),
                ],
              ),
            ),
            const SizedBox(width: 24),
            GestureDetector(
              onTap: () => setState(() => _profileGender = 'Male'),
              child: Row(
                children: [
                  Radio<String>(
                    value: 'Male',
                    groupValue: _profileGender,
                    activeColor: const Color(0xFF28B79B),
                    onChanged: (val) {
                      if (val != null) setState(() => _profileGender = val);
                    },
                  ),
                  const Text('Male', style: TextStyle(fontFamily: 'Outfit', fontSize: 15)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDatePickerField(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Date of Birth',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
                fontFamily: 'Outfit')),
        const SizedBox(height: 8),
        TextField(
          controller: _profileDobController,
          readOnly: true,
          style: const TextStyle(fontFamily: 'Outfit', fontSize: 15),
          onTap: () async {
            DateTime? initialDate;
            try {
              final parts = _profileDobController.text.split('/');
              if (parts.length == 3) {
                initialDate = DateTime(
                    int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
              }
            } catch (_) {
              initialDate = null;
            }

            final picked = await showDatePicker(
              context: context,
              initialDate: initialDate ?? DateTime(2000, 1, 1),
              firstDate: DateTime(1900),
              lastDate: DateTime.now(),
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: const ColorScheme.light(
                      primary: Color(0xFF28B79B),
                      onPrimary: Colors.white,
                      onSurface: Color(0xFF1F2937),
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (picked != null && mounted) {
              setState(() {
                final d = picked.day.toString().padLeft(2, '0');
                final m = picked.month.toString().padLeft(2, '0');
                _profileDobController.text = '$d/$m/${picked.year}';
              });
            }
          },
          decoration: InputDecoration(
            suffixIcon: const Icon(Icons.calendar_today_outlined,
                color: Color(0xFF9CA3AF), size: 18),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF28B79B), width: 1.5)),
            hintText: 'DD/MM/YYYY',
            hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontFamily: 'Outfit'),
          ),
        ),
      ],
    );
  }
}
