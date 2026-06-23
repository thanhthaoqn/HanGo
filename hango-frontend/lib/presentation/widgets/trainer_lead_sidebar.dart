import 'package:flutter/material.dart';

class TrainerLeadSidebar extends StatelessWidget {
  final String activeMenu;

  const TrainerLeadSidebar({
    Key? key,
    required this.activeMenu,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(
            color: Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Logo Area
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Row(
              children: [
                Image.network(
                  'https://res.cloudinary.com/diqekap4o/image/upload/v1781621071/logo_ayqvq4.png',
                  height: 40,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE6FFFA),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.school, size: 24, color: Color(0xFF28B79B)),
                    );
                  },
                ),
                const SizedBox(width: 12),
                const Text(
                  'HanGo',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                    fontFamily: 'Outfit',
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Menu Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildMenuItem(
                  icon: Icons.dashboard_outlined,
                  title: 'Dashboard',
                  isActive: activeMenu == 'Dashboard',
                  onTap: () {
                    // Navigate to Dashboard
                  },
                ),
                _buildMenuItem(
                  icon: Icons.menu_book_outlined,
                  title: 'Courses',
                  isActive: activeMenu == 'Courses',
                  onTap: () {
                    // Navigate to Courses
                  },
                ),
                _buildMenuItem(
                  icon: Icons.assignment_outlined,
                  title: 'Task',
                  isActive: activeMenu == 'Task',
                  onTap: () {
                    // Navigate to Task
                  },
                ),
                _buildMenuItem(
                  icon: Icons.chat_bubble_outline,
                  title: 'Comment',
                  isActive: activeMenu == 'Comment',
                  onTap: () {
                    // Navigate to Comment
                  },
                ),
              ],
            ),
          ),
          
          // Bottom Items
          const Divider(color: Color(0xFFE2E8F0), height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              children: [
                _buildMenuItem(
                  icon: Icons.help_outline,
                  title: 'Help Center',
                  isActive: false,
                  onTap: () {},
                  isBottom: true,
                ),
                _buildMenuItem(
                  icon: Icons.logout_outlined,
                  title: 'Logout',
                  isActive: false,
                  onTap: () {
                    // Handle Logout
                  },
                  isBottom: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required bool isActive,
    required VoidCallback onTap,
    bool isBottom = false,
  }) {
    final color = isActive ? Colors.white : const Color(0xFF4B5563);
    final bgColor = isActive ? const Color(0xFF28B79B) : Colors.transparent;
    
    return Padding(
      padding: EdgeInsets.only(bottom: isBottom ? 8 : 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                  fontSize: 15,
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
