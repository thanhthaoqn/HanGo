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

  // Accounts tab state and variables
  String _accountsTab = 'staff'; // 'staff' | 'learner'
  int _accountsPage = 0;
  int _accountsTotalPages = 1;
  bool _isLoadingAccounts = false;
  List<dynamic> _accountsList = [];
  final TextEditingController _searchController = TextEditingController();
  Map<String, dynamic>? _selectedUserForEdit;
  String _editStatus = 'ACTIVE';
  String _editRole = 'Trainer';
  final TextEditingController _dobController = TextEditingController(text: '28/04/2004');
  bool _isLoadingUserDetail = false;

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
    _fetchAccounts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _dobController.dispose();
    super.dispose();
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

  Future<void> _fetchAccounts() async {
    setState(() {
      _isLoadingAccounts = true;
    });

    try {
      final token = await _authService.getToken();
      if (token == null) {
        debugPrint('No auth token found, cannot fetch accounts.');
        setState(() {
          _isLoadingAccounts = false;
        });
        return;
      }

      final search = Uri.encodeComponent(_searchController.text.trim());
      final url = Uri.parse(
        '$apiBaseUrl/admin/users?roleType=$_accountsTab&search=$search&page=$_accountsPage&size=6'
      );
      
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _accountsList = data['content'] ?? [];
          _accountsTotalPages = data['totalPages'] ?? 1;
          _isLoadingAccounts = false;
        });
      } else {
        debugPrint('Failed to load accounts: ${response.statusCode} - ${response.body}');
        setState(() {
          _isLoadingAccounts = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching accounts: $e');
      setState(() {
        _isLoadingAccounts = false;
      });
    }
  }

  Future<void> _toggleUserStatus(int userId, bool newStatus) async {
    final statusStr = newStatus ? 'ACTIVE' : 'INACTIVE';
    try {
      final token = await _authService.getToken();
      if (token == null) return;

      final url = Uri.parse('$apiBaseUrl/admin/users/$userId/status?status=$statusStr');
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          final userIndex = _accountsList.indexWhere((u) => u['id'] == userId);
          if (userIndex != -1) {
            _accountsList[userIndex]['status'] = statusStr;
          }
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('User status updated to $statusStr'),
              backgroundColor: const Color(0xFF28B79B),
              duration: const Duration(seconds: 1),
            ),
          );
        }
      } else {
        debugPrint('Failed to update status: ${response.statusCode} - ${response.body}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update status: ${response.body}'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error toggling status: $e');
    }
  }

  Future<void> _fetchUserDetail(int userId) async {
    setState(() {
      _isLoadingUserDetail = true;
    });
    try {
      final token = await _authService.getToken();
      if (token == null) {
        setState(() {
          _isLoadingUserDetail = false;
        });
        return;
      }

      final url = Uri.parse('$apiBaseUrl/admin/users/$userId');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _selectedUserForEdit = data;
          _editStatus = data['status'] ?? 'ACTIVE';
          final rolesList = data['roles'] as List?;
          final role = (rolesList != null && rolesList.isNotEmpty) ? rolesList.first.toString() : 'Trainer';
          if (role.contains('TRAINING_LEAD')) {
            _editRole = 'Training Lead';
          } else if (role.contains('ADMIN')) {
            _editRole = 'ADMIN';
          } else {
            _editRole = 'Trainer';
          }
          
          if (data['dateOfBirth'] != null) {
            try {
              final dobStr = data['dateOfBirth'].toString(); // yyyy-MM-dd
              final parts = dobStr.split('-');
              if (parts.length == 3) {
                _dobController.text = '${parts[2]}/${parts[1]}/${parts[0]}';
              } else {
                _dobController.text = dobStr;
              }
            } catch (e) {
              _dobController.text = '';
            }
          } else {
            _dobController.text = '';
          }
          _isLoadingUserDetail = false;
        });
      } else {
        debugPrint('Failed to load user detail: ${response.statusCode}');
        setState(() {
          _isLoadingUserDetail = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching user detail: $e');
      setState(() {
        _isLoadingUserDetail = false;
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
          else if (_selectedUserForEdit != null)
            Row(
              children: [
                const Icon(Icons.chevron_right, size: 14, color: Color(0xFF9CA3AF)),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedUserForEdit = null;
                    });
                  },
                  child: const Text(
                    'Accounts',
                    style: TextStyle(
                      fontSize: 13, 
                      color: Color(0xFF28B79B), 
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right, size: 14, color: Color(0xFF9CA3AF)),
                const SizedBox(width: 6),
                Text(
                  _selectedUserForEdit != null && (_selectedUserForEdit!['roles'] as List?)?.first?.toString().contains('LEARNER') == true 
                      ? 'Learner Account Detail' 
                      : 'Trainer Account Detail',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF28B79B),
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Outfit',
                  ),
                ),
              ],
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
          if (index == 1) {
            _fetchAccounts();
          }
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
    if (_selectedUserForEdit != null) {
      return _buildTrainerDetailView(_selectedUserForEdit!);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Breadcrumbs
        Row(
          children: [
            const Text(
              'Accounts',
              style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF), fontFamily: 'Outfit'),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, size: 14, color: Color(0xFF9CA3AF)),
            const SizedBox(width: 6),
            Text(
              _accountsTab == 'staff' ? 'Trainer' : 'Learner',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF28B79B),
                fontWeight: FontWeight.bold,
                fontFamily: 'Outfit',
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // 2. Subtabs Menu (Trainer | Learner)
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildAccountsSubTab('Trainer', _accountsTab == 'staff', () {
                  setState(() {
                    _accountsTab = 'staff';
                    _accountsPage = 0;
                  });
                  _fetchAccounts();
                }),
                const SizedBox(width: 24),
                _buildAccountsSubTab('Learner', _accountsTab == 'learner', () {
                  setState(() {
                    _accountsTab = 'learner';
                    _accountsPage = 0;
                  });
                  _fetchAccounts();
                }),
              ],
            ),
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
          ],
        ),
        const SizedBox(height: 24),

        // 3. Search and Actions Header
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
                  children: [
                    const Icon(Icons.search, color: Color(0xFF9CA3AF), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) {
                          setState(() {
                            _accountsPage = 0;
                          });
                          _fetchAccounts();
                        },
                        decoration: const InputDecoration(
                          hintText: 'Search by name or email...',
                          hintStyle: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        style: const TextStyle(fontSize: 14, fontFamily: 'Outfit'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Account registration is handled via Auth registration flows.')),
                );
              },
              icon: const Icon(Icons.add, color: Colors.white, size: 18),
              label: const Text('Create', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
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

        // 4. Accounts Table Card
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Table Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: const BoxDecoration(
                  color: Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: const [
                    Expanded(flex: 3, child: Text('NAME', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF4B5563), fontFamily: 'Outfit'))),
                    Expanded(flex: 3, child: Text('EMAIL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF4B5563), fontFamily: 'Outfit'))),
                    Expanded(flex: 2, child: Text('ROLE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF4B5563), fontFamily: 'Outfit'))),
                    Expanded(flex: 2, child: Text('ACTIVITY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF4B5563), fontFamily: 'Outfit'))),
                    Expanded(flex: 1, child: Text('ACTION', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF4B5563), fontFamily: 'Outfit'))),
                  ],
                ),
              ),
              
              // Table Rows
              _isLoadingAccounts
                  ? const SizedBox(
                      height: 300,
                      child: Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF28B79B)),
                        ),
                      ),
                    )
                  : _accountsList.isEmpty
                      ? const SizedBox(
                          height: 200,
                          child: Center(
                            child: Text(
                              'No accounts found.',
                              style: TextStyle(color: Color(0xFF6B7280), fontSize: 14, fontFamily: 'Outfit'),
                            ),
                          ),
                        )
                      : Column(
                          children: _accountsList.map((user) {
                            final isActive = user['status'] == 'ACTIVE';
                            final List roles = user['roles'] ?? [];
                            final roleStr = roles.isNotEmpty ? roles.first.toString() : 'LEARNER';
                            final int userId = user['id'] ?? 0;

                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                border: Border(
                                  bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
                                ),
                              ),
                              child: Row(
                                children: [
                                  // NAME Column
                                  Expanded(
                                    flex: 3,
                                    child: Row(
                                      children: [
                                        _buildAvatarCircle(user['fullName'] ?? ''),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            user['fullName'] ?? '',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                              color: Color(0xFF1F2937),
                                              fontFamily: 'Outfit',
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // EMAIL Column
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      user['email'] ?? '',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF4B5563),
                                        fontFamily: 'Outfit',
                                      ),
                                    ),
                                  ),
                                  // ROLE Column
                                  Expanded(
                                    flex: 2,
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: _buildRoleBadge(roleStr),
                                    ),
                                  ),
                                  // ACTIVITY Column
                                  Expanded(
                                    flex: 2,
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Transform.scale(
                                        scale: 0.8,
                                        alignment: Alignment.centerLeft,
                                        child: Switch(
                                          value: isActive,
                                          activeColor: const Color(0xFF28B79B),
                                          onChanged: (newVal) {
                                            if (userId != 0) {
                                              _toggleUserStatus(userId, newVal);
                                            }
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                  // ACTION Column
                                  Expanded(
                                    flex: 1,
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: IconButton(
                                        icon: const Icon(Icons.edit_outlined, color: Color(0xFF28B79B), size: 18),
                                        onPressed: () {
                                          final userId = user['id'] ?? 0;
                                          setState(() {
                                            _selectedUserForEdit = user;
                                            _editStatus = user['status'] ?? 'ACTIVE';
                                            final rolesList = user['roles'] as List?;
                                            final role = (rolesList != null && rolesList.isNotEmpty) ? rolesList.first.toString() : 'Trainer';
                                            if (role.contains('TRAINING_LEAD')) {
                                              _editRole = 'Training Lead';
                                            } else if (role.contains('ADMIN')) {
                                              _editRole = 'ADMIN';
                                            } else {
                                              _editRole = 'Trainer';
                                            }
                                            _dobController.text = ''; // Clear initially
                                          });
                                          if (userId != 0) {
                                            _fetchUserDetail(userId);
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 5. Pagination Footer
        _buildPagination(),

        // 6. Main Lower Footer
        _buildAccountsFooter(),
      ],
    );
  }

  Widget _buildAccountsSubTab(String text, bool active, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? const Color(0xFF28B79B) : Colors.transparent,
              width: 2.5,
            ),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: active ? const Color(0xFF28B79B) : const Color(0xFF4B5563),
            fontSize: 14,
            fontWeight: active ? FontWeight.bold : FontWeight.w500,
            fontFamily: 'Outfit',
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarCircle(String fullName) {
    String initials = '';
    if (fullName.trim().isNotEmpty) {
      final parts = fullName.trim().split(' ');
      if (parts.length > 1) {
        initials = parts.first[0].toUpperCase() + parts.last[0].toUpperCase();
      } else if (parts.isNotEmpty) {
        initials = parts.first[0].toUpperCase();
      }
    }
    if (initials.isEmpty) initials = 'U';

    final colors = [
      const Color(0xFFEFF6FF), // Blue
      const Color(0xFFECFDF5), // Green
      const Color(0xFFFDF2F8), // Pink
      const Color(0xFFF5F3FF), // Purple
      const Color(0xFFFFF7ED), // Orange
    ];
    final textColors = [
      const Color(0xFF2563EB),
      const Color(0xFF059669),
      const Color(0xFFDB2777),
      const Color(0xFF7C3AED),
      const Color(0xFFEA580C),
    ];
    final hash = fullName.hashCode.abs() % colors.length;

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: colors[hash],
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: textColors[hash],
            fontWeight: FontWeight.bold,
            fontSize: 12,
            fontFamily: 'Outfit',
          ),
        ),
      ),
    );
  }

  Widget _buildPagination() {
    if (_accountsTotalPages <= 1) return const SizedBox();
    
    List<Widget> children = [];
    
    // Left arrow
    children.add(
      IconButton(
        icon: const Icon(Icons.chevron_left, size: 18),
        onPressed: _accountsPage > 0 
          ? () {
              setState(() {
                _accountsPage--;
              });
              _fetchAccounts();
            }
          : null,
      ),
    );
    
    // Page numbers
    for (int i = 0; i < _accountsTotalPages; i++) {
      final isCurrent = _accountsPage == i;
      children.add(
        InkWell(
          onTap: () {
            setState(() {
              _accountsPage = i;
            });
            _fetchAccounts();
          },
          child: Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: isCurrent ? const Color(0xFF28B79B) : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: Text(
                '${i + 1}',
                style: TextStyle(
                  color: isCurrent ? Colors.white : const Color(0xFF4B5563),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  fontFamily: 'Outfit',
                ),
              ),
            ),
          ),
        ),
      );
    }
    
    // Right arrow
    children.add(
      IconButton(
        icon: const Icon(Icons.chevron_right, size: 18),
        onPressed: _accountsPage < _accountsTotalPages - 1 
          ? () {
              setState(() {
                _accountsPage++;
              });
              _fetchAccounts();
            }
          : null,
      ),
    );
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: children,
    );
  }

  Widget _buildAccountsFooter() {
    return Container(
      padding: const EdgeInsets.only(top: 48, bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: const [
              Text(
                'HanGo',
                style: TextStyle(
                  color: Color(0xFF28B79B),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  fontFamily: 'Outfit',
                ),
              ),
              SizedBox(width: 8),
              Text(
                'Smart Language Self-Study Platform',
                style: TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 12,
                  fontFamily: 'Outfit',
                ),
              ),
            ],
          ),
          Row(
            children: [
              _buildFooterLink('Privacy Policy'),
              const SizedBox(width: 16),
              _buildFooterLink('Terms of Service'),
              const SizedBox(width: 16),
              _buildFooterLink('Contact Support'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFooterLink(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF9CA3AF),
        fontSize: 12,
        fontFamily: 'Outfit',
      ),
    );
  }

  Widget _buildRoleBadge(String role) {
    String cleanRole = role.replaceAll('ROLE_', '').toUpperCase();
    
    Color bg = const Color(0xFFF3F4F6);
    Color fg = const Color(0xFF4B5563);
    String label = cleanRole;

    switch (cleanRole) {
      case 'ADMINISTRATOR':
      case 'ADMIN':
        bg = const Color(0xFFF3E8FF);
        fg = const Color(0xFF7C3AED);
        label = 'Admin';
        break;
      case 'TRAINING_LEAD':
        bg = const Color(0xFFEEF2F6);
        fg = const Color(0xFF6366F1);
        label = 'Training Lead';
        break;
      case 'TRAINER':
        bg = const Color(0xFFDBEAFE);
        fg = const Color(0xFF2563EB);
        label = 'Trainer';
        break;
      case 'LEARNER':
        bg = const Color(0xFFE6FFFA);
        fg = const Color(0xFF047857);
        label = 'Learner';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
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

  Widget _buildTrainerDetailView(Map<String, dynamic> user) {
    if (_isLoadingUserDetail) {
      return const SizedBox(
        height: 400,
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF28B79B)),
          ),
        ),
      );
    }

    final fullName = user['fullName'] ?? '';
    final email = user['email'] ?? '';
    final username = email.split('@').first;
    final userId = user['id'] ?? 0;
    final rolesList = user['roles'] as List?;
    final role = (rolesList != null && rolesList.isNotEmpty) ? rolesList.first.toString() : 'Trainer';
    
    // Normalize role string for display (e.g. ROLE_TRAINING_LEAD -> Training Lead)
    String displayRole = role.replaceAll('ROLE_', '').replaceAll('_', ' ');
    // Capitalize words
    displayRole = displayRole.split(' ').map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');

    String userInitials = '';
    if (fullName.trim().isNotEmpty) {
      final parts = fullName.trim().split(' ');
      if (parts.length > 1) {
        userInitials = parts.first[0].toUpperCase() + parts.last[0].toUpperCase();
      } else if (parts.isNotEmpty) {
        userInitials = parts.first[0].toUpperCase();
      }
    }
    if (userInitials.isEmpty) userInitials = 'U';

    String genderStr = user['gender'] ?? 'Female';
    if (genderStr.toLowerCase() == 'male') {
      genderStr = 'Male';
    } else {
      genderStr = 'Female';
    }

    final isLearner = role.contains('LEARNER');
    final titleText = isLearner ? 'Learner Account Detail' : 'Trainer Account Detail';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Text(
          titleText,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
            fontFamily: 'Outfit',
          ),
        ),
        const SizedBox(height: 20),

        // Main Card Container
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar & Basic Info Header
              Row(
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFE5E7EB), width: 2),
                        ),
                        child: Center(
                          child: Text(
                            userInitials,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2563EB),
                              fontFamily: 'Outfit',
                            ),
                          ),
                        ),
                      ),
                      // Pencil Edit Badge
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Color(0xFF28B79B),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.edit_outlined,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 24),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937),
                          fontFamily: 'Outfit',
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'ID: PS-$userId-CC',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                          fontFamily: 'Outfit',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 40),

              // Fields Row 1: FullName & Username
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'FullName',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF4B5563),
                            fontFamily: 'Outfit',
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          initialValue: fullName,
                          readOnly: true,
                          enabled: false,
                          style: const TextStyle(color: Color(0xFF9CA3AF), fontFamily: 'Outfit'),
                          decoration: InputDecoration(
                            fillColor: const Color(0xFFF9FAFB),
                            filled: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            disabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Username',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF4B5563),
                            fontFamily: 'Outfit',
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          initialValue: username,
                          readOnly: true,
                          enabled: false,
                          style: const TextStyle(color: Color(0xFF9CA3AF), fontFamily: 'Outfit'),
                          decoration: InputDecoration(
                            fillColor: const Color(0xFFF9FAFB),
                            filled: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            disabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Fields Row 2: Email & Role
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Email',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF4B5563),
                            fontFamily: 'Outfit',
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          initialValue: email,
                          readOnly: true,
                          enabled: false,
                          style: const TextStyle(color: Color(0xFF9CA3AF), fontFamily: 'Outfit'),
                          decoration: InputDecoration(
                            fillColor: const Color(0xFFF9FAFB),
                            filled: true,
                            prefixIcon: const Icon(Icons.mail_outline, color: Color(0xFF9CA3AF), size: 20),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            disabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Role',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF4B5563),
                            fontFamily: 'Outfit',
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _editRole,
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _editRole = val;
                              });
                            }
                          },
                          items: const [
                            DropdownMenuItem(value: 'Trainer', child: Text('Trainer')),
                            DropdownMenuItem(value: 'Training Lead', child: Text('Training Lead')),
                            DropdownMenuItem(value: 'ADMIN', child: Text('Admin')),
                          ],
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFF28B79B), width: 1.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Fields Row 3: Date of Birth & Gender
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Date of Birth',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF4B5563),
                            fontFamily: 'Outfit',
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _dobController,
                          readOnly: true,
                          enabled: false,
                          style: const TextStyle(color: Color(0xFF9CA3AF), fontFamily: 'Outfit'),
                          decoration: InputDecoration(
                            fillColor: const Color(0xFFF9FAFB),
                            filled: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            disabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Gender',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF4B5563),
                            fontFamily: 'Outfit',
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Row(
                              children: [
                                Radio<String>(
                                  value: 'Female',
                                  groupValue: genderStr,
                                  onChanged: null,
                                  activeColor: const Color(0xFF28B79B),
                                ),
                                const Text('Female', style: TextStyle(color: Color(0xFF9CA3AF), fontFamily: 'Outfit')),
                              ],
                            ),
                            const SizedBox(width: 20),
                            Row(
                              children: [
                                Radio<String>(
                                  value: 'Male',
                                  groupValue: genderStr,
                                  onChanged: null,
                                  activeColor: const Color(0xFF28B79B),
                                ),
                                const Text('Male', style: TextStyle(color: Color(0xFF9CA3AF), fontFamily: 'Outfit')),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Account Status Section
              const Text(
                'Account Status',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF4B5563),
                  fontFamily: 'Outfit',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _editStatus = 'ACTIVE';
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: _editStatus == 'ACTIVE' ? const Color(0xFFE6FDF9) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _editStatus == 'ACTIVE' ? const Color(0xFF28B79B) : const Color(0xFFD1D5DB),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            color: _editStatus == 'ACTIVE' ? const Color(0xFF28B79B) : const Color(0xFF6B7280),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Active',
                            style: TextStyle(
                              color: _editStatus == 'ACTIVE' ? const Color(0xFF28B79B) : const Color(0xFF4B5563),
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Outfit',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _editStatus = 'INACTIVE';
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: _editStatus == 'INACTIVE' ? const Color(0xFFF3F4F6) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _editStatus == 'INACTIVE' ? const Color(0xFF9CA3AF) : const Color(0xFFD1D5DB),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.cancel_outlined,
                            color: _editStatus == 'INACTIVE' ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Inactive',
                            style: TextStyle(
                              color: _editStatus == 'INACTIVE' ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563),
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Outfit',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 40),
              const Divider(color: Color(0xFFE5E7EB)),
              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () async {
                      if (user['status'] != _editStatus) {
                        await _toggleUserStatus(userId, _editStatus == 'ACTIVE');
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Trainer details updated successfully (Mocked roles/DOB)'),
                            backgroundColor: Color(0xFF28B79B),
                          ),
                        );
                      }
                      setState(() {
                        _selectedUserForEdit = null;
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF28B79B), width: 1.5),
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Update',
                      style: TextStyle(
                        color: Color(0xFF28B79B),
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Outfit',
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _selectedUserForEdit = null;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF28B79B),
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Back',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Outfit',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
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
