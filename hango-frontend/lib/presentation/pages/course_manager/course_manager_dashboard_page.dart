import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../utils/toast_helper.dart';
import 'package:hango/presentation/widgets/internal_app_header.dart';
import '../../widgets/course_manager_sidebar.dart';
import 'course_manager_shell_page.dart';
import '../../../data/services/course_manager_api.dart';
import '../../../data/models/course_manager_dashboard_summary.dart';

// ─── Reusable card widget ────────────────────────────────────────────
class _DashCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const _DashCard({required this.child, this.padding = const EdgeInsets.all(24)});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: const [BoxShadow(color: Color(0x08000000), offset: Offset(0, 4), blurRadius: 12)],
      ),
      child: child,
    );
  }
}

// ─── Main page ───────────────────────────────────────────────────────
class CourseManagerDashboardPage extends StatefulWidget {
  final bool isEmbedded;
  const CourseManagerDashboardPage({super.key, this.isEmbedded = false});

  @override
  State<CourseManagerDashboardPage> createState() => _CourseManagerDashboardPageState();
}

class _CourseManagerDashboardPageState extends State<CourseManagerDashboardPage> {
  final _api = CourseManagerApi();
  CourseManagerDashboardSummary? _s;
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
          _s = results[0] as CourseManagerDashboardSummary;
          _pendingCourses = (results[1] as Map<String, dynamic>)['courses'] as List<CourseReviewCourse>;
          _pendingCourses?.sort((a, b) {
            if (a.submittedAt == null && b.submittedAt == null) return 0;
            if (a.submittedAt == null) return 1;
            if (b.submittedAt == null) return -1;
            return b.submittedAt!.compareTo(a.submittedAt!);
          });
          if (_pendingCourses != null && _pendingCourses!.length > 5) {
            _pendingCourses = _pendingCourses!.sublist(0, 5);
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ToastHelper.showError(context, 'Error loading data: $e');
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

    final Widget bodyContent = _isLoading
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
                      // Section 1: KPI Cards
                      _buildKpiCards(isDesktop),
                      const SizedBox(height: 24),
                      // Section 2: Approval Pipeline
                      _buildApprovalPipeline(),
                      const SizedBox(height: 24),
                      // Section 3: Charts Row
                      _buildChartsRow(isDesktop),
                      const SizedBox(height: 24),
                      // Section 4: Top Performers Row
                      _buildTopPerformersRow(isDesktop),
                      const SizedBox(height: 24),
                      // Section 5: Content Quality
                      _buildContentQuality(),
                      const SizedBox(height: 24),
                      // Section 6: Recent Pending Courses + Quick Actions
                      _buildBottomRow(isDesktop),
                      const SizedBox(height: 48),
                    ],
                  ),
                ),
              ),
            ],
          );

    if (widget.isEmbedded) return bodyContent;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: InternalAppHeader(isMobile: !isDesktop, activeTab: ''),
      drawer: !isDesktop ? const Drawer(child: CourseManagerSidebar(currentRoute: 'dashboard')) : null,
      body: Row(
        children: [
          if (isDesktop) const SizedBox(width: 240, child: CourseManagerSidebar(currentRoute: 'dashboard')),
          Expanded(child: bodyContent),
        ],
      ),
    );
  }

  // ─── Welcome Header ─────────────────────────────────────────────
  Widget _buildWelcomeHeader(BuildContext context, bool isDesktop) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 8),
      child: Row(
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
                Text(_getGreeting(),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF64748B), fontFamily: 'Fira Sans')),
                const SizedBox(height: 4),
                const Text('Manager Dashboard',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: Color(0xFF0F172A), fontFamily: 'Fira Sans')),
              ],
            ),
          ),
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF64748B)),
            tooltip: 'Refresh data',
            onPressed: () {
              setState(() => _isLoading = true);
              _fetchData();
            },
          ),
        ],
      ),
    );
  }

  // ─── Section 1: KPI Cards ────────────────────────────────────────
  Widget _buildKpiCards(bool isDesktop) {
    final s = _s!;
    final totalPending = s.pendingCoursesCount + s.pendingExamsCount;

    final cards = [
      _kpiCard('TOTAL COURSES', '${s.activeCoursesCount + s.inactiveCoursesCount}', Icons.school_rounded,
          const Color(0xFF0D9488), const Color(0xFFF0FDFA), s.coursesGrowthPercent),
      _kpiCard('PENDING APPROVALS', '$totalPending', Icons.assignment_late_rounded,
          const Color(0xFFF59E0B), const Color(0xFFFEF3C7), null, badge: totalPending > 0),
      _kpiCard('ACTIVE LEARNERS', '${s.activeLearnerCount}', Icons.people_rounded,
          const Color(0xFF3B82F6), const Color(0xFFEFF6FF), s.learnersGrowthPercent),
      _kpiCard('TOTAL EXAMS', '${s.examsCount}', Icons.assignment_rounded,
          const Color(0xFF6366F1), const Color(0xFFEEF2FF), s.examsGrowthPercent),
      _kpiCard('AVG RATING', s.avgCourseRating.toStringAsFixed(1), Icons.star_rounded,
          const Color(0xFFF59E0B), const Color(0xFFFEF3C7), null),
    ];

    if (isDesktop) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 16), child: c))).toList(),
        ),
      );
    }
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: cards.map((c) => SizedBox(width: 180, child: c)).toList(),
    );
  }

  Widget _kpiCard(String title, String value, IconData icon, Color color, Color bgColor, double? delta, {bool badge = false}) {
    return _DashCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(title,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: Color(0xFF64748B), fontFamily: 'Fira Sans')),
              ),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)),
                    child: Icon(icon, color: color, size: 18),
                  ),
                  if (badge)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        width: 10, height: 10,
                        decoration: BoxDecoration(color: const Color(0xFFEF4444), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(value,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Color(0xFF0F172A), fontFamily: 'Fira Code', height: 1.0)),
          if (delta != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(delta >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded, size: 14, color: delta >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
                const SizedBox(width: 4),
                Text('${delta >= 0 ? "+" : ""}${delta.toStringAsFixed(1)}%',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: delta >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444), fontFamily: 'Fira Sans')),
                const SizedBox(width: 4),
                const Text('vs last week', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontFamily: 'Fira Sans')),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ─── Section 2: Approval Pipeline ──────────────────────────────
  Widget _buildApprovalPipeline() {
    final s = _s!;
    final stages = [
      _PipelineStage('Draft', s.draftCoursesCount, const Color(0xFF94A3B8)),
      _PipelineStage('Pending', s.pendingCoursesCount, const Color(0xFFF59E0B)),
      _PipelineStage('Published', s.publishedCoursesCount, const Color(0xFF10B981)),
      _PipelineStage('Rejected', s.rejectedCoursesCount, const Color(0xFFEF4444)),
      _PipelineStage('Hidden', s.hiddenCoursesCount, const Color(0xFF6B7280)),
    ];
    final total = stages.fold<int>(0, (sum, st) => sum + st.count);

    return _DashCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Course Approval Pipeline',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1E293B), fontFamily: 'Fira Sans')),
          const SizedBox(height: 20),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 12,
              child: Row(
                children: stages.map((st) {
                  final fraction = total > 0 ? st.count / total : 0.0;
                  if (fraction == 0) return const SizedBox.shrink();
                  return Expanded(
                    flex: (fraction * 1000).round().clamp(1, 1000),
                    child: Container(color: st.color),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Legend
          Wrap(
            spacing: 24,
            runSpacing: 8,
            children: stages.map((st) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: st.color, borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 6),
                Text('${st.label} ', style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontFamily: 'Fira Sans')),
                Text('${st.count}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: st.color, fontFamily: 'Fira Code')),
              ],
            )).toList(),
          ),
        ],
      ),
    );
  }

  // ─── Section 3: Charts Row ──────────────────────────────────────
  Widget _buildChartsRow(bool isDesktop) {
    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 3, child: _buildEnrollmentTrendChart()),
          const SizedBox(width: 20),
          Expanded(flex: 2, child: _buildCategoryDonut()),
        ],
      );
    }
    return Column(children: [_buildEnrollmentTrendChart(), const SizedBox(height: 20), _buildCategoryDonut()]);
  }

  Widget _buildEnrollmentTrendChart() {
    final trend = _s?.enrollmentTrend ?? [];
    if (trend.isEmpty) {
      return _DashCard(
        child: SizedBox(height: 200, child: Center(child: Text('No enrollment data', style: TextStyle(color: Color(0xFF94A3B8))))),
      );
    }
    final maxY = trend.map((e) => e.count.toDouble()).reduce((a, b) => a > b ? a : b);
    final safeMaxY = maxY == 0 ? 10.0 : maxY * 1.2;

    return _DashCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Enrollment Trend (8 Weeks)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1E293B), fontFamily: 'Fira Sans')),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: safeMaxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: safeMaxY / 4,
                  getDrawingHorizontalLine: (value) => FlLine(color: const Color(0xFFE2E8F0), strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: true, reservedSize: 36, interval: safeMaxY / 4,
                      getTitlesWidget: (value, meta) => Text(value.toInt().toString(), style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontFamily: 'Fira Code'))),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: true, reservedSize: 28, interval: 1,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= trend.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(trend[idx].weekLabel, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontFamily: 'Fira Sans')),
                        );
                      }),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: trend.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.count.toDouble())).toList(),
                    isCurved: true,
                    preventCurveOverShooting: true,
                    color: const Color(0xFF0D9488),
                    barWidth: 3,
                    dotData: FlDotData(show: true, getDotPainter: (spot, percent, bar, index) =>
                        FlDotCirclePainter(radius: 4, color: Colors.white, strokeWidth: 2, strokeColor: const Color(0xFF0D9488))),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                          colors: [const Color(0xFF0D9488).withValues(alpha: 0.2), const Color(0xFF0D9488).withValues(alpha: 0.0)]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryDonut() {
    final categories = _s?.coursesByCategory ?? {};
    if (categories.isEmpty) {
      return _DashCard(child: const SizedBox(height: 200, child: Center(child: Text('No category data', style: TextStyle(color: Color(0xFF94A3B8))))));
    }

    final colors = [
      const Color(0xFF0D9488), const Color(0xFF3B82F6), const Color(0xFFF59E0B),
      const Color(0xFF8B5CF6), const Color(0xFFEC4899), const Color(0xFF6366F1),
      const Color(0xFFEF4444), const Color(0xFF14B8A6),
    ];

    final entries = categories.entries.toList();
    return _DashCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Course Distribution', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1E293B), fontFamily: 'Fira Sans')),
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                height: 140, width: 140,
                child: PieChart(PieChartData(
                  sections: entries.asMap().entries.map((e) => PieChartSectionData(
                    value: e.value.value.toDouble(),
                    color: colors[e.key % colors.length],
                    title: '${e.value.value}',
                    radius: 24,
                    titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white, fontFamily: 'Fira Code'),
                  )).toList(),
                  centerSpaceRadius: 40,
                  sectionsSpace: 3,
                )),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: entries.asMap().entries.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(children: [
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: colors[e.key % colors.length], shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(e.value.key, style: const TextStyle(fontSize: 12, color: Color(0xFF475569), fontFamily: 'Fira Sans'), overflow: TextOverflow.ellipsis)),
                    ]),
                  )).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Section 4: Top Performers ──────────────────────────────────
  Widget _buildTopPerformersRow(bool isDesktop) {
    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildTopCoursesChart()),
          const SizedBox(width: 20),
          Expanded(child: _buildTopTrainersCard()),
        ],
      );
    }
    return Column(children: [_buildTopCoursesChart(), const SizedBox(height: 20), _buildTopTrainersCard()]);
  }

  Widget _buildTopCoursesChart() {
    final courses = _s?.topCoursesByEnrollment ?? [];
    if (courses.isEmpty) {
      return _DashCard(child: const SizedBox(height: 200, child: Center(child: Text('No course data', style: TextStyle(color: Color(0xFF94A3B8))))));
    }
    final maxEnroll = courses.map((c) => c.enrollmentCount).reduce((a, b) => a > b ? a : b);

    return _DashCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Top 5 Courses by Enrollment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1E293B), fontFamily: 'Fira Sans')),
          const SizedBox(height: 20),
          ...courses.asMap().entries.map((e) {
            final c = e.value;
            final fraction = maxEnroll > 0 ? c.enrollmentCount / maxEnroll : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(c.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155), fontFamily: 'Fira Sans'), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      const SizedBox(width: 8),
                      Text('${c.enrollmentCount}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0D9488), fontFamily: 'Fira Code')),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: fraction,
                      minHeight: 8,
                      backgroundColor: const Color(0xFFF1F5F9),
                      valueColor: AlwaysStoppedAnimation(Color.lerp(const Color(0xFF0D9488), const Color(0xFF10B981), fraction)!),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTopTrainersCard() {
    final trainers = _s?.topTrainersByRating ?? [];
    if (trainers.isEmpty) {
      return _DashCard(child: const SizedBox(height: 200, child: Center(child: Text('No trainer data', style: TextStyle(color: Color(0xFF94A3B8))))));
    }

    return _DashCard(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Top Trainers by Rating', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1E293B), fontFamily: 'Fira Sans')),
          const SizedBox(height: 16),
          ...trainers.asMap().entries.map((e) {
            final t = e.value;
            final rank = e.key + 1;
            final medal = rank == 1 ? '🥇' : rank == 2 ? '🥈' : rank == 3 ? '🥉' : '#$rank';
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  SizedBox(width: 28, child: Text(medal, style: const TextStyle(fontSize: 16), textAlign: TextAlign.center)),
                  const SizedBox(width: 10),
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFFF0FDFA),
                    backgroundImage: t.avatarUrl != null && t.avatarUrl!.isNotEmpty ? NetworkImage(t.avatarUrl!) : null,
                    child: t.avatarUrl == null || t.avatarUrl!.isEmpty
                        ? Text(t.fullName.isNotEmpty ? t.fullName[0].toUpperCase() : '?',
                            style: const TextStyle(color: Color(0xFF0D9488), fontWeight: FontWeight.w700))
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.fullName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B), fontFamily: 'Fira Sans'), maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text('${t.courseCount} courses · ${t.totalEnrollments} students', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontFamily: 'Fira Sans')),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF59E0B)),
                        const SizedBox(width: 2),
                        Text(t.avgRating.toStringAsFixed(1), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFF59E0B), fontFamily: 'Fira Code')),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─── Section 5: Content Quality ─────────────────────────────────
  Widget _buildContentQuality() {
    final s = _s!;
    final items = [
      _QualityItem('Courses without description', s.coursesWithoutDescription, s.coursesWithoutDescription > 0 ? _QSeverity.red : _QSeverity.green),
      _QualityItem('Courses with < 3 lessons', s.coursesWithFewLessons, s.coursesWithFewLessons > 0 ? _QSeverity.yellow : _QSeverity.green),
      _QualityItem('Exams without questions', s.examsWithoutQuestions, s.examsWithoutQuestions > 0 ? _QSeverity.red : _QSeverity.green),
      _QualityItem('Avg lessons per course', s.avgLessonsPerCourse.toInt(), _QSeverity.green, displayValue: s.avgLessonsPerCourse.toStringAsFixed(1)),
      _QualityItem('Courses rated below 3.0', s.lowRatedCourses, s.lowRatedCourses > 0 ? _QSeverity.yellow : _QSeverity.green),
    ];

    return _DashCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Content Health', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1E293B), fontFamily: 'Fira Sans')),
          const SizedBox(height: 16),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Container(
                  width: 10, height: 10,
                  decoration: BoxDecoration(
                    color: item.severity == _QSeverity.red ? const Color(0xFFEF4444)
                        : item.severity == _QSeverity.yellow ? const Color(0xFFF59E0B)
                        : const Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(item.label, style: const TextStyle(fontSize: 13, color: Color(0xFF475569), fontFamily: 'Fira Sans'))),
                Text(item.displayValue ?? '${item.value}',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, fontFamily: 'Fira Code',
                        color: item.severity == _QSeverity.red ? const Color(0xFFEF4444)
                            : item.severity == _QSeverity.yellow ? const Color(0xFFF59E0B)
                            : const Color(0xFF10B981))),
                const SizedBox(width: 8),
                Text(
                  item.severity == _QSeverity.red ? 'Action needed'
                      : item.severity == _QSeverity.yellow ? 'Warning'
                      : 'Healthy',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, fontFamily: 'Fira Sans',
                      color: item.severity == _QSeverity.red ? const Color(0xFFEF4444)
                          : item.severity == _QSeverity.yellow ? const Color(0xFFF59E0B)
                          : const Color(0xFF10B981)),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  // ─── Section 6: Bottom Row ──────────────────────────────────────
  Widget _buildBottomRow(bool isDesktop) {
    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 3, child: _buildRecentPendingCourses()),
          const SizedBox(width: 20),
          Expanded(flex: 2, child: _buildQuickActions()),
        ],
      );
    }
    return Column(children: [_buildRecentPendingCourses(), const SizedBox(height: 20), _buildQuickActions()]);
  }

  Widget _buildRecentPendingCourses() {
    final courses = _pendingCourses;
    if (courses == null || courses.isEmpty) {
      return _DashCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Recent Pending Courses', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1E293B), fontFamily: 'Fira Sans')),
            const SizedBox(height: 24),
            const Center(child: Text('No pending courses 🎉', style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8), fontFamily: 'Fira Sans'))),
          ],
        ),
      );
    }

    return _DashCard(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Recent Pending Courses', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1E293B), fontFamily: 'Fira Sans')),
              TextButton(
                onPressed: () {
                  final shellState = context.findAncestorStateOfType<CourseManagerShellPageState>();
                  if (shellState != null) {
                    shellState.selectTab(1); // 1 is 'courses' tab
                  } else {
                    Navigator.pushNamed(context, '/course-manager/courses');
                  }
                },
                child: const Text('View All →', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0D9488), fontFamily: 'Fira Sans')),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...courses.map((course) {
            String timeAgo = 'Just now';
            if (course.submittedAt != null) {
              final diff = DateTime.now().difference(course.submittedAt!);
              if (diff.inDays > 0) {
                timeAgo = '${diff.inDays}d ago';
              } else if (diff.inHours > 0) {
                timeAgo = '${diff.inHours}h ago';
              } else if (diff.inMinutes > 0) {
                timeAgo = '${diff.inMinutes}m ago';
              }
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 40, height: 40,
                    color: const Color(0xFFF0FDFA),
                    child: course.thumbnailUrl.isNotEmpty
                        ? Image.network(course.thumbnailUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.school_outlined, color: Color(0xFF0D9488), size: 20))
                        : const Icon(Icons.school_outlined, color: Color(0xFF0D9488), size: 20),
                  ),
                ),
                title: Text(course.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B), fontFamily: 'Fira Sans'), maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('by ${course.creatorName}', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontFamily: 'Fira Sans')),
                trailing: Text(timeAgo, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontFamily: 'Fira Sans')),
                onTap: () => Navigator.pushNamed(context, '/course-manager/courses/review/${course.id}'),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      _QuickAction('Manage Courses', Icons.school_outlined, const Color(0xFF0D9488), const Color(0xFFF0FDFA), 1),
      _QuickAction('Manage Exams', Icons.assignment_outlined, const Color(0xFFF97316), const Color(0xFFFFF7ED), 2),
      _QuickAction('Matrix Builder', Icons.grid_view_outlined, const Color(0xFF6366F1), const Color(0xFFEEF2FF), 3),
      _QuickAction('Question Bank', Icons.question_answer_outlined, const Color(0xFF3B82F6), const Color(0xFFEFF6FF), 4),
    ];

    return _DashCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Quick Actions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1E293B), fontFamily: 'Fira Sans')),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 2.2,
            children: actions.map((a) => InkWell(
              onTap: () {
                // Find shell page state and switch tab
                final shellState = context.findAncestorStateOfType<CourseManagerShellPageState>();
                if (shellState != null) {
                  shellState.selectTab(a.tabIndex);
                } else {
                  // Fallback for standalone view
                  final routes = ['/course-manager', '/course-manager/courses', '/course-manager/exams', '/course-manager/matrix', '/course-manager/question-bank'];
                  if (a.tabIndex >= 0 && a.tabIndex < routes.length) {
                    Navigator.pushNamed(context, routes[a.tabIndex]);
                  }
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: BoxDecoration(
                  color: a.bgColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: a.color.withValues(alpha: 0.15)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(a.icon, color: a.color, size: 20),
                    const SizedBox(width: 8),
                    Flexible(child: Text(a.label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: a.color, fontFamily: 'Fira Sans'), overflow: TextOverflow.ellipsis)),
                  ],
                ),
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }
}

// ─── Helper classes ───────────────────────────────────────────────
class _PipelineStage {
  final String label;
  final int count;
  final Color color;
  const _PipelineStage(this.label, this.count, this.color);
}

enum _QSeverity { red, yellow, green }

class _QualityItem {
  final String label;
  final int value;
  final _QSeverity severity;
  final String? displayValue;
  const _QualityItem(this.label, this.value, this.severity, {this.displayValue});
}

class _QuickAction {
  final String label;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final int tabIndex;
  const _QuickAction(this.label, this.icon, this.color, this.bgColor, this.tabIndex);
}
