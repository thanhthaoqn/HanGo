import 'package:flutter/material.dart';
import '../trainer_lead_dashboard_page.dart';
import '../trainer_lead_tasks_page.dart';

class TrainerLeadSidebar extends StatelessWidget {
  final String activeMenu;

  const TrainerLeadSidebar({Key? key, required this.activeMenu}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      color: Colors.white,
      child: Column(
        children: [
          // Logo
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
            child: Row(
              children: [
                Icon(Icons.school, color: const Color(0xFF2ec4b6), size: 32), // Placeholder logo
                const SizedBox(width: 10),
                const Text(
                  'HanGo',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1b5c58),
                  ),
                ),
              ],
            ),
          ),
          
          // Menu Items
          _buildMenuItem(context, 'Dashboard', Icons.dashboard, 'Dashboard'),
          _buildMenuItem(context, 'Courses', Icons.book, 'Courses'),
          _buildMenuItem(context, 'Task', Icons.task, 'Task'),
          
          const Spacer(),
          
          const Divider(height: 1),
          _buildMenuItem(context, 'Logout', Icons.logout, 'Logout'),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, String title, IconData icon, String menuId) {
    final isActive = activeMenu == menuId;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF2ec4b6) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isActive ? Colors.white : Colors.grey.shade700,
          size: 20,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.grey.shade800,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
        ),
        onTap: () {
          if (!isActive) {
            if (menuId == 'Dashboard') {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const TrainerLeadDashboardPage()),
              );
            } else if (menuId == 'Task') {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const TrainerLeadTasksPage()),
              );
            }
          }
        },
      ),
    );
  }
}
