import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/repositories/course_repository.dart';
import '../../../domain/model/course.dart';
import '../../../utils/language_manager.dart';
import '../../widgets/course_card.dart';
import '../../widgets/shared_header.dart';
import '../../widgets/shared_footer.dart';
import 'list_courses_page.dart';

class WishlistPage extends StatefulWidget {
  const WishlistPage({Key? key}) : super(key: key);

  @override
  State<WishlistPage> createState() => _WishlistPageState();
}

class _WishlistPageState extends State<WishlistPage> {
  final CourseRepository _repository = CourseRepository();
  List<Course> _wishlistedCourses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWishlist();
  }

  Future<void> _loadWishlist() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final wishlistIds = prefs.getStringList('wishlisted_course_ids') ?? [];
      
      if (wishlistIds.isEmpty) {
        if (mounted) {
          setState(() {
            _wishlistedCourses = [];
            _isLoading = false;
          });
        }
        return;
      }

      // Fetch all courses and filter locally
      final allCourses = await _repository.fetchCourses(search: '', filterType: 'ALL', difficulty: 'ALL');
      final filtered = allCourses.where((c) => wishlistIds.contains(c.id.toString())).toList();

      if (mounted) {
        setState(() {
          _wishlistedCourses = filtered;
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

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;
    final isVi = LanguageManager.isVi;

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
                    // Heading Section
                    Text(
                      isVi ? 'Danh sách yêu thích' : 'My Wishlist',
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
                          ? 'Nơi lưu trữ các khóa học tiếng Anh bạn đang quan tâm và muốn học.'
                          : 'Save English courses you are interested in and plan to learn.',
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
                        : _wishlistedCourses.isEmpty
                            ? _buildEmptyState(isVi)
                            : _buildGrid(isDesktop),
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
                Icons.favorite_border_rounded,
                size: 64,
                color: Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isVi ? 'Danh sách yêu thích của bạn đang trống' : 'Your wishlist is empty',
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
                  ? 'Hãy khám phá các khóa học tiếng Anh thú vị của HanGo để bắt đầu thêm nhé!'
                  : 'Explore interesting English courses on HanGo to start adding!',
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

  Widget _buildGrid(bool isDesktop) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _wishlistedCourses.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isDesktop ? 4 : 2,
        childAspectRatio: isDesktop ? 0.76 : 0.65,
        crossAxisSpacing: 20,
        mainAxisSpacing: 24,
      ),
      itemBuilder: (context, index) {
        return TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: 1),
          duration: Duration(milliseconds: 300 + (index * 80)),
          curve: Curves.easeOutCirc,
          builder: (context, animValue, child) {
            return Transform.translate(
              offset: Offset(0, (1 - animValue) * 24),
              child: Opacity(
                opacity: animValue,
                child: child,
              ),
            );
          },
          child: CourseCard(
            course: _wishlistedCourses[index],
            onStateChanged: () {
              // Reload listing
              _loadWishlist();
            },
          ),
        );
      },
    );
  }
}
