// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';

class TrainerLeadSidebar extends StatelessWidget {
  final String activeMenu;
  final ValueChanged<String>? onMenuChanged;
  final VoidCallback? onLogout;
  final bool isMobileDrawer;

  const TrainerLeadSidebar({
    super.key,
    required this.activeMenu,
    this.onMenuChanged,
    this.onLogout,
    this.isMobileDrawer = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Logo Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
            child: Row(
              children: [
                Image.network(
                  'https://res.cloudinary.com/diqekap4o/image/upload/v1781621071/logo_ayqvq4.png',
                  height: 40,
                  width: 40,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE6FFFA),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.school, size: 20, color: Color(0xFF28B79B)),
                    );
                  },
                ),
                const SizedBox(width: 10),
                RichText(
                  text: const TextSpan(
                    text: 'Han',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                      fontFamily: 'Outfit',
                    ),
                    children: [
                      TextSpan(
                        text: 'Go',
                        style: TextStyle(
                          color: Color(0xFF28B79B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Menu Items
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _buildMenuItem(
                    context,
                    icon: Icons.grid_view_outlined,
                    title: 'Dashboard',
                    menuKey: 'Dashboard',
                  ),
                  const SizedBox(height: 8),
                  _buildMenuItem(
                    context,
                    icon: Icons.menu_book_outlined,
                    title: 'Courses',
                    menuKey: 'Courses',
                  ),
                  const SizedBox(height: 8),
                  _buildMenuItem(
                    context,
                    icon: Icons.assignment_outlined,
                    title: 'Task',
                    menuKey: 'Task',
                  ),
                  const SizedBox(height: 8),
                  _buildMenuItem(
                    context,
                    icon: Icons.chat_bubble_outline,
                    title: 'Comment',
                    menuKey: 'Comment',
                  ),

                  const Spacer(),
                  const Divider(color: Color(0xFFE5E7EB)),
                  const SizedBox(height: 12),

                  // Bottom Items
                  _buildBottomItem(
                    context,
                    icon: Icons.help_outline,
                    title: 'Help Center',
                    onTap: () {
                      if (isMobileDrawer) Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Opening Help Center...')),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildBottomItem(
                    context,
                    icon: Icons.logout,
                    title: 'Logout',
                    onTap: () {
                      if (isMobileDrawer) Navigator.pop(context);
                      onLogout?.call();
                    },
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String menuKey,
  }) {
    final isSelected = activeMenu == menuKey;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (isMobileDrawer) Navigator.pop(context);
          onMenuChanged?.call(menuKey);
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF28B79B) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : const Color(0xFF4B5563),
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF4B5563),
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  fontFamily: 'Outfit',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(
                icon,
                color: const Color(0xFF4B5563),
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF4B5563),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
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
