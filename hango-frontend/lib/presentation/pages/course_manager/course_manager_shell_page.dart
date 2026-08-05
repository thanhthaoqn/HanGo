import 'package:flutter/material.dart';
import 'package:hango/presentation/widgets/internal_app_header.dart';
import '../../widgets/course_manager_sidebar.dart';
import 'course_manager_dashboard_page.dart';
import 'course_manager_courses_page.dart';
import 'course_manager_exams_page.dart';
import 'course_manager_matrix_management_page.dart';
import 'course_manager_question_bank_page.dart';
import 'course_manager_settlement_page.dart';
import '../ticket/management_tickets_page.dart';

/// Tab order for the shell's [IndexedStack], matching the route keys
/// [CourseManagerSidebar] already uses for its `currentRoute`/`onSelectRoute`.
const List<String> _kCourseManagerShellRoutes = [
  'dashboard',
  'courses',
  'exams',
  'matrix',
  'question_bank',
  'settlement',
  'support',
];

/// Persistent shell for the Course Manager role: keeps a single header and
/// sidebar mounted while switching sections, mirroring [TrainerShellPage].
/// Section pages are rendered `isEmbedded: true` inside an [IndexedStack] so
/// navigating between them no longer rebuilds the header/sidebar.
class CourseManagerShellPage extends StatefulWidget {
  final int initialIndex;

  const CourseManagerShellPage({super.key, this.initialIndex = 0});

  @override
  State<CourseManagerShellPage> createState() => CourseManagerShellPageState();
}

class CourseManagerShellPageState extends State<CourseManagerShellPage> {
  // Real section widgets, in the same order as _kCourseManagerShellRoutes.
  // Kept out of build() so identity stays stable across rebuilds.
  static const List<Widget> _pages = [
    CourseManagerDashboardPage(isEmbedded: true),
    CourseManagerCoursesPage(isEmbedded: true),
    CourseManagerExamsPage(isEmbedded: true),
    CourseManagerMatrixManagementPage(isEmbedded: true),
    CourseManagerQuestionBankPage(isEmbedded: true),
    CourseManagerSettlementPage(isEmbedded: true),
    ManagementTicketsPage(isEmbedded: true),
  ];

  late int _currentIndex;
  // Only a visited tab's real page is placed in the IndexedStack (and thus
  // mounted/fetches its data) — otherwise every section would fetch at once
  // the moment the shell builds, including ones the user can't even see a
  // sidebar link for, and races against auth/session restore on cold boot.
  late final Set<int> _visitedIndices;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, _kCourseManagerShellRoutes.length - 1);
    _visitedIndices = {_currentIndex};
  }

  void selectTab(int index) {
    if (_currentIndex != index) {
      setState(() {
        _currentIndex = index;
        _visitedIndices.add(index);
      });
    } else {
      _visitedIndices.add(index);
    }
  }

  void _selectRoute(String route) {
    final index = _kCourseManagerShellRoutes.indexOf(route);
    if (index != -1) {
      selectTab(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 1024;

    final sidebar = CourseManagerSidebar(
      currentRoute: _kCourseManagerShellRoutes[_currentIndex],
      onSelectRoute: _selectRoute,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: InternalAppHeader(isMobile: !isDesktop),
      drawer: !isDesktop ? Drawer(child: sidebar) : null,
      body: Row(
        children: [
          if (isDesktop) SizedBox(width: 240, child: sidebar),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: [
                for (var i = 0; i < _pages.length; i++)
                  _visitedIndices.contains(i) ? _pages[i] : const SizedBox.shrink(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
