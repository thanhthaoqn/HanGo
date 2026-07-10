import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/services/auth_service.dart';
import '../login_page.dart';
import 'trainer_dashboard_page.dart';
import 'trainer_courses_page.dart';
import 'trainer_create_exam_page.dart';
import 'trainer_edit_exam_page.dart';
import 'question_bank/trainer_question_bank_page.dart';
import '../../../utils/toast_helper.dart';

class TrainerExamsPage extends StatefulWidget {
  const TrainerExamsPage({super.key});

  @override
  State<TrainerExamsPage> createState() => _TrainerExamsPageState();
}

class _TrainerExamsPageState extends State<TrainerExamsPage> {
  final _authService = AuthService();
  String _trainerName = 'Thảo';
  String _trainerInitials = 'T';
  String _trainerAvatarUrl = '';

  bool _isLoading = true;
  String _errorMessage = '';
  List<dynamic> _examsList = [];
  
  int _currentPage = 1;
  final int _itemsPerPage = 10;

  String get apiBaseUrl {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080/api/v1';
    }
    return 'http://localhost:8080/api/v1';
  }

  @override
  void initState() {
    super.initState();
    _loadTrainerInfo();
    _fetchExamsData();
  }

  Future<void> _fetchExamsData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _currentPage = 1;
    });

    try {
      final token = await _authService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final uri = Uri.parse('$apiBaseUrl/trainer/exams');
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() {
          _examsList = data;
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load exams data: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error loading exams data: $e');
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
      _loadMockFallback();
    }
  }

  void _loadMockFallback() {
    setState(() {
      _examsList = [
        {
          'id': 1,
          'title': 'Thi Thử Tốt Nghiệp THPT Tiếng anh năm 2025 - THPT Chuyên Phan Bội Châu (Mock)',
          'createdAt': '2025-05-20', 
          'questionCount': 50,
          'durationMinutes': 60,
          'status': 'public',
        },
      ];
    });
  }

  String _formatDate(dynamic dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      final dateTime = DateTime.parse(dateStr.toString());
      return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
    } catch (e) {
      String str = dateStr.toString();
      if (str.length >= 10) return str.substring(0, 10);
      return str;
    }
  }

  Future<void> _loadTrainerInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final fullName = prefs.getString('user_fullname') ?? 'Thảo';
    final avatarUrl = prefs.getString('user_avatar_url') ?? '';
    String initials = 'T';
    if (fullName.trim().isNotEmpty) {
      final parts = fullName.trim().split(' ');
      if (parts.isNotEmpty) {
        initials = parts.last[0].toUpperCase();
      }
    }
    setState(() {
      _trainerName = fullName;
      _trainerInitials = initials;
      _trainerAvatarUrl = avatarUrl;
    });
  }

  void _handleLogout() async {
    await _authService.logout();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 1024;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: !isDesktop ? Drawer(child: _buildSidebar(context)) : null,
      body: Row(
        children: [
          if (isDesktop) SizedBox(width: 240, child: _buildSidebar(context)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(context, !isDesktop),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Create New Exam button on top right
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const TrainerCreateExamPage()),
                              );
                              _fetchExamsData();
                            },
                            icon: const Icon(Icons.add, color: Colors.white, size: 18),
                            label: const Text(
                              'Create New Exam',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Outfit',
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF38C9A6), // matches mockup
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (_isLoading)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(40.0),
                              child: CircularProgressIndicator(color: Color(0xFF20B486)),
                            ),
                          )
                        else
                          _buildExamsTable(),
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

  Widget _buildExamsTable() {
    int totalItems = _examsList.length;
    int totalPages = (totalItems / _itemsPerPage).ceil();
    if (totalPages == 0) totalPages = 1;
    if (_currentPage > totalPages) _currentPage = totalPages;

    int startIndex = (_currentPage - 1) * _itemsPerPage;
    int endIndex = startIndex + _itemsPerPage;
    if (endIndex > totalItems) endIndex = totalItems;

    List<dynamic> currentExams = _examsList.isEmpty ? [] : _examsList.sublist(startIndex, endIndex);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Expanded(flex: 3, child: _buildTableHeaderText('Exam Title')),
                Expanded(flex: 1, child: _buildTableHeaderText('Create Date')),
                Expanded(flex: 1, child: _buildTableHeaderText('Questions')),
                Expanded(flex: 1, child: _buildTableHeaderText('Duration')),
                Expanded(flex: 1, child: _buildTableHeaderText('Status')),
                Expanded(flex: 1, child: _buildTableHeaderText('Visibility')),
                Expanded(flex: 1, child: _buildTableHeaderText('Actions', align: TextAlign.center)),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          // Table Body
          currentExams.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(40.0),
                  child: Center(
                    child: Text(
                      'No exams found.',
                      style: TextStyle(color: Color(0xFF64748B), fontFamily: 'Outfit'),
                    ),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: currentExams.length,
                  separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  itemBuilder: (context, index) {
                    final exam = currentExams[index];
                    return _buildExamRow(exam);
                  },
                ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          // Pagination Footer
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Showing ${totalItems == 0 ? 0 : startIndex + 1} to $endIndex of $totalItems entries',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 14,
                    fontFamily: 'Outfit',
                  ),
                ),
                Row(
                  children: [
                    _buildPaginationButton(
                      Icons.chevron_left,
                      onPressed: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
                    ),
                    const SizedBox(width: 8),
                    ...List.generate(totalPages, (index) {
                      int pageNum = index + 1;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: _buildPaginationNumber(
                          pageNum.toString(),
                          isActive: pageNum == _currentPage,
                          onPressed: () => setState(() => _currentPage = pageNum),
                        ),
                      );
                    }),
                    _buildPaginationButton(
                      Icons.chevron_right,
                      onPressed: _currentPage < totalPages ? () => setState(() => _currentPage++) : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeaderText(String text, {TextAlign align = TextAlign.left}) {
    return Text(
      text,
      textAlign: align,
      style: const TextStyle(
        color: Color(0xFF64748B),
        fontWeight: FontWeight.bold,
        fontSize: 14,
        fontFamily: 'Outfit',
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildExamRow(Map<String, dynamic> exam) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              exam['title'],
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
                fontSize: 15,
                fontFamily: 'Outfit',
                height: 1.5,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6FFFA),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _formatDate(exam['createdAt']),
                  style: const TextStyle(
                    color: Color(0xFF20B486),
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                    fontFamily: 'Outfit',
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              exam['questionCount']?.toString() ?? '0',
              style: const TextStyle(
                color: Color(0xFF1E293B),
                fontWeight: FontWeight.w500,
                fontSize: 14,
                fontFamily: 'Outfit',
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              '${exam['durationMinutes'] ?? 0} mins',
              style: const TextStyle(
                color: Color(0xFF1E293B),
                fontWeight: FontWeight.w500,
                fontSize: 14,
                fontFamily: 'Outfit',
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _buildStatusChip(exam['status'] ?? 'DRAFT'),
            ),
          ),
          Expanded(
            flex: 1,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _buildVisibilityChip(exam['status'], exam['visibility']),
            ),
          ),
          Expanded(
            flex: 1,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: Color(0xFF64748B), size: 20),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => TrainerEditExamPage(
                        examId: exam['id'],
                        examTitle: exam['title'] ?? 'Untitled',
                        examExpectedCount: (exam['expectedQuestionCount'] ?? exam['questionCount'] ?? 10) as int,
                      )),
                    );
                    _fetchExamsData();
                  },
                  splashRadius: 20,
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Color(0xFF64748B), size: 20),
                  onPressed: () {},
                  splashRadius: 20,
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    status = status.toUpperCase();
    Color bgColor;
    Color textColor;
    if (status == 'APPROVED') {
      bgColor = const Color(0xFFE6FFFA);
      textColor = const Color(0xFF20B486);
    } else if (status == 'SUBMITTED' || status == 'PENDING') {
      bgColor = const Color(0xFFFEF3C7);
      textColor = const Color(0xFFD97706);
    } else if (status == 'REJECTED') {
      bgColor = const Color(0xFFFEE2E2);
      textColor = const Color(0xFFEF4444);
    } else { // DRAFT
      bgColor = const Color(0xFFF1F5F9);
      textColor = const Color(0xFF64748B);
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: textColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            status.length > 1 ? status.substring(0, 1).toUpperCase() + status.substring(1).toLowerCase() : status,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w600,
              fontSize: 12,
              fontFamily: 'Outfit',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisibilityChip(String? status, String? visibility) {
    if (status == null || status.toUpperCase() != 'APPROVED') {
      return const Text(
        '-',
        style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold),
      );
    }
    
    bool isPublic = visibility?.toUpperCase() == 'PUBLIC';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isPublic ? const Color(0xFFE0F2FE) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPublic ? Icons.public : Icons.lock_outline,
            size: 14,
            color: isPublic ? const Color(0xFF0284C7) : const Color(0xFF64748B),
          ),
          const SizedBox(width: 6),
          Text(
            isPublic ? 'Public' : 'Private',
            style: TextStyle(
              color: isPublic ? const Color(0xFF0284C7) : const Color(0xFF64748B),
              fontWeight: FontWeight.w600,
              fontSize: 12,
              fontFamily: 'Outfit',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationButton(IconData icon, {VoidCallback? onPressed}) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: onPressed == null ? const Color(0xFFF8FAFC) : Colors.white,
          border: Border.all(color: const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 18, color: onPressed == null ? const Color(0xFFCBD5E1) : const Color(0xFF64748B)),
      ),
    );
  }

  Widget _buildPaginationNumber(String text, {bool isActive = false, VoidCallback? onPressed}) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF0F766E) : Colors.white,
          border: Border.all(color: isActive ? const Color(0xFF0F766E) : const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(6),
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: TextStyle(
            color: isActive ? Colors.white : const Color(0xFF64748B),
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

// --- Layout stuff (sidebar and header) to keep the page consistent ---
  Widget _buildSidebar(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE6FFFA),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.school,
                    size: 18,
                    color: Color(0xFF38C9A6),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'HanGo',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                    fontFamily: 'Outfit',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          _buildSidebarItem(
            Icons.dashboard_outlined,
            'Dashboard',
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const TrainerDashboardPage(),
                ),
              );
            },
          ),
          _buildSidebarItem(Icons.book_outlined, 'Courses', onTap: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const TrainerCoursesPage(),
              ),
            );
          }),
          _buildSidebarItem(Icons.assignment_outlined, 'Exam', isActive: true),
          _buildSidebarItem(Icons.people_outline, 'Learner'),
          _buildSidebarItem(Icons.question_answer_outlined, 'Question Bank', onTap: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const TrainerQuestionBankPage(),
              ),
            );
          }),
          const Spacer(),
          const Divider(color: Color(0xFFE2E8F0)),
          const SizedBox(height: 12),
          _buildSidebarItem(Icons.help_outline, 'Help Center', onTap: () {
            ToastHelper.show(context, 'Help Center is under construction');
          }),
          _buildSidebarItem(Icons.logout, 'Logout', color: Colors.redAccent, onTap: _handleLogout),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(
    IconData icon,
    String title, {
    bool isActive = false,
    Color? color,
    VoidCallback? onTap,
  }) {
    final activeColor = const Color(0xFF38C9A6);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: InkWell(
        onTap: onTap ?? () {},
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isActive ? Colors.white : (color ?? const Color(0xFF4B5563)),
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  color: isActive ? Colors.white : (color ?? const Color(0xFF1F2937)),
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                  fontSize: 14,
                  fontFamily: 'Outfit',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool showMenuButton) {
    return Container(
      color: Colors.white,
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          if (showMenuButton) ...[
            IconButton(
              icon: const Icon(Icons.menu, color: Color(0xFF4B5563)),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
            const SizedBox(width: 12),
          ],
          Row(
            children: const [
              Icon(Icons.chevron_right, size: 16, color: Color(0xFF38C9A6)),
              SizedBox(width: 4),
              Text(
                'Exam',
                style: TextStyle(
                  color: Color(0xFF38C9A6),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  fontFamily: 'Outfit',
                ),
              ),
            ],
          ),
          const Spacer(),
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.notifications_none_outlined,
                  color: Color(0xFF4B5563),
                  size: 24,
                ),
                onPressed: () {
                  ToastHelper.show(context, 'No new notifications');
                },
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Row(
            children: [
              Text(
                _trainerName,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                  fontSize: 14,
                  fontFamily: 'Outfit',
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: Color(0xFFE2F9F3),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: _trainerAvatarUrl.isNotEmpty
                    ? ClipOval(
                        child: Image.network(
                          _trainerAvatarUrl,
                          width: 32,
                          height: 32,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Text(
                            _trainerInitials,
                            style: const TextStyle(
                              color: Color(0xFF38C9A6),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              fontFamily: 'Outfit',
                            ),
                          ),
                        ),
                      )
                    : Text(
                        _trainerInitials,
                        style: const TextStyle(
                          color: Color(0xFF38C9A6),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          fontFamily: 'Outfit',
                        ),
                      ),
              ),
              const SizedBox(width: 4),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF38C9A6),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
