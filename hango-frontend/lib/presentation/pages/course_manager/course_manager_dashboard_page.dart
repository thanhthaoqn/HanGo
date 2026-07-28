import 'package:flutter/material.dart';
import '../../../utils/toast_helper.dart';
import '../../widgets/shared_header.dart';
import '../../widgets/course_manager_sidebar.dart';
import '../../../data/services/course_manager_api.dart';
import '../../../data/models/course_manager_dashboard_summary.dart';

class CourseManagerDashboardPage extends StatefulWidget {
  const CourseManagerDashboardPage({super.key});

  @override
  State<CourseManagerDashboardPage> createState() =>
      _CourseManagerDashboardPageState();
}

class _CourseManagerDashboardPageState
    extends State<CourseManagerDashboardPage> {
  final _api = CourseManagerApi();
  CourseManagerDashboardSummary? _summary;


  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final summary = await _api.getDashboardSummary();
      if (mounted) {
        setState(() {
          _summary = summary;
        });
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, 'Lỗi tải dữ liệu dashboard: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 1024;

    return Scaffold(
      backgroundColor: const Color(0xFFF0FDFA),
      appBar: SharedHeader(
        isDesktop: isDesktop,
        activeTab: '',
        hideNavLinks: true,
        hideCommerceActions: true,
        hideLanguageSwitcher: true,
      ),
      drawer: !isDesktop
          ? const Drawer(child: CourseManagerSidebar(currentRoute: 'dashboard'))
          : null,
      body: Row(
        children: [
          if (isDesktop)
            const SizedBox(
              width: 240,
              child: CourseManagerSidebar(currentRoute: 'dashboard'),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildContentHeader(context, isDesktop),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildMetricCards(
                          constraints: BoxConstraints(maxWidth: size.width),
                        ),
                        const SizedBox(height: 32),
                        _buildQuickActions(context, useRow: size.width > 768),
                        const SizedBox(height: 32),
                        _buildRecentPendingCourses(context),
                        const SizedBox(height: 32),
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



  Widget _buildContentHeader(BuildContext context, bool isDesktop) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 8),
      child: Row(
        children: [
          if (!isDesktop) ...[
            IconButton(
              icon: const Icon(Icons.menu, color: Color(0xFF4B5563)),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
            const SizedBox(width: 12),
          ],
          const Text(
            'Course Manager Dashboard',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              fontFamily: 'Outfit',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCards({required BoxConstraints constraints}) {
    // 4 cards in a row if there is enough space. Since each card is roughly 250-300px min width.
    // We'll wrap them in a Wrap or Responsive layout.
    final useRow = constraints.maxWidth > 1024;
    final useTwoColumns =
        constraints.maxWidth > 600 && constraints.maxWidth <= 1024;

    final usersCount = _summary?.registeredUsersCount ?? 0;
    final activeCourses = _summary?.activeCoursesCount ?? 0;
    final inactiveCourses = _summary?.inactiveCoursesCount ?? 0;
    final totalCourses = activeCourses + inactiveCourses;
    final examsCount = _summary?.examsCount ?? 0;

    final cards = [
      _buildCard(
        title: 'REGISTERED USERS',
        value: '$usersCount',
        valueColor: const Color(0xFF134E4A),
        icon: Icons.people_rounded,
        iconBgColor: const Color(0xFFE6FFFA),
        iconColor: const Color(0xFF0D9488),
        borderColor: const Color(0xFF0D9488),
        subtitleWidget: const Row(
          children: [
            Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF0D9488)),
            Text(' Total system users', style: TextStyle(color: Color(0xFF0F766E), fontSize: 13, fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      _buildCard(
        title: 'COURSES',
        value: '$totalCourses',
        valueColor: const Color(0xFF134E4A),
        icon: Icons.school_rounded,
        iconBgColor: const Color(0xFFFFF7ED),
        iconColor: const Color(0xFFF97316),
        borderColor: const Color(0xFFF97316),
        subtitleWidget: Row(
          children: [
            Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFF97316), shape: BoxShape.circle)),
            Text(' $activeCourses active  ', style: const TextStyle(color: Color(0xFF9A3412), fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Outfit')),
            Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFFDBA74), shape: BoxShape.circle)),
            Text(' $inactiveCourses inactive', style: const TextStyle(color: Color(0xFF9A3412), fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Outfit')),
          ],
        ),
      ),
      _buildCard(
        title: 'EXAMS',
        value: '$examsCount',
        valueColor: const Color(0xFF134E4A),
        icon: Icons.assignment_rounded,
        iconBgColor: const Color(0xFFF1F5F9),
        iconColor: const Color(0xFF334155),
        borderColor: const Color(0xFF475569),
        subtitleWidget: const Row(
          children: [
            Icon(Icons.assignment_turned_in_rounded, size: 14, color: Color(0xFF475569)),
            Text(' System-wide exams', style: TextStyle(color: Color(0xFF334155), fontSize: 13, fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    ];

    if (useRow) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: cards[0]),
            const SizedBox(width: 16),
            Expanded(child: cards[1]),
            const SizedBox(width: 16),
            Expanded(child: cards[2]),
          ],
        ),
      );
    } else if (useTwoColumns) {
      return Column(
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: cards[0]),
                const SizedBox(width: 16),
                Expanded(child: cards[1]),
              ],
            ),
          ),
          const SizedBox(height: 16),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: cards[2]),
                const Spacer(),
              ],
            ),
          ),
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
  }

  Widget _buildCard({
    required String title,
    required String value,
    Color valueColor = const Color(0xFF0F172A),
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required Color borderColor,
    required Widget subtitleWidget,
  }) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.02),
            blurRadius: 10,
            offset: Offset(0, 2),
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
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: Color(0xFF64748B),
                    fontFamily: 'Outfit',
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: valueColor,
              fontFamily: 'Outfit',
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          subtitleWidget,
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, {required bool useRow}) {
    final actions = [
      _buildActionButton(
        icon: Icons.school_rounded,
        label: 'Manage Courses',
        color: const Color(0xFF0D9488),
        bgColor: const Color(0xFFCCFBF1),
        onTap: () => Navigator.pushNamed(context, '/course-manager/courses'),
      ),
      _buildActionButton(
        icon: Icons.assignment_rounded,
        label: 'Manage Exams',
        color: const Color(0xFFF97316),
        bgColor: const Color(0xFFFFEDD5),
        onTap: () => Navigator.pushNamed(context, '/course-manager/exams'),
      ),
      _buildActionButton(
        icon: Icons.grid_view_rounded,
        label: 'Matrix Builder',
        color: const Color(0xFF6366F1),
        bgColor: const Color(0xFFE0E7FF),
        onTap: () => Navigator.pushNamed(context, '/course-manager/matrix'),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF134E4A), fontFamily: 'Outfit'),
        ),
        const SizedBox(height: 16),
        useRow
            ? Row(children: actions.map((a) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 16), child: a))).toList())
            : Column(children: actions.map((a) => Padding(padding: const EdgeInsets.only(bottom: 16), child: a)).toList()),
      ],
    );
  }

  Widget _buildActionButton({required IconData icon, required String label, required Color color, required Color bgColor, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(0, 0, 0, 0.02),
              offset: Offset(0, 2),
              blurRadius: 10,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: color, size: 18)),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF334155), fontFamily: 'Outfit')),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentPendingCourses(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Pending Courses',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF134E4A), fontFamily: 'Outfit'),
            ),
            Text(
              'View All',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFF97316), fontFamily: 'Outfit'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
            boxShadow: const [BoxShadow(color: Color.fromRGBO(0,0,0,0.02), offset: Offset(0, 2), blurRadius: 10)],
          ),
          child: Column(
            children: [
              _buildCourseItem(title: 'Advanced English Grammar 2026', trainer: 'Sarah Johnson', date: '2 mins ago', color: const Color(0xFF20B486)),
              const Divider(color: Color(0xFFF1F5F9), height: 32, thickness: 1),
              _buildCourseItem(title: 'IELTS Speaking Masterclass', trainer: 'David Chen', date: '1 hour ago', color: const Color(0xFF3B82F6)),
              const Divider(color: Color(0xFFF1F5F9), height: 32, thickness: 1),
              _buildCourseItem(title: 'Business English Basics', trainer: 'Emma Williams', date: '3 hours ago', color: const Color(0xFFF59E0B)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCourseItem({required String title, required String trainer, required String date, required Color color}) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.school_rounded, color: color),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontFamily: 'Outfit')),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 14, color: Color(0xFF64748B)),
                  const SizedBox(width: 4),
                  Text(trainer, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(date, style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8), fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFF59E0B), width: 1.5)),
              child: const Text('PENDING', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFD97706), fontFamily: 'Outfit')),
            ),
          ],
        ),
      ],
    );
  }
}
