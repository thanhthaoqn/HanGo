import 'package:flutter/material.dart';
import '../pages/course_manager/course_manager_courses_page.dart';
import '../pages/course_manager/course_manager_dashboard_page.dart';
import '../pages/course_manager/course_manager_exams_page.dart';
import '../pages/course_manager/course_manager_matrix_management_page.dart';
import '../pages/course_manager/course_manager_question_bank_page.dart';
import '../pages/course_manager/course_manager_settlement_page.dart';
import '../pages/ticket/management_tickets_page.dart';

class CourseManagerSidebar extends StatelessWidget {
  final String currentRoute;
  final Function(String route)? onSelectRoute;

  const CourseManagerSidebar({
    super.key,
    required this.currentRoute,
    this.onSelectRoute,
  });

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
          _buildSidebarItem(
            context,
            Icons.dashboard,
            'Dashboard',
            isActive: currentRoute == 'dashboard',
            onTap: () {
              if (onSelectRoute != null) {
                onSelectRoute!('dashboard');
              } else if (currentRoute != 'dashboard') {
                _navigateSeamless(context, const CourseManagerDashboardPage());
              }
            },
          ),
          _buildSidebarItem(
            context,
            Icons.book_outlined,
            'Courses',
            isActive: currentRoute == 'courses',
            onTap: () {
              if (onSelectRoute != null) {
                onSelectRoute!('courses');
              } else if (currentRoute != 'courses') {
                _navigateSeamless(context, const CourseManagerCoursesPage());
              }
            },
          ),
          _buildSidebarItem(
            context,
            Icons.assignment_outlined,
            'Exam',
            isActive: currentRoute == 'exams',
            onTap: () {
              if (onSelectRoute != null) {
                onSelectRoute!('exams');
              } else if (currentRoute != 'exams') {
                _navigateSeamless(context, const CourseManagerExamsPage());
              }
            },
          ),
          _buildSidebarItem(
            context,
            Icons.grid_on,
            'Exam Matrix',
            isActive: currentRoute == 'matrix',
            onTap: () {
              if (onSelectRoute != null) {
                onSelectRoute!('matrix');
              } else if (currentRoute != 'matrix') {
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
            isActive: currentRoute == 'question_bank',
            onTap: () {
              if (onSelectRoute != null) {
                onSelectRoute!('question_bank');
              } else if (currentRoute != 'question_bank') {
                _navigateSeamless(context, const CourseManagerQuestionBankPage());
              }
            },
          ),
          _buildSidebarItem(
            context,
            Icons.account_balance_wallet_outlined,
            'Revenue Settlement',
            isActive: currentRoute == 'settlement',
            onTap: () {
              if (onSelectRoute != null) {
                onSelectRoute!('settlement');
              } else if (currentRoute != 'settlement') {
                _navigateSeamless(context, const CourseManagerSettlementPage());
              }
            },
          ),
          _buildSidebarItem(
            context,
            Icons.confirmation_number_outlined,
            'Support Tickets',
            isActive: currentRoute == 'support',
            onTap: () {
              if (onSelectRoute != null) {
                onSelectRoute!('support');
              } else if (currentRoute != 'support') {
                _navigateSeamless(context, const ManagementTicketsPage());
              }
            },
          ),
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
