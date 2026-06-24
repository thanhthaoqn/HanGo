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
          // ── Logo Section (giống Admin) ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
            child: Image.network(
              'https://res.cloudinary.com/diqekap4o/image/upload/v1781621071/logo_ayqvq4.png',
              height: 48,
              alignment: Alignment.centerLeft,
              errorBuilder: (context, error, stackTrace) {
                return Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE6FFFA),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.school, size: 20, color: Color(0xFF28B79B)),
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
                );
              },
            ),
          ),

          const SizedBox(height: 10),

          // ── Menu Items ─────────────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _buildSidebarMenuItem(
                    context,
                    index: 0,
                    icon: Icons.grid_view_outlined,
                    title: 'Dashboard',
                    menuKey: 'Dashboard',
                  ),
                  const SizedBox(height: 8),
                  _buildSidebarMenuItem(
                    context,
                    index: 1,
                    icon: Icons.menu_book_outlined,
                    title: 'Courses',
                    menuKey: 'Courses',
                  ),
                  const SizedBox(height: 8),
                  _buildSidebarMenuItem(
                    context,
                    index: 2,
                    icon: Icons.assignment_outlined,
                    title: 'Task',
                    menuKey: 'Task',
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarMenuItem(
    BuildContext context, {
    required int index,
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
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
                    colors: [Color(0xFF28B79B), Color(0xFF1F9E84)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  )
                : null,
            color: isSelected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF28B79B).withOpacity(0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
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

  Widget _buildSidebarBottomItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final color = isDestructive ? const Color(0xFFEF4444) : const Color(0xFF4B5563);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  color: color,
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
