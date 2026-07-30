import 'package:flutter/material.dart';
import '../pages/course_manager/course_manager_courses_page.dart';
import '../pages/course_manager/course_manager_dashboard_page.dart';
import '../pages/course_manager/course_manager_exams_page.dart';
import '../pages/course_manager/course_manager_matrix_management_page.dart';
import '../pages/course_manager/course_manager_question_bank_page.dart';
import '../pages/course_manager/course_manager_settlement_page.dart';

import 'package:shared_preferences/shared_preferences.dart';

class CourseManagerSidebar extends StatefulWidget {
  final String currentRoute;
  final Function(String route)? onSelectRoute;

  const CourseManagerSidebar({
    super.key,
    required this.currentRoute,
    this.onSelectRoute,
  });

  @override
  State<CourseManagerSidebar> createState() => _CourseManagerSidebarState();
}

class _CourseManagerSidebarState extends State<CourseManagerSidebar> {
  List<String> _userRoles = [];
  bool _canViewDashboard = false;
  bool _canManageExams = false;

  @override
  void initState() {
    super.initState();
    _loadRoles();
  }

  Future<void> _loadRoles() async {
    final prefs = await SharedPreferences.getInstance();
    final roles = prefs.getStringList('user_roles') ?? [];
    setState(() {
      _userRoles = roles;
      _canViewDashboard = roles.contains('VIEW_PLATFORM_DASHBOARD') || roles.contains('ROLE_ADMINISTRATOR');
      _canManageExams = roles.contains('CREATE_AND_MANAGE_EXAMS_CM') || roles.contains('ROLE_ADMINISTRATOR');
    });
  }

  void _navigateSeamless(BuildContext context, Widget targetPage) {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => targetPage,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_canViewDashboard) ...[
            _buildSidebarItem(
              context,
              Icons.dashboard,
              'Dashboard',
              isActive: widget.currentRoute == 'dashboard',
              onTap: () {
                if (widget.onSelectRoute != null) {
                  widget.onSelectRoute!('dashboard');
                } else if (widget.currentRoute != 'dashboard') {
                  _navigateSeamless(context, const CourseManagerDashboardPage());
                }
              },
            ),
          ],
          _buildSidebarItem(
            context,
            Icons.book_outlined,
            'Courses',
            isActive: widget.currentRoute == 'courses',
            onTap: () {
              if (widget.onSelectRoute != null) {
                widget.onSelectRoute!('courses');
              } else if (widget.currentRoute != 'courses') {
                _navigateSeamless(context, const CourseManagerCoursesPage());
              }
            },
          ),
          if (_canManageExams) ...[
            _buildSidebarItem(
              context,
              Icons.assignment_outlined,
              'Exam',
              isActive: widget.currentRoute == 'exams',
              onTap: () {
                if (widget.onSelectRoute != null) {
                  widget.onSelectRoute!('exams');
                } else if (widget.currentRoute != 'exams') {
                  _navigateSeamless(context, const CourseManagerExamsPage());
                }
              },
            ),
            _buildSidebarItem(
              context,
              Icons.grid_on,
              'Exam Matrix',
              isActive: widget.currentRoute == 'matrix',
              onTap: () {
                if (widget.onSelectRoute != null) {
                  widget.onSelectRoute!('matrix');
                } else if (widget.currentRoute != 'matrix') {
                  _navigateSeamless(
                    context,
                    CourseManagerMatrixManagementPage(
                      onBack: () {
                        _navigateSeamless(context, const CourseManagerDashboardPage());
                      },
                    ),
                  );
                }
              },
            ),
            _buildSidebarItem(
              context,
              Icons.question_answer_outlined,
              'Question Bank',
              isActive: widget.currentRoute == 'question_bank',
              onTap: () {
                if (widget.onSelectRoute != null) {
                  widget.onSelectRoute!('question_bank');
                } else if (widget.currentRoute != 'question_bank') {
                  _navigateSeamless(context, const CourseManagerQuestionBankPage());
                }
              },
            ),
          ],
          if (_canViewDashboard) ...[
            _buildSidebarItem(
              context,
              Icons.account_balance_wallet_outlined,
              'Revenue Settlement',
              isActive: widget.currentRoute == 'settlement',
              onTap: () {
                if (widget.onSelectRoute != null) {
                  widget.onSelectRoute!('settlement');
                } else if (widget.currentRoute != 'settlement') {
                  _navigateSeamless(context, const CourseManagerSettlementPage());
                }
              },
            ),
          ],
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(
    BuildContext context,
    IconData icon,
    String title, {
    bool isActive = false,
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
                color: isActive ? Colors.white : const Color(0xFF4B5563),
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  color: isActive ? Colors.white : const Color(0xFF1F2937),
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
