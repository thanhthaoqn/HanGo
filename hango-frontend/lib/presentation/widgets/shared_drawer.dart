import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../routes/app_routes.dart';
import '../../../data/services/auth_service.dart';
import '../../utils/cart_manager.dart';
import '../../utils/permission_utils.dart';
import '../pages/learner/learner_shell_page.dart';

class SharedDrawer extends StatefulWidget {
  final String activeTab;

  const SharedDrawer({super.key, this.activeTab = ''});

  @override
  State<SharedDrawer> createState() => _SharedDrawerState();
}

class _SharedDrawerState extends State<SharedDrawer> {
  final _authService = AuthService();
  bool _isLoggedIn = false;
  String _userFullName = 'Learner';
  String _userEmail = '';
  String _userInitials = 'L';
  String _userAvatarUrl = '';
  int _cartCount = 0;
  List<String> _userRoles = [];
  bool _canAttemptExam = true;

  @override
  void initState() {
    super.initState();

    if (AuthService.cachedIsLoggedIn != null) {
      _isLoggedIn = AuthService.cachedIsLoggedIn!;
      _userFullName = AuthService.cachedFullName ?? 'Learner';
      _userEmail = AuthService.cachedEmail ?? '';
      _userAvatarUrl = AuthService.cachedAvatarUrl ?? '';
      _updateInitials(_userFullName);
    }

    _cartCount = CartManager.cartCountNotifier.value;

    AuthService.userChangeNotifier.addListener(_onUserChanged);
    CartManager.cartCountNotifier.addListener(_onCartChanged);

    _loadUserInfo();
  }

  @override
  void dispose() {
    AuthService.userChangeNotifier.removeListener(_onUserChanged);
    CartManager.cartCountNotifier.removeListener(_onCartChanged);
    super.dispose();
  }

  void _onUserChanged() {
    if (mounted) {
      _loadUserInfo();
    }
  }

  void _onCartChanged() {
    if (mounted) {
      setState(() {
        _cartCount = CartManager.cartCountNotifier.value;
      });
    }
  }

  void _updateInitials(String fullName) {
    if (fullName.trim().isNotEmpty) {
      final parts = fullName.trim().split(' ');
      if (parts.isNotEmpty) {
        _userInitials = parts.last[0].toUpperCase();
      }
    }
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null) {
      AuthService.cachedIsLoggedIn = false;
      if (mounted) {
        setState(() {
          _isLoggedIn = false;
          _canAttemptExam = true;
        });
      }
      return;
    }

    final fullName = prefs.getString('user_fullname') ?? 'Learner';
    final email = prefs.getString('user_email') ?? '';
    final avatarUrl = prefs.getString('user_avatar_url') ?? '';
    final roles = prefs.getStringList('user_roles') ?? [];

    AuthService.cachedFullName = fullName;
    AuthService.cachedEmail = email;
    AuthService.cachedAvatarUrl = avatarUrl;
    AuthService.cachedIsLoggedIn = true;

    _updateInitials(fullName);

    if (mounted) {
      setState(() {
        _isLoggedIn = true;
        _userFullName = fullName;
        _userEmail = email;
        _userAvatarUrl = avatarUrl;
        _userRoles = roles;
        _canAttemptExam = PermissionUtils.shouldShowExamUi(true, roles);
      });
    }
  }

  void _navigateToTab(BuildContext context, int tabIndex, {int subTab = 0}) {
    Navigator.of(context).pop();
    final learnerShell = LearnerShellPage.of(context);
    if (learnerShell != null) {
      learnerShell.selectTab(tabIndex, subTab: subTab);
      return;
    }
    final targetRoute = _getLearnerRoute(tabIndex, subTab: subTab);
    try {
      context.go(targetRoute);
    } catch (_) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) =>
              LearnerShellPage(initialIndex: tabIndex, initialSubTab: subTab),
        ),
        (route) => false,
      );
    }
  }

  String _getLearnerRoute(int tabIndex, {int subTab = 0}) {
    switch (tabIndex) {
      case 0:
        return AppRoutes.home;
      case 1:
        return AppRoutes.courses;
      case 2:
        return AppRoutes.exams;
      case 3:
        return AppRoutes.pathway;
      case 4:
        return AppRoutes.myLearning;
      case 5:
        return subTab > 0
            ? '${AppRoutes.profile}?tab=$subTab'
            : AppRoutes.profile;
      case 6:
        return AppRoutes.cart;
      default:
        return AppRoutes.home;
    }
  }

  void _handleLogout() async {
    Navigator.of(context).pop();
    await _authService.logout();
    if (mounted) {
      context.go(AppRoutes.home);
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

  Widget _buildLoggedInHeader() {
    String? roleBadge;
    if (_userRoles.any((r) => r.toUpperCase().contains('ADMIN'))) {
      roleBadge = 'Admin';
    } else if (_userRoles.any((r) => r.toUpperCase().contains('TRAINER'))) {
      roleBadge = 'Trainer';
    } else if (_userRoles.any(
      (r) =>
          r.toUpperCase().contains('COURSE_MANAGER') ||
          r.toUpperCase().contains('MANAGER'),
    )) {
      roleBadge = 'Course Manager';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF28B79B), Color(0xFF1F9E84)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: _userAvatarUrl.isNotEmpty
                      ? Image.network(
                          _userAvatarUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _buildInitialsAvatar(52, 20),
                        )
                      : _buildInitialsAvatar(52, 20),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _userFullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _userEmail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                    if (roleBadge != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          roleBadge,
                          style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGuestHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.network(
            'https://res.cloudinary.com/diqekap4o/image/upload/v1781621071/logo_ayqvq4.png',
            height: 36,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE6FFFA),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.school,
                      size: 20,
                      color: Color(0xFF28B79B),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'HanGo',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 6),
          const Text(
            'Master English, open your future.',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 12,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isActive = false,
    Widget? trailing,
    Color? textColor,
    Color? iconColor,
  }) {
    const activeColor = Color(0xFF28B79B);
    final itemBg = isActive ? const Color(0xFFE6FFFA) : Colors.transparent;
    final itemTextColor =
        textColor ?? (isActive ? activeColor : const Color(0xFF334155));
    final itemIconColor =
        iconColor ?? (isActive ? activeColor : const Color(0xFF64748B));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: itemBg,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(icon, size: 20, color: itemIconColor),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 14,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                      color: itemTextColor,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 16, 16, 6),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontFamily: 'Outfit',
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
          color: Color(0xFF94A3B8),
        ),
      ),
    );
  }

  Widget? _buildRoleDashboardItem() {
    String? roleTitle;
    String? targetRoute;

    if (_userRoles.any((r) => r.toUpperCase().contains('ADMIN'))) {
      roleTitle = 'Admin Dashboard';
      targetRoute = AppRoutes.admin;
    } else if (_userRoles.any((r) => r.toUpperCase().contains('TRAINER'))) {
      roleTitle = 'Trainer Dashboard';
      targetRoute = AppRoutes.trainer;
    } else if (_userRoles.any(
      (r) =>
          r.toUpperCase().contains('COURSE_MANAGER') ||
          r.toUpperCase().contains('MANAGER'),
    )) {
      roleTitle = 'Manager Dashboard';
      targetRoute = AppRoutes.courseManager;
    }

    if (roleTitle == null || targetRoute == null) return null;

    return _buildDrawerItem(
      icon: Icons.dashboard_outlined,
      title: roleTitle,
      iconColor: const Color(0xFF28B79B),
      textColor: const Color(0xFF28B79B),
      onTap: () {
        Navigator.of(context).pop();
        context.go(targetRoute!);
      },
    );
  }

  Widget _buildLogoutButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Material(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: _handleLogout,
          borderRadius: BorderRadius.circular(10),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.logout_rounded, size: 20, color: Colors.redAccent),
                SizedBox(width: 14),
                Text(
                  'Log Out',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.redAccent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasRole = _userRoles.any(
      (r) =>
          r.toUpperCase().contains('ADMIN') ||
          r.toUpperCase().contains('TRAINER') ||
          r.toUpperCase().contains('MANAGER'),
    );

    final roleItem = _isLoggedIn && hasRole ? _buildRoleDashboardItem() : null;

    return Drawer(
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Column(
        children: [
          _isLoggedIn ? _buildLoggedInHeader() : _buildGuestHeader(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _buildDrawerItem(
                  icon: Icons.home_outlined,
                  title: 'Home',
                  isActive:
                      widget.activeTab == '' ||
                      widget.activeTab == 'Home' ||
                      widget.activeTab == 'Trang chủ',
                  onTap: () => _navigateToTab(context, 0),
                ),
                _buildDrawerItem(
                  icon: Icons.school_outlined,
                  title: 'Courses',
                  isActive: widget.activeTab == 'Courses',
                  onTap: () => _navigateToTab(context, 1),
                ),
                if (_canAttemptExam)
                  _buildDrawerItem(
                    icon: Icons.description_outlined,
                    title: 'Exams',
                    isActive: widget.activeTab == 'Exams',
                    onTap: () => _navigateToTab(context, 2),
                  ),
                _buildDrawerItem(
                  icon: Icons.alt_route_rounded,
                  title: 'Learning Pathway',
                  isActive:
                      widget.activeTab == 'Learning Pathway' ||
                      widget.activeTab == 'Pathway',
                  onTap: () => _navigateToTab(context, 3),
                ),
                if (_isLoggedIn) ...[
                  const Divider(height: 24, indent: 16, endIndent: 16),
                  _buildSectionHeader('My Account'),
                  _buildDrawerItem(
                    icon: Icons.play_lesson_outlined,
                    title: 'My Learning',
                    isActive: widget.activeTab == 'Learning',
                    onTap: () => _navigateToTab(context, 4),
                  ),
                  _buildDrawerItem(
                    icon: Icons.shopping_cart_outlined,
                    title: 'Shopping Cart',
                    isActive: widget.activeTab == 'Cart',
                    trailing: _cartCount > 0
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF9333EA),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$_cartCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        : null,
                    onTap: () => _navigateToTab(context, 6),
                  ),
                  _buildDrawerItem(
                    icon: Icons.receipt_long_outlined,
                    title: 'Purchase History',
                    onTap: () => _navigateToTab(context, 5, subTab: 2),
                  ),
                  _buildDrawerItem(
                    icon: Icons.person_outline,
                    title: 'Profile',
                    isActive: widget.activeTab == 'Profile',
                    onTap: () => _navigateToTab(context, 5),
                  ),
                  if (roleItem != null) ...[
                    const Divider(height: 24, indent: 16, endIndent: 16),
                    _buildSectionHeader('Management'),
                    roleItem,
                  ],
                ],
              ],
            ),
          ),
          if (_isLoggedIn) _buildLogoutButton(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Text(
              'HanGo © 2026',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 11,
                color: Colors.grey.shade400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
