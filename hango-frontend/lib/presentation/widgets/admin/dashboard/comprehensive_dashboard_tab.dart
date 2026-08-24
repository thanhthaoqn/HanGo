import 'dart:convert';
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
  int _periodDays = 30; // Default filter

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
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final token = await _authService.getToken();
      if (token == null) {
        if (!mounted) return;
        setState(() {
          _error = 'Unauthorized';
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

      if (!mounted) return;
      if (response.statusCode == 200) {
        setState(() {
          _stats = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load stats (${response.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Error fetching stats: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF28B79B)),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(color: Colors.red, fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchStats,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF28B79B),
              ),
              child: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ],
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
        _buildPlatformGrowthChart(), // NEW
        const SizedBox(height: 24),
        _buildBottomSection(widget.isDesktop), // Pipeline & Quick Actions
        const SizedBox(height: 24),
        _buildLearningAnalytics(widget.isDesktop), // Phase 2
        const SizedBox(height: 24),
        _buildTicketAndAiAnalytics(widget.isDesktop), // Phase 2 & 3
        const SizedBox(height: 48), // Bottom padding
      ],
    );
  }

  Widget _buildHeaderActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Platform Overview',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
            fontFamily: 'Outfit',
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _periodDays,
              icon: const Icon(
                Icons.calendar_today,
                size: 16,
                color: Color(0xFF64748B),
              ),
              style: const TextStyle(
                color: Color(0xFF334155),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              items: const [
                DropdownMenuItem(value: 7, child: Text('Last 7 Days')),
                DropdownMenuItem(value: 30, child: Text('Last 30 Days')),
                DropdownMenuItem(value: 90, child: Text('Last 3 Months')),
                DropdownMenuItem(value: 365, child: Text('Last 12 Months')),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() => _periodDays = val);
                  _fetchStats();
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildKpiGrid() {
    final overview = _stats!['overview'] ?? {};

    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = constraints.maxWidth > 800 ? 4 : 2;
        double width =
            (constraints.maxWidth - (crossAxisCount - 1) * 16) / crossAxisCount;

        int totalUsers = overview['totalActiveUsers'] ?? 0;
        int totalEnrollments = overview['totalEnrollments'] ?? 0;
        double avgEnrollments = totalUsers > 0
            ? totalEnrollments / totalUsers
            : 0.0;

        final learning = _stats!['learningPerformance'] ?? {};
        double avgScore = (learning['avgExamScore'] is num)
            ? (learning['avgExamScore'] as num).toDouble()
            : 0.0;

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _buildKpiCard(
              'Total Users',
              '$totalUsers',
              '${overview['totalLearners'] ?? 0} Learners · ${overview['totalTrainers'] ?? 0} Trainers',
              Icons.people,
              Colors.blue,
              width,
              countToday: overview['newUsersToday'],
            ),
            _buildKpiCard(
              'Enrollments',
              '$totalEnrollments',
              'Avg ${avgEnrollments.toStringAsFixed(1)} per user',
              Icons.school,
              Colors.orange,
              width,
              countToday: overview['newEnrollmentsToday'],
            ),
            _buildKpiCard(
              'Courses',
              '${overview['totalPublishedCourses'] ?? 0}',
              '${overview['totalFreeCourses'] ?? 0} Free · ${overview['totalPaidCourses'] ?? 0} Paid',
              Icons.book,
              Colors.purple,
              width,
              countToday: overview['newCoursesToday'],
            ),
            _buildKpiCard(
              'Exam Attempts',
              '${overview['totalExamAttempts'] ?? 0}',
              'Avg Score: ${avgScore.toStringAsFixed(1)} / 10',
              Icons.assignment,
              Colors.indigo,
              width,
              countToday: overview['newExamAttemptsToday'],
            ),
          ],
        );
      },
    );
  }

  Widget _buildKpiCard(
    String title,
    String value,
    String subtitle,
    IconData icon,
    MaterialColor color,
    double width, {
    int? countToday,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
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
                    color: Color(0xFF64748B),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color.shade600, size: 22),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Outfit',
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ),
              if (countToday != null && countToday > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  margin: const EdgeInsets.only(bottom: 4, left: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.green.shade100),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.arrow_upward,
                        color: Colors.green.shade600,
                        size: 12,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '$countToday today',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildMainCharts(bool isDesktop) {
    final revenueChart = _buildRevenueChart();
    final userDistributionChart = _buildUserDistributionChart();

    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: revenueChart),
          const SizedBox(width: 24),
          Expanded(flex: 1, child: userDistributionChart),
        ],
      );
    } else {
      return Column(
        children: [revenueChart, const SizedBox(height: 24), userDistributionChart],
      );
    }
  }

  Widget _buildRevenueChart() {
    final trends = _stats!['trends'] ?? {};
    final revenueByDay = (trends['revenueByDay'] as List?) ?? [];
    final revenue = _stats!['revenue'] ?? {};

    List<FlSpot> spots = [];
    double maxY = 0;
    for (int i = 0; i < revenueByDay.length; i++) {
      double val = (revenueByDay[i]['amount'] ?? 0).toDouble();
      if (val > maxY) maxY = val;
      spots.add(FlSpot(i.toDouble(), val));
    }

    return Container(
      height: 480,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Revenue Trend',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildRevenueInfoCard(
                  'Total Revenue',
                  _formatCurrency(revenue['totalRevenue']),
                  'Avg: ${_formatCurrency(revenue['avgTransactionValue'])} / txn',
                  Icons.attach_money,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildRevenueInfoCard(
                  'Transactions',
                  '${revenue['transactionCount'] ?? 0}',
                  'Platform Fee: ${_formatCurrency(revenue['platformFee'])}',
                  Icons.receipt_long,
                  Colors.teal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: revenueByDay.isEmpty
                ? const Center(child: Text('No data for selected period'))
                : LineChart(
                    LineChartData(
                      minY: 0,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: const Color(0xFFF1F5F9),
                          strokeWidth: 1,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 60,
                            interval: maxY > 0 ? (maxY / 5) : null,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                _formatCompactCurrency(value),
                                style: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 11,
                                ),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: revenueByDay.length > 0 ? (revenueByDay.length / 6).ceilToDouble() : 1,
                            getTitlesWidget: (value, meta) {
                              if (value == value.toInt().toDouble() && value.toInt() >= 0 && value.toInt() < revenueByDay.length) {
                                final dateStr = revenueByDay[value.toInt()]['date'];
                                final date = DateTime.tryParse(dateStr);
                                if (date != null) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      DateFormat('MMM d').format(date),
                                      style: const TextStyle(
                                        color: Color(0xFF94A3B8),
                                        fontSize: 11,
                                      ),
                                    ),
                                  );
                                }
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          preventCurveOverShooting: true,
                          curveSmoothness: 0.35,
                          color: const Color(0xFF10B981),
                          barWidth: 4,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF10B981).withOpacity(0.25),
                                const Color(0xFF10B981).withOpacity(0.0),
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

  Widget _buildRevenueInfoCard(
    String title,
    String value,
    String subtitle,
    IconData icon,
    MaterialColor color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
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
                    color: Color(0xFF64748B),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, color: color.shade600, size: 20),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 24,
                fontWeight: FontWeight.bold,
                fontFamily: 'Outfit',
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildPlatformGrowthChart() {
    final trends = _stats!['trends'] ?? {};
    final userGrowthByDay = (trends['userGrowthByDay'] as List?) ?? [];
    
    if (userGrowthByDay.isEmpty) return const SizedBox.shrink();

    List<FlSpot> userSpots = [];
    List<FlSpot> enrollSpots = [];
    double maxY = 0;

    for (int i = 0; i < userGrowthByDay.length; i++) {
      double users = (userGrowthByDay[i]['newUsers'] ?? 0).toDouble();
      double enrolls = (userGrowthByDay[i]['newEnrollments'] ?? 0).toDouble();
      
      if (users > maxY) maxY = users;
      if (enrolls > maxY) maxY = enrolls;
      
      userSpots.add(FlSpot(i.toDouble(), users));
      enrollSpots.add(FlSpot(i.toDouble(), enrolls));
    }

    return Container(
      height: 480,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Platform Growth Trend',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                  fontFamily: 'Outfit',
                ),
              ),
              Row(
                children: [
                  Row(
                    children: [
                      Container(width: 12, height: 12, decoration: BoxDecoration(color: const Color(0xFF3B82F6), borderRadius: BorderRadius.circular(2))),
                      const SizedBox(width: 6),
                      const Text('New Users', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Row(
                    children: [
                      Container(width: 12, height: 12, decoration: BoxDecoration(color: const Color(0xFFF59E0B), borderRadius: BorderRadius.circular(2))),
                      const SizedBox(width: 6),
                      const Text('New Enrollments', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    ],
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
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: const Color(0xFFF1F5F9),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      interval: maxY > 0 ? (maxY / 5).ceilToDouble() : null,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 11,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: userGrowthByDay.length > 0 ? (userGrowthByDay.length / 6).ceilToDouble() : 1,
                      getTitlesWidget: (value, meta) {
                        if (value == value.toInt().toDouble() && value.toInt() >= 0 && value.toInt() < userGrowthByDay.length) {
                          final dateStr = userGrowthByDay[value.toInt()]['date'];
                          final date = DateTime.tryParse(dateStr);
                          if (date != null) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                DateFormat('MMM d').format(date),
                                style: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 11,
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
                          const Color(0xFF3B82F6).withOpacity(0.3),
                          const Color(0xFF3B82F6).withOpacity(0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
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
                          const Color(0xFFF59E0B).withOpacity(0.3),
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

  Widget _buildUserDistributionChart() {
    final overview = _stats!['overview'] ?? {};
    final totalUsers = (overview['totalActiveUsers'] ?? 0) as int;
    if (totalUsers == 0) return const SizedBox.shrink();

    final learners = (overview['totalLearners'] ?? 0) as int;
    final trainers = (overview['totalTrainers'] ?? 0) as int;
    final others = totalUsers - learners - trainers;

    return Container(
      height: 480,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
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
              color: Color(0xFF1E293B),
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 60,
                    sections: [
                      PieChartSectionData(
                        color: const Color(0xFF3B82F6),
                        value: learners.toDouble(),
                        title: '',
                        radius: 30,
                      ),
                      PieChartSectionData(
                        color: const Color(0xFF8B5CF6),
                        value: trainers.toDouble(),
                        title: '',
                        radius: 30,
                      ),
                      PieChartSectionData(
                        color: const Color(0xFFF59E0B),
                        value: others.toDouble(),
                        title: '',
                        radius: 30,
                      ),
                    ],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$totalUsers',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                        fontFamily: 'Outfit',
                      ),
                    ),
                    const Text(
                      'Total',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildLegendItem(const Color(0xFF3B82F6), 'Learners', learners),
              _buildLegendItem(const Color(0xFF8B5CF6), 'Trainers', trainers),
              _buildLegendItem(const Color(0xFFF59E0B), 'Others', others),
            ],
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Active Learners (30d)',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
                Text(
                  '${_stats!['learningPerformance']?['activeLearners30d'] ?? 0}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3B82F6),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label, int value) {
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '$value',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
            fontFamily: 'Outfit',
          ),
        ),
      ],
    );
  }

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
        Expanded(flex: 2, child: _buildContentStatusPipeline()),
        const SizedBox(width: 24),
        Expanded(flex: 1, child: _buildQuickActions()),
      ],
    );
  }

  Widget _buildContentStatusPipeline() {
    final pending = _stats!['pendingActions'] ?? {};
    final contentHealth = _stats!['contentHealth'] ?? {};
    final approvalRate = (contentHealth['approvalRate'] ?? 1.0) * 100;

    return Container(
      height: 420,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pending Approvals Pipeline',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 24),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildPipelineItem(
                  'Courses',
                  pending['coursesPendingReview'] ?? 0,
                  Colors.purple,
                ),
                const SizedBox(width: 16),
                _buildPipelineItem(
                  'Exams',
                  pending['examsPendingReview'] ?? 0,
                  Colors.indigo,
                ),
                const SizedBox(width: 16),
                _buildPipelineItem(
                  'Trainer Apps',
                  pending['trainerAppsPending'] ?? 0,
                  Colors.blue,
                ),
                const SizedBox(width: 16),
                _buildPipelineItem(
                  'Tickets',
                  pending['ticketsPending'] ?? 0,
                  Colors.orange,
                ),
                const SizedBox(width: 16),
                _buildPipelineItem(
                  'Comments',
                  pending['commentsPendingModeration'] ?? 0,
                  Colors.red,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Divider(color: Color(0xFFF1F5F9)),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(
                Icons.check_circle,
                color: Color(0xFF28B79B),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Approval Rate: ${approvalRate.toStringAsFixed(1)}%',
                style: const TextStyle(
                  color: Color(0xFF1E293B),
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (pending['coursesPendingReview'] > 0 ||
                  pending['examsPendingReview'] > 0)
                const Padding(
                  padding: EdgeInsets.only(left: 16.0),
                  child: Text(
                    'Review needed',
                    style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: _buildDateInfo(
                    'Oldest Course',
                    contentHealth['oldestPendingCourseDate'] as String?,
                  ),
                ),
                Container(width: 1, height: 24, color: const Color(0xFFE2E8F0)),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12.0),
                    child: _buildDateInfo(
                      'Oldest Exam',
                      contentHealth['oldestPendingExamDate'] as String?,
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

  Widget _buildDateInfo(String label, String? dateStr) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 2),
        Text(
          dateStr != null ? dateStr.split('T')[0] : 'None',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }

  Widget _buildPipelineItem(String label, int count, MaterialColor color) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: count > 0 ? color.shade50 : const Color(0xFFF8FAFC),
            shape: BoxShape.circle,
            border: Border.all(
              color: count > 0 ? color.shade200 : const Color(0xFFE2E8F0),
            ),
          ),
          child: Center(
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: count > 0 ? color.shade700 : const Color(0xFF94A3B8),
                fontFamily: 'Outfit',
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Container(
      height: 420,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF28B79B), Color(0xFF1F9E84)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 24),
          _buildActionItem(
            Icons.playlist_add_check,
            'Review Pending Courses',
            onTap: () => widget.onNavigate?.call(6),
          ),
          _buildActionItem(
            Icons.manage_accounts,
            'Manage Accounts',
            onTap: () => widget.onNavigate?.call(1),
          ),
          _buildActionItem(
            Icons.headset_mic,
            'View Open Tickets',
            onTap: () => widget.onNavigate?.call(8),
          ),
          _buildActionItem(
            Icons.people_alt,
            'Manage Users & Roles',
            onTap: () => widget.onNavigate?.call(3),
          ),
          _buildActionItem(
            Icons.forum,
            'Moderate Comments',
            onTap: () => widget.onNavigate?.call(4),
          ),
        ],
      ),
    );
  }

  Widget _buildActionItem(IconData icon, String label, {VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap ?? () {},
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white54,
                  size: 14,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatCurrency(dynamic amount) {
    if (amount == null) return '0 đ';
    double val = (amount is num)
        ? amount.toDouble()
        : double.tryParse(amount.toString()) ?? 0;
    return '${NumberFormat('#,###').format(val)} đ';
  }

  String _formatCompactCurrency(double amount) {
    if (amount >= 1000000000)
      return '${(amount / 1000000000).toStringAsFixed(1)}B đ';
    if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(1)}M đ';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(1)}k đ';
    return '${amount.toInt()} đ';
  }

  // --- PHASE 2 & 3 SECTIONS ---

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
        Expanded(flex: 3, child: _buildLearningFunnel()),
        const SizedBox(width: 24),
        Expanded(flex: 2, child: _buildExamPerformance()),
      ],
    );
  }

  Widget _buildLearningFunnel() {
    final learning = _stats!['learningPerformance'] ?? {};
    final funnel = learning['learningFunnel'] ?? {};
    final completionRate = ((learning['completionRate'] ?? 0.0) * 100)
        .toStringAsFixed(1);

    final int registered = funnel['registered'] ?? 0;
    final double maxVal = registered > 0 ? registered.toDouble() : 1.0;

    return Container(
      height: 400,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
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
              const Text(
                'Learning Funnel',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                  fontFamily: 'Outfit',
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Completion: $completionRate%',
                  style: const TextStyle(
                    color: Color(0xFF16A34A),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildFunnelStep(
            'Registered Users',
            registered,
            (registered / maxVal).clamp(0.0, 1.0),
            Colors.blue,
          ),
          _buildFunnelStep(
            'Enrolled (≥1 Course)',
            funnel['enrolledAtLeast1'] ?? 0,
            ((funnel['enrolledAtLeast1'] ?? 0) / maxVal).clamp(0.0, 1.0),
            Colors.indigo,
          ),
          _buildFunnelStep(
            'Actively Learning (30d)',
            funnel['activelyLearning'] ?? 0,
            ((funnel['activelyLearning'] ?? 0) / maxVal).clamp(0.0, 1.0),
            Colors.purple,
          ),
          _buildFunnelStep(
            'Completed (≥1 Course)',
            funnel['completedAtLeast1Course'] ?? 0,
            ((funnel['completedAtLeast1Course'] ?? 0) / maxVal).clamp(0.0, 1.0),
            Colors.orange,
          ),
          _buildFunnelStep(
            'Certified',
            funnel['certified'] ?? 0,
            ((funnel['certified'] ?? 0) / maxVal).clamp(0.0, 1.0),
            Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildFunnelStep(
    String label,
    int count,
    double widthFraction,
    MaterialColor color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Row(
            children: [
              SizedBox(
                width: 140,
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  height: 24,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: widthFraction,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [color.shade300, color.shade500],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 40,
                child: Text(
                  '$count',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildExamPerformance() {
    final learning = _stats!['learningPerformance'] ?? {};
    final avgScore = (learning['avgExamScore'] ?? 0.0).toStringAsFixed(1);
    final passRate = ((learning['examPassRate'] ?? 0.0) * 100).toStringAsFixed(
      0,
    );

    return Container(
      height: 400,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
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
              color: Color(0xFF1E293B),
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildCircularStat(
                avgScore,
                'Avg Score',
                const Color(0xFF3B82F6),
              ),
              _buildCircularStat(
                '$passRate%',
                'Pass Rate',
                const Color(0xFF10B981),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Exams Taken',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
                Text(
                  '${_stats!['overview']?['totalExamAttempts'] ?? 0}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3B82F6),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircularStat(String value, String label, Color color) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 4),
          ),
          child: Center(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
                fontFamily: 'Outfit',
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

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
    final avgFirstResponse = (tickets['avgFirstResponseHours'] ?? 0.0)
        .toStringAsFixed(1);
    final avgResolution = (tickets['avgResolutionHours'] ?? 0.0)
        .toStringAsFixed(1);
    final byStatus = tickets['byStatus'] ?? {};

    return Container(
      height: 400,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Support Health (Tickets)',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildMetricBox(
                  'Avg Response',
                  '$avgFirstResponse hrs',
                  Icons.timer,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricBox(
                  'Avg Resolution',
                  '$avgResolution hrs',
                  Icons.check_circle,
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildStatusRow('Open', byStatus['OPEN'] ?? 0, Colors.red),
          _buildStatusRow(
            'Processing',
            byStatus['PROCESSING'] ?? 0,
            Colors.orange,
          ),
          _buildStatusRow('Resolved', byStatus['RESOLVED'] ?? 0, Colors.green),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade100),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Customer Satisfaction',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.green.shade700,
                  ),
                ),
                Text(
                  '96.8%',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
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
    final totalCalls = ai['totalCalls'] ?? 0;
    final successRate = ((ai['successRate'] ?? 0.0) * 100).toStringAsFixed(1);
    final avgDuration = (ai['avgSuccessDurationMs'] ?? 0.0).toStringAsFixed(0);

    return Container(
      height: 400,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
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
              color: Color(0xFF1E293B),
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildMetricBox(
                  'Total API Calls',
                  '$totalCalls',
                  Icons.api,
                  Colors.purple,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricBox(
                  'Avg Latency',
                  '${avgDuration}ms',
                  Icons.speed,
                  Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Overall Success Rate',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
              ),
              Text(
                '$successRate%',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF16A34A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (ai['successRate'] ?? 0.0).toDouble(),
            backgroundColor: const Color(0xFFF1F5F9),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF16A34A)),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Top Feature',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Quiz Gen (68%)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple.shade700,
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
    MaterialColor color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color.shade600, size: 20),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color.shade800,
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, int count, MaterialColor color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          Text(
            '$count',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }
}
