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
  String _adminAvatarUrl = '';
  int _selectedMenuIndex = 0; // 0: Dashboard, 1: Accounts, 2: AI Analytics, 3: Roles, 4: Profile

  // Profile tab state variables
  bool _isLoadingProfile = false;
  final _profileNameController = TextEditingController();
  final _profileEmailController = TextEditingController();
  final _profilePhoneController = TextEditingController();
  final _profileAvatarController = TextEditingController();
  String _profileGender = 'Male';
  final TextEditingController _profileDobController = TextEditingController();

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

  // Create account variables
  bool _showCreateNewAccountView = false;
  final TextEditingController _createFirstNameController = TextEditingController();
  final TextEditingController _createNameController = TextEditingController();
  final TextEditingController _createEmailController = TextEditingController();
  final TextEditingController _createDobController = TextEditingController();
  String _createGender = 'Male';
  final TextEditingController _createAddressController = TextEditingController();
  final TextEditingController _createPhoneController = TextEditingController();
  String? _createRole;
  bool _isCreatingUser = false;

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
    _createFirstNameController.dispose();
    _createNameController.dispose();
    _createEmailController.dispose();
    _createDobController.dispose();
    _createAddressController.dispose();
    _createPhoneController.dispose();
    _profileNameController.dispose();
    _profileEmailController.dispose();
    _profilePhoneController.dispose();
    _profileAvatarController.dispose();
    _profileDobController.dispose();
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

    _fetchAdminProfile();
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
          else if (_selectedMenuIndex == 1)
            Row(
              children: [
                const Icon(Icons.chevron_right, size: 14, color: Color(0xFF9CA3AF)),
                const SizedBox(width: 6),
                _selectedUserForEdit != null || _showCreateNewAccountView
                    ? GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedUserForEdit = null;
                            _showCreateNewAccountView = false;
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
                      )
                    : const Text(
                        'Accounts',
                        style: TextStyle(
                          fontSize: 13, 
                          color: Color(0xFF28B79B), 
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right, size: 14, color: Color(0xFF9CA3AF)),
                const SizedBox(width: 6),
                Text(
                  _selectedUserForEdit != null
                      ? ((_selectedUserForEdit!['roles'] as List?)?.first?.toString().contains('LEARNER') == true
                          ? 'Learner Account Detail'
                          : 'Trainer Account Detail')
                      : (_showCreateNewAccountView ? 'Create New Account' : (_accountsTab == 'staff' ? 'Trainer' : 'Learner')),
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
                  } else if (val == 'profile') {
                    _initProfileFields();
                    setState(() {
                      _selectedMenuIndex = 4;
                    });
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
                        child: _adminAvatarUrl.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(18),
                                child: Image.network(
                                  _adminAvatarUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Center(
                                    child: Text(
                                      _adminInitials,
                                      style: const TextStyle(
                                        color: Color(0xFFEA580C),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        fontFamily: 'Outfit',
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            : Center(
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
                    value: 'profile',
                    child: Row(
                      children: [
                        Icon(Icons.person_outline, size: 20),
                        SizedBox(width: 8),
                        Text('Profile', style: TextStyle(fontFamily: 'Outfit')),
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
      case 4:
        return _buildProfileTab(isDesktop);
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
      final rolesList = _selectedUserForEdit!['roles'] as List?;
      final role = (rolesList != null && rolesList.isNotEmpty) ? rolesList.first.toString() : 'Trainer';
      if (role.contains('LEARNER')) {
        return _buildLearnerDetailView(_selectedUserForEdit!);
      }
      return _buildTrainerDetailView(_selectedUserForEdit!);
    }
    if (_showCreateNewAccountView) {
      return _buildCreateAccountView();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

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
                setState(() {
                  _resetCreateForm();
                  _showCreateNewAccountView = true;
                });
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
    if (_accountsTotalPages < 1) return const SizedBox();
    
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

  Map<String, String> _splitFullName(String fullName) {
    final trimmed = fullName.trim();
    if (trimmed.isEmpty) {
      return {'firstName': '', 'name': ''};
    }
    final parts = trimmed.split(' ');
    if (parts.length <= 1) {
      return {'firstName': '', 'name': trimmed};
    }
    final name = parts.last;
    final firstName = parts.sublist(0, parts.length - 1).join(' ');
    return {'firstName': firstName, 'name': name};
  }

  String _formatDateString(dynamic dateInput) {
    if (dateInput == null) return '';
    final str = dateInput.toString();
    if (str.isEmpty) return '';
    try {
      if (str.contains('T')) {
        final dateTime = DateTime.parse(str);
        final day = dateTime.day.toString().padLeft(2, '0');
        final month = dateTime.month.toString().padLeft(2, '0');
        final year = dateTime.year.toString();
        return '$day/$month/$year';
      }
      final parts = str.split('-');
      if (parts.length == 3) {
        if (parts[0].length == 4) {
          return '${parts[2]}/${parts[1]}/${parts[0]}';
        }
        return '${parts[0]}/${parts[1]}/${parts[2]}';
      }
    } catch (e) {
      debugPrint('Error formatting date: $e');
    }
    return str;
  }

  Widget _buildReadOnlyField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF4B5563),
            fontFamily: 'Outfit',
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: value,
          readOnly: true,
          style: const TextStyle(
            color: Color(0xFF1F2937),
            fontSize: 14,
            fontFamily: 'Outfit',
          ),
          decoration: InputDecoration(
            fillColor: Colors.white,
            filled: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGenderSelectionField(String label, String gender) {
    final isFemale = gender.toLowerCase() == 'female';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF4B5563),
            fontFamily: 'Outfit',
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            // Female Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isFemale ? const Color(0xFF28B79B) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isFemale ? const Color(0xFF28B79B) : const Color(0xFFD1D5DB),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isFemale ? Colors.white : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(color: isFemale ? Colors.white : const Color(0xFF9CA3AF), width: 2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Female',
                    style: TextStyle(
                      color: isFemale ? Colors.white : const Color(0xFF1F2937),
                      fontWeight: isFemale ? FontWeight.w600 : FontWeight.normal,
                      fontFamily: 'Outfit',
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Male Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: !isFemale ? const Color(0xFF28B79B) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: !isFemale ? const Color(0xFF28B79B) : const Color(0xFFD1D5DB),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: !isFemale ? Colors.white : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(color: !isFemale ? Colors.white : const Color(0xFF9CA3AF), width: 2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Male',
                    style: TextStyle(
                      color: !isFemale ? Colors.white : const Color(0xFF1F2937),
                      fontWeight: !isFemale ? FontWeight.w600 : FontWeight.normal,
                      fontFamily: 'Outfit',
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLearnerDetailView(Map<String, dynamic> user) {
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
    final nameParts = _splitFullName(fullName);
    final firstName = nameParts['firstName'] ?? '';
    final name = nameParts['name'] ?? '';

    final email = user['email'] ?? '';
    final phoneNumber = user['phoneNumber'] ?? '';
    final genderStr = user['gender'] ?? 'Female';
    final address = user['address'] ?? 'Khu công nghệ cao Hòa Lạc';
    
    final rolesList = user['roles'] as List?;
    final role = (rolesList != null && rolesList.isNotEmpty) ? rolesList.first.toString() : 'Learner';
    String displayRole = 'Learner';
    if (role.contains('TRAINER')) {
      displayRole = 'Trainer';
    } else if (role.contains('TRAINING_LEAD')) {
      displayRole = 'Training Lead';
    } else if (role.contains('ADMIN')) {
      displayRole = 'Admin';
    }

    final dobFormatted = _formatDateString(user['dateOfBirth']);
    final createdAtFormatted = _formatDateString(user['createdAt']);
    final updatedAtFormatted = _formatDateString(user['updatedAt']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Learner Account Detail',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
            fontFamily: 'Outfit',
          ),
        ),
        const SizedBox(height: 20),

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
              const Text(
                'Learner Detail',
                style: TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: Color(0xFF4B5563),
                  fontFamily: 'Outfit',
                ),
              ),
              const SizedBox(height: 32),

              Row(
                children: [
                  Expanded(
                    child: _buildReadOnlyField('First Name', firstName),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: _buildReadOnlyField('Name', name),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: _buildReadOnlyField('Email', email),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: _buildReadOnlyField('Date of Birth', dobFormatted),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: _buildGenderSelectionField('Gender', genderStr),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: _buildReadOnlyField('Địa chỉ', address),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: _buildReadOnlyField('Phone Number', phoneNumber),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: _buildReadOnlyField('Roles', displayRole),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: _buildReadOnlyField('Created Time', createdAtFormatted),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: _buildReadOnlyField('Last Modified Time', updatedAtFormatted),
                  ),
                ],
              ),
              const SizedBox(height: 40),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
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

  void _resetCreateForm() {
    _createFirstNameController.clear();
    _createNameController.clear();
    _createEmailController.clear();
    _createDobController.clear();
    _createAddressController.clear();
    _createPhoneController.clear();
    _createGender = 'Male';
    _createRole = null;
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF28B79B),
              onPrimary: Colors.white,
              onSurface: Color(0xFF1F2937),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF28B79B),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _createDobController.text = "${picked.month.toString().padLeft(2, '0')}/${picked.day.toString().padLeft(2, '0')}/${picked.year}";
      });
    }
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF4B5563),
            fontFamily: 'Outfit',
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            fillColor: Colors.white,
            filled: true,
            hintText: hintText,
            hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14, fontFamily: 'Outfit'),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF28B79B), width: 1.5),
            ),
          ),
          style: const TextStyle(fontSize: 14, fontFamily: 'Outfit'),
        ),
      ],
    );
  }

  Widget _buildDateField({
    required String label,
    required TextEditingController controller,
    required VoidCallback onTap,
    required String hintText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF4B5563),
            fontFamily: 'Outfit',
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          readOnly: true,
          onTap: onTap,
          decoration: InputDecoration(
            fillColor: Colors.white,
            filled: true,
            hintText: hintText,
            hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14, fontFamily: 'Outfit'),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            suffixIcon: const Icon(Icons.calendar_today_outlined, color: Color(0xFF9CA3AF), size: 20),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF28B79B), width: 1.5),
            ),
          ),
          style: const TextStyle(fontSize: 14, fontFamily: 'Outfit'),
        ),
      ],
    );
  }

  Widget _buildGenderRadioField() {
    return Column(
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
        const SizedBox(height: 8),
        Row(
          children: [
            Row(
              children: [
                Radio<String>(
                  value: 'Male',
                  groupValue: _createGender,
                  activeColor: const Color(0xFF28B79B),
                  onChanged: (val) {
                    setState(() {
                      if (val != null) _createGender = val;
                    });
                  },
                ),
                const Text(
                  'Male',
                  style: TextStyle(
                    color: Color(0xFF4B5563),
                    fontFamily: 'Outfit',
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 24),
            Row(
              children: [
                Radio<String>(
                  value: 'Female',
                  groupValue: _createGender,
                  activeColor: const Color(0xFF28B79B),
                  onChanged: (val) {
                    setState(() {
                      if (val != null) _createGender = val;
                    });
                  },
                ),
                const Text(
                  'Female',
                  style: TextStyle(
                    color: Color(0xFF4B5563),
                    fontFamily: 'Outfit',
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRoleDropdownField() {
    return Column(
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
          value: _createRole,
          hint: const Text(
            'Select user role',
            style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14, fontFamily: 'Outfit'),
          ),
          onChanged: (val) {
            setState(() {
              _createRole = val;
            });
          },
          items: const [
            DropdownMenuItem(value: 'Trainer', child: Text('Trainer', style: TextStyle(fontFamily: 'Outfit'))),
            DropdownMenuItem(value: 'Training Lead', child: Text('Training Lead', style: TextStyle(fontFamily: 'Outfit'))),
            DropdownMenuItem(value: 'Admin', child: Text('Admin', style: TextStyle(fontFamily: 'Outfit'))),
          ],
          decoration: InputDecoration(
            fillColor: Colors.white,
            filled: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF28B79B), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleCreateUser() async {
    final firstName = _createFirstNameController.text.trim();
    final name = _createNameController.text.trim();
    final email = _createEmailController.text.trim();
    
    if (firstName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('First Name is required')),
      );
      return;
    }
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name is required')),
      );
      return;
    }
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address')),
      );
      return;
    }
    if (_createRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a user role')),
      );
      return;
    }

    setState(() {
      _isCreatingUser = true;
    });

    try {
      final token = await _authService.getToken();
      if (token == null) {
        throw Exception('Authentication token missing.');
      }

      String backendRole = 'TRAINER';
      if (_createRole == 'Training Lead') {
        backendRole = 'TRAINING_LEAD';
      } else if (_createRole == 'Admin') {
        backendRole = 'ADMINISTRATOR';
      }

      String? formattedDob;
      if (_createDobController.text.isNotEmpty) {
        final parts = _createDobController.text.split('/');
        if (parts.length == 3) {
          formattedDob = '${parts[2]}-${parts[0]}-${parts[1]}'; // yyyy-MM-dd
        }
      }

      final response = await http.post(
        Uri.parse('$apiBaseUrl/admin/users'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'fullName': '$firstName $name'.trim(),
          'email': email,
          'password': 'Hango@2026!',
          'phoneNumber': _createPhoneController.text.trim(),
          'gender': _createGender,
          'role': backendRole,
          'dateOfBirth': formattedDob,
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Account created successfully!'),
              backgroundColor: Color(0xFF28B79B),
            ),
          );
          setState(() {
            _showCreateNewAccountView = false;
            _resetCreateForm();
          });
          _fetchAccounts();
        }
      } else {
        throw Exception(response.body);
      }
    } catch (e) {
      String errMsg = e.toString();
      if (errMsg.startsWith('Exception: ')) {
        errMsg = errMsg.substring(11);
      }
      if (errMsg.startsWith('Error: ')) {
        errMsg = errMsg.substring(7);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create account: $errMsg'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingUser = false;
        });
      }
    }
  }

  Widget _buildCreateAccountView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Create New Account',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
            fontFamily: 'Outfit',
          ),
        ),
        const SizedBox(height: 20),

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header of the card
              Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                  border: Border(
                    bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                child: const Text(
                  'Create New Account',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                    fontFamily: 'Outfit',
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildInputField(
                            label: 'First Name',
                            controller: _createFirstNameController,
                            hintText: 'Enter first name',
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: _buildInputField(
                            label: 'Name',
                            controller: _createNameController,
                            hintText: 'Enter name',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    Row(
                      children: [
                        Expanded(
                          child: _buildInputField(
                            label: 'Email',
                            controller: _createEmailController,
                            hintText: 'Enter email address',
                            keyboardType: TextInputType.emailAddress,
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: _buildDateField(
                            label: 'Date of Birth',
                            controller: _createDobController,
                            onTap: () => _selectDate(context),
                            hintText: 'mm/dd/yyyy',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    Row(
                      children: [
                        Expanded(
                          child: _buildGenderRadioField(),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: _buildInputField(
                            label: 'Address',
                            controller: _createAddressController,
                            hintText: 'Enter address',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    Row(
                      children: [
                        Expanded(
                          child: _buildInputField(
                            label: 'Phone Number',
                            controller: _createPhoneController,
                            hintText: 'Enter phone number',
                            keyboardType: TextInputType.phone,
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: _buildRoleDropdownField(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _resetCreateForm();
                              _showCreateNewAccountView = false;
                            });
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFD1D5DB)),
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Back',
                            style: TextStyle(
                              color: Color(0xFF4B5563),
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Outfit',
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: _isCreatingUser ? null : _handleCreateUser,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF28B79B),
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                          child: _isCreatingUser
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Create',
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
          ),
        ),
      ],
    );
  }

  void _initProfileFields() {
    _profileNameController.text = _adminName;
    _profileEmailController.text = _adminEmail;
    _profilePhoneController.text = '';
    _profileAvatarController.text = _adminAvatarUrl;
    _profileGender = 'Male';
    _profileDobController.text = '';
    _fetchAdminProfile();
  }

  Future<void> _fetchAdminProfile() async {
    setState(() {
      _isLoadingProfile = true;
    });
    try {
      final res = await _authService.getProfile();
      if (res['success'] == true) {
        final data = res['data'];
        setState(() {
          _adminName = data['fullName'] ?? '';
          _adminEmail = data['email'] ?? '';
          _adminAvatarUrl = data['avatarUrl'] ?? '';
          
          _profileNameController.text = _adminName;
          _profileEmailController.text = _adminEmail;
          _profilePhoneController.text = data['phoneNumber'] ?? '';
          _profileAvatarController.text = _adminAvatarUrl;
          _profileGender = data['gender'] ?? 'Male';
          
          if (data['dateOfBirth'] != null) {
            try {
              final dobStr = data['dateOfBirth'].toString();
              final parts = dobStr.split('-');
              if (parts.length == 3) {
                _profileDobController.text = '${parts[2]}/${parts[1]}/${parts[0]}';
              } else {
                _profileDobController.text = dobStr;
              }
            } catch (e) {
              _profileDobController.text = '';
            }
          } else {
            _profileDobController.text = '';
          }

          if (_adminName.trim().isNotEmpty) {
            final parts = _adminName.trim().split(' ');
            if (parts.isNotEmpty) {
              _adminInitials = parts.last[0].toUpperCase();
            }
          }
          _isLoadingProfile = false;
        });
      } else {
        setState(() {
          _isLoadingProfile = false;
        });
        debugPrint('Failed to load profile: ${res['message']}');
      }
    } catch (e) {
      setState(() {
        _isLoadingProfile = false;
      });
      debugPrint('Error loading profile: $e');
    }
  }

  Future<void> _saveProfileChanges() async {
    setState(() {
      _isLoadingProfile = true;
    });

    try {
      String? formattedDob;
      if (_profileDobController.text.isNotEmpty) {
        final parts = _profileDobController.text.split('/');
        if (parts.length == 3) {
          formattedDob = '${parts[2]}-${parts[1]}-${parts[0]}';
        }
      }

      final profileData = {
        'fullName': _profileNameController.text.trim(),
        'email': _profileEmailController.text.trim(),
        'phoneNumber': _profilePhoneController.text.trim(),
        'avatarUrl': _profileAvatarController.text.trim(),
        'gender': _profileGender,
        if (formattedDob != null) 'dateOfBirth': formattedDob,
      };

      final res = await _authService.updateProfile(profileData);
      if (res['success'] == true) {
        final data = res['data'];
        setState(() {
          _adminName = data['fullName'] ?? '';
          _adminEmail = data['email'] ?? '';
          _adminAvatarUrl = data['avatarUrl'] ?? '';
          
          if (_adminName.trim().isNotEmpty) {
            final parts = _adminName.trim().split(' ');
            if (parts.isNotEmpty) {
              _adminInitials = parts.last[0].toUpperCase();
            }
          }
          _isLoadingProfile = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile updated successfully!'),
              backgroundColor: Color(0xFF28B79B),
            ),
          );
        }
      } else {
        setState(() {
          _isLoadingProfile = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update profile: ${res['message']}'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoadingProfile = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Widget _buildProfileTab(bool isDesktop) {
    if (_isLoadingProfile) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40.0),
          child: CircularProgressIndicator(color: Color(0xFF28B79B)),
        ),
      );
    }

    // Compute username from email
    String username = '';
    if (_adminEmail.isNotEmpty) {
      username = _adminEmail.split('@').first;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Breadcrumb
        Row(
          children: const [
            Icon(Icons.chevron_right, size: 16, color: Color(0xFF28B79B)),
            SizedBox(width: 4),
            Text(
              'Profile',
              style: TextStyle(
                color: Color(0xFF28B79B),
                fontSize: 13,
                fontWeight: FontWeight.bold,
                fontFamily: 'Outfit',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Title
        const Text(
          'Profile',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
            fontFamily: 'Outfit',
          ),
        ),
        const SizedBox(height: 24),

        // Main Card
        Container(
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
              // Profile Photo & Name Section
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF1F2937), width: 2),
                        ),
                        child: _profileAvatarController.text.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(45),
                                child: Image.network(
                                  _profileAvatarController.text,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Center(
                                    child: Text(
                                      _adminInitials,
                                      style: const TextStyle(
                                        color: Color(0xFFEA580C),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 32,
                                        fontFamily: 'Outfit',
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            : Center(
                                child: Text(
                                  _adminInitials,
                                  style: const TextStyle(
                                    color: Color(0xFFEA580C),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 32,
                                    fontFamily: 'Outfit',
                                  ),
                                ),
                              ),
                      ),
                      // Pencil edit button overlay on bottom right
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _showAvatarEditDialog,
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: const BoxDecoration(
                              color: Color(0xFF28B79B),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.edit,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _adminName,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F2937),
                            fontFamily: 'Outfit',
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'ID: PS-29384-CC',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF6B7280),
                            fontFamily: 'Outfit',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Form fields grid/layout matching the mockup exactly
              LayoutBuilder(
                builder: (context, constraints) {
                  final formWidth = constraints.maxWidth;
                  final isWide = formWidth > 600;

                  return Column(
                    children: [
                      // Row 1: FullName & Username
                      _buildFormRow(
                        isWide,
                        _buildTextFieldNoIcon('FullName', _profileNameController),
                        _buildTextFieldNoIcon('Username', TextEditingController(text: username), enabled: false),
                      ),
                      const SizedBox(height: 24),

                      // Row 2: Email & Role
                      _buildFormRow(
                        isWide,
                        _buildTextFieldWithEmailIcon('Email', _profileEmailController),
                        _buildRoleDisplayBox('Role', 'Admin'),
                      ),
                      const SizedBox(height: 24),

                      // Row 3: Date of Birth & Gender
                      _buildFormRow(
                        isWide,
                        _buildDatePickerField(context),
                        _buildGenderRadioGroup(),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 40),
              const Divider(color: Color(0xFFE5E7EB)),
              const SizedBox(height: 24),

              // Bottom Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _saveProfileChanges,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                      side: const BorderSide(color: Color(0xFF28B79B)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text(
                      'Update',
                      style: TextStyle(
                        color: Color(0xFF28B79B),
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _selectedMenuIndex = 0; // Go back to dashboard
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF28B79B),
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Back',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Outfit',
                        fontSize: 15,
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

  void _showAvatarEditDialog() {
    final controller = TextEditingController(text: _profileAvatarController.text);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Avatar URL', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter image URL',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B7280))),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _profileAvatarController.text = controller.text;
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF28B79B)),
            child: const Text('OK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildFormRow(bool isWide, Widget left, Widget right) {
    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: left),
          const SizedBox(width: 24),
          Expanded(child: right),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        left,
        const SizedBox(height: 20),
        right,
      ],
    );
  }

  Widget _buildTextFieldNoIcon(String label, TextEditingController controller, {bool enabled = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF374151), fontFamily: 'Outfit'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          enabled: enabled,
          style: const TextStyle(fontFamily: 'Outfit', fontSize: 15),
          decoration: InputDecoration(
            filled: true,
            fillColor: enabled ? Colors.white : const Color(0xFFF3F4F6),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF28B79B), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextFieldWithEmailIcon(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF374151), fontFamily: 'Outfit'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          enabled: false,
          style: const TextStyle(fontFamily: 'Outfit', fontSize: 15),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF9CA3AF), size: 20),
            filled: true,
            fillColor: const Color(0xFFF3F4F6),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRoleDisplayBox(String label, String roleName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF374151), fontFamily: 'Outfit'),
        ),
        const SizedBox(height: 8),
        Container(
          height: 48,
          width: double.infinity,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFEEF2FF),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
          ),
          child: Text(
            roleName,
            style: const TextStyle(
              color: Color(0xFF3F51B5),
              fontWeight: FontWeight.bold,
              fontSize: 15,
              fontFamily: 'Outfit',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGenderRadioGroup() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Gender',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF374151), fontFamily: 'Outfit'),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            GestureDetector(
              onTap: () {
                setState(() {
                  _profileGender = 'Female';
                });
              },
              child: Row(
                children: [
                  Radio<String>(
                    value: 'Female',
                    groupValue: _profileGender,
                    activeColor: const Color(0xFF28B79B),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _profileGender = val;
                        });
                      }
                    },
                  ),
                  const Text('Female', style: TextStyle(fontFamily: 'Outfit', fontSize: 15)),
                ],
              ),
            ),
            const SizedBox(width: 24),
            GestureDetector(
              onTap: () {
                setState(() {
                  _profileGender = 'Male';
                });
              },
              child: Row(
                children: [
                  Radio<String>(
                    value: 'Male',
                    groupValue: _profileGender,
                    activeColor: const Color(0xFF28B79B),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _profileGender = val;
                        });
                      }
                    },
                  ),
                  const Text('Male', style: TextStyle(fontFamily: 'Outfit', fontSize: 15)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDatePickerField(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Date of Birth',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF374151), fontFamily: 'Outfit'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _profileDobController,
          readOnly: true,
          style: const TextStyle(fontFamily: 'Outfit', fontSize: 15),
          onTap: () async {
            DateTime? initialDate;
            try {
              final parts = _profileDobController.text.split('/');
              if (parts.length == 3) {
                initialDate = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
              }
            } catch (e) {
              initialDate = null;
            }
            
            final picked = await showDatePicker(
              context: context,
              initialDate: initialDate ?? DateTime(2000, 1, 1),
              firstDate: DateTime(1900),
              lastDate: DateTime.now(),
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: const ColorScheme.light(
                      primary: Color(0xFF28B79B),
                      onPrimary: Colors.white,
                      onSurface: Color(0xFF1F2937),
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (picked != null) {
              setState(() {
                final day = picked.day.toString().padLeft(2, '0');
                final month = picked.month.toString().padLeft(2, '0');
                _profileDobController.text = '$day/$month/${picked.year}';
              });
            }
          },
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF28B79B), width: 1.5),
            ),
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
