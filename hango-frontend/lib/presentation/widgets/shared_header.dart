import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/services/auth_service.dart';
import '../pages/login_page.dart';
import '../pages/register_page.dart';
import '../pages/exam/list_exams_page.dart';
import '../pages/course/list_courses_page.dart';
import '../pages/learner/learner_home_page.dart';
import '../pages/learner/learning_pathway_page.dart';
import '../pages/learner/my_information_page.dart';
import '../pages/learner/my_learning_page.dart';

import '../../utils/toast_helper.dart';
import '../../utils/language_manager.dart';

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
  bool _isVietnamese = true;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _isVietnamese = LanguageManager.isVi;
    LanguageManager.isVietnamese.addListener(_onLanguageChanged);
  }

  void _onLanguageChanged() {
    if (mounted) {
      setState(() {
        _isVietnamese = LanguageManager.isVi;
      });
    }
  }

  @override
  void dispose() {
    LanguageManager.isVietnamese.removeListener(_onLanguageChanged);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SharedHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
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
            fontFamily: 'Outfit',
          ),
        ),
      ),
    );
  }

  Widget _buildTeachingButton() {
    return TextButton.icon(
      onPressed: () {
        ToastHelper.show(context, _isVietnamese ? 'Chuyển sang giao diện giảng dạy' : 'Switch to teaching interface');
      },
      icon: const Icon(
        Icons.school_outlined,
        size: 18,
        color: Color(0xFF4B5563),
      ),
      label: Text(
        _isVietnamese ? 'Dạy học' : 'Teach',
        style: const TextStyle(
          color: Color(0xFF4B5563),
          fontWeight: FontWeight.bold,
          fontSize: 14,
          fontFamily: 'Outfit',
        ),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }

  Widget _buildLanguageSwitcher() {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () {
              LanguageManager.setLanguage(true);
              ToastHelper.show(context, 'Đã chuyển sang Tiếng Việt');
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _isVietnamese ? const Color(0xFF28B79B) : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'VI',
                style: TextStyle(
                  color: _isVietnamese ? Colors.white : const Color(0xFF64748B),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  fontFamily: 'Outfit',
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              LanguageManager.setLanguage(false);
              ToastHelper.show(context, 'Switched to English');
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: !_isVietnamese ? const Color(0xFF28B79B) : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'EN',
                style: TextStyle(
                  color: !_isVietnamese ? Colors.white : const Color(0xFF64748B),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  fontFamily: 'Outfit',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWishlistButton() {
    return IconButton(
      icon: const Icon(
        Icons.favorite_border_rounded,
        color: Color(0xFF4B5563),
        size: 24,
      ),
      onPressed: () {
        ToastHelper.show(context, 'Danh sách yêu thích');
      },
      tooltip: 'Danh sách yêu thích',
    );
  }

  Widget _buildCartButton() {
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: const Icon(
            Icons.shopping_cart_outlined,
            color: Color(0xFF4B5563),
            size: 24,
          ),
          onPressed: () {
            ToastHelper.show(context, 'Giỏ hàng của bạn');
          },
          tooltip: 'Giỏ hàng',
        ),
        Positioned(
          top: 4,
          right: 4,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: Color(0xFFF05A22),
              shape: BoxShape.circle,
            ),
            constraints: const BoxConstraints(
              minWidth: 16,
              minHeight: 16,
            ),
            child: const Center(
              child: Text(
                '3',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final logoWidget = InkWell(
      onTap: widget.hideNavLinks
          ? null
          : () {
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
          _isVietnamese ? 'Trang chủ' : 'Home',
          active: widget.activeTab == 'Trang chủ' || widget.activeTab == '',
          onTap: () {
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
        ),
        const SizedBox(width: 12),
        _buildHeaderNavLink(
          _isVietnamese ? 'Khóa học' : 'Courses',
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
        const SizedBox(width: 12),
        _buildHeaderNavLink(
          _isVietnamese ? 'Đề thi' : 'Exams',
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
        const SizedBox(width: 12),
        _buildHeaderNavLink(
          _isVietnamese ? 'Lộ trình' : 'Pathway',
          active: widget.activeTab == 'Learning Pathway',
          onTap: () {
            if (widget.activeTab != 'Learning Pathway') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const LearningPathwayPage(),
                ),
              );
            }
          },
        ),
      ],
    );

    final rightActionsWidget = _isLoggedIn
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.isDesktop) ...[
                _buildTeachingButton(),
                const SizedBox(width: 4),
                _buildLanguageSwitcher(),
                const SizedBox(width: 4),
                _buildWishlistButton(),
                const SizedBox(width: 2),
                _buildCartButton(),
                const SizedBox(width: 2),
              ],
              // Notification Bell
              Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.notifications_none_outlined,
                      color: Color(0xFF4B5563),
                      size: 24,
                    ),
                    onPressed: widget.hideNavLinks
                        ? null
                        : () {
                            ToastHelper.show(context, _isVietnamese ? 'Không có thông báo mới' : 'No new notifications');
                          },
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF05A22),
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: const Center(
                        child: Text(
                          '3',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),

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
                  } else if (val == 'learning') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MyLearningPage(),
                      ),
                    );
                  } else if (val == 'cart') {
                    ToastHelper.show(context, _isVietnamese ? 'Mở giỏ hàng của bạn' : 'Opening your cart');
                  } else if (val == 'wishlist') {
                    ToastHelper.show(context, _isVietnamese ? 'Mở danh sách mong ước của bạn' : 'Opening your wishlist');
                  } else if (val == 'instructor_dashboard') {
                    ToastHelper.show(context, _isVietnamese ? 'Mở bảng điều khiển giảng viên' : 'Opening instructor dashboard');
                  } else if (val == 'purchase_history') {
                    ToastHelper.show(context, _isVietnamese ? 'Mở lịch sử mua hàng' : 'Opening purchase history');
                  } else if (val == 'notifications') {
                    ToastHelper.show(context, _isVietnamese ? 'Không có thông báo mới' : 'No new notifications');
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
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFE2E8F0),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 4,
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
                                  _buildInitialsAvatar(36, 14),
                            )
                          : _buildInitialsAvatar(36, 14),
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
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
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
                    value: 'learning',
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.school_outlined,
                            size: 18,
                            color: Color(0xFF4B5563),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _isVietnamese ? 'Học tập' : 'My Learning',
                            style: const TextStyle(
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
                    value: 'cart',
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.shopping_cart_outlined,
                            size: 18,
                            color: Color(0xFF4B5563),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _isVietnamese ? 'Giỏ hàng của tôi' : 'My Cart',
                              style: const TextStyle(
                                fontFamily: 'Outfit',
                                color: Color(0xFF1E293B),
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B5CF6),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              '5',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'wishlist',
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.favorite_border_rounded,
                            size: 18,
                            color: Color(0xFF4B5563),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _isVietnamese ? 'Danh sách mong ước' : 'Wishlist',
                            style: const TextStyle(
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
                    value: 'instructor_dashboard',
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.dashboard_outlined,
                            size: 18,
                            color: Color(0xFF4B5563),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _isVietnamese ? 'Bảng điều khiển của giảng viên' : 'Instructor Dashboard',
                            style: const TextStyle(
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
                    value: 'purchase_history',
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.history_rounded,
                            size: 18,
                            color: Color(0xFF4B5563),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _isVietnamese ? 'Lịch sử mua hàng' : 'Purchase History',
                            style: const TextStyle(
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
                  const PopupMenuDivider(height: 1),
                  PopupMenuItem(
                    value: 'notifications',
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.notifications_none_outlined,
                            size: 18,
                            color: Color(0xFF4B5563),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _isVietnamese ? 'Thông báo' : 'Notifications',
                            style: const TextStyle(
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
                  const PopupMenuDivider(height: 1),
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
                          Text(
                            _isVietnamese ? 'Thông tin của tôi' : 'My Information',
                            style: const TextStyle(
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
                          Text(
                            _isVietnamese ? 'Đăng xuất' : 'Logout',
                            style: const TextStyle(
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
              if (widget.isDesktop) ...[
                _buildTeachingButton(),
                const SizedBox(width: 8),
                _buildLanguageSwitcher(),
                const SizedBox(width: 8),
                _buildWishlistButton(),
                const SizedBox(width: 4),
                _buildCartButton(),
                const SizedBox(width: 8),
              ],
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LoginPage(),
                    ),
                  );
                },
                child: const Text(
                  'Đăng nhập',
                  style: TextStyle(
                    color: Color(0xFF1E293B),
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    fontFamily: 'Outfit',
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF05A22),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF05A22).withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RegisterPage(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text(
                    'Đăng ký',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      fontFamily: 'Outfit',
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
