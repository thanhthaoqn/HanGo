import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/repositories/course_repository.dart';
import '../../../data/repositories/cart_repository.dart';
import '../../../domain/model/course.dart';
import '../../../utils/language_manager.dart';
import '../../../utils/toast_helper.dart';
import '../../../utils/cart_manager.dart';
import '../../widgets/shared_header.dart';
import '../../widgets/shared_footer.dart';
import 'list_courses_page.dart';
import 'course_detail_page.dart';
import '../login_page.dart';
import '../../widgets/payment_qr_dialog.dart';

class CartPage extends StatefulWidget {
  final bool isEmbedded;
  const CartPage({Key? key, this.isEmbedded = false}) : super(key: key);

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final CourseRepository _repository = CourseRepository();
  final CartRepository _cartRepository = CartRepository();
  List<Course> _cartCourses = [];
  Set<String> _enrolledCourseIds = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    // 1. Instant 0ms memory populate from RAM cache
    final cached = CartManager.cartCoursesNotifier.value;
    if (cached.isNotEmpty) {
      _cartCourses = List<Course>.from(cached);
      _isLoading = false;
    }

    CartManager.cartCoursesNotifier.addListener(_onCartNotifierChanged);
    _loadCart();
  }

  void _onCartNotifierChanged() {
    if (mounted) {
      setState(() {
        _cartCourses = List<Course>.from(CartManager.cartCoursesNotifier.value);
      });
    }
  }

  @override
  void dispose() {
    CartManager.cartCoursesNotifier.removeListener(_onCartNotifierChanged);
    super.dispose();
  }

  Future<void> _loadCart() async {
    if (_cartCourses.isEmpty) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      List<Course> coursesInCart = [];
      if (token != null && token.isNotEmpty) {
        try {
          coursesInCart = await _cartRepository.getCartItems();
        } catch (e) {
          debugPrint('Error loading DB cart: $e');
        }
      }

      if (coursesInCart.isEmpty) {
        final cartIds = await CartManager.getCartIds();
        if (cartIds.isNotEmpty) {
          final allCourses = await _repository.fetchCourses(search: '', filterType: 'ALL', difficulty: 'ALL');
          coursesInCart = allCourses.where((c) => cartIds.contains(c.id.toString())).toList();
        }
      }

      final enrolled = <String>{};
      for (final c in coursesInCart) {
        final isEnrolled = prefs.getBool('enrolled_course_id_${c.id}') ?? false;
        if (isEnrolled) {
          enrolled.add(c.id.toString());
        }
      }

      if (mounted) {
        setState(() {
          _cartCourses = coursesInCart;
          _enrolledCourseIds = enrolled;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _removeItem(int courseId) async {
    // 1. Optimistic removal (0ms lag)
    setState(() {
      _cartCourses.removeWhere((c) => c.id == courseId);
    });

    ToastHelper.show(context, LanguageManager.isVi ? 'Đã xóa khóa học khỏi giỏ hàng' : 'Removed from cart');
    await CartManager.removeFromCart(courseId);
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

  void _enrollFreeCourse(Course course) async {
    setState(() {
      _isLoading = true;
    });
    try {
      await _repository.enrollCourse(course.id);
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('enrolled_course_id_${course.id}', true);
      
      final cartIds = await CartManager.getCartIds();
      cartIds.remove(course.id.toString());
      await CartManager.setCartIds(cartIds);
      await CartManager.updateCount();
      
      if (mounted) {
        ToastHelper.showSuccess(context, LanguageManager.isVi ? 'Đăng ký khóa học thành công!' : 'Enrolled successfully!');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => CourseDetailPage(courseId: course.id),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, 'Failed to enroll: $e');
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _checkoutCart() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null || token.isEmpty) {
      if (mounted) {
        ToastHelper.show(context, LanguageManager.isVi ? 'Vui lòng đăng nhập để thực hiện thanh toán.' : 'Please log in to check out.');
        Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginPage()));
      }
      return;
    }

    final unpaidCourses = _cartCourses.where((c) => !_enrolledCourseIds.contains(c.id.toString()) && c.price > 0).toList();
    final freeCourses = _cartCourses.where((c) => !_enrolledCourseIds.contains(c.id.toString()) && c.price <= 0).toList();

    if (unpaidCourses.isEmpty && freeCourses.isEmpty) {
      ToastHelper.show(context, LanguageManager.isVi ? 'Bạn đã sở hữu tất cả khóa học trong giỏ hàng' : 'All courses in cart are already enrolled');
      return;
    }

    // Auto enroll free courses if any
    for (final freeCourse in freeCourses) {
      try {
        await _repository.enrollCourse(freeCourse.id);
        await prefs.setBool('enrolled_course_id_${freeCourse.id}', true);
      } catch (_) {}
    }

    if (unpaidCourses.isNotEmpty) {
      double totalCartPrice = 0;
      for (final c in unpaidCourses) {
        totalCartPrice += c.price;
      }
      _payPaidCourses(unpaidCourses, totalCartPrice);
    } else {
      final cartIds = await CartManager.getCartIds();
      for (final fc in freeCourses) {
        cartIds.remove(fc.id.toString());
      }
      await CartManager.setCartIds(cartIds);
      await CartManager.updateCount();
      ToastHelper.showSuccess(context, LanguageManager.isVi ? 'Đăng ký thành công các khóa học miễn phí!' : 'Free courses enrolled successfully!');
      _loadCart();
    }
  }

  void _payPaidCourses(List<Course> courses, double totalPrice) {
    final courseIds = courses.map((c) => c.id).toList();
    final title = courses.length > 1
        ? (LanguageManager.isVi ? 'Thanh toán ${courses.length} khóa học trong giỏ hàng' : 'Checkout ${courses.length} courses in cart')
        : courses.first.title;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PaymentQrDialog(
        courseIds: courseIds,
        courseTitle: title,
        price: totalPrice,
        onPaymentSuccess: () async {
          final prefs = await SharedPreferences.getInstance();
          final cartIds = await CartManager.getCartIds();

          for (final c in courses) {
            await prefs.setBool('enrolled_course_id_${c.id}', true);
            cartIds.remove(c.id.toString());
          }
          await CartManager.setCartIds(cartIds);
          await CartManager.updateCount();

          if (mounted) {
            ToastHelper.showSuccess(context, LanguageManager.isVi ? 'Thanh toán thành công! Các khóa học đã được mở khóa.' : 'Payment successful! Courses unlocked.');
            _loadCart();
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;
    final isVi = LanguageManager.isVi;

    int subtotal = 0;
    for (final c in _cartCourses) {
      subtotal += _parsePriceInt(_getCoursePrice(c));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: widget.isEmbedded ? null : SharedHeader(isDesktop: isDesktop, activeTab: ''),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 1440),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isVi ? 'Giỏ hàng của tôi' : 'Shopping Cart',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Outfit',
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isVi
                          ? 'Vui lòng kiểm tra lại các khóa học trước khi tiến hành thanh toán.'
                          : 'Please double-check your courses before checking out.',
                      style: const TextStyle(
                        fontSize: 14,
                        fontFamily: 'Outfit',
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 32),

                    _isLoading
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 80.0),
                            child: Center(child: CircularProgressIndicator(color: Color(0xFF28B79B))),
                          )
                        : _cartCourses.isEmpty
                            ? _buildEmptyState(isVi)
                            : _buildCartContent(isDesktop, isVi, subtotal),
                  ],
                ),
              ),
            ),
            SharedFooter(isDesktop: isDesktop),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isVi) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 80.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Icon(
                Icons.shopping_cart_outlined,
                size: 64,
                color: Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isVi ? 'Giỏ hàng của bạn đang trống' : 'Your cart is empty',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Outfit',
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              isVi
                  ? 'Hãy lựa chọn các khóa học tiếng Anh phù hợp để bắt đầu hành trình ôn luyện.'
                  : 'Select suitable English courses to start your learning journey.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontFamily: 'Outfit',
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF28B79B),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const ListCoursesPage()),
                );
              },
              child: Text(
                isVi ? 'Khám phá khóa học ngay' : 'Explore Courses Now',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Outfit'),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildCartContent(bool isDesktop, bool isVi, int subtotal) {
    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: _buildItemsList(isVi),
          ),
          const SizedBox(width: 32),
          Expanded(
            flex: 1,
            child: _buildSummaryCard(isVi, subtotal),
          )
        ],
      );
    } else {
      return Column(
        children: [
          _buildItemsList(isVi),
          const SizedBox(height: 28),
          _buildSummaryCard(isVi, subtotal),
        ],
      );
    }
  }

  Widget _buildItemsList(bool isVi) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _cartCourses.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final course = _cartCourses[index];
        final price = _getCoursePrice(course);

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Row(
            children: [
              // Course Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 90,
                  height: 90,
                  color: const Color(0xFFF1F5F9),
                  child: course.thumbnailUrl.isNotEmpty
                      ? Image.network(course.thumbnailUrl, fit: BoxFit.cover)
                      : const Center(child: Icon(Icons.school_rounded, color: Color(0xFF94A3B8))),
                ),
              ),
              const SizedBox(width: 16),

              // Course Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Outfit',
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${isVi ? 'Giáo viên' : 'Educator'}: ${course.creatorName}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontFamily: 'Outfit'),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      price,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Outfit',
                        color: price == 'Miễn phí' ? const Color(0xFF28B79B) : const Color(0xFF1E293B),
                      ),
                    )
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Builder(
                builder: (context) {
                  final isEnrolled = _enrolledCourseIds.contains(course.id.toString());
                  final isFree = course.price <= 0;
                  
                  if (isEnrolled) {
                    return ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CourseDetailPage(courseId: course.id),
                          ),
                        );
                      },
                      child: Text(
                        isVi ? 'Học ngay' : 'Study Now',
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                      ),
                    );
                  } else if (isFree) {
                    return ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF28B79B),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      onPressed: () => _enrollFreeCourse(course),
                      child: Text(
                        isVi ? 'Đăng ký học' : 'Enroll',
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                      ),
                    );
                  } else {
                    return const SizedBox.shrink();
                  }
                },
              ),
              const SizedBox(width: 8),
              // Delete Button
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)),
                onPressed: () => _removeItem(course.id),
                tooltip: isVi ? 'Xóa khỏi giỏ hàng' : 'Remove from cart',
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryCard(bool isVi, int subtotal) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 16,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isVi ? 'Chi tiết đơn hàng' : 'Order Summary',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'Outfit',
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 20),

          // Detailed Price breakdown
          _buildSummaryRow(
            isVi ? 'Số lượng khóa học' : 'Total Items',
            isVi ? '${_cartCourses.length} khóa học' : '${_cartCourses.length} items',
          ),
          const SizedBox(height: 12),
          _buildSummaryRow(
            isVi ? 'Tạm tính' : 'Subtotal',
            _formatPrice(subtotal),
          ),
          const SizedBox(height: 12),
          _buildSummaryRow(
            isVi ? 'Giảm giá' : 'Discount',
            '0đ',
            valueColor: const Color(0xFF10B981),
          ),
          const SizedBox(height: 16),
          const Divider(color: Color(0xFFE2E8F0)),
          const SizedBox(height: 16),
          _buildSummaryRow(
            isVi ? 'Tổng tiền' : 'Total',
            _formatPrice(subtotal),
            isBold: true,
            fontSize: 20,
            valueColor: const Color(0xFF28B79B),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF05A22),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 2,
            ),
            onPressed: _checkoutCart,
            icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
            label: Text(
              isVi ? 'Quét mã QR thanh toán' : 'Scan QR Code Checkout',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                fontFamily: 'Outfit',
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF64748B)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isVi 
                      ? 'Nút trên sẽ tự động mở VietQR PayOS để quét mã thanh toán các khóa học.'
                      : 'Button above will automatically open VietQR PayOS for your checkout.',
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                      fontFamily: 'Outfit',
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false, double fontSize = 13.5, Color valueColor = const Color(0xFF1E293B)}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            color: const Color(0xFF64748B),
            fontFamily: 'Outfit',
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w700,
            color: valueColor,
            fontFamily: 'Outfit',
          ),
        ),
      ],
    );
  }
}
