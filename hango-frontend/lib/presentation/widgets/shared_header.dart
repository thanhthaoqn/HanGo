import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/services/auth_service.dart';
import '../pages/login_page.dart';
import '../pages/register_page.dart';
import '../pages/exam/list_exams_page.dart';
import '../pages/learner/learner_home_page.dart';

class SharedHeader extends StatefulWidget implements PreferredSizeWidget {
  final bool isDesktop;
  final String activeTab;

  const SharedHeader({
    Key? key,
    required this.isDesktop,
    this.activeTab = 'Courses',
  }) : super(key: key);

  @override
  Size get preferredSize => const Size.fromHeight(70);

  @override
  State<SharedHeader> createState() => _SharedHeaderState();
}

class _SharedHeaderState extends State<SharedHeader> {
  final _authService = AuthService();
  bool _isLoggedIn = false;
  String _userFullName = 'Learner';
  String _userEmail = '';
  String _userInitials = 'L';

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    
    if (token == null) {
      if (mounted) {
        setState(() {
          _isLoggedIn = false;
        });
      }
      return;
    }

    final fullName = prefs.getString('user_fullname') ?? 'Learner';
    final email = prefs.getString('user_email') ?? '';
    
    String initials = 'L';
    if (fullName.trim().isNotEmpty) {
      final parts = fullName.trim().split(' ');
      if (parts.isNotEmpty) {
        initials = parts.last[0].toUpperCase();
      }
    }

    if (mounted) {
      setState(() {
        _isLoggedIn = true;
        _userFullName = fullName;
        _userEmail = email;
        _userInitials = initials;
      });
    }
  }

  void _handleLogout() async {
    await _authService.logout();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LearnerHomePage()),
        (route) => false,
      );
    }
  }

  Widget _buildHeaderNavLink(String text, {bool active = false, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? const Color(0xFF28B79B) : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: active ? const Color(0xFF28B79B) : const Color(0xFF4B5563),
            fontWeight: active ? FontWeight.bold : FontWeight.w500,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Left Logo & Title
            InkWell(
              onTap: () {
                if (widget.activeTab != 'Courses') {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const LearnerHomePage()),
                    (route) => false,
                  );
                }
              },
              child: Row(
                children: [
                  if (!widget.isDesktop) ...[
                    Builder(
                      builder: (context) => IconButton(
                        icon: const Icon(Icons.menu, color: Color(0xFF1F2937)),
                        onPressed: () => Scaffold.of(context).openDrawer(),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Image.network(
                    'https://res.cloudinary.com/diqekap4o/image/upload/v1781621071/logo_ayqvq4.png',
                    height: 36,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: const BoxDecoration(
                              color: Color(0xFFE6FFFA),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.school, size: 18, color: Color(0xFF28B79B)),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'HanGo',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),

            // Center Navigation Links (Visible on desktop only)
            if (widget.isDesktop)
              Row(
                children: [
                  _buildHeaderNavLink(
                    'Exams',
                    active: widget.activeTab == 'Exams',
                    onTap: () {
                      if (widget.activeTab != 'Exams') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ListExamsPage(),
                          ),
                        );
                      }
                    },
                  ),
                  const SizedBox(width: 24),
                  _buildHeaderNavLink(
                    'Courses',
                    active: widget.activeTab == 'Courses',
                    onTap: () {
                      if (widget.activeTab != 'Courses') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LearnerHomePage(),
                          ),
                        );
                      }
                    },
                  ),
                  const SizedBox(width: 24),
                  _buildHeaderNavLink('Flashcard'),
                ],
              ),

            // Right User Profile & Notification Actions OR Login/Register
            _isLoggedIn
                ? Row(
                    children: [
                      // Notification Bell
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.notifications_none_outlined, color: Color(0xFF4B5563), size: 26),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('No new notifications'),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            },
                          ),
                          Positioned(
                            top: 10,
                            right: 10,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFFEF4444),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),

                      // User profile with Popup Menu
                      PopupMenuButton<String>(
                        onSelected: (val) {
                          if (val == 'logout') {
                            _handleLogout();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Profile details for $_userFullName')),
                            );
                          }
                        },
                        offset: const Offset(0, 50),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            color: Color(0xFF6366F1), // Violet
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              _userInitials,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            enabled: false,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _userFullName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                                ),
                                Text(
                                  _userEmail,
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                                ),
                                const Divider(),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'profile',
                            child: Row(
                              children: [
                                Icon(Icons.person_outline, size: 20),
                                SizedBox(width: 8),
                                Text('Profile Settings'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'logout',
                            child: Row(
                              children: [
                                Icon(Icons.logout, size: 20, color: Colors.redAccent),
                                SizedBox(width: 8),
                                Text('Log Out', style: TextStyle(color: Colors.redAccent)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                : Row(
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const RegisterPage()),
                          );
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        child: const Text('Register', style: TextStyle(color: Color(0xFF2DD4BF), fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF14B8A6), Color(0xFF0891B2)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const LoginPage()),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          child: const Text('Login', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }
}
