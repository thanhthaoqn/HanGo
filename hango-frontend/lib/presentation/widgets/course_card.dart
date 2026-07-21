import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../domain/model/course.dart';
import '../../../data/repositories/course_repository.dart';
import '../../../utils/language_manager.dart';
import '../../../utils/toast_helper.dart';
import '../../../utils/cart_manager.dart';
import '../../../utils/wishlist_manager.dart';
import '../pages/course/course_detail_page.dart';

class CourseCard extends StatefulWidget {
  final Course course;
  final VoidCallback? onStateChanged;

  const CourseCard({
    Key? key,
    required this.course,
    this.onStateChanged,
  }) : super(key: key);

  @override
  State<CourseCard> createState() => _CourseCardState();
}

class _CourseCardState extends State<CourseCard> {
  bool _isHovered = false;
  bool _isInWishlist = false;
  bool _isInCart = false;
  bool _isEnrolled = false;
  bool _isLoadingEnroll = false;
  final CourseRepository _repository = CourseRepository();

  @override
  void initState() {
    super.initState();
    _loadStates();
  }

  @override
  void didUpdateWidget(covariant CourseCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadStates();
  }

  Future<void> _loadStates() async {
    final prefs = await SharedPreferences.getInstance();
    final wishlist = prefs.getStringList('wishlisted_course_ids') ?? [];
    final cart = prefs.getStringList('cart_course_ids') ?? [];
    final enrolledLocal = prefs.getBool('enrolled_course_id_${widget.course.id}') ?? false;

    if (mounted) {
      setState(() {
        _isInWishlist = wishlist.contains(widget.course.id.toString());
        _isInCart = cart.contains(widget.course.id.toString());
        _isEnrolled = enrolledLocal || (widget.course.progressPercentage > 0);
      });
    }
  }

  Future<void> _toggleWishlist() async {
    final prefs = await SharedPreferences.getInstance();
    final wishlist = prefs.getStringList('wishlisted_course_ids') ?? [];
    final courseIdStr = widget.course.id.toString();

    setState(() {
      if (_isInWishlist) {
        wishlist.remove(courseIdStr);
        _isInWishlist = false;
        ToastHelper.show(context, LanguageManager.isVi ? 'Đã xóa khỏi danh sách yêu thích' : 'Removed from wishlist');
      } else {
        wishlist.add(courseIdStr);
        _isInWishlist = true;
        ToastHelper.show(context, LanguageManager.isVi ? 'Đã thêm vào danh sách yêu thích' : 'Added to wishlist');
      }
    });

    await prefs.setStringList('wishlisted_course_ids', wishlist);
    await WishlistManager.updateCount();
    if (widget.onStateChanged != null) {
      widget.onStateChanged!();
    }
  }

  Future<void> _toggleCart() async {
    final prefs = await SharedPreferences.getInstance();
    final cart = prefs.getStringList('cart_course_ids') ?? [];
    final courseIdStr = widget.course.id.toString();

    setState(() {
      if (_isInCart) {
        cart.remove(courseIdStr);
        _isInCart = false;
        ToastHelper.show(context, LanguageManager.isVi ? 'Đã xóa khỏi giỏ hàng' : 'Removed from cart');
      } else {
        cart.add(courseIdStr);
        _isInCart = true;
        ToastHelper.show(context, LanguageManager.isVi ? 'Đã thêm vào giỏ hàng' : 'Added to cart');
      }
    });

    await prefs.setStringList('cart_course_ids', cart);
    await CartManager.updateCount();
    if (widget.onStateChanged != null) {
      widget.onStateChanged!();
    }
  }

  Future<void> _enrollFreeCourse() async {
    if (_isLoadingEnroll) return;
    setState(() {
      _isLoadingEnroll = true;
    });

    try {
      await _repository.enrollCourse(widget.course.id);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('enrolled_course_id_${widget.course.id}', true);

      if (mounted) {
        setState(() {
          _isEnrolled = true;
          _isLoadingEnroll = false;
        });
        ToastHelper.show(context, LanguageManager.isVi ? 'Đăng ký khóa học thành công!' : 'Enrolled successfully!');
        if (widget.onStateChanged != null) {
          widget.onStateChanged!();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingEnroll = false;
        });
        ToastHelper.showError(context, LanguageManager.isVi ? 'Đăng ký thất bại. Vui lòng thử lại.' : 'Enrollment failed. Please try again.');
      }
    }
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

  String _getOriginalPrice(String currentPrice) {
    if (currentPrice == 'Miễn phí') return '';
    try {
      final clean = currentPrice.replaceAll(RegExp(r'[^0-9]'), '');
      if (clean.isEmpty) return '';
      final val = double.parse(clean);
      final original = val * 1.3;
      final formatted = original.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]}.',
      );
      return '$formattedđ';
    } catch (_) {
      return '';
    }
  }

  String _getTeacherSalutation(String name) {
    final lowerName = name.toLowerCase();
    final femaleKeywords = [
      'thị', 'linh', 'thảo', 'trang', 'hoa', 'mai', 'phuong', 'huong', 'hạnh',
      'nga', 'yến', 'lan', 'nhi', 'ngọc', 'anh', 'vy', 'quỳnh', 'tuyết',
      'hồng', 'diệp', 'oanh', 'trà', 'liên', 'dung', 'huyền', 'kim', 'chi'
    ];
    for (final keyword in femaleKeywords) {
      if (lowerName.contains(keyword)) {
        return 'Ms. $name';
      }
    }
    return 'Mr. $name';
  }

  Map<String, dynamic> _getCourseCategoryTheme(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('grammar') || cat.contains('ngữ pháp')) {
      return {
        'color': const Color(0xFF0EA5E9),
        'icon': Icons.menu_book_rounded,
        'tagColor': const Color(0xFFE0F2FE),
        'textColor': const Color(0xFF0369A1),
      };
    } else if (cat.contains('reading') || cat.contains('đọc hiểu')) {
      return {
        'color': const Color(0xFF28B79B),
        'icon': Icons.chrome_reader_mode_rounded,
        'tagColor': const Color(0xFFE6FFFA),
        'textColor': const Color(0xFF137333),
      };
    } else if (cat.contains('pronunciation') || cat.contains('phát âm') || cat.contains('stress') || cat.contains('trọng âm')) {
      return {
        'color': const Color(0xFF8B5CF6),
        'icon': Icons.volume_up_rounded,
        'tagColor': const Color(0xFFF3E8FF),
        'textColor': const Color(0xFF6D28D9),
      };
    } else if (cat.contains('vocabulary') || cat.contains('từ vựng')) {
      return {
        'color': const Color(0xFFF97316),
        'icon': Icons.translate_rounded,
        'tagColor': const Color(0xFFFFF7ED),
        'textColor': const Color(0xFFC2410C),
      };
    } else {
      return {
        'color': const Color(0xFF28B79B),
        'icon': Icons.school_rounded,
        'tagColor': const Color(0xFFE6FFFA),
        'textColor': const Color(0xFF137333),
      };
    }
  }

  Widget _buildCardPlaceholder(Map<String, dynamic> theme) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme['color'] as Color, (theme['color'] as Color).withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              widget.course.category,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                fontFamily: 'Outfit',
                height: 1.3,
              ),
            ),
          ),
          Positioned(
            bottom: -15,
            right: -10,
            child: Icon(
              theme['icon'] as IconData,
              size: 80,
              color: Colors.white.withOpacity(0.15),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isVi = LanguageManager.isVi;
    final theme = _getCourseCategoryTheme(widget.course.category);
    final priceStr = _getCoursePrice(widget.course);
    final originalPriceStr = _getOriginalPrice(priceStr);
    final isFree = priceStr == 'Miễn phí';
    final displayPrice = isFree ? (isVi ? 'Miễn phí' : 'Free') : priceStr;
    final teacherName = _getTeacherSalutation(widget.course.creatorName);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CourseDetailPage(courseId: widget.course.id),
            ),
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: _isHovered
              ? (Matrix4.identity()
                  ..translate(0, -6, 0)
                  ..scale(1.02))
              : Matrix4.identity(),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isHovered ? const Color(0xFF28B79B) : const Color(0xFFE5E7EB),
              width: _isHovered ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: _isHovered ? const Color(0x1A28B79B) : const Color(0x0A000000),
                blurRadius: _isHovered ? 12 : 6,
                offset: _isHovered ? const Offset(0, 8) : const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image / Thumbnail Section
            Stack(
              children: [
                Container(
                  height: 140,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                    child: widget.course.thumbnailUrl.isNotEmpty
                        ? Image.network(
                            widget.course.thumbnailUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                _buildCardPlaceholder(theme),
                          )
                        : _buildCardPlaceholder(theme),
                  ),
                ),

                // Free badge
                if (isFree)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF97316),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isVi ? 'MIỄN PHÍ' : 'FREE',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Outfit',
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            // Card Body details
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.course.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                        fontFamily: 'Outfit',
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      teacherName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        fontFamily: 'Outfit',
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          widget.course.stars.toStringAsFixed(1).replaceAll('.', ','),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFB45309),
                            fontFamily: 'Outfit',
                          ),
                        ),
                        const SizedBox(width: 4),
                        Row(
                          children: List.generate(5, (index) {
                            return Icon(
                              Icons.star_rounded,
                              size: 14,
                              color: index < widget.course.stars.floor()
                                  ? const Color(0xFFF59E0B)
                                  : const Color(0xFFE2E8F0),
                            );
                          }),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '(${widget.course.learnerCount})',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                            fontFamily: 'Outfit',
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),

                    // Price display
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          displayPrice,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isFree ? const Color(0xFF28B79B) : const Color(0xFF0F172A),
                            fontFamily: 'Outfit',
                          ),
                        ),
                        if (!isFree) ...[
                          const SizedBox(width: 8),
                          Text(
                            originalPriceStr,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF94A3B8),
                              decoration: TextDecoration.lineThrough,
                              fontFamily: 'Outfit',
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildActionButton(bool isVi) {
    if (_isEnrolled) {
      return SizedBox(
        width: double.infinity,
        height: 36,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFF28B79B)),
            foregroundColor: const Color(0xFF28B79B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: EdgeInsets.zero,
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CourseDetailPage(courseId: widget.course.id),
              ),
            );
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF28B79B)),
              const SizedBox(width: 6),
              Text(
                isVi ? 'Vào học ngay' : 'Learn Now',
                style: const TextStyle(fontSize: 12, fontFamily: 'Outfit', fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
    }

    final priceStr = _getCoursePrice(widget.course);
    final isFree = priceStr == 'Miễn phí';

    if (isFree) {
      return SizedBox(
        width: double.infinity,
        height: 36,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF28B79B),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: EdgeInsets.zero,
          ),
          onPressed: _isLoadingEnroll ? null : _enrollFreeCourse,
          child: _isLoadingEnroll
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(
                  isVi ? 'Đăng ký miễn phí' : 'Enroll Free',
                  style: const TextStyle(fontSize: 12, fontFamily: 'Outfit', fontWeight: FontWeight.bold),
                ),
        ),
      );
    }

    // For paid courses, show Buy Now & Cart icon side by side
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 36,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF28B79B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: EdgeInsets.zero,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CourseDetailPage(courseId: widget.course.id),
                  ),
                );
              },
              child: Text(
                isVi ? 'Mua ngay' : 'Buy Now',
                style: const TextStyle(fontSize: 12, fontFamily: 'Outfit', fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          height: 36,
          width: 36,
          decoration: BoxDecoration(
            color: _isInCart ? const Color(0xFFE6FFFA) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _isInCart ? const Color(0xFF28B79B) : Colors.transparent,
              width: _isInCart ? 1.2 : 0,
            ),
          ),
          child: IconButton(
            icon: Icon(
              _isInCart ? Icons.shopping_bag_rounded : Icons.add_shopping_cart_rounded,
              size: 16,
              color: _isInCart ? const Color(0xFF28B79B) : const Color(0xFF475569),
            ),
            padding: EdgeInsets.zero,
            onPressed: _toggleCart,
          ),
        ),
      ],
    );
  }
}
