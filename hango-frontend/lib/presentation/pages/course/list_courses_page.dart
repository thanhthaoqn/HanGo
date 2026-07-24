import 'package:flutter/material.dart';
import 'dart:ui';
import '../../../data/repositories/course_repository.dart';
import '../../../domain/model/course.dart';
import '../../../utils/language_manager.dart';
import '../../widgets/course_card.dart';
import '../../widgets/shared_header.dart';
import '../../widgets/shared_footer.dart';
import '../learner/learner_home_page.dart';
import 'course_detail_page.dart';

class ListCoursesPage extends StatefulWidget {
  const ListCoursesPage({Key? key}) : super(key: key);

  @override
  State<ListCoursesPage> createState() => _ListCoursesPageState();
}

class _ListCoursesPageState extends State<ListCoursesPage> {
  final CourseRepository _repository = CourseRepository();
  late Future<List<Course>> _coursesFuture;

  String _searchQuery = '';
  String _filterType = 'All'; // All, Free, Paid
  String _difficulty = 'All'; // All, Basic, Intermediate, Advanced
  String _ratingFilter = 'All'; // All, 4.5, 4.0, 3.5
  String _priceSort = 'All'; // All, LowToHigh, HighToLow
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchCourses();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  double _getCoursePriceNumeric(Course course) {
    final title = course.title.toLowerCase();
    if (title.contains('ngữ pháp') || title.contains('grammar') || course.id % 4 == 0) {
      return 0.0;
    }
    final prices = [699000.0, 899000.0, 1290000.0, 1500000.0];
    return prices[course.id % prices.length];
  }

  void _fetchCourses() {
    String backendDifficulty = 'ALL';
    if (_difficulty == 'Basic') backendDifficulty = 'BASIC';
    if (_difficulty == 'Intermediate') backendDifficulty = 'INTERMEDIATE';
    if (_difficulty == 'Advanced') backendDifficulty = 'ADVANCED';

    setState(() {
      _coursesFuture = _repository.fetchCourses(
        search: _searchQuery,
        filterType: 'ALL',
        difficulty: backendDifficulty,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;
    final isVi = LanguageManager.isVi;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: SharedHeader(isDesktop: isDesktop, activeTab: 'Courses'),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            _buildPremiumHero(isVi),
            Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 1440),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFiltersPanel(isVi, isDesktop),
                    const SizedBox(height: 12),
                    _buildGrid(isVi),
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

  Widget _buildPremiumHero(bool isVi) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF135D4E),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.zero,
        child: Stack(
          children: [
            // Layer 1: Background Image (Courses premium study theme)
            Positioned.fill(
              child: Image.network(
                'https://images.unsplash.com/photo-1524995997946-a1c2e315a42f?q=80&w=1200',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: const Color(0xFF135D4E),
                ),
              ),
            ),

            // Layer 2: Dark Overlay Gradient (matching homepage hero)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withOpacity(0.85),
                      Colors.black.withOpacity(0.55),
                      Colors.black.withOpacity(0.2),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
              ),
            ),
            // Floating Neon Mesh Orbs for Wow factor
            Positioned(
              right: -80,
              top: -60,
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF28B79B).withOpacity(0.22),
                      const Color(0xFF28B79B).withOpacity(0),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 100,
              bottom: -100,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF10B981).withOpacity(0.18),
                      const Color(0xFF10B981).withOpacity(0),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: 180,
              bottom: 40,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFF97316).withOpacity(0.10),
                      const Color(0xFFF97316).withOpacity(0),
                    ],
                  ),
                ),
              ),
            ),

            // Content Container
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 56.0, vertical: 56.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Glassmorphic tag
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.12)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.bolt, color: Color(0xFF28B79B), size: 14),
                        const SizedBox(width: 6),
                        Text(
                          isVi ? 'KHÓA HỌC CHUYÊN SÂU' : 'ELITE COURSES',
                          style: const TextStyle(
                            color: Color(0xFF28B79B),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                            fontFamily: 'Outfit',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Rich Gradient Heading
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFF32D3A7), Color(0xFF10B981), Color(0xFFA7F3D0)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ).createShader(bounds),
                    child: Text(
                      isVi 
                        ? 'Chinh Phục Đỉnh Cao Tiếng Anh THPT' 
                        : 'Conquer the English High School Exams',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Outfit',
                        height: 1.25,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isVi 
                      ? 'Kho bài giảng cấu trúc khoa học bởi đội ngũ giáo viên giàu kinh nghiệm, kết hợp với lộ trình thông minh và trợ lý học tập AI cá nhân hóa.' 
                      : 'An expertly structured learning path designed by veteran educators, enhanced by smart recommendations and personalized AI mentoring.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.75),
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      height: 1.6,
                      fontFamily: 'Outfit',
                    ),
                  ),
                  const SizedBox(height: 36),
                  // Glassmorphic Stats Section
                  Wrap(
                    spacing: 24,
                    runSpacing: 16,
                    children: [
                      _buildGlassStat(40000, isVi ? 'Học sinh đang học' : 'Active students', Icons.people_rounded),
                      _buildGlassStat(50, isVi ? 'Bài thi luyện tập' : 'Mock exams available', Icons.assignment_turned_in_rounded),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassStat(int target, String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF28B79B).withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFF28B79B), size: 18),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedCounter(
                targetValue: target,
                suffix: '+',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Outfit',
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  fontFamily: 'Outfit',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersPanel(bool isVi, bool isDesktop) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
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
          // Elegant glowing search bar
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      _searchQuery = value;
                    },
                    onSubmitted: (value) {
                      _fetchCourses();
                    },
                    style: const TextStyle(fontFamily: 'Outfit', fontSize: 14, fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      hintText: isVi ? 'Tìm kiếm bài học, giáo viên, từ khóa...' : 'Search lessons, educators, keywords...',
                      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF94A3B8)),
                    onPressed: () {
                      setState(() {
                        _searchController.clear();
                        _searchQuery = '';
                      });
                      _fetchCourses();
                    },
                  ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF28B79B),
                    minimumSize: const Size(100, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _fetchCourses,
                  child: Text(
                    isVi ? 'Tìm kiếm' : 'Search',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Outfit'),
                  ),
                )
              ],
            ),
          ),
          const SizedBox(height: 24),

          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              SizedBox(
                width: isDesktop ? 220 : double.infinity,
                child: _buildDropdownFilter<String>(
                  label: isVi ? 'Độ khó' : 'Difficulty',
                  value: _difficulty,
                  icon: Icons.signal_cellular_alt_rounded,
                  items: [
                    DropdownMenuItem(value: 'All', child: Text(isVi ? 'Tất cả độ khó' : 'All levels')),
                    DropdownMenuItem(value: 'Basic', child: Text(isVi ? 'Cơ bản' : 'Basic')),
                    DropdownMenuItem(value: 'Intermediate', child: Text(isVi ? 'Trung cấp' : 'Intermediate')),
                    DropdownMenuItem(value: 'Advanced', child: Text(isVi ? 'Nâng cao' : 'Advanced')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _difficulty = val;
                        _fetchCourses();
                      });
                    }
                  },
                ),
              ),
              SizedBox(
                width: isDesktop ? 220 : double.infinity,
                child: _buildDropdownFilter<String>(
                  label: isVi ? 'Hình thức' : 'Fee Type',
                  value: _filterType,
                  icon: Icons.account_balance_wallet_rounded,
                  items: [
                    DropdownMenuItem(value: 'All', child: Text(isVi ? 'Tất cả hình thức' : 'All types')),
                    DropdownMenuItem(value: 'Free', child: Text(isVi ? 'Miễn phí' : 'Free')),
                    DropdownMenuItem(value: 'Paid', child: Text(isVi ? 'Có phí (Trả phí)' : 'Paid')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _filterType = val;
                        _fetchCourses();
                      });
                    }
                  },
                ),
              ),
              SizedBox(
                width: isDesktop ? 220 : double.infinity,
                child: _buildDropdownFilter<String>(
                  label: isVi ? 'Đánh giá' : 'Star Rating',
                  value: _ratingFilter,
                  icon: Icons.star_rounded,
                  items: [
                    DropdownMenuItem(value: 'All', child: Text(isVi ? 'Tất cả đánh giá' : 'All ratings')),
                    DropdownMenuItem(value: '4.5', child: Text(isVi ? '4,5⭐ trở lên' : '4.5⭐ & above')),
                    DropdownMenuItem(value: '4.0', child: Text(isVi ? '4,0⭐ trở lên' : '4.0⭐ & above')),
                    DropdownMenuItem(value: '3.5', child: Text(isVi ? '3,5⭐ trở lên' : '3.5⭐ & above')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _ratingFilter = val;
                      });
                    }
                  },
                ),
              ),
              SizedBox(
                width: isDesktop ? 220 : double.infinity,
                child: _buildDropdownFilter<String>(
                  label: isVi ? 'Giá tiền' : 'Price Sort',
                  value: _priceSort,
                  icon: Icons.unfold_more_rounded,
                  items: [
                    DropdownMenuItem(value: 'All', child: Text(isVi ? 'Mặc định' : 'Default sorting')),
                    DropdownMenuItem(value: 'LowToHigh', child: Text(isVi ? 'Giá thấp đến cao' : 'Price: Low to High')),
                    DropdownMenuItem(value: 'HighToLow', child: Text(isVi ? 'Giá cao xuống thấp' : 'Price: High to Low')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _priceSort = val;
                      });
                    }
                  },
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildDropdownFilter<T>({
    required String label,
    required T value,
    required IconData icon,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: const Color(0xFF64748B)),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF475569),
                fontFamily: 'Outfit',
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              items: items,
              onChanged: onChanged,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
              style: const TextStyle(
                fontFamily: 'Outfit',
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
              dropdownColor: Colors.white,
              isExpanded: true,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGrid(bool isVi) {
    final isDesktop = MediaQuery.of(context).size.width > 900;
    return FutureBuilder<List<Course>>(
      future: _coursesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 60.0),
            child: Center(child: CircularProgressIndicator(color: Color(0xFF28B79B))),
          );
        } else if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 40.0),
            child: Center(
              child: Text(
                isVi ? 'Lỗi tải danh sách: ${snapshot.error}' : 'Error: ${snapshot.error}',
                style: const TextStyle(fontFamily: 'Outfit', color: Colors.red),
              ),
            ),
          );
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 60.0),
            child: Center(
              child: Text(
                isVi ? 'Không tìm thấy khóa học nào.' : 'No courses found.',
                style: const TextStyle(fontFamily: 'Outfit', fontSize: 16, color: Color(0xFF64748B)),
              ),
            ),
          );
        }

        final courses = snapshot.data!;

        // 0. Local filtering to exclude IELTS, TOEIC, Giao tiếp, and Certification courses
        List<Course> filteredCourses = courses.where((c) {
          final title = c.title.toLowerCase();
          final cat = c.category.toLowerCase();
          return !title.contains('ielts') && !title.contains('toeic') && 
                 !title.contains('giao tiếp') && !title.contains('communication') &&
                 !title.contains('chứng chỉ') && !cat.contains('ielts') && 
                 !cat.contains('toeic') && !cat.contains('giao tiếp') && 
                 !cat.contains('communication') && !cat.contains('chứng chỉ');
        }).toList();

        // 1. Filter by Fee Type
        if (_filterType == 'Free') {
          filteredCourses = filteredCourses.where((c) {
            final price = _getCoursePriceNumeric(c);
            return price == 0.0;
          }).toList();
        } else if (_filterType == 'Paid') {
          filteredCourses = filteredCourses.where((c) {
            final price = _getCoursePriceNumeric(c);
            return price > 0.0;
          }).toList();
        }

        // 2. Filter by Rating
        if (_ratingFilter == '4.5') {
          filteredCourses = filteredCourses.where((c) => c.stars >= 4.5).toList();
        } else if (_ratingFilter == '4.0') {
          filteredCourses = filteredCourses.where((c) => c.stars >= 4.0).toList();
        } else if (_ratingFilter == '3.5') {
          filteredCourses = filteredCourses.where((c) => c.stars >= 3.5).toList();
        }

        // 3. Sort by Price
        if (_priceSort == 'LowToHigh') {
          filteredCourses.sort((a, b) => _getCoursePriceNumeric(a).compareTo(_getCoursePriceNumeric(b)));
        } else if (_priceSort == 'HighToLow') {
          filteredCourses.sort((a, b) => _getCoursePriceNumeric(b).compareTo(_getCoursePriceNumeric(a)));
        }

        if (filteredCourses.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 60.0),
            child: Center(
              child: Text(
                isVi ? 'Không tìm thấy khóa học nào phù hợp với bộ lọc.' : 'No matching courses found.',
                style: const TextStyle(fontFamily: 'Outfit', fontSize: 15, color: Color(0xFF64748B)),
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24.0),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredCourses.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isDesktop ? 4 : 2,
              childAspectRatio: isDesktop ? 0.85 : 0.85,
              crossAxisSpacing: 20,
              mainAxisSpacing: 24,
            ),
            itemBuilder: (context, index) {
              return TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: 1),
                duration: Duration(milliseconds: 350 + (index * 80)),
                curve: Curves.easeOutCirc,
                builder: (context, animValue, child) {
                  return Transform.translate(
                    offset: Offset(0, (1 - animValue) * 28),
                    child: Opacity(
                      opacity: animValue,
                      child: child,
                    ),
                  );
                },
                child: CourseCard(
                  course: filteredCourses[index],
                  onStateChanged: () {
                    setState(() {});
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// Animated Counter widget
class AnimatedCounter extends StatefulWidget {
  final int targetValue;
  final String suffix;
  final TextStyle style;

  const AnimatedCounter({
    Key? key,
    required this.targetValue,
    required this.suffix,
    required this.style,
  }) : super(key: key);

  @override
  State<AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<AnimatedCounter> with SingleTickerProviderStateMixin {
  late Animation<double> _animation;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: widget.targetValue.toDouble()).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutQuad),
    )..addListener(() {
        setState(() {});
      });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final valueInt = _animation.value.round();
    String formatted = valueInt.toString();
    if (valueInt >= 1000) {
      formatted = valueInt.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.');
    }
    return Text(
      '$formatted${widget.suffix}',
      style: widget.style,
    );
  }
}
