import 'package:flutter/material.dart';
import '../pages/course_manager/course_manager_courses_page.dart';
import '../pages/course_manager/course_manager_dashboard_page.dart';
import '../pages/course_manager/course_manager_exams_page.dart';
import '../pages/course_manager/course_manager_matrix_management_page.dart';
import '../pages/course_manager/course_manager_question_bank_page.dart';

class CourseManagerSidebar extends StatelessWidget {
  final String currentRoute;

  const CourseManagerSidebar({
    super.key,
    required this.currentRoute,
  });

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
              if (currentRoute != 'dashboard') {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const CourseManagerDashboardPage()),
                );
              }
            },
          ),
          _buildSidebarItem(
            context,
            Icons.book_outlined,
            'Courses',
            isActive: currentRoute == 'courses',
            onTap: () {
              if (currentRoute != 'courses') {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const CourseManagerCoursesPage()),
                );
              }
            },
          ),
          _buildSidebarItem(
            context,
            Icons.assignment_outlined,
            'Exam',
            isActive: currentRoute == 'exams',
            onTap: () {
              if (currentRoute != 'exams') {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const CourseManagerExamsPage()),
                );
              }
            },
          ),
          _buildSidebarItem(
            context,
            Icons.grid_on,
            'Exam Matrix',
            isActive: currentRoute == 'matrix',
            onTap: () {
              if (currentRoute != 'matrix') {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CourseManagerMatrixManagementPage(
                      onBack: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => const CourseManagerDashboardPage()),
                        );
                      },
                    ),
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
              if (currentRoute != 'question_bank') {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const CourseManagerQuestionBankPage()),
                );
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
    Color? color,
    VoidCallback? onTap,
  }) {
    const activeColor = Color(0xFF20B486);
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
                color: isActive ? Colors.white : (color ?? const Color(0xFF4B5563)),
                size: 20,
              ),
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
