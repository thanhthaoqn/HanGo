import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/services/auth_service.dart';
import '../pages/login_page.dart';
import '../pages/register_page.dart';
import '../pages/exam/list_exams_page.dart';
import '../pages/course/list_courses_page.dart';
import '../pages/course/cart_page.dart';
import '../pages/course/course_detail_page.dart';
import '../pages/learner/learner_home_page.dart';
import '../pages/learner/learner_shell_page.dart';
import '../pages/learner/learning_pathway_page.dart';
import '../pages/learner/my_information_page.dart';
import '../pages/course_manager/course_manager_my_information_page.dart';
import '../pages/course_manager/course_manager_shell_page.dart';
import '../pages/learner/my_learning_page.dart';
import '../pages/admin/admin_dashboard_page.dart';

import '../pages/trainer/trainer_shell_page.dart';
import '../../../domain/model/course.dart';
import '../../../domain/model/notification_item.dart';
import '../../../data/repositories/notification_repository.dart';

import '../../utils/toast_helper.dart';
import '../../utils/language_manager.dart';
import '../../utils/cart_manager.dart';
import '../../utils/permission_utils.dart';

class SharedHeader extends StatefulWidget implements PreferredSizeWidget {
  final bool isDesktop;
  final String activeTab;
  final bool hideNavLinks;
  final bool hideCommerceActions;
  final bool hideLanguageSwitcher;
  final bool showBackButton;

  const SharedHeader({
    Key? key,
    required this.isDesktop,
    this.activeTab = 'Courses',
    this.hideNavLinks = false,
    this.hideCommerceActions = false,
    this.hideLanguageSwitcher = false,
    this.showBackButton = false,
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
  int _cartCount = 0;
  List<String> _userRoles = [];
  bool _canEnroll = true;
  bool _canAttemptExam = true;

  List<Course> _cartCourses = [];

  OverlayEntry? _cartOverlayEntry;
  final LayerLink _cartLink = LayerLink();
  bool _isHoveringCartIcon = false;
  bool _isHoveringCartPopup = false;

  final _notificationRepository = NotificationRepository();
  List<NotificationItem> _notifications = [];
  int _unreadNotificationCount = 0;
  bool _isLoadingNotifications = false;

  @override
  void initState() {
    super.initState();
    _isVietnamese = LanguageManager.isVi;

    // Instant synchronous in-memory populate (0ms lag)
    if (AuthService.cachedIsLoggedIn != null) {
      _isLoggedIn = AuthService.cachedIsLoggedIn!;
      _userFullName = AuthService.cachedFullName ?? 'Learner';
      _userEmail = AuthService.cachedEmail ?? '';
      _userAvatarUrl = AuthService.cachedAvatarUrl ?? '';
      _updateInitials(_userFullName);
    }

    _cartCourses = CartManager.cartCoursesNotifier.value;
    _cartCount = CartManager.cartCountNotifier.value;

    LanguageManager.isVietnamese.addListener(_onLanguageChanged);
    AuthService.userChangeNotifier.addListener(_onUserChanged);
    CartManager.cartCountNotifier.addListener(_onCartChanged);
    CartManager.cartCoursesNotifier.addListener(_onCartCoursesChanged);

    _loadUserInfo();
    CartManager.updateCount();
    if (_isLoggedIn) {
      _loadNotifications();
    }
  }

  StateSetter? _popupSetState;

  void _updatePopup() {
    if (_popupSetState == null) return;
    try {
      _popupSetState!(() {});
    } catch (_) {
      _popupSetState = null;
    }
  }

  Future<void> _loadNotifications() async {
    if (_isLoadingNotifications) return;
    setState(() => _isLoadingNotifications = true);
    _updatePopup();
    try {
      final notifications = await _notificationRepository.getNotifications();
      final unreadCount = await _notificationRepository.getUnreadCount();
      if (!mounted) return;
      setState(() {
        _notifications = notifications;
        _unreadNotificationCount = unreadCount;
        _isLoadingNotifications = false;
      });
      _updatePopup();
    } catch (_) {
      if (mounted) setState(() => _isLoadingNotifications = false);
      _updatePopup();
    }
  }

  Future<void> _markNotificationAsRead(NotificationItem notification) async {
    if (notification.read) return;
    try {
      await _notificationRepository.markAsRead(notification.id);
      if (!mounted) return;
      setState(() {
        _notifications = _notifications
            .map((n) => n.id == notification.id
                ? NotificationItem(
                    id: n.id,
                    type: n.type,
                    title: n.title,
                    message: n.message,
                    courseId: n.courseId,
                    courseTitle: n.courseTitle,
                    read: true,
                    createdAt: n.createdAt,
                  )
                : n)
            .toList();
        _unreadNotificationCount = _unreadNotificationCount > 0 ? _unreadNotificationCount - 1 : 0;
      });
    } catch (_) {}
  }

  Future<void> _markAllNotificationsAsRead() async {
    try {
      await _notificationRepository.markAllAsRead();
      if (!mounted) return;
      setState(() {
        _notifications = _notifications
            .map((n) => NotificationItem(
                  id: n.id,
                  type: n.type,
                  title: n.title,
                  message: n.message,
                  courseId: n.courseId,
                  courseTitle: n.courseTitle,
                  read: true,
                  createdAt: n.createdAt,
                ))
            .toList();
        _unreadNotificationCount = 0;
      });
    } catch (_) {}
  }

  String _formatNotificationTime(DateTime? createdAt) {
    if (createdAt == null) return '';
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} mins ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    return '${diff.inDays} days ago';
  }

  IconData _notificationIcon(String type) {
    switch (type) {
      case 'PurchaseSuccess':
        return Icons.shopping_bag_outlined;
      case 'NewEnrollment':
        return Icons.school_outlined;
      case 'CommentReply':
        return Icons.chat_bubble_outline;
      case 'ContentApproved':
        return Icons.check_circle_outline;
      case 'ContentRejected':
        return Icons.cancel_outlined;
      case 'StatementReady':
        return Icons.receipt_long_outlined;
      case 'CourseUpdated':
        return Icons.upgrade_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  void _updateInitials(String name) {
    if (name.trim().isNotEmpty) {
      final parts = name.trim().split(' ');
      if (parts.isNotEmpty) {
        _userInitials = parts.last[0].toUpperCase();
      }
    }
  }

  void _onLanguageChanged() {
    if (mounted) {
      setState(() {
        _isVietnamese = LanguageManager.isVi;
      });
    }
  }

  void _onUserChanged() {
    if (mounted) {
      _loadUserInfo();
      if (AuthService.cachedIsLoggedIn == true) {
        _loadNotifications();
      }
    }
  }

  void _onCartChanged() {
    if (mounted) {
      setState(() {
        _cartCount = CartManager.cartCountNotifier.value;
      });
    }
  }

  void _onCartCoursesChanged() {
    if (mounted) {
      setState(() {
        _cartCourses = CartManager.cartCoursesNotifier.value;
        _cartCount = CartManager.cartCountNotifier.value;
      });
    }
  }

  @override
  void dispose() {
    _hideCartOverlay();
    LanguageManager.isVietnamese.removeListener(_onLanguageChanged);
    AuthService.userChangeNotifier.removeListener(_onUserChanged);
    CartManager.cartCountNotifier.removeListener(_onCartChanged);
    CartManager.cartCoursesNotifier.removeListener(_onCartCoursesChanged);
    super.dispose();
  }

  String _getCoursePrice(Course course) {
    if (course.price <= 0) {
      return 'Miễn phí';
    }
    final formatted = course.price.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
    return '$formattedđ';
  }

  int _parsePriceInt(String priceStr) {
    if (priceStr == 'Miễn phí' || priceStr.toLowerCase() == 'free') return 0;
    final cleaned = priceStr.replaceAll('.', '').replaceAll('đ', '').trim();
    return int.tryParse(cleaned) ?? 0;
  }

  String _formatPrice(int price) {
    return price.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.') + 'đ';
  }

  void _showCartOverlay() {
    _hideCartOverlay();
    if (!mounted) return;

    _cartOverlayEntry = OverlayEntry(
      builder: (context) {
        return Positioned(
          width: 320,
          child: CompositedTransformFollower(
            link: _cartLink,
            showWhenUnlinked: false,
            offset: const Offset(-280, 40),
            child: MouseRegion(
              onEnter: (_) {
                _isHoveringCartPopup = true;
              },
              onExit: (_) {
                _isHoveringCartPopup = false;
                _scheduleHideOverlays();
              },
              child: _buildCartDropdown(),
            ),
          ),
        );
      },
    );
    Overlay.of(context).insert(_cartOverlayEntry!);
  }

  void _hideCartOverlay() {
    if (_cartOverlayEntry != null) {
      _cartOverlayEntry!.remove();
      _cartOverlayEntry = null;
    }
  }

  void _scheduleHideOverlays() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!_isHoveringCartIcon && !_isHoveringCartPopup) {
        _hideCartOverlay();
      }
    });
  }

  Widget _buildCartDropdown() {
    final isVi = _isVietnamese;
    final cartCourses = _cartCourses;

    int totalVal = 0;
    for (final c in cartCourses) {
      totalVal += _parsePriceInt(_getCoursePrice(c));
    }

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isVi ? 'Giỏ hàng' : 'Cart',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Outfit'),
                ),
                InkWell(
                  onTap: () {
                    _hideCartOverlay();
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const CartPage()));
                  },
                  child: Text(
                    isVi ? 'Xem giỏ hàng' : 'View cart',
                    style: const TextStyle(color: Color(0xFF28B79B), fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            const SizedBox(height: 8),
            if (cartCourses.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                child: Text(
                  isVi ? 'Giỏ hàng trống.' : 'Cart is empty.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontFamily: 'Outfit'),
                ),
              )
            else ...[
              Container(
                constraints: const BoxConstraints(maxHeight: 220),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: cartCourses.length > 3 ? 3 : cartCourses.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final course = cartCourses[index];
                    return _buildDropdownItem(course);
                  },
                ),
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isVi ? 'Tổng cộng:' : 'Total:',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B), fontFamily: 'Outfit'),
                  ),
                  Text(
                    _formatPrice(totalVal),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF28B79B), fontFamily: 'Outfit'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 38,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF28B79B),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    _hideCartOverlay();
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const CartPage()));
                  },
                  child: Text(
                    isVi ? 'Thanh toán' : 'Checkout',
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownItem(Course course) {
    final isVi = _isVietnamese;
    final priceStr = _getCoursePrice(course);
    final displayPrice = priceStr == 'Miễn phí' ? (isVi ? 'Miễn phí' : 'Free') : priceStr;

    return InkWell(
      onTap: () {
        _hideCartOverlay();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => CourseDetailPage(courseId: course.id)),
        );
      },
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(
              width: 44,
              height: 44,
              color: const Color(0xFFF1F5F9),
              child: course.thumbnailUrl.isNotEmpty
                  ? Image.network(course.thumbnailUrl, fit: BoxFit.cover)
                  : const Icon(Icons.school_rounded, color: Color(0xFF94A3B8), size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B), fontFamily: 'Outfit'),
                ),
                const SizedBox(height: 3),
                Text(
                  course.creatorName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontFamily: 'Outfit'),
                ),
                const SizedBox(height: 3),
                Text(
                  displayPrice,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: priceStr == 'Miễn phí' ? const Color(0xFF28B79B) : const Color(0xFF1E293B),
                    fontFamily: 'Outfit',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
      AuthService.cachedIsLoggedIn = false;
      if (mounted) {
        setState(() {
          _isLoggedIn = false;
          _canEnroll = true;
          _canAttemptExam = true;
        });
      }
      return;
    }

    final fullName = prefs.getString('user_fullname') ?? 'Learner';
    final email = prefs.getString('user_email') ?? '';
    final avatarUrl = prefs.getString('user_avatar_url') ?? '';

    AuthService.cachedFullName = fullName;
    AuthService.cachedEmail = email;
    AuthService.cachedAvatarUrl = avatarUrl;
    AuthService.cachedIsLoggedIn = true;

    String initials = 'L';
    if (fullName.trim().isNotEmpty) {
      final parts = fullName.trim().split(' ');
      if (parts.isNotEmpty) {
        initials = parts.last[0].toUpperCase();
      }
    }

    final roles = prefs.getStringList('user_roles') ?? [];

    if (mounted) {
      setState(() {
        _isLoggedIn = true;
        _userFullName = fullName;
        _userEmail = email;
        _userInitials = initials;
        _userAvatarUrl = avatarUrl;
        _userRoles = roles;
        _canEnroll = PermissionUtils.shouldShowEnrollUi(true, roles);
        _canAttemptExam = PermissionUtils.shouldShowExamUi(true, roles);
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



  Widget _buildCartButton() {
    return CompositedTransformTarget(
      link: _cartLink,
      child: MouseRegion(
        onEnter: (_) {
          _isHoveringCartIcon = true;
          _showCartOverlay();
        },
        onExit: (_) {
          _isHoveringCartIcon = false;
          _scheduleHideOverlays();
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(
                Icons.shopping_cart_outlined,
                color: Color(0xFF4B5563),
                size: 24,
              ),
              onPressed: () {
                _hideCartOverlay();
                _navigateToLearnerTab(6);
              },
              tooltip: _isVietnamese ? 'Giỏ hàng' : 'Cart',
            ),
            if (_cartCount > 0)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Color(0xFF9333EA),
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Center(
                    child: Text(
                      '$_cartCount',
                      style: const TextStyle(
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
      ),
    );
  }

  void _navigateToLearnerTab(int tabIndex, {int subTab = 0}) {
    final shellState = LearnerShellPage.of(context);
    if (shellState != null) {
      shellState.selectTab(tabIndex, subTab: subTab);
    } else {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => LearnerShellPage(initialIndex: tabIndex, initialSubTab: subTab),
        ),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final logoWidget = InkWell(
      onTap: () => _navigateToLearnerTab(0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.showBackButton) ...[
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFF1F2937)),
              onPressed: () {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
              },
            ),
            const SizedBox(width: 8),
          ] else if (!widget.isDesktop && !widget.hideNavLinks) ...[
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
          onTap: () => _navigateToLearnerTab(0),
        ),
        const SizedBox(width: 12),
        _buildHeaderNavLink(
          _isVietnamese ? 'Khóa học' : 'Courses',
          active: widget.activeTab == 'Courses',
          onTap: () => _navigateToLearnerTab(1),
        ),
        const SizedBox(width: 12),
        if (_canAttemptExam) ...[
          _buildHeaderNavLink(
            _isVietnamese ? 'Đề thi' : 'Exams',
            active: widget.activeTab == 'Exams',
            onTap: () => _navigateToLearnerTab(2),
          ),
          const SizedBox(width: 12),
        ],
        _buildHeaderNavLink(
          _isVietnamese ? 'Lộ trình' : 'Pathway',
          active: widget.activeTab == 'Learning Pathway',
          onTap: () => _navigateToLearnerTab(3),
        ),
      ],
    );

    final rightActionsWidget = _isLoggedIn
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.isDesktop) ...[
                if (!widget.hideCommerceActions && _canEnroll) ...[
                  _buildCartButton(),
                  const SizedBox(width: 8),
                ],
              ],
              // Notification Bell
              Stack(
                clipBehavior: Clip.none,
                children: [
                  PopupMenuButton<void>(
                    
                    offset: const Offset(0, 50),
                    color: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    onOpened: _loadNotifications,
                    icon: const Icon(
                      Icons.notifications_none_outlined,
                      color: Color(0xFF4B5563),
                      size: 24,
                    ),
                    itemBuilder: (context) => [
                      PopupMenuItem<void>(
                        enabled: false,
                        child: StatefulBuilder(
                          builder: (context, setMenuState) {
                            _popupSetState = setMenuState;
                            return Container(
                            width: 320,
                            constraints: const BoxConstraints(maxHeight: 420),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _isVietnamese ? 'Thông báo' : 'Notifications',
                                        style: const TextStyle(
                                          fontFamily: 'Outfit',
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      if (_unreadNotificationCount > 0)
                                        InkWell(
                                          onTap: () async {
                                            await _markAllNotificationsAsRead();
                                            setMenuState(() {});
                                          },
                                          child: Text(
                                            _isVietnamese ? 'Đánh dấu đã đọc' : 'Mark all as read',
                                            style: const TextStyle(fontSize: 12, color: Color(0xFF28B79B), fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                                if (_isLoadingNotifications)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 32),
                                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                  )
                                else if (_notifications.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 24),
                                    child: Column(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: const BoxDecoration(color: Color(0xFFF8FAFC), shape: BoxShape.circle),
                                          child: const Icon(Icons.notifications_off_outlined, size: 40, color: Color(0xFF94A3B8)),
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          _isVietnamese ? 'Không có thông báo mới' : 'No new notifications',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontFamily: 'Outfit',
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  Flexible(
                                    child: ListView.separated(
                                      shrinkWrap: true,
                                      padding: const EdgeInsets.only(top: 12),
                                      itemCount: _notifications.length,
                                      separatorBuilder: (_, __) => const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 10),
                                        child: Divider(height: 1, color: Color(0xFFF1F5F9)),
                                      ),
                                      itemBuilder: (context, index) {
                                        final n = _notifications[index];
                                        return InkWell(
                                          onTap: () async {
                                            await _markNotificationAsRead(n);
                                            setMenuState(() {});
                                          },
                                          child: Container(
                                            color: n.read ? Colors.transparent : const Color(0xFFF0FDFA),
                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                            child: _buildNotificationItem(
                                              icon: _notificationIcon(n.type),
                                              iconColor: const Color(0xFF28B79B),
                                              bgColor: const Color(0xFFE6FBF7),
                                              title: n.title,
                                              description: n.message,
                                              time: _formatNotificationTime(n.createdAt),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                              ],
                            ),
                          );
                          }
                        ),
                      ),
                    ],
                  ),
                  if (_unreadNotificationCount > 0)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: IgnorePointer(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          constraints: const BoxConstraints(minWidth: 16),
                          child: Text(
                            _unreadNotificationCount > 99 ? '99+' : '$_unreadNotificationCount',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 8),

              // User profile with Popup Menu
              PopupMenuButton<String>(
                enabled: true,
                onSelected: (val) {
                  if (val == 'dashboard') {
                    final isTrainer = _userRoles.any((r) => r.toUpperCase().contains('TRAINER'));
                    final isAdmin = _userRoles.any((r) => r.toUpperCase().contains('ADMIN'));
                    if (isAdmin) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AdminDashboardPage(),
                        ),
                      );
                    } else if (isTrainer) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const TrainerShellPage(),
                        ),
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CourseManagerShellPage(),
                        ),
                      );
                    }
                  } else if (val == 'logout') {
                    _handleLogout();
                  } else if (val == 'my_info' || val == 'profile') {
                    if (widget.hideCommerceActions) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CourseManagerMyInformationPage(),
                        ),
                      );
                    } else {
                      _navigateToLearnerTab(5, subTab: 0);
                    }
                  } else if (val == 'learning') {
                    _navigateToLearnerTab(4);
                  } else if (val == 'cart') {
                    _navigateToLearnerTab(6);
                  } else if (val == 'purchase_history') {
                    _navigateToLearnerTab(5, subTab: 2);
                  } else if (val == 'support_tickets') {
                    if (_userRoles.contains('ROLE_COURSE_MANAGER')) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CourseManagerShellPage(initialIndex: 6),
                        ),
                      );
                    } else if (_userRoles.contains('ROLE_TRAINER')) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const TrainerShellPage(initialIndex: 6),
                        ),
                      );
                    } else {
                      _navigateToLearnerTab(5, subTab: 3);
                    }
                  } else if (val == 'notifications') {
                    ToastHelper.show(
                      context,
                      _unreadNotificationCount > 0
                          ? (_isVietnamese ? 'Bạn có $_unreadNotificationCount thông báo chưa đọc' : 'You have $_unreadNotificationCount unread notifications')
                          : (_isVietnamese ? 'Không có thông báo mới' : 'No new notifications'),
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
                  if (_userRoles.any((r) => r.toUpperCase().contains('TRAINER') || r.toUpperCase().contains('MANAGER') || r.toUpperCase().contains('ADMIN')))
                    PopupMenuItem(
                      value: 'dashboard',
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE6F7F1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.dashboard_outlined,
                                size: 18,
                                color: Color(0xFF20B486),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Dashboard',
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
                  if (!widget.hideCommerceActions) ...[
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
                  if (_canEnroll)
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
                          ],
                        ),
                      ),
                    ),


                  if (_userRoles.any((r) => r.toUpperCase().contains('TRAINER') || r.toUpperCase().contains('MANAGER')))
                    PopupMenuItem(
                      value: 'support_tickets',
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.confirmation_number_outlined,
                              size: 18,
                              color: Color(0xFF28B79B),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _isVietnamese ? 'Phiếu hỗ trợ' : 'Support Tickets',
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
                  ],
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
                            widget.hideCommerceActions
                                ? 'My information'
                                : (_isVietnamese ? 'Thông tin của tôi' : 'My Information'),
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
                            widget.hideCommerceActions
                                ? 'Log out'
                                : (_isVietnamese ? 'Đăng xuất' : 'Logout'),
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
                _buildCartButton(),
                const SizedBox(width: 12),
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
                  'Login',
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
                    'Register',
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

  Widget _buildNotificationItem({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String title,
    required String description,
    required String time,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                time,
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
