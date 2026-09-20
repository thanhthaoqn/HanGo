// ignore_for_file: deprecated_member_use
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import '../../../../data/services/auth_service.dart';
import 'package:intl/intl.dart';

class ComprehensiveDashboardTab extends StatefulWidget {
  final bool isDesktop;
  final void Function(int)? onNavigate;

  const ComprehensiveDashboardTab({
    super.key,
    this.isDesktop = true,
    this.onNavigate,
  });

  @override
  State<ComprehensiveDashboardTab> createState() =>
      _ComprehensiveDashboardTabState();
}

class _ComprehensiveDashboardTabState extends State<ComprehensiveDashboardTab> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _stats;
  final AuthService _authService = AuthService();
  int _periodDays = 30; // Default filter: 30 days
  int _touchedPieIndex = -1;

  // Chart Series Visibility Toggles
  bool _showGrossRevenue = true;
  bool _showPlatformFee = true;
  bool _showNewUsersLine = true;
  bool _showEnrollmentsLine = true;

  String get apiBaseUrl {
    final authUrl = AuthService.baseUrl;
    return authUrl.replaceAll('/auth', '');
  }

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final token = await _authService.getToken();
      if (token == null) {
        setState(() {
          _error = 'Unauthorized: Please login with administrator account';
          _isLoading = false;
        });
        return;
      }

      final url = Uri.parse(
        '$apiBaseUrl/admin/dashboard/comprehensive-stats?periodDays=$_periodDays',
      );
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          _stats = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load dashboard metrics (${response.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error fetching platform telemetry: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 520,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withOpacity(0.18),
                    blurRadius: 32,
                    spreadRadius: 6,
                  ),
                ],
              ),
              child: const SizedBox(
                width: 38,
                height: 38,
                child: CircularProgressIndicator(
                  strokeWidth: 3.2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                ),
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'Synchronizing Platform Intelligence...',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF334155),
                fontFamily: 'Outfit',
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Fetching real-time business telemetry and learning metrics',
              style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(36),
          margin: const EdgeInsets.symmetric(vertical: 40),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFFEE2E2)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFEF4444).withOpacity(0.06),
                blurRadius: 28,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFFFEF2F2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 36),
              ),
              const SizedBox(height: 18),
              const Text(
                'Unable to Load Platform Metrics',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                  fontFamily: 'Outfit',
                ),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 13, height: 1.4),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 22),
              ElevatedButton.icon(
                onPressed: _fetchStats,
                icon: const Icon(Icons.refresh_rounded, size: 18, color: Colors.white),
                label: const Text('Retry Connection', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_stats == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeaderActions(),
        const SizedBox(height: 24),
        _buildKpiGrid(),
        const SizedBox(height: 24),
        _buildMainCharts(widget.isDesktop),
        const SizedBox(height: 24),
        _buildPlatformGrowthChart(),
        const SizedBox(height: 24),
        _buildBottomSection(widget.isDesktop),
        const SizedBox(height: 24),
        _buildLearningAnalytics(widget.isDesktop),
        const SizedBox(height: 24),
        _buildTicketAndAiAnalytics(widget.isDesktop),
        const SizedBox(height: 48),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // HEADER & TIME FILTER CONTROL
  // --------------------------------------------------------------------------
  Widget _buildHeaderActions() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 680;

        final titleSection = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Platform Overview',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    fontFamily: 'Outfit',
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(width: 12),
                Tooltip(
                  message: 'Real-time telemetry synced with Aiven Cloud DB',
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Live Sync',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF047857),
                            fontFamily: 'Outfit',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Real-time metrics, financial health & student learning trajectory',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        );

        final filterControl = Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildPeriodOption(7, isNarrow ? '7D' : '7 Days'),
              _buildPeriodOption(30, isNarrow ? '30D' : '30 Days'),
              _buildPeriodOption(90, isNarrow ? '3M' : '3 Months'),
              _buildPeriodOption(365, isNarrow ? '1Y' : '12 Months'),
              Container(
                width: 1,
                height: 20,
                color: const Color(0xFFCBD5E1),
                margin: const EdgeInsets.symmetric(horizontal: 4),
              ),
              Material(
                color: Colors.transparent,
                child: Tooltip(
                  message: 'Refresh data from database',
                  child: InkWell(
                    onTap: _fetchStats,
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.all(6.0),
                      child: Icon(Icons.refresh_rounded, size: 18, color: Color(0xFF475569)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleSection,
              const SizedBox(height: 16),
              filterControl,
            ],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            titleSection,
            filterControl,
          ],
        );
      },
    );
  }

  Widget _buildPeriodOption(int days, String label) {
    final isSelected = _periodDays == days;
    return GestureDetector(
      onTap: () {
        if (_periodDays != days) {
          setState(() => _periodDays = days);
          _fetchStats();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 5,
                    offset: const Offset(0, 1.5),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
            fontFamily: 'Outfit',
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // TOP KPI CARDS
  // --------------------------------------------------------------------------
  Widget _buildKpiGrid() {
    final overview = _stats!['overview'] ?? {};

    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = constraints.maxWidth > 1150
            ? 4
            : constraints.maxWidth > 650
                ? 2
                : 1;
        double width =
            (constraints.maxWidth - (crossAxisCount - 1) * 16) / crossAxisCount;

        int totalUsers = overview['totalActiveUsers'] ?? 0;
        int totalEnrollments = overview['totalEnrollments'] ?? 0;
        double avgEnrollments =
            totalUsers > 0 ? totalEnrollments / totalUsers : 0.0;

        final learning = _stats!['learningPerformance'] ?? {};
        double avgScore = (learning['avgExamScore'] is num)
            ? (learning['avgExamScore'] as num).toDouble()
            : 0.0;

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _InteractiveKpiCard(
              title: 'Total Users',
              value: '$totalUsers',
              subtitle:
                  '${overview['totalLearners'] ?? 0} Learners · ${overview['totalTrainers'] ?? 0} Trainers',
              icon: Icons.group_rounded,
              themeColor: const Color(0xFF3B82F6),
              width: width,
              countToday: overview['newUsersToday'],
            ),
            _InteractiveKpiCard(
              title: 'Enrollments',
              value: '$totalEnrollments',
              subtitle: 'Avg ${avgEnrollments.toStringAsFixed(1)} courses / learner',
              icon: Icons.school_rounded,
              themeColor: const Color(0xFFF59E0B),
              width: width,
              countToday: overview['newEnrollmentsToday'],
            ),
            _InteractiveKpiCard(
              title: 'Published Courses',
              value: '${overview['totalPublishedCourses'] ?? 0}',
              subtitle:
                  '${overview['totalFreeCourses'] ?? 0} Free · ${overview['totalPaidCourses'] ?? 0} Paid',
              icon: Icons.auto_stories_rounded,
              themeColor: const Color(0xFF10B981),
              width: width,
              countToday: overview['newCoursesToday'],
            ),
            _InteractiveKpiCard(
              title: 'Exam Attempts',
              value: '${overview['totalExamAttempts'] ?? 0}',
              subtitle: 'Avg Score: ${avgScore.toStringAsFixed(1)} / 10 pts',
              icon: Icons.assignment_turned_in_rounded,
              themeColor: const Color(0xFF8B5CF6),
              width: width,
              countToday: overview['newExamAttemptsToday'],
            ),
          ],
        );
      },
    );
  }

  // --------------------------------------------------------------------------
  // MAIN CHARTS: REVENUE TREND & USER DISTRIBUTION
  // --------------------------------------------------------------------------
  Widget _buildMainCharts(bool isDesktop) {
    final revenueChart = _buildRevenueChart();
    final userDistributionChart = _buildUserDistributionChart();

    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 5, child: revenueChart),
          const SizedBox(width: 24),
          Expanded(flex: 3, child: userDistributionChart),
        ],
      );
    } else {
      return Column(
        children: [
          revenueChart,
          const SizedBox(height: 24),
          userDistributionChart,
        ],
      );
    }
  }

  Widget _buildRevenueChart() {
    final trends = _stats!['trends'] ?? {};
    final revenueByDay = (trends['revenueByDay'] as List?) ?? [];
    final revenue = _stats!['revenue'] ?? {};

    // Tỷ lệ phí sàn THỰC TẾ từ backend:
    // Teacher (Trainer): sàn giữ 30%, giảng viên nhận 70%
    // Tutor:             sàn giữ 40%, giảng viên nhận 60%
    // Backend đã tổng hợp đúng platformFee → tính blended ratio từ dữ liệu thật
    final double totalRevenue = (revenue['totalRevenue'] is num)
        ? (revenue['totalRevenue'] as num).toDouble()
        : 0.0;
    final double totalPlatformFee = (revenue['platformFee'] is num)
        ? (revenue['platformFee'] as num).toDouble()
        : 0.0;
    final double blendedFeeRatio = (totalRevenue > 0)
        ? (totalPlatformFee / totalRevenue).clamp(0.0, 1.0)
        : 0.30; // fallback hợp lý (teacher-heavy mix)

    final String feeRatioLabel =
        'Platform Net (~${(blendedFeeRatio * 100).toStringAsFixed(0)}%)';

    List<FlSpot> grossSpots = [];
    List<FlSpot> platformFeeSpots = [];
    double maxY = 0;

    for (int i = 0; i < revenueByDay.length; i++) {
      double grossVal = (revenueByDay[i]['amount'] ?? 0).toDouble();
      double feeVal = grossVal * blendedFeeRatio; // tỷ lệ thực tế blended
      if (grossVal > maxY) maxY = grossVal;
      grossSpots.add(FlSpot(i.toDouble(), grossVal));
      platformFeeSpots.add(FlSpot(i.toDouble(), feeVal));
    }
    if (maxY == 0) maxY = 1000000;

    return Container(
      height: 520,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.035),
            blurRadius: 22,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Revenue Trajectory',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                      fontFamily: 'Outfit',
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Financial gross GMV & platform net fee share over time',
                    style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _buildInteractiveSeriesChip(
                    label: 'Gross GMV',
                    color: const Color(0xFF10B981),
                    isActive: _showGrossRevenue,
                    onTap: () => setState(() => _showGrossRevenue = !_showGrossRevenue),
                  ),
                  _buildInteractiveSeriesChip(
                    label: feeRatioLabel,
                    color: const Color(0xFF0284C7),
                    isActive: _showPlatformFee,
                    onTap: () => setState(() => _showPlatformFee = !_showPlatformFee),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.lock_clock_rounded, size: 12, color: Color(0xFF64748B)),
                        SizedBox(width: 4),
                        Text(
                          'VNPay IPN',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _buildRevenueInfoCard(
                  'Total Gross GMV',
                  _formatCurrency(revenue['totalRevenue']),
                  'Avg: ${_formatCurrency(revenue['avgTransactionValue'])} / txn',
                  Icons.payments_rounded,
                  const Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildRevenueInfoCard(
                  feeRatioLabel,
                  _formatCurrency(revenue['platformFee']),
                  '${revenue['transactionCount'] ?? 0} orders · Teacher 30% · Tutor 40%',
                  Icons.account_balance_wallet_rounded,
                  const Color(0xFF0284C7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: revenueByDay.isEmpty
                ? _buildEmptyChartState(
                    title: 'No Revenue Records in This Timeframe',
                    message:
                        'Transactions recorded during the selected period will automatically chart your financial trajectory here.',
                  )
                : LineChart(
                    LineChartData(
                      minY: 0,
                      maxY: maxY * 1.15,
                      lineTouchData: LineTouchData(
                        enabled: true,
                        handleBuiltInTouches: true,
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipColor: (_) => const Color(0xFF0F172A),
                          tooltipBorderRadius: BorderRadius.circular(10),
                          tooltipPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          maxContentWidth: 240,
                          fitInsideHorizontally: true,
                          fitInsideVertically: true,
                          getTooltipItems: (List<LineBarSpot> touchedSpots) {
                            if (touchedSpots.isEmpty) return [];
                            final first = touchedSpots.first;
                            final int index = first.x.toInt();
                            String dateLabel = '';
                            if (index >= 0 && index < revenueByDay.length) {
                              final dateStr = revenueByDay[index]['date'];
                              final date = DateTime.tryParse(dateStr);
                              if (date != null) {
                                dateLabel = DateFormat('dd MMM, yyyy').format(date);
                              }
                            }
                            final txCount = (index >= 0 && index < revenueByDay.length)
                                ? (revenueByDay[index]['txCount'] ?? 0)
                                : 0;

                            return touchedSpots.map((spot) {
                              final bool isGross = spot.bar.color == const Color(0xFF10B981);
                              return LineTooltipItem(
                                spot == touchedSpots.first ? '$dateLabel\n' : '',
                                const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w500),
                                children: [
                                  TextSpan(
                                    text: isGross ? '• Gross GMV: ' : '• Net Take (20%): ',
                                    style: TextStyle(
                                      color: isGross ? const Color(0xFF34D399) : const Color(0xFF38BDF8),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  TextSpan(
                                    text: _formatCurrency(spot.y),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Outfit',
                                    ),
                                  ),
                                  if (isGross)
                                    TextSpan(
                                      text: '  ($txCount orders)',
                                      style: const TextStyle(
                                        color: Color(0xFF94A3B8),
                                        fontSize: 11,
                                      ),
                                    ),
                                ],
                              );
                            }).toList();
                          },
                        ),
                        getTouchedSpotIndicator: (barData, spotIndexes) {
                          return spotIndexes.map((index) {
                            return TouchedSpotIndicatorData(
                              FlLine(
                                color: const Color(0xFF10B981).withOpacity(0.5),
                                strokeWidth: 1.5,
                                dashArray: [4, 4],
                              ),
                              FlDotData(
                                show: true,
                                getDotPainter: (spot, percent, bar, idx) => FlDotCirclePainter(
                                  radius: 6,
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                  strokeColor: bar.color ?? const Color(0xFF10B981),
                                ),
                              ),
                            );
                          }).toList();
                        },
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: maxY > 0 ? (maxY / 4) : 1,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: const Color(0xFFF1F5F9),
                          strokeWidth: 1,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 68,
                            interval: maxY > 0 ? (maxY / 4) : null,
                            getTitlesWidget: (value, meta) {
                              if (value == 0) return const SizedBox.shrink();
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Text(
                                  _formatCompactCurrency(value),
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    fontFamily: 'Outfit',
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            interval: revenueByDay.length > 6
                                ? (revenueByDay.length / 5).ceilToDouble()
                                : 1,
                            getTitlesWidget: (value, meta) {
                              final int idx = value.toInt();
                              if (value == idx.toDouble() && idx >= 0 && idx < revenueByDay.length) {
                                final dateStr = revenueByDay[idx]['date'];
                                final date = DateTime.tryParse(dateStr);
                                if (date != null) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      DateFormat('dd MMM').format(date),
                                      style: const TextStyle(
                                        color: Color(0xFF94A3B8),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  );
                                }
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        if (_showGrossRevenue)
                          LineChartBarData(
                            spots: grossSpots,
                            isCurved: true,
                            preventCurveOverShooting: true,
                            curveSmoothness: 0.35,
                            color: const Color(0xFF10B981),
                            barWidth: 3.5,
                            isStrokeCapRound: true,
                            dotData: FlDotData(
                              show: grossSpots.length <= 15,
                              getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                                radius: 3,
                                color: const Color(0xFF10B981),
                                strokeWidth: 2,
                                strokeColor: Colors.white,
                              ),
                            ),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF10B981).withOpacity(0.24),
                                  const Color(0xFF10B981).withOpacity(0.04),
                                  const Color(0xFF10B981).withOpacity(0.0),
                                ],
                                stops: const [0.0, 0.7, 1.0],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                        if (_showPlatformFee)
                          LineChartBarData(
                            spots: platformFeeSpots,
                            isCurved: true,
                            preventCurveOverShooting: true,
                            curveSmoothness: 0.35,
                            color: const Color(0xFF0284C7),
                            barWidth: 2.2,
                            isStrokeCapRound: true,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF0284C7).withOpacity(0.12),
                                  const Color(0xFF0284C7).withOpacity(0.0),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
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

  Widget _buildInteractiveSeriesChip({
    required String label,
    required Color color,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isActive ? color.withOpacity(0.12) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? color.withOpacity(0.4) : const Color(0xFFCBD5E1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: isActive ? color : const Color(0xFF94A3B8),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? color : const Color(0xFF64748B),
                fontFamily: 'Outfit',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueInfoCard(
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color accentColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accentColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Outfit',
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // USER DISTRIBUTION DONUT CHART
  // --------------------------------------------------------------------------
  Widget _buildUserDistributionChart() {
    final overview = _stats!['overview'] ?? {};
    final totalUsers = (overview['totalActiveUsers'] ?? 0) as int;
    if (totalUsers == 0) return const SizedBox.shrink();

    final learners = (overview['totalLearners'] ?? 0) as int;
    final trainers = (overview['totalTrainers'] ?? 0) as int;
    final others = (totalUsers - learners - trainers).clamp(0, totalUsers);

    final double learnerPct = totalUsers > 0 ? (learners / totalUsers * 100) : 0;
    final double trainerPct = totalUsers > 0 ? (trainers / totalUsers * 100) : 0;
    final double otherPct = totalUsers > 0 ? (others / totalUsers * 100) : 0;

    // Dynamic center feedback
    String centerCount = '$totalUsers';
    String centerLabel = 'TOTAL COMMUNITY';
    Color centerColor = const Color(0xFF0F172A);

    if (_touchedPieIndex == 0) {
      centerCount = '$learners';
      centerLabel = 'LEARNERS (${learnerPct.toStringAsFixed(1)}%)';
      centerColor = const Color(0xFF3B82F6);
    } else if (_touchedPieIndex == 1) {
      centerCount = '$trainers';
      centerLabel = 'TRAINERS (${trainerPct.toStringAsFixed(1)}%)';
      centerColor = const Color(0xFF8B5CF6);
    } else if (_touchedPieIndex == 2) {
      centerCount = '$others';
      centerLabel = 'STAFF/ADMINS (${otherPct.toStringAsFixed(1)}%)';
      centerColor = const Color(0xFFF59E0B);
    }

    return Container(
      height: 520,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.035),
            blurRadius: 22,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'User Distribution',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Community segment breakdown by account role',
            style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    pieTouchData: PieTouchData(
                      touchCallback: (FlTouchEvent event, pieTouchResponse) {
                        setState(() {
                          if (!event.isInterestedForInteractions ||
                              pieTouchResponse == null ||
                              pieTouchResponse.touchedSection == null) {
                            _touchedPieIndex = -1;
                            return;
                          }
                          _touchedPieIndex =
                              pieTouchResponse.touchedSection!.touchedSectionIndex;
                        });
                      },
                    ),
                    sectionsSpace: 3,
                    centerSpaceRadius: 62,
                    sections: [
                      PieChartSectionData(
                        color: const Color(0xFF3B82F6),
                        value: learners.toDouble(),
                        title: '',
                        radius: _touchedPieIndex == 0 ? 34 : 26,
                      ),
                      PieChartSectionData(
                        color: const Color(0xFF8B5CF6),
                        value: trainers.toDouble(),
                        title: '',
                        radius: _touchedPieIndex == 1 ? 34 : 26,
                      ),
                      PieChartSectionData(
                        color: const Color(0xFFF59E0B),
                        value: others.toDouble(),
                        title: '',
                        radius: _touchedPieIndex == 2 ? 34 : 26,
                      ),
                    ],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 180),
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: centerColor,
                        fontFamily: 'Outfit',
                        letterSpacing: -1,
                      ),
                      child: Text(centerCount),
                    ),
                    const SizedBox(height: 2),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 180),
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: centerColor.withOpacity(0.8),
                        letterSpacing: 0.8,
                      ),
                      child: Text(centerLabel),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildInteractiveLegendRow(
            index: 0,
            color: const Color(0xFF3B82F6),
            label: 'Learners',
            value: learners,
            percentage: '${learnerPct.toStringAsFixed(1)}%',
            fraction: learnerPct / 100,
          ),
          const SizedBox(height: 8),
          _buildInteractiveLegendRow(
            index: 1,
            color: const Color(0xFF8B5CF6),
            label: 'Trainers',
            value: trainers,
            percentage: '${trainerPct.toStringAsFixed(1)}%',
            fraction: trainerPct / 100,
          ),
          const SizedBox(height: 8),
          _buildInteractiveLegendRow(
            index: 2,
            color: const Color(0xFFF59E0B),
            label: 'Staff / Admins',
            value: others,
            percentage: '${otherPct.toStringAsFixed(1)}%',
            fraction: otherPct / 100,
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Active Learners (30d)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
                Text(
                  '${_stats!['learningPerformance']?['activeLearners30d'] ?? 0}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                    fontSize: 15,
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

  Widget _buildInteractiveLegendRow({
    required int index,
    required Color color,
    required String label,
    required int value,
    required String percentage,
    required double fraction,
  }) {
    final isHovered = _touchedPieIndex == index;
    return MouseRegion(
      onEnter: (_) => setState(() => _touchedPieIndex = index),
      onExit: (_) => setState(() => _touchedPieIndex = -1),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: isHovered ? color.withOpacity(0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: isHovered ? const Color(0xFF0F172A) : const Color(0xFF475569),
                  fontWeight: isHovered ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            Text(
              '$value',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
                fontFamily: 'Outfit',
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                percentage,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // PLATFORM GROWTH CHART (DUAL LINE)
  // --------------------------------------------------------------------------
  Widget _buildPlatformGrowthChart() {
    final trends = _stats!['trends'] ?? {};
    final userGrowthByDay = (trends['userGrowthByDay'] as List?) ?? [];

    if (userGrowthByDay.isEmpty) return const SizedBox.shrink();

    List<FlSpot> userSpots = [];
    List<FlSpot> enrollSpots = [];
    double maxY = 0;

    int sumUsers = 0;
    int sumEnrolls = 0;

    for (int i = 0; i < userGrowthByDay.length; i++) {
      double users = (userGrowthByDay[i]['newUsers'] ?? 0).toDouble();
      double enrolls = (userGrowthByDay[i]['newEnrollments'] ?? 0).toDouble();

      sumUsers += users.toInt();
      sumEnrolls += enrolls.toInt();

      if (users > maxY) maxY = users;
      if (enrolls > maxY) maxY = enrolls;

      userSpots.add(FlSpot(i.toDouble(), users));
      enrollSpots.add(FlSpot(i.toDouble(), enrolls));
    }
    if (maxY == 0) maxY = 10;

    return Container(
      height: 450,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.035),
            blurRadius: 22,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Acquisition & Enrollment Growth',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                      fontFamily: 'Outfit',
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Daily user sign-ups vs course registration momentum',
                    style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
              Row(
                children: [
                  _buildInteractiveSeriesChip(
                    label: 'New Users ($sumUsers)',
                    color: const Color(0xFF3B82F6),
                    isActive: _showNewUsersLine,
                    onTap: () => setState(() => _showNewUsersLine = !_showNewUsersLine),
                  ),
                  const SizedBox(width: 10),
                  _buildInteractiveSeriesChip(
                    label: 'Enrollments ($sumEnrolls)',
                    color: const Color(0xFFF59E0B),
                    isActive: _showEnrollmentsLine,
                    onTap: () => setState(() => _showEnrollmentsLine = !_showEnrollmentsLine),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: maxY * 1.2,
                lineTouchData: LineTouchData(
                  enabled: true,
                  handleBuiltInTouches: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => const Color(0xFF0F172A),
                    tooltipBorderRadius: BorderRadius.circular(10),
                    tooltipPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    maxContentWidth: 240,
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipItems: (List<LineBarSpot> touchedSpots) {
                      if (touchedSpots.isEmpty) return [];
                      final first = touchedSpots.first;
                      final int idx = first.x.toInt();
                      String dateLabel = '';
                      if (idx >= 0 && idx < userGrowthByDay.length) {
                        final date = DateTime.tryParse(userGrowthByDay[idx]['date'] ?? '');
                        if (date != null) dateLabel = DateFormat('dd MMM, yyyy').format(date);
                      }

                      return touchedSpots.map((spot) {
                        final bool isUser = spot.bar.color == const Color(0xFF3B82F6);
                        return LineTooltipItem(
                          spot == touchedSpots.first ? '$dateLabel\n' : '',
                          const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w500),
                          children: [
                            TextSpan(
                              text: isUser ? '• New Users: ' : '• Enrollments: ',
                              style: TextStyle(
                                color: isUser ? const Color(0xFF60A5FA) : const Color(0xFFFBBF24),
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                            TextSpan(
                              text: '${spot.y.toInt()}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                fontFamily: 'Outfit',
                              ),
                            ),
                          ],
                        );
                      }).toList();
                    },
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY > 0 ? (maxY / 4) : 1,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: const Color(0xFFF1F5F9),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      interval: maxY > 0 ? (maxY / 4) : null,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Outfit',
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: userGrowthByDay.length > 6
                          ? (userGrowthByDay.length / 5).ceilToDouble()
                          : 1,
                      getTitlesWidget: (value, meta) {
                        final int idx = value.toInt();
                        if (value == idx.toDouble() && idx >= 0 && idx < userGrowthByDay.length) {
                          final dateStr = userGrowthByDay[idx]['date'];
                          final date = DateTime.tryParse(dateStr);
                          if (date != null) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                DateFormat('dd MMM').format(date),
                                style: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          }
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  if (_showNewUsersLine)
                    LineChartBarData(
                      spots: userSpots,
                      isCurved: true,
                      preventCurveOverShooting: true,
                      curveSmoothness: 0.35,
                      color: const Color(0xFF3B82F6),
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF3B82F6).withOpacity(0.18),
                            const Color(0xFF3B82F6).withOpacity(0.0),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  if (_showEnrollmentsLine)
                    LineChartBarData(
                      spots: enrollSpots,
                      isCurved: true,
                      preventCurveOverShooting: true,
                      curveSmoothness: 0.35,
                      color: const Color(0xFFF59E0B),
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFFF59E0B).withOpacity(0.18),
                            const Color(0xFFF59E0B).withOpacity(0.0),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
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

  // --------------------------------------------------------------------------
  // BOTTOM SECTION: APPROVALS PIPELINE & QUICK ACTIONS
  // --------------------------------------------------------------------------
  Widget _buildBottomSection(bool isDesktop) {
    if (!isDesktop) {
      return Column(
        children: [
          _buildContentStatusPipeline(),
          const SizedBox(height: 24),
          _buildQuickActions(),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 5, child: _buildContentStatusPipeline()),
        const SizedBox(width: 24),
        Expanded(flex: 3, child: _buildQuickActions()),
      ],
    );
  }

  Widget _buildContentStatusPipeline() {
    final pending = _stats!['pendingActions'] ?? {};
    final contentHealth = _stats!['contentHealth'] ?? {};
    final approvalRate = (contentHealth['approvalRate'] ?? 1.0) * 100;

    return Container(
      height: 440,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.035),
            blurRadius: 22,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Pending Approvals Pipeline',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                      fontFamily: 'Outfit',
                    ),
                  ),
                  SizedBox(height: 2),
                  Text('Content queue awaiting verification and publishing', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFDCFCE7)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'Rate ${approvalRate.toStringAsFixed(0)}%',
                      style: const TextStyle(color: Color(0xFF16A34A), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _InteractivePipelineItem(
                  label: 'Courses',
                  count: pending['coursesPendingReview'] ?? 0,
                  color: const Color(0xFF8B5CF6),
                  icon: Icons.auto_stories_rounded,
                  onTap: () => widget.onNavigate?.call(6),
                ),
                const SizedBox(width: 14),
                _InteractivePipelineItem(
                  label: 'Exams',
                  count: pending['examsPendingReview'] ?? 0,
                  color: const Color(0xFF3B82F6),
                  icon: Icons.assignment_turned_in_rounded,
                  onTap: () => widget.onNavigate?.call(6),
                ),
                const SizedBox(width: 14),
                _InteractivePipelineItem(
                  label: 'Trainer Apps',
                  count: pending['trainerAppsPending'] ?? 0,
                  color: const Color(0xFF0284C7),
                  icon: Icons.badge_rounded,
                  onTap: () => widget.onNavigate?.call(6),
                ),
                const SizedBox(width: 14),
                _InteractivePipelineItem(
                  label: 'Tickets',
                  count: pending['ticketsPending'] ?? 0,
                  color: const Color(0xFFF59E0B),
                  icon: Icons.headset_mic_rounded,
                  onTap: () => widget.onNavigate?.call(8),
                ),
                const SizedBox(width: 14),
                _InteractivePipelineItem(
                  label: 'Comments',
                  count: pending['commentsPendingModeration'] ?? 0,
                  color: const Color(0xFFF43F5E),
                  icon: Icons.chat_bubble_rounded,
                  onTap: () => widget.onNavigate?.call(4),
                ),
              ],
            ),
          ),
          const Spacer(),
          const Divider(color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: _buildDateInfo('Oldest Pending Course', contentHealth['oldestPendingCourseDate'] as String?)),
                Container(width: 1, height: 28, color: const Color(0xFFE2E8F0)),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16.0),
                    child: _buildDateInfo('Oldest Pending Exam', contentHealth['oldestPendingExamDate'] as String?),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateInfo(String label, String? dateStr) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 3),
        Text(
          dateStr != null ? dateStr.split('T')[0] : 'None in queue',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
            fontFamily: 'Outfit',
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Container(
      height: 440,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F766E), Color(0xFF0D9488), Color(0xFF10B981)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D9488).withOpacity(0.25),
            blurRadius: 22,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Operations',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Direct access to platform management tools',
            style: TextStyle(fontSize: 12, color: Colors.white70),
          ),
          const SizedBox(height: 20),
          _buildActionItem(Icons.verified_rounded, 'Review Course Approvals', onTap: () => widget.onNavigate?.call(6)),
          _buildActionItem(Icons.manage_accounts_rounded, 'Manage User Accounts', onTap: () => widget.onNavigate?.call(1)),
          _buildActionItem(Icons.headset_mic_rounded, 'Support Tickets Desk', onTap: () => widget.onNavigate?.call(8)),
          _buildActionItem(Icons.admin_panel_settings_rounded, 'Security & Role Matrix', onTap: () => widget.onNavigate?.call(3)),
          _buildActionItem(Icons.chat_bubble_rounded, 'Moderate Comments', onTap: () => widget.onNavigate?.call(4)),
        ],
      ),
    );
  }

  Widget _buildActionItem(IconData icon, String label, {VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap ?? () {},
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(icon, color: Colors.white, size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white60,
                  size: 13,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // LEARNING ANALYTICS (FUNNEL & EXAMS)
  // --------------------------------------------------------------------------
  Widget _buildLearningAnalytics(bool isDesktop) {
    if (!isDesktop) {
      return Column(
        children: [
          _buildLearningFunnel(),
          const SizedBox(height: 24),
          _buildExamPerformance(),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 5, child: _buildLearningFunnel()),
        const SizedBox(width: 24),
        Expanded(flex: 3, child: _buildExamPerformance()),
      ],
    );
  }

  Widget _buildLearningFunnel() {
    final learning = _stats!['learningPerformance'] ?? {};
    final funnel = learning['learningFunnel'] ?? {};
    final completionRate = ((learning['completionRate'] ?? 0.0) * 100).toStringAsFixed(1);

    final int registered = funnel['registered'] ?? 0;
    final int enrolled = funnel['enrolledAtLeast1'] ?? 0;
    final int activelyLearning = funnel['activelyLearning'] ?? 0;
    final int completed = funnel['completedAtLeast1Course'] ?? 0;
    final int certified = funnel['certified'] ?? 0;

    final double maxVal = registered > 0 ? registered.toDouble() : 1.0;

    return Container(
      height: 440,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.035),
            blurRadius: 22,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Student Learning Funnel',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                      fontFamily: 'Outfit',
                    ),
                  ),
                  SizedBox(height: 2),
                  Text('Conversion from registration to certificate completion', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Text(
                  'Completion: $completionRate%',
                  style: const TextStyle(
                    color: Color(0xFF16A34A),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    fontFamily: 'Outfit',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _buildFunnelStep(
            stepNumber: 1,
            label: 'Registered Accounts',
            count: registered,
            percentageOfTop: 100.0,
            widthFraction: 1.0,
            color: const Color(0xFF3B82F6),
            dropOffRate: registered > 0 && enrolled < registered
                ? (registered - enrolled) / registered * 100
                : null,
          ),
          _buildFunnelStep(
            stepNumber: 2,
            label: 'Course Enrolled (≥1)',
            count: enrolled,
            percentageOfTop: registered > 0 ? (enrolled / registered * 100) : 0,
            widthFraction: (enrolled / maxVal).clamp(0.02, 1.0),
            color: const Color(0xFF0284C7),
            dropOffRate: enrolled > 0 && activelyLearning < enrolled
                ? (enrolled - activelyLearning) / enrolled * 100
                : null,
          ),
          _buildFunnelStep(
            stepNumber: 3,
            label: 'Actively Learning (30d)',
            count: activelyLearning,
            percentageOfTop: registered > 0 ? (activelyLearning / registered * 100) : 0,
            widthFraction: (activelyLearning / maxVal).clamp(0.02, 1.0),
            color: const Color(0xFF8B5CF6),
            dropOffRate: activelyLearning > 0 && completed < activelyLearning
                ? (activelyLearning - completed) / activelyLearning * 100
                : null,
          ),
          _buildFunnelStep(
            stepNumber: 4,
            label: 'Course Completed (≥1)',
            count: completed,
            percentageOfTop: registered > 0 ? (completed / registered * 100) : 0,
            widthFraction: (completed / maxVal).clamp(0.02, 1.0),
            color: const Color(0xFFF59E0B),
            dropOffRate: completed > 0 && certified < completed
                ? (completed - certified) / completed * 100
                : null,
          ),
          _buildFunnelStep(
            stepNumber: 5,
            label: 'Certified Graduates',
            count: certified,
            percentageOfTop: registered > 0 ? (certified / registered * 100) : 0,
            widthFraction: (certified / maxVal).clamp(0.02, 1.0),
            color: const Color(0xFF10B981),
            dropOffRate: null,
          ),
        ],
      ),
    );
  }

  Widget _buildFunnelStep({
    required int stepNumber,
    required String label,
    required int count,
    required double percentageOfTop,
    required double widthFraction,
    required Color color,
    double? dropOffRate,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$stepNumber',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: color,
                      fontFamily: 'Outfit',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 148,
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF334155),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  height: 22,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: widthFraction.clamp(0.02, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [color.withOpacity(0.75), color],
                        ),
                        borderRadius: BorderRadius.circular(11),
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 72,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '$count',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        fontFamily: 'Outfit',
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '(${percentageOfTop.toStringAsFixed(0)}%)',
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (dropOffRate != null && dropOffRate > 0)
            Padding(
              padding: const EdgeInsets.only(left: 178, top: 2, bottom: 2),
              child: Row(
                children: [
                  const Icon(Icons.arrow_downward_rounded, size: 10, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 2),
                  Text(
                    '${dropOffRate.toStringAsFixed(1)}% drop-off',
                    style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildExamPerformance() {
    final learning = _stats!['learningPerformance'] ?? {};
    final double avgScore = (learning['avgExamScore'] is num)
        ? (learning['avgExamScore'] as num).toDouble()
        : 0.0;
    final double passRate = (learning['examPassRate'] is num)
        ? (learning['examPassRate'] as num).toDouble()
        : 0.0;

    return Container(
      height: 440,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.035),
            blurRadius: 22,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Global Exam Performance',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 2),
          const Text('Mastery level and benchmark success rates', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildRadialGauge(
                value: avgScore.toStringAsFixed(1),
                progress: (avgScore / 10.0).clamp(0.0, 1.0),
                label: 'Avg Score / 10',
                badgeText: avgScore >= 7.5 ? 'Mastery' : 'Passing',
                color: const Color(0xFF3B82F6),
              ),
              _buildRadialGauge(
                value: '${(passRate * 100).toStringAsFixed(0)}%',
                progress: passRate.clamp(0.0, 1.0),
                label: 'Pass Benchmark',
                badgeText: (passRate * 100) >= 80 ? 'Optimal' : 'Standard',
                color: const Color(0xFF10B981),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Assessments Evaluated',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569),
                    fontSize: 13,
                  ),
                ),
                Text(
                  '${_stats!['overview']?['totalExamAttempts'] ?? 0}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    fontSize: 16,
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

  Widget _buildRadialGauge({
    required String value,
    required double progress,
    required String label,
    required String badgeText,
    required Color color,
  }) {
    return Column(
      children: [
        SizedBox(
          width: 96,
          height: 96,
          child: CustomPaint(
            painter: _RadialGaugePainter(
              progress: progress,
              trackColor: const Color(0xFFF1F5F9),
              progressColor: color,
              strokeWidth: 8,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                      fontFamily: 'Outfit',
                      letterSpacing: -0.5,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                        color: color,
                        fontFamily: 'Outfit',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // SUPPORT & AI ANALYTICS
  // --------------------------------------------------------------------------
  Widget _buildTicketAndAiAnalytics(bool isDesktop) {
    if (!isDesktop) {
      return Column(
        children: [
          _buildTicketAnalytics(),
          const SizedBox(height: 24),
          _buildAiUsage(),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 1, child: _buildTicketAnalytics()),
        const SizedBox(width: 24),
        Expanded(flex: 1, child: _buildAiUsage()),
      ],
    );
  }

  Widget _buildTicketAnalytics() {
    final tickets = _stats!['ticketHealth'] ?? {};
    final avgFirstResponse = (tickets['avgFirstResponseHours'] ?? 0.0).toStringAsFixed(1);
    final avgResolution = (tickets['avgResolutionHours'] ?? 0.0).toStringAsFixed(1);
    final byStatus = tickets['byStatus'] ?? {};

    final int pendingCount = (byStatus['PENDING'] as num? ?? byStatus['OPEN'] as num? ?? 0).toInt();
    final int processingCount = (byStatus['PROCESSING'] as num? ?? 0).toInt();
    final int resolvedCount = ((byStatus['APPROVED'] as num? ?? 0) +
            (byStatus['REJECTED'] as num? ?? 0) +
            (byStatus['RESOLVED'] as num? ?? 0))
        .toInt();
    final int totalTickets = pendingCount + processingCount + resolvedCount;
    final double resolutionRate = totalTickets > 0 ? (resolvedCount / totalTickets * 100) : 100.0;

    return Container(
      height: 420,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.035),
            blurRadius: 22,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Support Health & Tickets',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 2),
          const Text('Customer service responsiveness and resolution SLA', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildMetricBox(
                  'Avg First Response',
                  '$avgFirstResponse hrs',
                  Icons.schedule_rounded,
                  const Color(0xFFF59E0B),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricBox(
                  'Avg Resolution Time',
                  '$avgResolution hrs',
                  Icons.task_alt_rounded,
                  const Color(0xFF10B981),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildStatusRow('Pending Triage', pendingCount, const Color(0xFFEF4444)),
          _buildStatusRow('In Processing', processingCount, const Color(0xFFF59E0B)),
          _buildStatusRow('Resolved / Closed', resolvedCount, const Color(0xFF10B981)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Ticket Resolution SLA',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF16A34A),
                  ),
                ),
                Text(
                  '${resolutionRate.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF16A34A),
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

  Widget _buildAiUsage() {
    final ai = _stats!['aiUsage'] ?? {};
    final totalCalls = (ai['totalCalls'] ?? 0) as int;
    final successRate = ((ai['successRate'] ?? 0.0) * 100).toStringAsFixed(1);
    final double avgDuration = (ai['avgSuccessDurationMs'] is num)
        ? (ai['avgSuccessDurationMs'] as num).toDouble()
        : 0.0;
    final chatCalls = (ai['chatCalls'] ?? 0) as int;
    final embeddingCalls = (ai['embeddingCalls'] ?? 0) as int;

    String topFeatureText = 'None';
    if (totalCalls > 0) {
      if (chatCalls >= embeddingCalls && chatCalls > 0) {
        final pct = (chatCalls / totalCalls * 100).toStringAsFixed(0);
        topFeatureText = 'Chat Assistant ($pct%)';
      } else if (embeddingCalls > 0) {
        final pct = (embeddingCalls / totalCalls * 100).toStringAsFixed(0);
        topFeatureText = 'Vector Embeddings ($pct%)';
      } else {
        topFeatureText = 'AI Core ($totalCalls calls)';
      }
    }

    return Container(
      height: 420,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.035),
            blurRadius: 22,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AI Integration Health',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 2),
          const Text('Gemini API call traffic, latency and success rates', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildMetricBox(
                  'Total API Requests',
                  '$totalCalls',
                  Icons.bolt_rounded,
                  const Color(0xFF8B5CF6),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricBox(
                  'Average Latency',
                  '${avgDuration.toInt()}ms',
                  Icons.speed_rounded,
                  avgDuration <= 500
                      ? const Color(0xFF10B981)
                      : avgDuration <= 1500
                          ? const Color(0xFF0284C7)
                          : const Color(0xFFF59E0B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Operational Success Rate',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                  fontSize: 12,
                ),
              ),
              Text(
                '$successRate%',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF10B981),
                  fontFamily: 'Outfit',
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (ai['successRate'] ?? 0.0).toDouble(),
              backgroundColor: const Color(0xFFF1F5F9),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
              minHeight: 8,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Top Feature Usage',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F3FF),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFDDD6FE)),
                  ),
                  child: Text(
                    topFeatureText,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF7C3AED),
                      fontFamily: 'Outfit',
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

  Widget _buildMetricBox(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              fontFamily: 'Outfit',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF475569),
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          Text(
            '$count',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
              fontFamily: 'Outfit',
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // EMPTY CHART PLACEHOLDER
  // --------------------------------------------------------------------------
  Widget _buildEmptyChartState({required String title, required String message}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Icon(
                Icons.insights_rounded,
                color: Color(0xFF94A3B8),
                size: 32,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF334155),
                fontFamily: 'Outfit',
              ),
            ),
            const SizedBox(height: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF94A3B8),
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // CURRENCY FORMATTERS
  // --------------------------------------------------------------------------
  String _formatCurrency(dynamic amount) {
    if (amount == null) return '0 ₫';
    double val = (amount is num)
        ? amount.toDouble()
        : double.tryParse(amount.toString()) ?? 0;
    return '${NumberFormat('#,###').format(val)} ₫';
  }

  String _formatCompactCurrency(double amount) {
    if (amount >= 1000000000) {
      return '${(amount / 1000000000).toStringAsFixed(1)}B ₫';
    }
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M ₫';
    }
    if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}k ₫';
    }
    return '${amount.toInt()} ₫';
  }
}

// ============================================================================
// HELPER WIDGETS & PAINTERS FOR WORLD-CLASS UX/UI
// ============================================================================

/// Interactive KPI Card with micro hover lift and border lighting
class _InteractiveKpiCard extends StatefulWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color themeColor;
  final double width;
  final int? countToday;

  const _InteractiveKpiCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.themeColor,
    required this.width,
    this.countToday,
  });

  @override
  State<_InteractiveKpiCard> createState() => _InteractiveKpiCardState();
}

class _InteractiveKpiCardState extends State<_InteractiveKpiCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, _isHovered ? -4 : 0, 0),
        width: widget.width,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _isHovered
                ? widget.themeColor.withOpacity(0.35)
                : const Color(0xFFF1F5F9),
            width: _isHovered ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: _isHovered
                  ? widget.themeColor.withOpacity(0.12)
                  : const Color(0xFF0F172A).withOpacity(0.035),
              blurRadius: _isHovered ? 24 : 18,
              offset: Offset(0, _isHovered ? 8 : 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _isHovered
                        ? widget.themeColor
                        : widget.themeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    widget.icon,
                    color: _isHovered ? Colors.white : widget.themeColor,
                    size: 22,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  widget.value,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Outfit',
                    letterSpacing: -0.8,
                  ),
                ),
                if (widget.countToday != null && widget.countToday! > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.arrow_upward_rounded,
                            color: Color(0xFF059669), size: 12),
                        const SizedBox(width: 2),
                        Text(
                          '+${widget.countToday}',
                          style: const TextStyle(
                            color: Color(0xFF047857),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Outfit',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(
              widget.subtitle,
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Interactive Approvals Pipeline Card with instant action navigation
class _InteractivePipelineItem extends StatefulWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;
  final VoidCallback? onTap;

  const _InteractivePipelineItem({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
    this.onTap,
  });

  @override
  State<_InteractivePipelineItem> createState() => _InteractivePipelineItemState();
}

class _InteractivePipelineItemState extends State<_InteractivePipelineItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final hasItems = widget.count > 0;
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          transform: Matrix4.translationValues(0, _isHovered ? -3 : 0, 0),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: _isHovered
                ? widget.color.withOpacity(0.08)
                : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isHovered
                  ? widget.color.withOpacity(0.45)
                  : hasItems
                      ? widget.color.withOpacity(0.25)
                      : const Color(0xFFE2E8F0),
              width: 1.5,
            ),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: widget.color.withOpacity(0.12),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    )
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: hasItems
                          ? widget.color.withOpacity(0.12)
                          : const Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        widget.icon,
                        color: hasItems ? widget.color : const Color(0xFF94A3B8),
                        size: 22,
                      ),
                    ),
                  ),
                  if (hasItems)
                    Positioned(
                      top: -3,
                      right: -5,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: widget.color,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Text(
                          '${widget.count}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Outfit',
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 12.5,
                  color: _isHovered ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                hasItems ? '${widget.count} pending' : 'All clear',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: hasItems ? widget.color : const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom Radial Gauge Painter for Exam Mastery & Pass Benchmark rings
class _RadialGaugePainter extends CustomPainter {
  final double progress; // 0.0 to 1.0
  final Color trackColor;
  final Color progressColor;
  final double strokeWidth;

  _RadialGaugePainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    this.strokeWidth = 8,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background track ring
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    // Active progress arc
    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * math.pi * progress.clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RadialGaugePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.trackColor != trackColor;
  }
}
