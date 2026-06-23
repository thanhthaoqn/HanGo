import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../data/models/trainer_lead_dashboard_stats_model.dart';
import '../../widgets/shared_header.dart';
import '../../widgets/trainer_lead_sidebar.dart';


class TrainerLeadDashboardPage extends StatefulWidget {
  const TrainerLeadDashboardPage({super.key});

  @override
  State<TrainerLeadDashboardPage> createState() => _TrainerLeadDashboardPageState();
}

class _TrainerLeadDashboardPageState extends State<TrainerLeadDashboardPage> {
  bool _isLoading = true;
  String _error = '';
  TrainerLeadDashboardStatsModel? _stats;
  final Dio _dio = Dio();

  @override
  void initState() {
    super.initState();
    _fetchDashboardStats();
  }

  Future<void> _fetchDashboardStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      // Use a fallback URL if API_CONSTANTS doesn't define it
      final response = await _dio.get(
        'http://localhost:8080/api/v1/trainer-lead/dashboard/stats',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        if (mounted) {
          setState(() {
            _stats = TrainerLeadDashboardStatsModel.fromJson(response.data);
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load dashboard stats: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1024;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: isDesktop ? null : const Drawer(child: TrainerLeadSidebar(activeMenu: 'Dashboard')),
      body: Column(
        children: [
          // Header Component
          SharedHeader(isDesktop: isDesktop, activeTab: ''),
          
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isDesktop) const TrainerLeadSidebar(activeMenu: 'Dashboard'),
                
                // Main Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Breadcrumb
                        const Row(
                          children: [
                            Text(
                              'Dashboard',
                              style: TextStyle(
                                color: Color(0xFF28B79B),
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                fontFamily: 'Outfit',
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.chevron_right, size: 16, color: Color(0xFF94A3B8)),
                          ],
                        ),
                        
                        const SizedBox(height: 32),
                        
                        // Error handling
                        if (_error.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.all(16),
                            margin: const EdgeInsets.only(bottom: 24),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, color: Color(0xFFEF4444)),
                                const SizedBox(width: 12),
                                Expanded(child: Text(_error, style: const TextStyle(color: Color(0xFF991B1B)))),
                              ],
                            ),
                          ),
                          
                        if (_isLoading)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(40),
                              child: CircularProgressIndicator(color: Color(0xFF28B79B)),
                            ),
                          )
                        else if (_stats != null)
                          // Metric Cards Row
                          LayoutBuilder(
                            builder: (context, constraints) {
                              // Responsive grid: 4 columns on wide screens, 2 on medium, 1 on small
                              int crossAxisCount = 4;
                              if (constraints.maxWidth < 600) {
                                crossAxisCount = 1;
                              } else if (constraints.maxWidth < 1200) {
                                crossAxisCount = 2;
                              }

                              return GridView.count(
                                crossAxisCount: crossAxisCount,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                crossAxisSpacing: 24,
                                mainAxisSpacing: 24,
                                childAspectRatio: 1.5,
                                children: [
                                  // REGISTERED USERS
                                  _buildMetricCard(
                                    title: 'REGISTERED\nUSERS',
                                    value: _stats!.totalUsers.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},'),
                                    iconBgColor: const Color(0xFFE6FFFA),
                                    iconColor: const Color(0xFF28B79B),
                                    iconData: Icons.trending_up,
                                    bottomWidget: Row(
                                      children: [
                                        const Icon(Icons.arrow_upward, size: 14, color: Color(0xFF28B79B)),
                                        Text(
                                          '+${_stats!.percentageIncrease}%',
                                          style: const TextStyle(color: Color(0xFF28B79B), fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                        const SizedBox(width: 4),
                                        const Text('vs last month', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                  
                                  // COURSES
                                  _buildMetricCard(
                                    title: 'COURSES',
                                    value: _stats!.totalCourses.toString(),
                                    iconBgColor: const Color(0xFFF1F5F9),
                                    iconColor: const Color(0xFF475569),
                                    iconData: Icons.school_outlined,
                                    bottomWidget: Row(
                                      children: [
                                        _buildStatusDot(const Color(0xFF28B79B), '${_stats!.activeCourses}\nactive'),
                                        const SizedBox(width: 24),
                                        _buildStatusDot(const Color(0xFFCBD5E1), '${_stats!.inactiveCourses}\ninactive'),
                                      ],
                                    ),
                                  ),
                                  
                                  // ASSIGNED TASKS
                                  _buildMetricCard(
                                    title: 'ASSIGNED\nTASKS',
                                    value: _stats!.assignedTasks.toString(),
                                    iconBgColor: const Color(0xFFF1F5F9),
                                    iconColor: const Color(0xFF475569),
                                    iconData: Icons.assignment_outlined,
                                    bottomWidget: const Row(
                                      children: [
                                        Icon(Icons.access_time, size: 14, color: Color(0xFF64748B)),
                                        SizedBox(width: 6),
                                        Text('Updated just now', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                  
                                  // PENDING APPROVALS
                                  _buildMetricCard(
                                    title: 'PENDING\nAPPROVALS',
                                    value: _stats!.pendingApprovals.toString().padLeft(2, '0'),
                                    valueColor: const Color(0xFFEF4444),
                                    iconBgColor: const Color(0xFFFEE2E2),
                                    iconColor: const Color(0xFFEF4444),
                                    iconData: Icons.assignment_late_outlined,
                                    bottomWidget: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFEE2E2),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text(
                                            'URGENT',
                                            style: TextStyle(color: Color(0xFFB91C1C), fontWeight: FontWeight.bold, fontSize: 10),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        const Text('Requiring attention', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
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

  Widget _buildMetricCard({
    required String title,
    required String value,
    Color valueColor = const Color(0xFF0F172A),
    required Color iconBgColor,
    required Color iconColor,
    required IconData iconData,
    required Widget bottomWidget,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  height: 1.3,
                ),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(iconData, color: iconColor, size: 20),
              ),
            ],
          ),
          
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 36,
              fontWeight: FontWeight.bold,
              fontFamily: 'Outfit',
            ),
          ),
          
          bottomWidget,
        ],
      ),
    );
  }

  Widget _buildStatusDot(Color color, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 4),
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            color: Color(0xFF475569),
            fontSize: 13,
            fontWeight: FontWeight.w500,
            fontFamily: 'Consolas', // Monospace for numbers
          ),
        ),
      ],
    );
  }
}
