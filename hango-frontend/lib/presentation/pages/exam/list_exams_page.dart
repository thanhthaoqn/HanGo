import 'package:flutter/material.dart';
import 'dart:ui';
import '../../../data/repositories/exam_repository.dart';
import '../../../domain/entities/exam.dart';
import '../../../utils/language_manager.dart';
import '../../widgets/exam_card.dart';
import '../../widgets/shared_header.dart';
import '../../widgets/shared_footer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../learner/learner_home_page.dart';

class ListExamsPage extends StatefulWidget {
  const ListExamsPage({Key? key}) : super(key: key);

  @override
  State<ListExamsPage> createState() => _ListExamsPageState();
}

class _ListExamsPageState extends State<ListExamsPage> {
  final ExamRepository _repository = ExamRepository();
  late Future<List<dynamic>> _dataFuture;

  String _searchQuery = '';
  String _examTypeFilter = 'All'; // All, Mock, Quiz
  String _durationFilter = 'All'; // All, 15m, 60m
  String _statusFilter = 'All'; // All, Completed, Not Started
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadData() {
    _dataFuture = _fetchData();
  }

  Future<List<dynamic>> _fetchData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    
    final examsFuture = _repository.fetchExams(status: 'All');
    final attemptsFuture = token != null
        ? _repository.fetchMyExamAttempts()
        : Future.value(<Map<String, dynamic>>[]);
        
    return Future.wait([examsFuture, attemptsFuture]);
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;
    final isVi = LanguageManager.isVi;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: SharedHeader(isDesktop: isDesktop, activeTab: 'Exams'),
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
            // Layer 1: Background Image (Exams premium academic theme)
            Positioned.fill(
              child: Image.network(
                'https://images.unsplash.com/photo-1427504494785-3a9ca7044f45?q=80&w=1200',
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
            // Floating Neon Mesh Orbs
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
                        const Icon(Icons.verified_user_rounded, color: Color(0xFF28B79B), size: 14),
                        const SizedBox(width: 6),
                        Text(
                          isVi ? 'PHÒNG LUYỆN THI CHUẨN HÓA' : 'STANDARDIZED EXAM HALL',
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
                        ? 'Đánh Giá Năng Lực & Luyện Đề THPT' 
                        : 'Practice Standardized Exams & Quizzes',
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
                      ? 'Luyện tập với kho đề thi cập nhật thường xuyên, căn giờ tự động giống thi thật, chấm điểm chính xác và phân tích điểm yếu tức thì.' 
                      : 'Sharpen your skills with real-time timers matching official guidelines, automated grading, and diagnostic analysis of your weaknesses.',
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
                      _buildGlassStat(40000, isVi ? 'Lượt làm bài thi' : 'Exams completed', Icons.military_tech_rounded),
                      _buildGlassStat(50, isVi ? 'Đề thi phong phú' : 'Awesome mock tests', Icons.assignment_rounded),
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
          // Elegant search bar
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
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                    style: const TextStyle(fontFamily: 'Outfit', fontSize: 14, fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      hintText: isVi ? 'Tìm kiếm đề thi thử, bài trắc nghiệm chuyên đề...' : 'Search mock exams, topic tests...',
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
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              SizedBox(
                width: isDesktop ? 280 : double.infinity,
                child: _buildDropdownFilter<String>(
                  label: isVi ? 'Loại hình đề thi' : 'Exam Type',
                  value: _examTypeFilter,
                  icon: Icons.workspace_premium_rounded,
                  items: [
                    DropdownMenuItem(value: 'All', child: Text(isVi ? 'Tất cả loại đề' : 'All types')),
                    DropdownMenuItem(value: 'Mock', child: Text(isVi ? 'Đề thi thử THPT' : 'Mock Exams')),
                    DropdownMenuItem(value: 'Quiz', child: Text(isVi ? 'Trắc nghiệm chuyên đề' : 'Topic Quizzes')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _examTypeFilter = val;
                      });
                    }
                  },
                ),
              ),
              SizedBox(
                width: isDesktop ? 280 : double.infinity,
                child: _buildDropdownFilter<String>(
                  label: isVi ? 'Thời gian làm bài' : 'Duration Limit',
                  value: _durationFilter,
                  icon: Icons.av_timer_rounded,
                  items: [
                    DropdownMenuItem(value: 'All', child: Text(isVi ? 'Tất cả thời gian' : 'All durations')),
                    DropdownMenuItem(value: '15m', child: Text(isVi ? 'Đề ngắn (15-30p)' : 'Short (15-30m)')),
                    DropdownMenuItem(value: '60m', child: Text(isVi ? 'Đề chuẩn (60p)' : 'Standard (60m)')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _durationFilter = val;
                      });
                    }
                  },
                ),
              ),
            ],
          ),
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
    return FutureBuilder<List<dynamic>>(
      future: _dataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 60.0),
            child: Center(child: CircularProgressIndicator(color: Color(0xFF28B79B))),
          );
        } else if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 40.0),
            child: Center(child: Text(isVi ? 'Lỗi tải danh sách: ${snapshot.error}' : 'Error: ${snapshot.error}', style: const TextStyle(fontFamily: 'Outfit', color: Colors.red))),
          );
        } else if (!snapshot.hasData) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 60.0),
            child: Center(child: Text(isVi ? 'Không tìm thấy đề thi nào.' : 'No exams found.', style: const TextStyle(fontFamily: 'Outfit', fontSize: 16, color: Color(0xFF64748B)))),
          );
        }

        final List<Exam> allExams = snapshot.data![0] as List<Exam>;
        final List<Map<String, dynamic>> attempts = (snapshot.data![1] as List<dynamic>).map((e) => Map<String, dynamic>.from(e)).toList();

        // 1. Search Query filter (local)
        List<Exam> filteredExams = allExams;
        if (_searchQuery.trim().isNotEmpty) {
          final query = _searchQuery.toLowerCase();
          filteredExams = allExams.where((e) {
            return e.title.toLowerCase().contains(query) || e.description.toLowerCase().contains(query);
          }).toList();
        }

        // 2. Exam Type Filter (local)
        if (_examTypeFilter == 'Mock') {
          filteredExams = filteredExams.where((e) {
            final title = e.title.toLowerCase();
            return title.contains('mock') || title.contains('graduation') || title.contains('thpt') || title.contains('minh họa') || title.contains('minh hoa');
          }).toList();
        } else if (_examTypeFilter == 'Quiz') {
          filteredExams = filteredExams.where((e) {
            final title = e.title.toLowerCase();
            return title.contains('quiz') || title.contains('15-minute') || title.contains('chuyên đề') || title.contains('topic');
          }).toList();
        }

        // 3. Duration Filter (local)
        if (_durationFilter == '15m') {
          filteredExams = filteredExams.where((e) => e.durationMinutes <= 30).toList();
        } else if (_durationFilter == '60m') {
          filteredExams = filteredExams.where((e) => e.durationMinutes > 30).toList();
        }

        // 4. Attempt status Filter (local) - status filter is removed from UI, so we do nothing if it's All

        if (filteredExams.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 60.0),
            child: Center(
              child: Text(
                isVi ? 'Không tìm thấy đề thi phù hợp.' : 'No matching exams found.',
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
            itemCount: filteredExams.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isDesktop ? 4 : 2,
              childAspectRatio: isDesktop ? 1.25 : 0.85,
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
                child: ExamCard(exam: filteredExams[index]),
              );
            },
          ),
        );
      },
    );
  }
}

// Animated Counter
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
