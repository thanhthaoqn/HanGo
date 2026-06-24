import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/services/auth_service.dart';
import '../pages/login_page.dart';
import '../pages/register_page.dart';
import '../pages/exam/list_exams_page.dart';
import '../pages/course/list_courses_page.dart';
import '../pages/learner/learner_home_page.dart';
import '../pages/learner/my_information_page.dart';

class SharedHeader extends StatefulWidget implements PreferredSizeWidget {
  final bool isDesktop;
  final String activeTab;
  final bool hideNavLinks;

  const SharedHeader({
    Key? key,
    required this.isDesktop,
    this.activeTab = 'Courses',
    this.hideNavLinks = false,
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
  String _userAvatarUrl = '';

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
    final avatarUrl = prefs.getString('user_avatar_url') ?? '';

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
        _userAvatarUrl = avatarUrl;
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

  Widget _buildInitialsAvatar(double size, double fontSize) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF28B79B), Color(0xFF1F9E84)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          _userInitials,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: fontSize,
            fontFamily: 'Outfit',
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderNavLink(
    String text, {
    bool active = false,
    VoidCallback? onTap,
  }) {
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
    final logoWidget = InkWell(
      onTap: widget.hideNavLinks
          ? null
          : () {
              // If not already on home page (activeTab is empty string for LearnerHomePage)
              if (widget.activeTab != '') {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LearnerHomePage(),
                  ),
                  (route) => false,
                );
              }
            },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!widget.isDesktop && !widget.hideNavLinks) ...[
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE6FFFA),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.school,
                      size: 18,
                      color: Color(0xFF28B79B),
                    ),
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
    );

    final navLinksWidget = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHeaderNavLink(
          'Exams',
          active: widget.activeTab == 'Exams',
          onTap: () {
            if (widget.activeTab != 'Exams') {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ListExamsPage()),
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
                  builder: (context) => const ListCoursesPage(),
                ),
              );
            }
          },
        ),
        const SizedBox(width: 24),
        _buildHeaderNavLink('Flashcard'),
      ],
    );

    final rightActionsWidget = _isLoggedIn
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Notification Bell
              Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.notifications_none_outlined,
                      color: Color(0xFF4B5563),
                      size: 26,
                    ),
                    onPressed: widget.hideNavLinks
                        ? null
                        : () {
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
                enabled: !widget.hideNavLinks,
                onSelected: (val) {
                  if (val == 'logout') {
                    _handleLogout();
                  } else if (val == 'my_info' || val == 'profile') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MyInformationPage(),
                      ),
                    );
                  }
                },
                offset: const Offset(0, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFFF1F5F9), width: 1),
                ),
                elevation: 10,
                color: Colors.white,
                shadowColor: Colors.black.withOpacity(0.08),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: const Color(0xFFE5E7EB),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                          ),
                          child: ClipOval(
                            child: _userAvatarUrl.isNotEmpty
                                ? Image.network(
                                    _userAvatarUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) =>
                                        _buildInitialsAvatar(28, 12),
                                  )
                                : _buildInitialsAvatar(28, 12),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _userFullName,
                          style: const TextStyle(
                            color: Color(0xFF1E293B),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            fontFamily: 'Outfit',
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 16,
                          color: Color(0xFF64748B),
                        ),
                      ],
                    ),
                  ),
                ),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    enabled: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                ),
                                child: ClipOval(
                                  child: _userAvatarUrl.isNotEmpty
                                      ? Image.network(
                                          _userAvatarUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) =>
                                              _buildInitialsAvatar(36, 14),
                                        )
                                      : _buildInitialsAvatar(36, 14),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _userFullName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0F172A),
                                        fontSize: 14,
                                        fontFamily: 'Outfit',
                                      ),
                                    ),
                                    Text(
                                      _userEmail,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF64748B),
                                        fontFamily: 'Outfit',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Divider(height: 1, color: Color(0xFFE2E8F0)),
                        ],
                      ),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'my_info',
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE6F4EA),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.assignment_ind_outlined,
                              size: 18,
                              color: Color(0xFF137333),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'My Information',
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              color: Color(0xFF1E293B),
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'profile',
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE6FFFA),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.settings_outlined,
                              size: 18,
                              color: Color(0xFF28B79B),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Profile Settings',
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              color: Color(0xFF1E293B),
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'logout',
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFDE8E8),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.logout_rounded,
                              size: 18,
                              color: Colors.redAccent,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Log Out',
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              color: Colors.redAccent,
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RegisterPage(),
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: const Text(
                  'Register',
                  style: TextStyle(
                    color: Color(0xFF2DD4BF),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
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
                      MaterialPageRoute(
                        builder: (context) => const LoginPage(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text(
                    'Login',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          );

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
          children: widget.isDesktop
              ? [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: logoWidget,
                    ),
                  ),
                  if (!widget.hideNavLinks)
                    Expanded(child: Center(child: navLinksWidget))
                  else
                    const Spacer(),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: rightActionsWidget,
                    ),
                  ),
                ]
              : [logoWidget, rightActionsWidget],
        ),
      ),
    );
  }
}
