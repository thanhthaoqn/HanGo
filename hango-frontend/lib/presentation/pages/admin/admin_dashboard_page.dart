// ignore_for_file: deprecated_member_use
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/services/auth_service.dart';
import '../login_page.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final _authService = AuthService();
  String _adminName = 'Thao';
  String _adminEmail = 'thao@hango.edu';
  String _adminInitials = 'T';
  int _selectedMenuIndex = 0; // 0: Dashboard, 1: Accounts, 2: AI Analytics, 3: Roles

  // Dashboard stats fetched dynamically from DB
  bool _isLoadingStats = true;
  String _totalUsers = '0';
  String _totalRoles = '0';
  List<String> _chartLabels = ['18/5', '19/5', '20/5', '21/5', '22/5', '23/5', '24/5'];
  List<double> _chartValues = [0, 0, 0, 0, 0, 0, 0];

  // Resolve backend base URL dynamically based on platform (matching AuthService)
  String get apiBaseUrl {
    final authUrl = AuthService.baseUrl; // e.g., 'http://localhost:8080/api/auth'
    return authUrl.replaceAll('/auth', ''); // returns 'http://localhost:8080/api'
  }

  @override
  void initState() {
    super.initState();
    _loadAdminInfo();
    _fetchDashboardStats();
  }

  Future<void> _loadAdminInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final fullName = prefs.getString('user_fullname') ?? 'Thao';
    final email = prefs.getString('user_email') ?? 'thao@hango.edu';
    
    String initials = 'T';
    if (fullName.trim().isNotEmpty) {
      final parts = fullName.trim().split(' ');
      if (parts.isNotEmpty) {
        initials = parts.last[0].toUpperCase();
      }
    }

    setState(() {
      _adminName = fullName;
      _adminEmail = email;
      _adminInitials = initials;
    });
  }

  Future<void> _fetchDashboardStats() async {
    setState(() {
      _isLoadingStats = true;
    });

    try {
      final token = await _authService.getToken();
      if (token == null) {
        debugPrint('No auth token found, using mock data.');
        setState(() {
          _isLoadingStats = false;
        });
        return;
      }

      final url = Uri.parse('$apiBaseUrl/admin/dashboard/stats');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> rawLabels = data['weeklyLabels'] ?? [];
        final List<dynamic> rawValues = data['weeklyValues'] ?? [];

        setState(() {
          _totalUsers = (data['totalUsers'] ?? 0).toString();
          _totalRoles = (data['totalRoles'] ?? 0).toString();

          if (rawLabels.isNotEmpty) {
            _chartLabels = List<String>.from(rawLabels);
          }
          if (rawValues.isNotEmpty) {
            _chartValues = rawValues.map((v) => (v as num).toDouble()).toList();
          }
          _isLoadingStats = false;
        });
      } else {
        debugPrint('Failed to load stats from DB: ${response.statusCode} - ${response.body}');
        setState(() {
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching dashboard stats from DB: $e');
      setState(() {
        _isLoadingStats = false;
      });
    }
  }

  void _handleLogout() async {
    await _authService.logout();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 960;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      drawer: isDesktop ? null : Drawer(child: _buildSidebarContent(context, isMobileDrawer: true)),
      body: Row(
        children: [
          // Sidebar for Desktop
          if (isDesktop)
            Container(
              width: 260,
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  right: BorderSide(color: Color(0xFFE5E7EB), width: 1),
                ),
              ),
              child: _buildSidebarContent(context),
            ),
          
          // Main content area
          Expanded(
            child: Column(
              children: [
                // Top Header Row
                _buildHeader(context, isDesktop),
                
                // Content Views
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                    child: Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 1200),
                        child: _buildMainContent(isDesktop),
                      ),
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

  // ------------------------------------------------------------------------
  // HEADER
  // ------------------------------------------------------------------------
  Widget _buildHeader(BuildContext context, bool isDesktop) {
    return Container(
      height: 70,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Hamburger menu for mobile drawer trigger
          if (!isDesktop)
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu, color: Color(0xFF4B5563)),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            )
          else
            const SizedBox(), // Empty spacer on desktop

          // Right: Bell notification & Profile avatar
          Row(
            children: [
              // Notification Bell with Badge
              Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_none_outlined, color: Color(0xFF4B5563), size: 26),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('No new notifications'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444), // Red
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),

              // Profile Avatar and Name Dropdown
              PopupMenuButton<String>(
                onSelected: (val) {
                  if (val == 'logout') {
                    _handleLogout();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Settings under development for $_adminName')),
                    );
                  }
                },
                offset: const Offset(0, 50),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFEDD5), // Peach light
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            _adminInitials,
                            style: const TextStyle(
                              color: Color(0xFFEA580C), // Dark Orange
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              fontFamily: 'Outfit',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _adminName,
                        style: const TextStyle(
                          color: Color(0xFF1F2937),
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          fontFamily: 'Outfit',
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.keyboard_arrow_down, size: 16, color: Color(0xFF4B5563)),
                    ],
                  ),
                ),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    enabled: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _adminName,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1F2937), fontFamily: 'Outfit'),
                        ),
                        Text(
                          _adminEmail,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontFamily: 'Outfit'),
                        ),
                        const Divider(),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'settings',
                    child: Row(
                      children: [
                        Icon(Icons.settings_outlined, size: 20),
                        SizedBox(width: 8),
                        Text('Settings', style: TextStyle(fontFamily: 'Outfit')),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(Icons.logout, size: 20, color: Colors.redAccent),
                        SizedBox(width: 8),
                        Text('Log Out', style: TextStyle(color: Colors.redAccent, fontFamily: 'Outfit')),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------------
  // SIDEBAR CONTENT
  // ------------------------------------------------------------------------
  Widget _buildSidebarContent(BuildContext context, {bool isMobileDrawer = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Sidebar Logo Section
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
          child: Image.network(
            'https://res.cloudinary.com/diqekap4o/image/upload/v1781621071/logo_ayqvq4.png',
            height: 48,
            alignment: Alignment.centerLeft,
            errorBuilder: (context, error, stackTrace) {
              return Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE6FFFA),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.school, size: 20, color: Color(0xFF28B79B)),
                  ),
                  const SizedBox(width: 10),
                  RichText(
                    text: const TextSpan(
                      text: 'Han',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                        fontFamily: 'Outfit',
                      ),
                      children: [
                        TextSpan(
                          text: 'Go',
                          style: TextStyle(
                            color: Color(0xFF28B79B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        
        const SizedBox(height: 10),
        
        // Menu Items List
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                _buildSidebarMenuItem(
                  index: 0,
                  icon: Icons.grid_view_outlined,
                  title: 'Dashboard',
                  isMobileDrawer: isMobileDrawer,
                ),
                const SizedBox(height: 8),
                _buildSidebarMenuItem(
                  index: 1,
                  icon: Icons.people_alt_outlined,
                  title: 'Accounts',
                  isMobileDrawer: isMobileDrawer,
                ),
                const SizedBox(height: 8),
                _buildSidebarMenuItem(
                  index: 2,
                  icon: Icons.analytics_outlined,
                  title: 'AI Analytics',
                  isMobileDrawer: isMobileDrawer,
                ),
                const SizedBox(height: 8),
                _buildSidebarMenuItem(
                  index: 3,
                  icon: Icons.security_outlined,
                  title: 'Roles',
                  isMobileDrawer: isMobileDrawer,
                ),
                
                const Spacer(),
                const Divider(color: Color(0xFFE5E7EB)),
                const SizedBox(height: 12),
                
                // Bottom Items
                _buildSidebarBottomItem(
                  icon: Icons.help_outline,
                  title: 'Help Center',
                  onTap: () {
                    if (isMobileDrawer) Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Opening Help Center...')),
                    );
                  },
                ),
                const SizedBox(height: 8),
                _buildSidebarBottomItem(
                  icon: Icons.logout,
                  title: 'Logout',
                  onTap: () {
                    if (isMobileDrawer) Navigator.pop(context);
                    _handleLogout();
                  },
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSidebarMenuItem({
    required int index,
    required IconData icon,
    required String title,
    required bool isMobileDrawer,
  }) {
    final isSelected = _selectedMenuIndex == index;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedMenuIndex = index;
          });
          if (isMobileDrawer) {
            Navigator.pop(context);
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF28B79B) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : const Color(0xFF4B5563),
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF4B5563),
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  fontFamily: 'Outfit',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarBottomItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(
                icon,
                color: const Color(0xFF4B5563),
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF4B5563),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Outfit',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------------
  // MAIN BODY SWITCHER
  // ------------------------------------------------------------------------
  Widget _buildMainContent(bool isDesktop) {
    switch (_selectedMenuIndex) {
      case 0:
        return _buildDashboardTab(isDesktop);
      case 1:
        return _buildAccountsTab();
      case 2:
        return _buildAnalyticsTab(isDesktop);
      case 3:
        return _buildRolesTab(isDesktop);
      default:
        return _buildDashboardTab(isDesktop);
    }
  }

  // ------------------------------------------------------------------------
  // TAB 0: DASHBOARD CONTENT
  // ------------------------------------------------------------------------
  Widget _buildDashboardTab(bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title and Subtitle
        const Text(
          'Dashboard',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
            fontFamily: 'Outfit',
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Welcome back, check your stats for today.',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF6B7280),
            fontFamily: 'Outfit',
          ),
        ),
        const SizedBox(height: 24),

        // Subtabs Menu (Overview)
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.only(bottom: 8),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Color(0xFF28B79B), // Selected tab line
                    width: 2.0,
                  ),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.insert_chart_outlined, size: 18, color: Color(0xFF28B79B)),
                  SizedBox(width: 8),
                  Text(
                    'Overview',
                    style: TextStyle(
                      color: Color(0xFF28B79B),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      fontFamily: 'Outfit',
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
          ],
        ),
        const SizedBox(height: 24),

        // Summary Cards
        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = isDesktop ? (constraints.maxWidth - 24) / 2 : constraints.maxWidth;
            
            final cardsList = [
              _buildSummaryCard(
                title: 'Account',
                value: _totalUsers,
                subtitle: 'Total account created',
                icon: Icons.people_outline,
                iconColor: const Color(0xFF2563EB), // Blue
                bgColor: const Color(0xFFEFF6FF), // Soft Blue
                width: cardWidth,
              ),
              _buildSummaryCard(
                title: 'Roles',
                value: _totalRoles,
                subtitle: 'Total account created',
                icon: Icons.settings_outlined,
                iconColor: const Color(0xFF059669), // Green
                bgColor: const Color(0xFFECFDF5), // Soft Green
                width: cardWidth,
              ),
            ];

            if (isDesktop) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: cardsList,
              );
            } else {
              return Column(
                children: [
                  cardsList[0],
                  const SizedBox(height: 16),
                  cardsList[1],
                ],
              );
            }
          },
        ),
        const SizedBox(height: 28),

        // Chart Card Section
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Chart Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Weekly Account Volume - Last 7 Days',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                      fontFamily: 'Outfit',
                    ),
                  ),
                  Row(
                    children: [
                      _buildIconButtonCircle(Icons.chevron_left),
                      const SizedBox(width: 8),
                      _buildIconButtonCircle(Icons.chevron_right),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Custom Painted Chart Area
              _isLoadingStats
                  ? const SizedBox(
                      height: 260,
                      child: Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF28B79B)),
                        ),
                      ),
                    )
                  : SizedBox(
                      height: 260,
                      width: double.infinity,
                      child: Builder(
                        builder: (context) {
                          double maxVal = _chartValues.isEmpty ? 100 : _chartValues.reduce((a, b) => a > b ? a : b);
                          if (maxVal < 10) maxVal = 10;
                          maxVal = maxVal * 1.25; // add 25% padding on top
                          
                          return CustomPaint(
                            painter: LineChartPainter(
                              values: _chartValues,
                              labels: _chartLabels,
                              maxVal: maxVal,
                              minVal: 0,
                            ),
                          );
                        }
                      ),
                    ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required double width,
  }) {
    return Container(
      width: width,
      height: 130,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: iconColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Outfit',
                  ),
                ),
                const SizedBox(height: 4),
                _isLoadingStats
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                          ),
                        ),
                      )
                    : Text(
                        value,
                        style: TextStyle(
                          color: iconColor,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Outfit',
                        ),
                      ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    fontFamily: 'Outfit',
                  ),
                ),
              ],
            ),
          ),
          
          // Right Icon Circle
          Container(
            width: 50,
            height: 50,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 26,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconButtonCircle(IconData icon) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Center(
        child: IconButton(
          padding: EdgeInsets.zero,
          icon: Icon(icon, color: const Color(0xFF4B5563), size: 18),
          onPressed: () {},
        ),
      ),
    );
  }

  // ------------------------------------------------------------------------
  // TAB 1: ACCOUNTS LIST MOCK
  // ------------------------------------------------------------------------
  Widget _buildAccountsTab() {
    final mockAccounts = [
      {'name': 'Nguyễn Văn A', 'email': 'a.nguyen@hango.edu', 'role': 'Learner', 'status': 'Active'},
      {'name': 'Trần Thị B', 'email': 'b.tran@hango.edu', 'role': 'Trainer', 'status': 'Active'},
      {'name': 'Lê Văn C', 'email': 'c.le@hango.edu', 'role': 'Training Lead', 'status': 'Inactive'},
      {'name': 'Admin Thao', 'email': 'thao@hango.edu', 'role': 'Administrator', 'status': 'Active'},
      {'name': 'Phạm Minh D', 'email': 'd.pham@hango.edu', 'role': 'Learner', 'status': 'Active'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Accounts Management',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
            fontFamily: 'Outfit',
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Manage all registered accounts, assignments, and roles in the platform.',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF6B7280),
            fontFamily: 'Outfit',
          ),
        ),
        const SizedBox(height: 24),
        
        // Search and Actions Header
        Row(
          children: [
            Expanded(
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: const [
                    Icon(Icons.search, color: Color(0xFF9CA3AF), size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search by name or email...',
                          hintStyle: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        style: TextStyle(fontSize: 14, fontFamily: 'Outfit'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add, color: Colors.white, size: 18),
              label: const Text('Add Account', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF28B79B),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Accounts Table Card
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: DataTable(
              headingRowColor: MaterialStateProperty.all(const Color(0xFFF9FAFB)),
              dataRowHeight: 60,
              columns: const [
                DataColumn(label: Text('Name', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Outfit'))),
                DataColumn(label: Text('Email', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Outfit'))),
                DataColumn(label: Text('Role', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Outfit'))),
                DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Outfit'))),
              ],
              rows: mockAccounts.map((account) {
                final isActive = account['status'] == 'Active';
                return DataRow(
                  cells: [
                    DataCell(Text(account['name']!, style: const TextStyle(fontWeight: FontWeight.w500, fontFamily: 'Outfit'))),
                    DataCell(Text(account['email']!, style: const TextStyle(fontFamily: 'Outfit'))),
                    DataCell(_buildRoleBadge(account['role']!)),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isActive ? const Color(0xFFD1FAE5) : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          account['status']!,
                          style: TextStyle(
                            color: isActive ? const Color(0xFF065F46) : const Color(0xFF4B5563),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Outfit',
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRoleBadge(String role) {
    Color bg = const Color(0xFFF3F4F6);
    Color fg = const Color(0xFF4B5563);
    
    switch (role) {
      case 'Administrator':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFF991B1B);
        break;
      case 'Training Lead':
        bg = const Color(0xFFFDE8E8);
        fg = const Color(0xFFC27803);
        break;
      case 'Trainer':
        bg = const Color(0xFFE0F2FE);
        fg = const Color(0xFF0369A1);
        break;
      case 'Learner':
        bg = const Color(0xFFE6FFFA);
        fg = const Color(0xFF047857);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        role,
        style: TextStyle(
          color: fg,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          fontFamily: 'Outfit',
        ),
      ),
    );
  }

  // ------------------------------------------------------------------------
  // TAB 2: ANALYTICS MOCK
  // ------------------------------------------------------------------------
  Widget _buildAnalyticsTab(bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'AI Analytics Insights',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
            fontFamily: 'Outfit',
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Monitor AI tutor usage, accuracy metrics, and response benchmarks.',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF6B7280),
            fontFamily: 'Outfit',
          ),
        ),
        const SizedBox(height: 24),

        // Grid cards
        LayoutBuilder(builder: (context, constraints) {
          final double cardWidth = isDesktop ? (constraints.maxWidth - 32) / 3 : constraints.maxWidth;
          final widgets = [
            _buildAnalyticsCard('Total AI Consults', '24,805', '+18.4% from last week', Icons.bolt, Colors.amber, cardWidth),
            _buildAnalyticsCard('AI Success Rate', '98.2%', '0.3% error margin', Icons.check_circle_outline, Colors.teal, cardWidth),
            _buildAnalyticsCard('Avg Response Time', '0.42s', 'Superfast resolution time', Icons.timer_outlined, Colors.purple, cardWidth),
          ];

          if (isDesktop) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: widgets,
            );
          } else {
            return Column(
              children: [
                widgets[0],
                const SizedBox(height: 16),
                widgets[1],
                const SizedBox(height: 16),
                widgets[2],
              ],
            );
          }
        }),

        const SizedBox(height: 24),
        
        // Log history box
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Recent AI Interactions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Outfit')),
              const SizedBox(height: 16),
              _buildInteractionRow('15 seconds ago', 'Summarized course "Lý thuyết Hóa học lớp 12"', 'Status: SUCCESS'),
              const Divider(),
              _buildInteractionRow('2 mins ago', 'Generated flashcard questions for Exam "Vật lý 10"', 'Status: SUCCESS'),
              const Divider(),
              _buildInteractionRow('5 mins ago', 'Answered quiz clarification for "Toán Học Giải Tích"', 'Status: SUCCESS'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAnalyticsCard(String label, String value, String desc, IconData icon, Color color, double width) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13, fontWeight: FontWeight.w500, fontFamily: 'Outfit')),
              Icon(icon, color: color, size: 22),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1F2937), fontFamily: 'Outfit')),
          const SizedBox(height: 4),
          Text(desc, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'Outfit')),
        ],
      ),
    );
  }

  Widget _buildInteractionRow(String time, String action, String status) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(action, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14, fontFamily: 'Outfit')),
                const SizedBox(height: 2),
                Text(time, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12, fontFamily: 'Outfit')),
              ],
            ),
          ),
          Text(status, style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'Outfit')),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------------
  // TAB 3: ROLES INFO MOCK
  // ------------------------------------------------------------------------
  Widget _buildRolesTab(bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Role Configurations',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
            fontFamily: 'Outfit',
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Configure permissions and visibility rules for system roles.',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF6B7280),
            fontFamily: 'Outfit',
          ),
        ),
        const SizedBox(height: 24),

        LayoutBuilder(builder: (context, constraints) {
          final double cardWidth = isDesktop ? (constraints.maxWidth - 20) / 2 : constraints.maxWidth;
          
          final cardsList = [
            _buildRoleConfigCard(
              'LEARNER',
              'The default role for platform users. Allows access to browse courses, review materials, create custom flashcards, and run exams standard to high school syllabus.',
              ['Take Exams', 'Browse Courses', 'Review Flashcards'],
              cardWidth,
            ),
            _buildRoleConfigCard(
              'TRAINER',
              'Intended for teachers or content curators. Grants privileges to create exams, write course sections, compile sample test libraries, and inspect student performance stats.',
              ['Create Course Contents', 'Manage Practice Tests', 'Grade Essay Submissions'],
              cardWidth,
            ),
            _buildRoleConfigCard(
              'TRAINING LEAD',
              'Managerial supervisor role. Has the access right to assign syllabus, audit trainer profiles, verify courses before publishing, and read learning analytics.',
              ['Audit Courses', 'Approve Syllabus Releases', 'Read Training Analytics'],
              cardWidth,
            ),
            _buildRoleConfigCard(
              'ADMINISTRATOR',
              'Total administrative system controls. Grants the capability to view administrative summaries, configure application settings, create/delete accounts, assign security roles, and monitor AI parameters.',
              ['User Account Control', 'Access System Settings', 'Override Database records'],
              cardWidth,
            ),
          ];

          if (isDesktop) {
            return Column(
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [cardsList[0], cardsList[1]]),
                const SizedBox(height: 20),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [cardsList[2], cardsList[3]]),
              ],
            );
          } else {
            return Column(
              children: [
                cardsList[0],
                const SizedBox(height: 16),
                cardsList[1],
                const SizedBox(height: 16),
                cardsList[2],
                const SizedBox(height: 16),
                cardsList[3],
              ],
            );
          }
        }),
      ],
    );
  }

  Widget _buildRoleConfigCard(String name, String desc, List<String> permissions, double width) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF28B79B), fontFamily: 'Outfit')),
              const Icon(Icons.shield_outlined, color: Color(0xFF28B79B), size: 20),
            ],
          ),
          const SizedBox(height: 10),
          Text(desc, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13, height: 1.4, fontFamily: 'Outfit')),
          const SizedBox(height: 16),
          const Text('Primary Grants:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF1F2937), fontFamily: 'Outfit')),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: permissions.map((perm) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  perm,
                  style: const TextStyle(
                    color: Color(0xFF4B5563),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Outfit',
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// CUSTOM LINE CHART PAINTER
// ----------------------------------------------------------------------------
class LineChartPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final double maxVal;
  final double minVal;

  LineChartPainter({
    required this.values,
    required this.labels,
    required this.maxVal,
    required this.minVal,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFFF3F4F6)
      ..strokeWidth = 1.0;

    final linePaint = Paint()
      ..color = const Color(0xFF28B79B)
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = const Color(0xFF28B79B)
      ..style = PaintingStyle.fill;

    final dotOutlinePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    // Grid coordinates calculations
    const double paddingX = 40.0;
    const double paddingY = 20.0;
    final double chartWidth = size.width - (paddingX * 2);
    final double chartHeight = size.height - (paddingY * 2) - 20; // Room for X-axis labels

    // Draw horizontal grid lines (4 lines)
    const int gridLinesCount = 4;
    for (int i = 0; i < gridLinesCount; i++) {
      final double y = paddingY + (chartHeight / (gridLinesCount - 1)) * i;
      canvas.drawLine(Offset(paddingX, y), Offset(size.width - paddingX, y), gridPaint);
    }

    if (values.isEmpty) return;

    // Convert values to coordinate offsets
    final List<Offset> points = [];
    final double xStep = chartWidth / (values.length - 1);
    final double valueRange = maxVal - minVal;

    for (int i = 0; i < values.length; i++) {
      final double x = paddingX + i * xStep;
      // Normalise values inside our range
      final double normalizedValue = (values[i] - minVal) / (valueRange == 0 ? 1 : valueRange);
      // Invert Y axes because Flutter coord (0,0) is top-left
      final double y = paddingY + chartHeight * (1 - normalizedValue);
      points.add(Offset(x, y));
    }

    // Gradient fill under the line chart
    final path = Path();
    path.moveTo(points.first.dx, paddingY + chartHeight);
    for (final pt in points) {
      path.lineTo(pt.dx, pt.dy);
    }
    path.lineTo(points.last.dx, paddingY + chartHeight);
    path.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFF28B79B).withOpacity(0.12),
          const Color(0xFF28B79B).withOpacity(0.0),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTRB(paddingX, paddingY, size.width - paddingX, paddingY + chartHeight))
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    // Draw connecting lines
    final linePath = Path();
    linePath.moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      linePath.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(linePath, linePaint);

    // Draw dots and X labels
    for (int i = 0; i < points.length; i++) {
      final pt = points[i];
      
      // Outer subtle shadow for dots
      canvas.drawCircle(pt, 7.0, Paint()..color = const Color(0xFF28B79B).withOpacity(0.3));
      
      // Main dot
      canvas.drawCircle(pt, 5.0, dotPaint);
      canvas.drawCircle(pt, 5.0, dotOutlinePaint);

      // X Label centering
      if (i < labels.length) {
        final textSpan = TextSpan(
          text: labels[i],
          style: const TextStyle(
            color: Color(0xFF9CA3AF),
            fontSize: 12,
            fontWeight: FontWeight.w500,
            fontFamily: 'Outfit',
          ),
        );
        textPainter.text = textSpan;
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(pt.dx - textPainter.width / 2, paddingY + chartHeight + 12),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant LineChartPainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.labels != labels;
  }
}
