import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../utils/toast_helper.dart';
import 'package:hango/presentation/widgets/internal_app_header.dart';
import '../../widgets/course_manager_sidebar.dart';
import '../../../data/services/course_manager_api.dart';
import '../../../data/models/course_manager_dashboard_summary.dart';

// Helper for Elegant Claymorphism Card
class ElegantCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color backgroundColor;
  final double borderRadius;
  final Color borderColor;
  final double borderWidth;
  final VoidCallback? onTap;

  const ElegantCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.backgroundColor = Colors.white,
    this.borderRadius = 16.0,
    this.borderColor = const Color(0xFFF1F5F9),
    this.borderWidth = 1.0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000), // Very soft shadow for luxury feel
            offset: Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: child,
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: content,
      );
    }
    return content;
  }
}

// Elegant Bouncy Button
class ElegantBouncyButton extends StatefulWidget {
  final VoidCallback onTap;
  final Widget child;
  final Color backgroundColor;
  final Color borderColor;

  const ElegantBouncyButton({
    super.key,
    required this.onTap,
    required this.child,
    this.backgroundColor = Colors.white,
    this.borderColor = const Color(0xFFF1F5F9),
  });

  @override
  State<ElegantBouncyButton> createState() => _ElegantBouncyButtonState();
}

class _ElegantBouncyButtonState extends State<ElegantBouncyButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            decoration: BoxDecoration(
              color: widget.backgroundColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: widget.borderColor, width: 1.0),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x06000000),
                  offset: Offset(0, 2),
                  blurRadius: 8,
                ),
              ],
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class CourseManagerDashboardPage extends StatefulWidget {
  const CourseManagerDashboardPage({super.key});

  @override
  State<CourseManagerDashboardPage> createState() =>
      _CourseManagerDashboardPageState();
}

class _CourseManagerDashboardPageState extends State<CourseManagerDashboardPage> {
  final _api = CourseManagerApi();
  CourseManagerDashboardSummary? _summary;
  List<CourseReviewCourse>? _pendingCourses;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final summaryFuture = _api.getDashboardSummary();
      final coursesFuture = _api.getReviewCourses(status: 'PENDING');
      
      final results = await Future.wait([summaryFuture, coursesFuture]);
      
      if (mounted) {
        setState(() {
          _summary = results[0] as CourseManagerDashboardSummary;
          _pendingCourses = results[1] as List<CourseReviewCourse>;
          
          // Sort by submittedAt descending (newest first)
          _pendingCourses?.sort((a, b) {
            if (a.submittedAt == null && b.submittedAt == null) return 0;
            if (a.submittedAt == null) return 1;
            if (b.submittedAt == null) return -1;
            return b.submittedAt!.compareTo(a.submittedAt!);
          });
          
          // Take top 5 for dashboard
          if (_pendingCourses != null && _pendingCourses!.length > 5) {
            _pendingCourses = _pendingCourses!.sublist(0, 5);
          }
          
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ToastHelper.showError(context, 'Lỗi tải dữ liệu: $e');
      }
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 18) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 1024;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Clean, light background
      appBar: InternalAppHeader(isMobile: !(isDesktop), activeTab: '',),
      drawer: !isDesktop
          ? const Drawer(child: CourseManagerSidebar(currentRoute: 'dashboard'))
          : null,
      body: Row(
        children: [
          if (isDesktop)
            const SizedBox(
              width: 240,
              child: CourseManagerSidebar(currentRoute: 'dashboard'),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF0D9488)))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildWelcomeHeader(context, isDesktop),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildMetricCards(
                                constraints: BoxConstraints(maxWidth: size.width),
                              ),
                              const SizedBox(height: 24),
                              _buildCourseDistributionBar(),
                              const SizedBox(height: 24),
                              _buildQuickActions(context, useRow: size.width > 768),
                              const SizedBox(height: 24),
                              _buildRecentPendingCourses(context),
                              const SizedBox(height: 48),
                            ],
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

  Widget _buildWelcomeHeader(BuildContext context, bool isDesktop) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (!isDesktop) ...[
            IconButton(
              icon: const Icon(Icons.menu, color: Color(0xFF4B5563)),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getGreeting(),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                    fontFamily: 'Fira Sans',
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Manager Dashboard',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                    fontFamily: 'Fira Sans',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCards({required BoxConstraints constraints}) {
    final useRow = constraints.maxWidth > 1024;
    final useTwoColumns = constraints.maxWidth > 600 && constraints.maxWidth <= 1024;

    final usersCount = _summary?.registeredUsersCount ?? 0;
    final activeCourses = _summary?.activeCoursesCount ?? 0;
    final inactiveCourses = _summary?.inactiveCoursesCount ?? 0;
    final totalCourses = activeCourses + inactiveCourses;
    final examsCount = _summary?.examsCount ?? 0;

    final cards = [
      _buildElegantCard(
        title: 'REGISTERED USERS',
        value: '$usersCount',
        icon: Icons.people_rounded,
        primaryColor: const Color(0xFF0D9488),
        bgColor: const Color(0xFFF0FDFA),
      ),
      _buildElegantCard(
        title: 'TOTAL COURSES',
        value: '$totalCourses',
        icon: Icons.school_rounded,
        primaryColor: const Color(0xFFF97316),
        bgColor: const Color(0xFFFFF7ED),
      ),
      _buildElegantCard(
        title: 'TOTAL EXAMS',
        value: '$examsCount',
        icon: Icons.assignment_rounded,
        primaryColor: const Color(0xFF3B82F6),
        bgColor: const Color(0xFFEFF6FF),
      ),
    ];

    if (useRow) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: cards[0]),
          const SizedBox(width: 20),
          Expanded(child: cards[1]),
          const SizedBox(width: 20),
          Expanded(child: cards[2]),
        ],
      );
    } else if (useTwoColumns) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(child: cards[0]),
              const SizedBox(width: 20),
              Expanded(child: cards[1]),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: cards[2]),
              const Spacer(),
            ],
          ),
        ],
      );
    } else {
      return Column(
        children: [
          cards[0],
          const SizedBox(height: 20),
          cards[1],
          const SizedBox(height: 20),
          cards[2],
        ],
      );
    }
  }

  Widget _buildElegantCard({
    required String title,
    required String value,
    required IconData icon,
    required Color primaryColor,
    required Color bgColor,
  }) {
    return ElegantCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: Color(0xFF64748B),
                    fontFamily: 'Fira Sans',
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: primaryColor, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
              fontFamily: 'Fira Code',
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseDistributionBar() {
    final active = _summary?.activeCoursesCount ?? 0;
    final inactive = _summary?.inactiveCoursesCount ?? 0;
    final total = active + inactive;
    if (total == 0) return const SizedBox.shrink();

    return ElegantCard(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Course Status Breakdown',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
              fontFamily: 'Fira Sans',
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              SizedBox(
                height: 120,
                width: 120,
                child: PieChart(
                  PieChartData(
                    sections: [
                      if (active > 0)
                        PieChartSectionData(
                          value: active.toDouble(),
                          color: const Color(0xFF0D9488),
                          title: '$active',
                          radius: 24,
                          titleStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            fontFamily: 'Fira Code',
                          ),
                        ),
                      if (inactive > 0)
                        PieChartSectionData(
                          value: inactive.toDouble(),
                          color: const Color(0xFF94A3B8),
                          title: '$inactive',
                          radius: 24,
                          titleStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            fontFamily: 'Fira Code',
                          ),
                        ),
                    ],
                    centerSpaceRadius: 36,
                    sectionsSpace: 4,
                  ),
                ),
              ),
              const SizedBox(width: 48),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLegendItem(color: const Color(0xFF0D9488), label: 'Active Courses ($active)'),
                    const SizedBox(height: 16),
                    _buildLegendItem(color: const Color(0xFF94A3B8), label: 'Inactive Courses ($inactive)'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem({required Color color, required String label}) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Color(0xFF475569),
            fontFamily: 'Fira Sans',
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context, {required bool useRow}) {
    final actions = [
      _buildActionButton(
        icon: Icons.school_outlined,
        label: 'Manage Courses',
        color: const Color(0xFF0D9488),
        bgColor: const Color(0xFFF0FDFA),
        onTap: () => Navigator.pushNamed(context, '/course-manager/courses'),
      ),
      _buildActionButton(
        icon: Icons.assignment_outlined,
        label: 'Manage Exams',
        color: const Color(0xFFF97316),
        bgColor: const Color(0xFFFFF7ED),
        onTap: () => Navigator.pushNamed(context, '/course-manager/exams'),
      ),
      _buildActionButton(
        icon: Icons.grid_view_outlined,
        label: 'Matrix Builder',
        color: const Color(0xFF6366F1),
        bgColor: const Color(0xFFEEF2FF),
        onTap: () => Navigator.pushNamed(context, '/course-manager/matrix'),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
            fontFamily: 'Fira Sans',
          ),
        ),
        const SizedBox(height: 16),
        useRow
            ? Row(
                children: actions
                    .map((a) => Expanded(
                            child: Padding(
                          padding: const EdgeInsets.only(right: 16),
                          child: a,
                        )))
                    .toList())
            : Column(
                children: actions
                    .map((a) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: a,
                        ))
                    .toList()),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return ElegantBouncyButton(
      onTap: onTap,
      backgroundColor: Colors.white,
      borderColor: const Color(0xFFF1F5F9),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF334155),
                fontFamily: 'Fira Sans',
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentPendingCourses(BuildContext context) {
    if (_pendingCourses == null || _pendingCourses!.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Pending Courses',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
              fontFamily: 'Fira Sans',
            ),
          ),
          const SizedBox(height: 16),
          ElegantCard(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: const Center(
              child: Text(
                'No pending courses for review.',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 14,
                  fontFamily: 'Fira Sans',
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Pending Courses',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
                fontFamily: 'Fira Sans',
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/course-manager/courses'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text(
                'View All',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0D9488),
                  fontFamily: 'Fira Sans',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ElegantCard(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: _pendingCourses!.asMap().entries.map((entry) {
              final index = entry.key;
              final course = entry.value;
              final isLast = index == _pendingCourses!.length - 1;
              return Column(
                children: [
                  _buildCourseItem(course),
                  if (!isLast)
                    const Divider(color: Color(0xFFF1F5F9), height: 1, thickness: 1, indent: 20, endIndent: 20),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildCourseItem(CourseReviewCourse course) {
    // Generate a soft color based on ID to make the list look varied but elegant
    final colors = [
      const Color(0xFF0D9488),
      const Color(0xFFF97316),
      const Color(0xFF3B82F6),
      const Color(0xFF8B5CF6),
      const Color(0xFFEC4899),
    ];
    final color = colors[course.id % colors.length];

    String timeAgo = 'Just now';
    if (course.submittedAt != null) {
      final diff = DateTime.now().difference(course.submittedAt!);
      if (diff.inDays > 0) {
        timeAgo = '${diff.inDays} days ago';
      } else if (diff.inHours > 0) {
        timeAgo = '${diff.inHours} hours ago';
      } else if (diff.inMinutes > 0) {
        timeAgo = '${diff.inMinutes} mins ago';
      }
    }

    return ElegantBouncyButton(
      onTap: () {
         // Optionally navigate to details
         Navigator.pushNamed(context, '/course-manager/courses/review/${course.id}');
      },
      backgroundColor: Colors.transparent,
      borderColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.school_outlined, color: color, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                      fontFamily: 'Fira Sans',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.person_outline, size: 14, color: Color(0xFF64748B)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          course.creatorName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                            fontFamily: 'Fira Sans',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  timeAgo,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF94A3B8),
                    fontFamily: 'Fira Sans',
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFFFEDD5), width: 1),
                  ),
                  child: Text(
                    course.status.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFEA580C),
                      fontFamily: 'Fira Sans',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
