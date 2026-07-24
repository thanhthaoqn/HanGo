import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import '../../../utils/config.dart';
import '../../../data/services/auth_service.dart';
import '../trainer/trainer_create_exam_page.dart';
import '../trainer/trainer_edit_exam_page.dart';
import '../../widgets/shared_header.dart';
import '../../widgets/course_manager_sidebar.dart';
import '../../../data/services/course_manager_api.dart';

class CourseManagerExamsPage extends StatefulWidget {
  const CourseManagerExamsPage({super.key});

  @override
  State<CourseManagerExamsPage> createState() => _CourseManagerExamsPageState();
}

class _CourseManagerExamsPageState extends State<CourseManagerExamsPage> {
  final _authService = AuthService();
  bool _isLoading = true;
  String _errorMessage = '';
  bool _isSidebarVisible = true;
  int? _currentUserId;
  List<dynamic> _examsList = [];
  
  int _currentPage = 1;
  final int _itemsPerPage = 10;

  // Tab Status Filters
  String _selectedStatus = 'ALL'; 

  // Status Counts
  int _allCount = 0;
  int _draftCount = 0;
  int _publishedCount = 0;
  int _hiddenCount = 0;
  int _pendingCount = 0;

  // Filter values
  final TextEditingController _searchController = TextEditingController();
  String _selectedSortBy = 'NEWEST';
  String _selectedTimePeriod = 'ALL';

  String get apiBaseUrl => EnvConfig.v1BaseUrl;

  @override
  void initState() {
    super.initState();
    _loadCourseManagerInfo();
    _fetchExamsData();
  }

  Future<void> _loadCourseManagerInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUserId = prefs.getInt('user_id');
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchExamsData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _currentPage = 1;
    });

    try {
      final api = CourseManagerApi();
      final data = await api.getExamsForReview(_selectedStatus);
      
      setState(() {
        _examsList = data;
        
        // Calculate counts if we fetched ALL
        if (_selectedStatus == 'ALL') {
          _allCount = data.length;
          _draftCount = data.where((e) => e['status'] == 'DRAFT').length;
          _publishedCount = data.where((e) => e['status'] == 'PUBLISHED').length;
          _hiddenCount = data.where((e) => e['status'] == 'HIDDEN').length;
          _pendingCount = data.where((e) => e['status'] == 'PENDING_APPROVAL' || e['status'] == 'SUBMITTED').length;
        } else {
          // If we filtered, just update the selected count (or allCount as fallback)
          _allCount = data.length;
        }
        _isLoading = false;
      });
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
      _allCount = 1;
      _draftCount = 0;
      _publishedCount = 1;
      _hiddenCount = 0;
      _pendingCount = 0;
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

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 1024;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: SharedHeader(
        isDesktop: isDesktop,
        activeTab: '',
        hideNavLinks: true,
        hideCommerceActions: true,
        hideLanguageSwitcher: true,
      ),
      drawer: !isDesktop ? const Drawer(child: CourseManagerSidebar(currentRoute: 'exams')) : null,
      body: Row(
        children: [
          if (isDesktop && _isSidebarVisible) const SizedBox(width: 240, child: CourseManagerSidebar(currentRoute: 'exams')),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildContentHeader(context, isDesktop),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        _buildFilterContainer(),
                        const SizedBox(height: 24),
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



  Widget _buildFilterContainer() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEFF2F5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildStatusTab('All', 'ALL', _allCount),
                const SizedBox(width: 8),
                _buildStatusTab('Draft', 'DRAFT', _draftCount),
                const SizedBox(width: 8),
                _buildStatusTab('Published', 'PUBLISHED', _publishedCount),
                const SizedBox(width: 8),
                _buildStatusTab('Hidden', 'HIDDEN', _hiddenCount),
                const SizedBox(width: 8),
                _buildStatusTab('Pending', 'PENDING_APPROVAL', _pendingCount),
              ],
            ),
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final useRow = constraints.maxWidth > 768;

              final searchField = TextField(
                controller: _searchController,
                onChanged: (val) => _fetchExamsData(),
                decoration: InputDecoration(
                  hintText: 'Search for exams...',
                  hintStyle: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 14,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Color(0xFF94A3B8),
                    size: 20,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF38C9A6)),
                  ),
                ),
              );

              final sortByDropdown = _buildDropdown(
                value: _selectedSortBy,
                items: const [
                  DropdownMenuItem(
                    value: 'NEWEST',
                    child: Text('Sort by: Newest'),
                  ),
                  DropdownMenuItem(
                    value: 'OLDEST',
                    child: Text('Sort by: Oldest'),
                  ),
                  DropdownMenuItem(
                    value: 'ALPHABETICAL',
                    child: Text('Sort by: Alphabetical'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedSortBy = val);
                    _fetchExamsData();
                  }
                },
              );

              final timePeriodDropdown = _buildDropdown(
                value: _selectedTimePeriod,
                items: const [
                  DropdownMenuItem(
                    value: 'ALL',
                    child: Text('Time Period: All'),
                  ),
                  DropdownMenuItem(
                    value: 'THIS_WEEK',
                    child: Text('Time Period: This Week'),
                  ),
                  DropdownMenuItem(
                    value: 'THIS_MONTH',
                    child: Text('Time Period: This Month'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedTimePeriod = val);
                    _fetchExamsData();
                  }
                },
              );

              if (useRow) {
                return Row(
                  children: [
                    Expanded(flex: 3, child: searchField),
                    const SizedBox(width: 16),
                    Expanded(flex: 1, child: sortByDropdown),
                    const SizedBox(width: 16),
                    Expanded(flex: 1, child: timePeriodDropdown),
                  ],
                );
              } else {
                return Column(
                  children: [
                    searchField,
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: sortByDropdown),
                        const SizedBox(width: 12),
                        Expanded(child: timePeriodDropdown),
                      ],
                    ),
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTab(String label, String statusKey, int count) {
    final isActive = _selectedStatus == statusKey;
    return InkWell(
      onTap: () {
        setState(() => _selectedStatus = statusKey);
        _fetchExamsData();
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFE6FFFA) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? const Color(0xFF38C9A6) : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isActive
                    ? const Color(0xFF38C9A6)
                    : const Color(0xFF4B5563),
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                fontSize: 14,
                fontFamily: 'Outfit',
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xFF38C9A6)
                    : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: isActive ? Colors.white : const Color(0xFF64748B),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          icon: const Icon(
            Icons.keyboard_arrow_down,
            color: Color(0xFF64748B),
            size: 18,
          ),
          style: const TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 14,
            fontWeight: FontWeight.w500,
            fontFamily: 'Outfit',
          ),
        ),
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
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: exam['thumbnailUrl'] != null && exam['thumbnailUrl'].toString().isNotEmpty
                      ? Image.network(
                          exam['thumbnailUrl'],
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            width: 48,
                            height: 48,
                            color: const Color(0xFFE2E8F0),
                            child: const Icon(Icons.image_not_supported, color: Color(0xFF94A3B8)),
                          ),
                        )
                      : Container(
                          width: 48,
                          height: 48,
                          color: const Color(0xFFE2E8F0),
                          child: const Icon(Icons.assignment, color: Color(0xFF94A3B8)),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    exam['title'] ?? 'Untitled',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                      fontSize: 15,
                      fontFamily: 'Outfit',
                      height: 1.5,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
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
              child: _buildVisibilityChip(exam),
            ),
          ),
          Expanded(
            flex: 1,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Builder(builder: (context) {
                  final status = exam['status']?.toString().toUpperCase() ?? 'DRAFT';
                  final bool isCreator = _currentUserId != null && exam['creatorId'] == _currentUserId;
                  
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Edit button for creator in draft
                      if (isCreator && status == 'DRAFT')
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
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ),

                      // View button for all others
                      if (!isCreator || status != 'DRAFT')
                        IconButton(
                          icon: const Icon(Icons.remove_red_eye_outlined, color: Color(0xFF38C9A6), size: 20),
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => TrainerEditExamPage(
                                examId: exam['id'],
                                examTitle: exam['title'] ?? 'Untitled',
                                examExpectedCount: (exam['expectedQuestionCount'] ?? exam['questionCount'] ?? 10) as int,
                                isReadOnly: true,
                                courseManagerActionStatus: status,
                              )),
                            );
                            _fetchExamsData();
                          },
                          splashRadius: 20,
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                    ],
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Future<void> _updateExamVisibility(int examId, String newVisibility) async {
    try {
      final token = await _authService.getToken();
      if (token == null) return;
      final response = await http.patch(
        Uri.parse('$apiBaseUrl/trainer/exams/$examId/visibility'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'visibility': newVisibility}),
      );
      if (response.statusCode == 200) {
        _fetchExamsData();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update visibility')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error updating exam visibility: $e');
    }
  }



  Widget _buildStatusChip(String status) {
    status = status.toUpperCase();
    Color bgColor;
    Color textColor;
    if (status == 'APPROVED') {
      bgColor = const Color(0xFFE6FFFA);
      textColor = const Color(0xFF20B486);
    } else if (status == 'PENDING_APPROVAL' || status == 'PENDING' || status == 'SUBMITTED') {
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

  Widget _buildVisibilityChip(Map<String, dynamic> exam) {
    String? visibility = exam['visibility'];
    bool isPublic = visibility?.toUpperCase() == 'PUBLIC';
    bool canEdit = _currentUserId != null && exam['creatorId'] == _currentUserId;

    return InkWell(
      onTap: canEdit ? () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Change Visibility', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
            content: Text(
              'Do you want to change visibility to ${isPublic ? "Private" : "Public"}?',
              style: const TextStyle(fontFamily: 'Outfit'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _updateExamVisibility(exam['id'], isPublic ? 'PRIVATE' : 'PUBLIC');
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF38C9A6)),
                child: const Text('Confirm', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      } : null,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isPublic ? const Color(0xFFE0F2FE) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: canEdit ? (isPublic ? const Color(0xFFBAE6FD) : const Color(0xFFE2E8F0)) : Colors.transparent),
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

  Widget _buildContentHeader(BuildContext context, bool isDesktop) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      child: Row(
        children: [
          if (!isDesktop) ...[
            IconButton(
              icon: const Icon(Icons.menu, color: Color(0xFF4B5563)),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
            const SizedBox(width: 12),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.menu, color: Color(0xFF4B5563)),
              onPressed: () {
                setState(() {
                  _isSidebarVisible = !_isSidebarVisible;
                });
              },
            ),
            const SizedBox(width: 12),
          ],
          const Text(
            'Exam',
            style: TextStyle(
              color: Color(0xFF20B486),
              fontWeight: FontWeight.bold,
              fontSize: 14,
              fontFamily: 'Outfit',
            ),
          ),
          const Spacer(),
          ElevatedButton.icon(
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
              backgroundColor: const Color(0xFF38C9A6),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }
}
