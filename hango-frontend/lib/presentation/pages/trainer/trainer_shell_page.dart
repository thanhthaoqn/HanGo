import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/services/auth_service.dart';
import '../login_page.dart';
import 'trainer_dashboard_page.dart';
import 'trainer_courses_page.dart';
import 'trainer_exams_page.dart';
import 'question_bank/trainer_question_bank_page.dart';
import 'trainer_revenue_page.dart';
import 'trainer_profile_page.dart';

class TrainerShellPage extends StatefulWidget {
  final int initialIndex;
  const TrainerShellPage({super.key, this.initialIndex = 0});

  static _TrainerShellPageState? of(BuildContext context) {
    return context.findAncestorStateOfType<_TrainerShellPageState>();
  }

  @override
  State<TrainerShellPage> createState() => _TrainerShellPageState();
}

class _TrainerShellPageState extends State<TrainerShellPage> {
  late int _currentIndex;
  final _authService = AuthService();

  String _trainerName = 'Trainer';
  String _trainerInitials = 'T';
  String _trainerAvatarUrl = '';

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _loadHeaderInfo();
  }

  Future<void> _loadHeaderInfo() async {
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
    if (mounted) {
      setState(() {
        _trainerName = fullName;
        _trainerInitials = initials;
        _trainerAvatarUrl = avatarUrl;
      });
    }
  }

  void selectTab(int index) {
    if (_currentIndex != index) {
      setState(() {
        _currentIndex = index;
      });
    }
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
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: !isDesktop ? Drawer(child: _buildSidebar(context)) : null,
      body: Row(
        children: [
          if (isDesktop) SizedBox(width: 250, child: _buildSidebar(context)),
          Expanded(
            child: Column(
              children: [
                _buildHeader(context, !isDesktop),
                Expanded(
                  child: IndexedStack(
                    index: _currentIndex,
                    children: const [
                      TrainerDashboardPage(isEmbedded: true),
                      TrainerCoursesPage(isEmbedded: true),
                      TrainerExamsPage(isEmbedded: true),
                      TrainerQuestionBankPage(isEmbedded: true),
                      TrainerRevenuePage(isEmbedded: true),
                      TrainerProfilePage(isEmbedded: true),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isMobile) {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
      ),
      child: Row(
        children: [
          if (isMobile)
            IconButton(
              icon: const Icon(Icons.menu, color: Color(0xFF64748B)),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          const Spacer(),
          Text(
            _trainerName,
            style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1E293B), fontSize: 14, fontFamily: 'Outfit'),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFFE2F9F3),
            backgroundImage: _trainerAvatarUrl.isNotEmpty ? NetworkImage(_trainerAvatarUrl) : null,
            child: _trainerAvatarUrl.isEmpty
                ? Text(_trainerInitials, style: const TextStyle(color: Color(0xFF28B79B), fontWeight: FontWeight.bold, fontSize: 14))
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFF28B79B), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.school, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              const Text(
                'HanGo',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontFamily: 'Outfit'),
              ),
            ],
          ),
          const SizedBox(height: 32),
          _buildSidebarItem(Icons.dashboard_outlined, 'Dashboard', isActive: _currentIndex == 0, onTap: () => selectTab(0)),
          _buildSidebarItem(Icons.book_outlined, 'Courses', isActive: _currentIndex == 1, onTap: () => selectTab(1)),
          _buildSidebarItem(Icons.assignment_outlined, 'Exam', isActive: _currentIndex == 2, onTap: () => selectTab(2)),
          _buildSidebarItem(Icons.question_answer_outlined, 'Question Bank', isActive: _currentIndex == 3, onTap: () => selectTab(3)),
          _buildSidebarItem(Icons.account_balance_wallet_outlined, 'Revenue', isActive: _currentIndex == 4, onTap: () => selectTab(4)),
          _buildSidebarItem(Icons.person_outline, 'My Profile', isActive: _currentIndex == 5, onTap: () => selectTab(5)),
          const Spacer(),
          const Divider(color: Color(0xFFE2E8F0)),
          const SizedBox(height: 12),
          _buildSidebarItem(Icons.logout, 'Logout', color: Colors.redAccent, onTap: _handleLogout),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(
    IconData icon,
    String title, {
    bool isActive = false,
    Color? color,
    VoidCallback? onTap,
  }) {
    final activeColor = const Color(0xFF28B79B);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(icon, color: isActive ? Colors.white : (color ?? const Color(0xFF4B5563)), size: 20),
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
}
