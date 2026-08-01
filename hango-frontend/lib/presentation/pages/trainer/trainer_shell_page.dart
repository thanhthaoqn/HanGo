import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'trainer_dashboard_page.dart';
import 'trainer_courses_page.dart';
import 'trainer_exams_page.dart';
import 'question_bank/trainer_question_bank_page.dart';
import 'trainer_revenue_page.dart';
import 'trainer_profile_page.dart';
import 'trainer_tickets_page.dart';
import '../../widgets/trainer/trainer_sidebar.dart';

class TrainerShellPage extends StatefulWidget {
  final int initialIndex;
  const TrainerShellPage({super.key, this.initialIndex = 0});

  static TrainerShellPageState? of(BuildContext context) {
    return context.findAncestorStateOfType<TrainerShellPageState>();
  }

  @override
  State<TrainerShellPage> createState() => TrainerShellPageState();
}

class TrainerShellPageState extends State<TrainerShellPage> {
  late int _currentIndex;

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

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 1024;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: !isDesktop ? Drawer(child: TrainerSidebar(activeIndex: _currentIndex, onTabSelect: (idx) => selectTab(idx))) : null,
      body: Row(
        children: [
          if (isDesktop) SizedBox(width: 250, child: TrainerSidebar(activeIndex: _currentIndex, onTabSelect: (idx) => selectTab(idx))),
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
                      TrainerTicketsPage(isEmbedded: true),
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
}
