import 'package:flutter/material.dart';

import '../../pages/login_page.dart';
import '../../pages/trainer/trainer_shell_page.dart';
import '../../../data/services/auth_service.dart';

import 'package:shared_preferences/shared_preferences.dart';
import '../../../utils/toast_helper.dart';
import '../../../utils/language_manager.dart';

class TrainerSidebar extends StatefulWidget {
  final int activeIndex;
  final bool isEnabled;
  final List<int> disabledIndices;
  final void Function(int index)? onTabSelect;

  const TrainerSidebar({
    super.key,
    required this.activeIndex,
    this.isEnabled = true,
    this.disabledIndices = const [],
    this.onTabSelect,
  });

  @override
  State<TrainerSidebar> createState() => _TrainerSidebarState();
}

class _TrainerSidebarState extends State<TrainerSidebar> {
  bool _canManageCourses = false;
  bool _canManageExams = false;
  bool _canViewRevenue = false;

  @override
  void initState() {
    super.initState();
    _loadRoles();
  }

  Future<void> _loadRoles() async {
    final prefs = await SharedPreferences.getInstance();
    final roles = prefs.getStringList('user_roles') ?? [];
    setState(() {
      _canManageCourses = roles.contains('MANAGE_OWN_COURSES') || roles.contains('ROLE_ADMINISTRATOR');
      _canManageExams = roles.contains('CREATE_EXAMS_TRAINER') || roles.contains('ROLE_ADMINISTRATOR');
      _canViewRevenue = roles.contains('VIEW_OWN_REVENUE') || roles.contains('ROLE_ADMINISTRATOR');
    });
  }

  void _handleSelectTab(BuildContext context, int index) {
    if (!widget.isEnabled || widget.disabledIndices.contains(index)) {
      final isVi = LanguageManager.isVi;
      ToastHelper.showInfo(
        context,
        isVi
            ? 'Vui lòng hoàn tất nộp hồ sơ Trainer trước khi truy cập tính năng này.'
            : 'Please complete your Trainer onboarding application first.',
      );
      return;
    }

    if (widget.onTabSelect != null) {
      widget.onTabSelect!(index);
      if (Scaffold.maybeOf(context)?.isDrawerOpen == true) {
        Navigator.of(context).pop();
      }
      return;
    }

    final shellState = TrainerShellPage.of(context);
    if (shellState != null) {
      shellState.selectTab(index);
      if (Scaffold.maybeOf(context)?.isDrawerOpen == true) {
        Navigator.of(context).pop();
      }
    } else {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => TrainerShellPage(initialIndex: index)),
        (route) => false,
      );
    }
  }

  Future<void> _handleLogout(BuildContext context) async {
    final authService = AuthService();
    await authService.logout();
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final showAllForOnboarding = widget.disabledIndices.isNotEmpty;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8.0, bottom: 24.0),
            child: Row(
              children: [
                Image.network(
                  'https://res.cloudinary.com/diqekap4o/image/upload/v1781621071/logo_ayqvq4.png',
                  height: 36,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
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
                            color: Color(0xFF28B79B),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'HanGo',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F2937),
                            fontFamily: 'Outfit',
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          _buildItem(context, 0, Icons.dashboard_outlined, 'Dashboard'),
          if (_canManageCourses || showAllForOnboarding)
            _buildItem(context, 1, Icons.book_outlined, 'Courses'),
          if (_canManageExams || showAllForOnboarding) ...[
            _buildItem(context, 2, Icons.assignment_outlined, 'Exam'),
            _buildItem(context, 3, Icons.question_answer_outlined, 'Question Bank'),
          ],
          if (_canViewRevenue || showAllForOnboarding)
            _buildItem(context, 4, Icons.account_balance_wallet_outlined, 'Revenue'),
          _buildItem(context, 5, Icons.person_outline, 'My Profile'),
          _buildItem(context, 6, Icons.confirmation_number_outlined, 'Support & Tickets'),
          const Spacer(),
          const Divider(color: Color(0xFFE2E8F0)),
          const SizedBox(height: 12),
          _buildLogoutItem(context),
        ],
      ),
    );
  }

  Widget _buildItem(BuildContext context, int index, IconData icon, String title) {
    final isActive = (widget.activeIndex == index);
    final itemEnabled = widget.isEnabled && !widget.disabledIndices.contains(index);
    final activeColor = const Color(0xFF20B486);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: InkWell(
        onTap: () => _handleSelectTab(context, index),
        borderRadius: BorderRadius.circular(12),
        hoverColor: itemEnabled ? activeColor.withValues(alpha: 0.08) : Colors.transparent,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: !itemEnabled
                    ? const Color(0xFF94A3B8)
                    : (isActive ? Colors.white : const Color(0xFF475569)),
                size: 20,
              ),
              const SizedBox(width: 14),
              Text(
                title,
                style: TextStyle(
                  color: !itemEnabled
                      ? const Color(0xFF94A3B8)
                      : (isActive ? Colors.white : const Color(0xFF334155)),
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
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

  Widget _buildLogoutItem(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: InkWell(
        onTap: () => _handleLogout(context),
        borderRadius: BorderRadius.circular(12),
        hoverColor: const Color(0xFFEF4444).withValues(alpha: 0.08),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.logout, color: Color(0xFFEF4444), size: 20),
              const SizedBox(width: 14),
              const Text(
                'Logout',
                style: TextStyle(
                  color: Color(0xFFEF4444),
                  fontWeight: FontWeight.w600,
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
