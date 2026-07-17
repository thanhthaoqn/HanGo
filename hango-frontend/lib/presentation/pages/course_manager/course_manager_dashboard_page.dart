<<<<<<< Updated upstream
=======

>>>>>>> Stashed changes
import 'package:flutter/material.dart';
import '../../../utils/toast_helper.dart';
import '../../widgets/shared_header.dart';
import '../../widgets/course_manager_sidebar.dart';
import '../../../data/services/course_manager_api.dart';
import '../../../data/models/course_manager_dashboard_summary.dart';
<<<<<<< Updated upstream
import 'course_manager_courses_page.dart';
import 'course_manager_exams_page.dart';
import 'course_manager_question_bank_page.dart';
import 'course_manager_matrix_management_page.dart';
=======

>>>>>>> Stashed changes

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
  bool _isLoading = true;
  bool _isSidebarVisible = true;

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
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ToastHelper.showError(context, 'Lỗi tải dữ liệu dashboard: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 1024;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: SharedHeader(
        isDesktop: isDesktop,
        activeTab: '',
        hideNavLinks: true,
        hideCommerceActions: true,
        hideLanguageSwitcher: true,
      ),
      drawer: !isDesktop ? const Drawer(child: CourseManagerSidebar(currentRoute: 'dashboard')) : null,
      body: Row(
        children: [
<<<<<<< Updated upstream
          if (isDesktop && _isSidebarVisible)
            SizedBox(width: 240, child: _buildSidebar(context)),
=======
          if (isDesktop && _isSidebarVisible) const SizedBox(width: 240, child: CourseManagerSidebar(currentRoute: 'dashboard')),
>>>>>>> Stashed changes
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildContentHeader(context, isDesktop),
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
                        : _buildMetricCards(
                            constraints: BoxConstraints(maxWidth: size.width),
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

<<<<<<< Updated upstream
  Widget _buildSidebar(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSidebarItem(Icons.dashboard, 'Dashboard', isActive: true),
          _buildSidebarItem(Icons.book_outlined, 'Courses', onTap: () {}),
          _buildSidebarItem(
            Icons.assignment_outlined,
            'Exam',
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const CourseManagerExamsPage(),
                ),
              );
            },
          ),
          _buildSidebarItem(
            Icons.grid_on,
            'Exam Matrix',
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => CourseManagerMatrixManagementPage(
                    onBack: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const CourseManagerDashboardPage(),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
          _buildSidebarItem(
            Icons.question_answer_outlined,
            'Question Bank',
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const CourseManagerQuestionBankPage(),
                ),
              );
            },
          ),
          const Spacer(),
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
                color: isActive
                    ? Colors.white
                    : (color ?? const Color(0xFF4B5563)),
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  color: isActive
                      ? Colors.white
                      : (color ?? const Color(0xFF1F2937)),
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
=======

>>>>>>> Stashed changes

  Widget _buildContentHeader(BuildContext context, bool isDesktop) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      child: Row(
        children: [
          if (!isDesktop) ...[
            IconButton(
              icon: const Icon(Icons.menu, color: Color(0xFF4B5563)),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
            const SizedBox(width: 12),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.menu, color: Color(0xFF4B5563)),
              onPressed: () {
                setState(() {
                  _isSidebarVisible = !_isSidebarVisible;
                });
              },
            ),
            const SizedBox(width: 12),
          ],
          const Text(
            'Dashboard',
            style: TextStyle(
              color: Color(0xFF20B486),
              fontWeight: FontWeight.bold,
              fontSize: 14,
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, size: 16, color: Color(0xFF20B486)),
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
        icon: Icons.people_outline,
        iconBgColor: const Color(0xFFE6FFFA),
        iconColor: const Color(0xFF20B486),
        subtitleWidget: const Row(
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 14,
              color: Color(0xFF20B486),
            ),
            Text(
              ' Total system users',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                fontFamily: 'Outfit',
              ),
            ),
          ],
        ),
      ),
      _buildCard(
        title: 'COURSES',
        value: '$totalCourses',
        icon: Icons.school_outlined,
        iconBgColor: const Color(0xFFF1F8F6),
        iconColor: const Color(0xFF4B5563),
        subtitleWidget: Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Color(0xFF20B486),
                shape: BoxShape.circle,
              ),
            ),
            Text(
              ' $activeCourses active  ',
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.bold,
                fontSize: 12,
                fontFamily: 'Outfit',
              ),
            ),
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Color(0xFFCBD5E1),
                shape: BoxShape.circle,
              ),
            ),
            Text(
              ' $inactiveCourses inactive',
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.bold,
                fontSize: 12,
                fontFamily: 'Outfit',
              ),
            ),
          ],
        ),
      ),
      _buildCard(
        title: 'EXAMS',
        value: '$examsCount',
        icon: Icons.assignment_outlined,
        iconBgColor: const Color(0xFFF1F5F9),
        iconColor: const Color(0xFF64748B),
        subtitleWidget: const Row(
          children: [
            Icon(
              Icons.assignment_turned_in_outlined,
              size: 14,
              color: Color(0xFF64748B),
            ),
            Text(
              ' System-wide exams',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                fontFamily: 'Outfit',
              ),
            ),
          ],
        ),
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
    } else if (useTwoColumns) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(child: cards[0]),
              const SizedBox(width: 16),
              Expanded(child: cards[1]),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: cards[2]),
              const Spacer(),
            ],
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
    required Widget subtitleWidget,
  }) {
    return Container(
      height: 160,
      padding: const EdgeInsets.all(20),
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
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
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
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
            ],
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: valueColor,
              fontFamily: 'Outfit',
            ),
          ),
          subtitleWidget,
        ],
      ),
    );
  }
}
