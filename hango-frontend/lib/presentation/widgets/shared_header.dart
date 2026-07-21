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
import '../pages/learner/learning_pathway_page.dart';
import '../pages/learner/my_information_page.dart';
import '../pages/course_manager/course_manager_my_information_page.dart';
import '../pages/learner/my_learning_page.dart';
import '../../../data/repositories/course_repository.dart';
import '../../../domain/model/course.dart';

import '../../utils/toast_helper.dart';
import '../../utils/language_manager.dart';
import '../../utils/cart_manager.dart';

class SharedHeader extends StatefulWidget implements PreferredSizeWidget {
  final bool isDesktop;
  final String activeTab;
  final bool hideNavLinks;
  final bool hideCommerceActions;
  final bool hideLanguageSwitcher;

  const SharedHeader({
    Key? key,
    required this.isDesktop,
    this.activeTab = 'Courses',
    this.hideNavLinks = false,
    this.hideCommerceActions = false,
    this.hideLanguageSwitcher = false,
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

  List<Course> _allCourses = [];
  List<String> _cartIds = [];

  OverlayEntry? _cartOverlayEntry;
  final LayerLink _cartLink = LayerLink();
  bool _isHoveringCartIcon = false;
  bool _isHoveringCartPopup = false;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _isVietnamese = LanguageManager.isVi;
    LanguageManager.isVietnamese.addListener(_onLanguageChanged);
    CartManager.cartCountNotifier.addListener(_onCartChanged);
    CartManager.updateCount();

    _loadCartIds();
    _fetchAllCoursesForDropdowns();
  }

  void _onLanguageChanged() {
    if (mounted) {
      setState(() {
        _isVietnamese = LanguageManager.isVi;
      });
    }
  }

  void _onCartChanged() {
    if (mounted) {
      setState(() {
        _cartCount = CartManager.cartCountNotifier.value;
      });
      _loadCartIds();
    }
  }

  Future<void> _loadCartIds() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _cartIds = prefs.getStringList('cart_course_ids') ?? [];
      });
    }
  }

  Future<void> _fetchAllCoursesForDropdowns() async {
    try {
      final courses = await CourseRepository().fetchCourses(search: '', filterType: 'ALL', difficulty: 'ALL');
      if (mounted) {
        setState(() {
          _allCourses = courses;
        });
      }
    } catch (e) {
      // ignore
    }
  }

  @override
  void dispose() {
    _hideCartOverlay();
    LanguageManager.isVietnamese.removeListener(_onLanguageChanged);
    CartManager.cartCountNotifier.removeListener(_onCartChanged);
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
    final cartCourses = _allCourses.where((c) => _cartIds.contains(c.id.toString())).toList();

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
    final cartList = prefs.getStringList('cart_course_ids') ?? [];
    final cartCount = cartList.length;
    final token = prefs.getString('auth_token');

    if (token == null) {
      if (mounted) {
        setState(() {
          _isLoggedIn = false;
          _cartCount = cartCount;
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
        _cartCount = cartCount;
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
                Navigator.push(context, MaterialPageRoute(builder: (context) => const CartPage()));
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
                if (!widget.hideCommerceActions) ...[
                  _buildCartButton(),
                  const SizedBox(width: 8),
                ],
              ],
              // Notification Bell
              PopupMenuButton<void>(
                enabled: !widget.hideNavLinks,
                offset: const Offset(0, 50),
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                icon: const Icon(
                  Icons.notifications_none_outlined,
                  color: Color(0xFF4B5563),
                  size: 24,
                ),
                itemBuilder: (context) => [
                  PopupMenuItem<void>(
                    enabled: false,
                    child: Container(
                      width: 280,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _isVietnamese ? 'Thông báo' : 'Notifications',
                              style: const TextStyle(
                                fontFamily: 'Outfit',
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Divider(height: 1, color: Color(0xFFE2E8F0)),
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: const BoxDecoration(
                              color: Color(0xFFF8FAFC),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.notifications_off_outlined,
                              size: 40,
                              color: Color(0xFF94A3B8),
                            ),
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
                          const SizedBox(height: 8),
                          Text(
                            _isVietnamese 
                                ? 'Chúng tôi sẽ thông báo khi có hoạt động mới.' 
                                : 'We\'ll let you know when something comes up.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
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
                  if (val == 'logout') {
                    _handleLogout();
                  } else if (val == 'my_info' || val == 'profile') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => widget.hideCommerceActions
                            ? const CourseManagerMyInformationPage()
                            : const MyInformationPage(),
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
