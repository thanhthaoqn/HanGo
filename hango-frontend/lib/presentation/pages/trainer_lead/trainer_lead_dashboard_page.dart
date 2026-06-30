import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/repositories/trainer_lead_repository.dart';
import '../../../domain/model/trainer_lead_dashboard_stats_model.dart';
import 'widgets/trainer_lead_sidebar.dart';
import 'widgets/trainer_lead_header.dart';
import 'widgets/trainer_lead_stat_card.dart';

class TrainerLeadDashboardPage extends StatefulWidget {
  const TrainerLeadDashboardPage({super.key});

  @override
  State<TrainerLeadDashboardPage> createState() => _TrainerLeadDashboardPageState();
}

class _TrainerLeadDashboardPageState extends State<TrainerLeadDashboardPage> {
  final TrainerLeadRepository _repository = TrainerLeadRepository();
  
  String _userName = 'Thảo';
  String _userInitial = 'T';
  bool _isLoading = true;
  String _errorMessage = '';
  TrainerLeadDashboardStatsModel? _stats;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _fetchStats();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final fullName = prefs.getString('user_fullname') ?? 'Thảo';
    String initials = 'T';
    if (fullName.trim().isNotEmpty) {
      final parts = fullName.trim().split(' ');
      if (parts.isNotEmpty) {
        initials = parts.last[0].toUpperCase();
      }
    }
    setState(() {
      _userName = fullName;
      _userInitial = initials;
    });
  }

  Future<void> _fetchStats() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      final stats = await _repository.getDashboardStats();
      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Row(
        children: [
          // Sidebar
          const TrainerLeadSidebar(activeMenu: 'Dashboard'),
          
          // Main Content Area
          Expanded(
            child: Column(
              children: [
                // Header
                TrainerLeadHeader(
                  title: 'Dashboard',
                  userName: _userName,
                  userInitial: _userInitial,
                ),
                
                // Dashboard Content
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _errorMessage.isNotEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('Error: $_errorMessage', style: const TextStyle(color: Colors.red)),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: _fetchStats,
                                    child: const Text('Retry'),
                                  )
                                ],
                              ),
                            )
                          : SingleChildScrollView(
                              padding: const EdgeInsets.all(30),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Stats Grid
                                  LayoutBuilder(
                                    builder: (context, constraints) {
                                      int crossAxisCount = constraints.maxWidth > 1200 ? 4 : (constraints.maxWidth > 800 ? 2 : 1);
                                      return GridView.count(
                                        crossAxisCount: crossAxisCount,
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        crossAxisSpacing: 20,
                                        mainAxisSpacing: 20,
                                        childAspectRatio: 1.3,
                                        children: [
                                          // Registered Users
                                          TrainerLeadStatCard(
                                            title: 'Registered Users',
                                            value: '1,248', // Using mock display for large numbers if needed, or _stats!.registeredUsers.toString()
                                            icon: Icons.trending_up,
                                            iconBackgroundColor: const Color(0xFFE6F8F6),
                                            iconColor: const Color(0xFF2ec4b6),
                                            footer: Row(
                                              children: [
                                                const Icon(Icons.arrow_upward, size: 14, color: Color(0xFF2ec4b6)),
                                                Text(
                                                  ' +${_stats?.userGrowthPercentage ?? 12.5}% ',
                                                  style: const TextStyle(color: Color(0xFF2ec4b6), fontWeight: FontWeight.bold, fontSize: 12),
                                                ),
                                                Text(
                                                  'vs last month',
                                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                                ),
                                              ],
                                            ),
                                          ),
                                          
                                          // Courses
                                          TrainerLeadStatCard(
                                            title: 'Courses',
                                            value: _stats?.totalCourses.toString() ?? '30',
                                            icon: Icons.school_outlined,
                                            iconBackgroundColor: Colors.grey.shade100,
                                            iconColor: Colors.grey.shade700,
                                            footer: Row(
                                              children: [
                                                _buildStatusDot(const Color(0xFF2ec4b6)),
                                                Text(' ${_stats?.activeCourses ?? 28} active   ', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                                _buildStatusDot(Colors.grey.shade400),
                                                Text(' ${_stats?.inactiveCourses ?? 2} inactive', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                              ],
                                            ),
                                          ),
                                          
                                          // Assigned Tasks
                                          TrainerLeadStatCard(
                                            title: 'Assigned Tasks',
                                            value: _stats?.assignedTasks.toString() ?? '10',
                                            icon: Icons.assignment_outlined,
                                            iconBackgroundColor: Colors.grey.shade100,
                                            iconColor: Colors.grey.shade700,
                                            footer: Row(
                                              children: [
                                                Icon(Icons.access_time, size: 14, color: Colors.grey.shade500),
                                                const SizedBox(width: 4),
                                                Text('Updated just now', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                              ],
                                            ),
                                          ),
                                          
                                          // Pending Approvals
                                          TrainerLeadStatCard(
                                            title: 'Pending Approvals',
                                            value: (_stats?.pendingApprovals ?? 2).toString().padLeft(2, '0'),
                                            icon: Icons.assignment_late_outlined,
                                            iconBackgroundColor: const Color(0xFFFFF0F0),
                                            iconColor: const Color(0xFFE53935),
                                            footer: Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFFFF0F0),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: const Text(
                                                    'URGENT',
                                                    style: TextStyle(color: Color(0xFFE53935), fontSize: 10, fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text('Requiring attention', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                              ],
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                  
                                  // Additional content could go below
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

  Widget _buildStatusDot(Color color) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
