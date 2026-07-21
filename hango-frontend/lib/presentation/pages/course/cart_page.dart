import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/repositories/course_repository.dart';
import '../../../domain/model/course.dart';
import '../../../utils/language_manager.dart';
import '../../../utils/toast_helper.dart';
import '../../../utils/cart_manager.dart';
import '../../widgets/shared_header.dart';
import '../../widgets/shared_footer.dart';
import 'list_courses_page.dart';
import 'course_detail_page.dart';
import '../../widgets/payment_qr_dialog.dart';

class CartPage extends StatefulWidget {
  const CartPage({Key? key}) : super(key: key);

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final CourseRepository _repository = CourseRepository();
  List<Course> _cartCourses = [];
  Set<String> _enrolledCourseIds = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCart();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadCart() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final cartIds = prefs.getStringList('cart_course_ids') ?? [];
      
      if (cartIds.isEmpty) {
        if (mounted) {
          setState(() {
            _cartCourses = [];
            _enrolledCourseIds = {};
            _isLoading = false;
          });
        }
        return;
      }

      final allCourses = await _repository.fetchCourses(search: '', filterType: 'ALL', difficulty: 'ALL');
      final filtered = allCourses.where((c) => cartIds.contains(c.id.toString())).toList();

      final enrolled = <String>{};
      for (final c in filtered) {
        final isEnrolled = prefs.getBool('enrolled_course_id_${c.id}') ?? false;
        if (isEnrolled) {
          enrolled.add(c.id.toString());
        }
      }

      if (mounted) {
        setState(() {
          _cartCourses = filtered;
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
    final prefs = await SharedPreferences.getInstance();
    final cartIds = prefs.getStringList('cart_course_ids') ?? [];
    cartIds.remove(courseId.toString());
    await prefs.setStringList('cart_course_ids', cartIds);
    await CartManager.updateCount();
    
    ToastHelper.show(context, LanguageManager.isVi ? 'Đã xóa khóa học khỏi giỏ hàng' : 'Removed from cart');
    _loadCart();
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
      
      final cartIds = prefs.getStringList('cart_course_ids') ?? [];
      cartIds.remove(course.id.toString());
      await prefs.setStringList('cart_course_ids', cartIds);
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

  void _payPaidCourse(Course course) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PaymentQrDialog(
        courseId: course.id,
        courseTitle: course.title,
        price: course.price,
        onPaymentSuccess: () async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('enrolled_course_id_${course.id}', true);
          
          final cartIds = prefs.getStringList('cart_course_ids') ?? [];
          cartIds.remove(course.id.toString());
          await prefs.setStringList('cart_course_ids', cartIds);
          await CartManager.updateCount();
          
          if (mounted) {
            ToastHelper.showSuccess(context, LanguageManager.isVi ? 'Thanh toán thành công! Khóa học đã được mở khóa.' : 'Payment successful! Course unlocked.');
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => CourseDetailPage(courseId: course.id),
              ),
            );
          }
        },
      ),
    );
  }

  void _checkout() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF28B79B), size: 28),
            const SizedBox(width: 10),
            Text(
              LanguageManager.isVi ? 'Thanh toán thành công' : 'Checkout Successful',
              style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          LanguageManager.isVi
              ? 'Chúc mừng bạn đã sở hữu các khóa học. Hãy bắt đầu chinh phục tiếng Anh ngay hôm nay!'
              : 'Congratulations! You now own these courses. Let\'s start conquering English today!',
          style: const TextStyle(fontFamily: 'Outfit', fontSize: 14),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF28B79B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              
              // Clear cart in local storage
              final prefs = await SharedPreferences.getInstance();
              
              // Also auto-enroll them in these courses locally
              for (final c in _cartCourses) {
                await prefs.setBool('enrolled_course_id_${c.id}', true);
              }
              
              await prefs.setStringList('cart_course_ids', []);
              await CartManager.updateCount();
              
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const ListCoursesPage()),
                );
              }
            },
            child: Text(
              LanguageManager.isVi ? 'Vào học ngay' : 'Learn Now',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          )
        ],
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
    int discount = (subtotal * _discountPercentage).round();
    int total = subtotal - discount;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: SharedHeader(isDesktop: isDesktop, activeTab: ''),
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
                            : _buildCartContent(isDesktop, isVi, subtotal, discount, total),
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

  Widget _buildCartContent(bool isDesktop, bool isVi, int subtotal, int discount, int total) {
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
            child: _buildSummaryCard(isVi, subtotal, discount, total),
          )
        ],
      );
    } else {
      return Column(
        children: [
          _buildItemsList(isVi),
          const SizedBox(height: 28),
          _buildSummaryCard(isVi, subtotal, discount, total),
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
                    return ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF05A22),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      onPressed: () => _payPaidCourse(course),
                      child: Text(
                        isVi ? 'Thanh toán' : 'Checkout',
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                      ),
                    );
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

  Widget _buildSummaryCard(bool isVi, int subtotal, int discount, int total) {
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

          // Price rows
          _buildSummaryRow(
            isVi ? 'Tổng tiền' : 'Total',
            _formatPrice(subtotal),
            isBold: true,
            fontSize: 18,
            valueColor: const Color(0xFF28B79B),
          ),
          const SizedBox(height: 20),
          Text(
            isVi 
              ? '* Vui lòng chọn đăng ký học hoặc thanh toán cho từng khóa học ở danh sách bên cạnh.'
              : '* Please enroll or pay for each course individually in the list.',
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 12,
              fontFamily: 'Outfit',
              fontStyle: FontStyle.italic,
              height: 1.4,
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
