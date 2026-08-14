import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import '../../../utils/config.dart';
import '../../../data/services/auth_service.dart';
import 'course_manager_create_exam_page.dart';
import 'course_manager_edit_exam_page.dart';
import 'exam_review_dashboard_dialog.dart';
import 'exam_history_dialog.dart';
import 'package:hango/presentation/widgets/internal_app_header.dart';
import '../../widgets/course_manager_sidebar.dart';
import '../../../data/services/course_manager_api.dart';
import '../../../domain/model/trainer_ai_exam_models.dart';

class CourseManagerExamsPage extends StatefulWidget {
  final bool isEmbedded;

  const CourseManagerExamsPage({super.key, this.isEmbedded = false});

  @override
  State<CourseManagerExamsPage> createState() => _CourseManagerExamsPageState();
}

class _CourseManagerExamsPageState extends State<CourseManagerExamsPage> {
  final _authService = AuthService();
  bool _isLoading = true;
  String _errorMessage = '';
  int? _currentUserId;
  List<dynamic> _allLoadedExams =
      []; // Stores all fetched exams for instant filtering
  List<dynamic> _examsList = [];
  bool _isCreatingExam = false;
  Map<String, dynamic>? _editingExamData;

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
  int _rejectedCount = 0;

  // Filter values
  final TextEditingController _searchController = TextEditingController();
  String _selectedSortBy = 'STATUS';
  String _selectedTimePeriod = 'ALL';

  int _getStatusPriority(String status) {
    status = status.toUpperCase();
    if (status == 'SUBMITTED') return 1;
    if (status == 'DRAFT') return 2;
    if (status == 'PUBLISHED' || status == 'APPROVED') return 3;
    if (status == 'REJECTED') return 4;
    if (status == 'HIDDEN') return 5;
    return 6;
  }

  String get apiBaseUrl => EnvConfig.v1BaseUrl;

  @override
  void initState() {
    super.initState();
    _loadCourseManagerInfo();
    _fetchExamsData();
  }

  Future<void> _loadCourseManagerInfo() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _currentUserId = prefs.getInt('user_id');
      });
    }
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
    });

    try {
      final api = CourseManagerApi();
      // Always fetch 'ALL' to support instant local filtering
      final data = await api.getExamsForReview('ALL');

      // Filter out DRAFTs not created by the current user
      final baseData = data
          .where(
            (e) =>
                e['status'] != 'DRAFT' ||
                (_currentUserId != null && e['creatorId'] == _currentUserId),
          )
          .toList();

      if (mounted) {
        setState(() {
          _allLoadedExams = baseData;

          // Pre-calculate counts based on all loaded data
          _allCount = baseData.length;
          _draftCount = baseData.where((e) => e['status'] == 'DRAFT').length;
          _publishedCount = baseData
              .where((e) => e['status'] == 'PUBLISHED')
              .length;
          _hiddenCount = baseData.where((e) => e['status'] == 'HIDDEN').length;
          _pendingCount = baseData
              .where((e) => e['status'] == 'SUBMITTED')
              .length;
          _rejectedCount = baseData
              .where((e) => e['status'] == 'REJECTED')
              .length;

          _isLoading = false;
        });
        _applyFilters();
      }
    } catch (e) {
      debugPrint('Error loading exams data: $e');
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
        _loadMockFallback();
      }
    }
  }

  DateTime _parseDate(dynamic dateData) {
    if (dateData == null) return DateTime(2000);
    if (dateData is List && dateData.isNotEmpty) {
      try {
        return DateTime(
          dateData.length > 0 ? (dateData[0] as num).toInt() : 2000,
          dateData.length > 1 ? (dateData[1] as num).toInt() : 1,
          dateData.length > 2 ? (dateData[2] as num).toInt() : 1,
          dateData.length > 3 ? (dateData[3] as num).toInt() : 0,
          dateData.length > 4 ? (dateData[4] as num).toInt() : 0,
          dateData.length > 5 ? (dateData[5] as num).toInt() : 0,
        );
      } catch (e) {
        return DateTime(2000);
      }
    }
    return DateTime.tryParse(dateData.toString()) ?? DateTime(2000);
  }

  void _applyFilters() {
    setState(() {
      var filteredData = List<dynamic>.from(_allLoadedExams);

      // 0. Status Filter
      if (_selectedStatus != 'ALL') {
        final targetStatus = _selectedStatus == 'PENDING'
            ? 'SUBMITTED'
            : _selectedStatus;
        filteredData = filteredData
            .where((e) => e['status'] == targetStatus)
            .toList();
      }

      // 1. Search Filter
      final searchQuery = _searchController.text.trim().toLowerCase();
      if (searchQuery.isNotEmpty) {
        filteredData = filteredData.where((e) {
          final title = (e['title'] ?? '').toString().toLowerCase();
          return title.contains(searchQuery);
        }).toList();
      }

      // 2. Time Period Filter
      if (_selectedTimePeriod != 'ALL') {
        final now = DateTime.now();
        DateTime threshold = DateTime(2000);
        if (_selectedTimePeriod == 'THIS_WEEK') {
          threshold = now.subtract(const Duration(days: 7));
        } else if (_selectedTimePeriod == 'THIS_MONTH') {
          threshold = now.subtract(const Duration(days: 30));
        }
        filteredData = filteredData.where((e) {
          DateTime d = _parseDate(e['createdAt']);
          return d.isAfter(threshold);
        }).toList();
      }

      // 3. Sorting
      filteredData.sort((a, b) {
        if (_selectedSortBy == 'STATUS') {
          if (_selectedStatus == 'ALL') {
            final dateA = _parseDate(a['updatedAt'] ?? a['createdAt']);
            final dateB = _parseDate(b['updatedAt'] ?? b['createdAt']);
            return dateB.compareTo(dateA);
          } else {
            final statusA = a['status']?.toString().toUpperCase() ?? '';
            final statusB = b['status']?.toString().toUpperCase() ?? '';
            final priorityA = _getStatusPriority(statusA);
            final priorityB = _getStatusPriority(statusB);
            if (priorityA != priorityB) return priorityA.compareTo(priorityB);

            final dateA = _parseDate(a['updatedAt'] ?? a['createdAt']);
            final dateB = _parseDate(b['updatedAt'] ?? b['createdAt']);
            return dateB.compareTo(dateA);
          }
        } else if (_selectedSortBy == 'NEWEST') {
          final dateA = _parseDate(a['createdAt']);
          final dateB = _parseDate(b['createdAt']);
          return dateB.compareTo(dateA);
        } else if (_selectedSortBy == 'OLDEST') {
          final dateA = _parseDate(a['createdAt']);
          final dateB = _parseDate(b['createdAt']);
          return dateA.compareTo(dateB);
        } else if (_selectedSortBy == 'ALPHABETICAL') {
          final nameA = (a['title'] ?? '').toString().toLowerCase();
          final nameB = (b['title'] ?? '').toString().toLowerCase();
          return nameA.compareTo(nameB);
        }
        return 0;
      });

      _examsList = filteredData;
      _currentPage = 1;
    });
  }

  void _loadMockFallback() {
    setState(() {
      _allCount = 1;
      _draftCount = 0;
      _publishedCount = 1;
      _hiddenCount = 0;
      _pendingCount = 0;
      _rejectedCount = 0;
      _examsList = [
        {
          'id': 1,
          'title':
              'Thi Thử Tốt Nghiệp THPT Tiếng anh năm 2025 - THPT Chuyên Phan Bội Châu (Mock)',
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
      DateTime dateTime;
      if (dateStr is List && dateStr.isNotEmpty) {
        dateTime = DateTime(
          dateStr.length > 0 ? (dateStr[0] as num).toInt() : 2000,
          dateStr.length > 1 ? (dateStr[1] as num).toInt() : 1,
          dateStr.length > 2 ? (dateStr[2] as num).toInt() : 1,
        );
      } else {
        dateTime = DateTime.parse(dateStr.toString());
      }
      return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
    } catch (e) {
      String str = dateStr.toString();
      if (str.length >= 10) {
        final parts = str.substring(0, 10).split('-');
        if (parts.length == 3) {
          return '${parts[2]}/${parts[1]}/${parts[0]}';
        }
      }
      return str;
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 1024;

    final Widget bodyContent = _isCreatingExam
        ? CourseManagerCreateExamPage(
            isEmbedded: true,
            onBack: () {
              setState(() {
                _isCreatingExam = false;
                _fetchExamsData();
              });
            },
            onExamCreated: (examData) {
              setState(() {
                _isCreatingExam = false;
                _editingExamData = examData;
              });
            },
          )
        : _editingExamData != null
        ? Builder(
            builder: (context) {
              final examStatus = _editingExamData!['status']
                  ?.toString()
                  .toUpperCase();
              return CourseManagerEditExamPage(
                examId: _editingExamData!['id'] as int,
                examTitle: _editingExamData!['title'] ?? 'Untitled Exam',
                examExpectedCount:
                    _editingExamData!['expectedQuestionCount'] as int? ?? 10,
                isReadOnly: (examStatus != 'DRAFT' && examStatus != 'REJECTED' && examStatus != 'PUBLISHED'),
                courseManagerActionStatus: examStatus,
                isCourseManager: true,
                initialExamData: _editingExamData,
                isEmbedded: true,
                initialAiData:
                    _editingExamData!['aiData'] as TrainerAiExamGenerateResponse?,
                onBack: () {
                  setState(() {
                    _editingExamData = null;
                    _fetchExamsData();
                  });
                },
              );
            },
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildContentHeader(context, isDesktop),
              Expanded(
                child: ClipRect(
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
              ),
            ],
          );

    if (widget.isEmbedded) {
      return bodyContent;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: InternalAppHeader(isMobile: !(isDesktop), activeTab: ''),
      drawer: !isDesktop
          ? const Drawer(child: CourseManagerSidebar(currentRoute: 'exams'))
          : null,
      body: Row(
        children: [
          if (isDesktop)
            const SizedBox(
              width: 240,
              child: CourseManagerSidebar(currentRoute: 'exams'),
            ),
          Expanded(child: bodyContent),
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
                _buildStatusTab('Pending', 'SUBMITTED', _pendingCount),
                const SizedBox(width: 8),
                _buildStatusTab('Published', 'PUBLISHED', _publishedCount),
                const SizedBox(width: 8),
                _buildStatusTab('Rejected', 'REJECTED', _rejectedCount),
                const SizedBox(width: 8),
                _buildStatusTab('Hidden', 'HIDDEN', _hiddenCount),
              ],
            ),
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final useRow = constraints.maxWidth > 768;

              final searchField = TextField(
                controller: _searchController,
                onChanged: (val) => _applyFilters(),
                onSubmitted: (val) => _applyFilters(),
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
                    borderSide: const BorderSide(color: Color(0xFF20B486)),
                  ),
                ),
              );

              final sortByDropdown = _buildDropdown(
                value: _selectedSortBy,
                items: const [
                  DropdownMenuItem(
                    value: 'STATUS',
                    child: Text('Sort by: Status'),
                  ),
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
                    _applyFilters();
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
                    _applyFilters();
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
        _applyFilters();
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFE6FFFA) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? const Color(0xFF20B486) : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isActive
                    ? const Color(0xFF20B486)
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
                    ? const Color(0xFF20B486)
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

    List<dynamic> currentExams = _examsList.isEmpty
        ? []
        : _examsList.sublist(startIndex, endIndex);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header + Body: fixed-flex columns need a minimum width so they
          // don't get squeezed/overflow on narrow windows; fall back to
          // horizontal scroll instead.
          LayoutBuilder(
            builder: (context, constraints) {
              final tableWidth = constraints.maxWidth < 900
                  ? 900.0
                  : constraints.maxWidth;
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: tableWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Table Header
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(12),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: _buildTableHeaderText('Exam Title'),
                            ),
                            Expanded(
                              flex: 1,
                              child: _buildTableHeaderText('Create Date'),
                            ),
                            Expanded(
                              flex: 1,
                              child: _buildTableHeaderText('Questions'),
                            ),
                            Expanded(
                              flex: 1,
                              child: _buildTableHeaderText('Duration'),
                            ),
                            Expanded(
                              flex: 1,
                              child: _buildTableHeaderText('Status'),
                            ),
                            Expanded(
                              flex: 1,
                              child: _buildTableHeaderText(
                                'Actions',
                                align: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: Color(0xFFE2E8F0)),
                      // Table Body
                      currentExams.isEmpty
                          ? (_isLoading
                                ? const Padding(
                                    padding: EdgeInsets.all(80.0),
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        color: Color(0xFF10B981),
                                      ),
                                    ),
                                  )
                                : const Padding(
                                    padding: EdgeInsets.all(40.0),
                                    child: Center(
                                      child: Text(
                                        'No exams found.',
                                        style: TextStyle(
                                          color: Color(0xFF64748B),
                                          fontFamily: 'Outfit',
                                        ),
                                      ),
                                    ),
                                  ))
                          : ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: currentExams.length,
                              separatorBuilder: (context, index) =>
                                  const Divider(
                                    height: 1,
                                    color: Color(0xFFE2E8F0),
                                  ),
                              itemBuilder: (context, index) {
                                final exam = currentExams[index];
                                return _buildExamRow(exam);
                              },
                            ),
                    ],
                  ),
                ),
              );
            },
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          // Pagination Footer
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                Text(
                  'Showing ${totalItems == 0 ? 0 : startIndex + 1} to $endIndex of $totalItems entries',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 14,
                    fontFamily: 'Outfit',
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildPaginationButton(
                        Icons.chevron_left,
                        onPressed: _currentPage > 1
                            ? () => setState(() => _currentPage--)
                            : null,
                      ),
                      const SizedBox(width: 8),
                      ...List.generate(totalPages, (index) {
                        int pageNum = index + 1;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: _buildPaginationNumber(
                            pageNum.toString(),
                            isActive: pageNum == _currentPage,
                            onPressed: () =>
                                setState(() => _currentPage = pageNum),
                          ),
                        );
                      }),
                      _buildPaginationButton(
                        Icons.chevron_right,
                        onPressed: _currentPage < totalPages
                            ? () => setState(() => _currentPage++)
                            : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeaderText(
    String text, {
    TextAlign align = TextAlign.left,
  }) {
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
                  child:
                      exam['thumbnailUrl'] != null &&
                          exam['thumbnailUrl'].toString().isNotEmpty
                      ? Image.network(
                          exam['thumbnailUrl'],
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                width: 48,
                                height: 48,
                                color: const Color(0xFFE2E8F0),
                                child: const Icon(
                                  Icons.image_not_supported,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                        )
                      : Container(
                          width: 48,
                          height: 48,
                          color: const Color(0xFFE2E8F0),
                          child: const Icon(
                            Icons.assignment,
                            color: Color(0xFF94A3B8),
                          ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Builder(
                  builder: (context) {
                    final status =
                        exam['status']?.toString().toUpperCase() ?? 'DRAFT';
                    final bool isCreator =
                        _currentUserId != null &&
                        exam['creatorId'] == _currentUserId;

                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isCreator &&
                            (status == 'DRAFT' || status == 'REJECTED'))
                          IconButton(
                            icon: const Icon(
                              Icons.edit_outlined,
                              color: Color(0xFF64748B),
                              size: 20,
                            ),
                            onPressed: () {
                              setState(() {
                                _editingExamData = exam as Map<String, dynamic>;
                              });
                            },
                            splashRadius: 20,
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                          ),

                        if (!isCreator ||
                            (status != 'DRAFT' && status != 'REJECTED'))
                          IconButton(
                            icon: const Icon(
                              Icons.remove_red_eye_outlined,
                              color: Color(0xFF20B486),
                              size: 20,
                            ),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (ctx) => ExamReviewDashboardDialog(
                                  examId: exam['id'] as int,
                                  examTitle: exam['title'] ?? 'Untitled Exam',
                                  examExpectedCount:
                                      exam['expectedQuestionCount'] as int? ??
                                      10,
                                  examQuestionCount:
                                      exam['questionCount'] as int? ?? 0,
                                  examDurationMinutes:
                                      exam['durationMinutes'] as int? ?? 0,
                                  examCreatedAt: _formatDate(exam['createdAt']),
                                  examUpdatedAt: exam['updatedAt'] != null
                                      ? _formatDate(exam['updatedAt'])
                                      : null,
                                  status: status,
                                  isCourseManager: true,
                                  creatorId: exam['creatorId'] as int?,
                                  creatorName: exam['creatorName']?.toString(),
                                  currentUserId: _currentUserId,
                                  onActionSuccess: () {
                                    _fetchExamsData();
                                  },
                                  onEditExam: isCreator && ['REJECTED', 'PUBLISHED'].contains(status)
                                      ? () {
                                          setState(() {
                                            _editingExamData = exam as Map<String, dynamic>;
                                          });
                                        }
                                      : null,
                                ),
                              );
                            },
                            splashRadius: 20,
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                          ),
                        IconButton(
                          icon: const Icon(
                            Icons.history,
                            color: Color(0xFF64748B),
                            size: 20,
                          ),
                          tooltip: 'View history',
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => ExamHistoryDialog(
                                examId: exam['id'] as int,
                                examTitle: exam['title'] ?? 'Untitled Exam',
                              ),
                            );
                          },
                          splashRadius: 20,
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                      ],
                    );
                  },
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
    } else if (status == 'SUBMITTED') {
      bgColor = const Color(0xFFFEF3C7);
      textColor = const Color(0xFFD97706);
    } else if (status == 'REJECTED') {
      bgColor = const Color(0xFFFEE2E2);
      textColor = const Color(0xFFEF4444);
    } else {
      // DRAFT
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
            decoration: BoxDecoration(color: textColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            status == 'SUBMITTED'
                ? 'Pending'
                : (status.length > 1
                      ? status.substring(0, 1).toUpperCase() +
                            status.substring(1).toLowerCase()
                      : status),
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

  Future<void> _updateExamVisibility(int examId, String newVisibility) async {
    try {
      final token = await _authService.getToken();
      if (token == null) return;
      final uri = Uri.parse('$apiBaseUrl/trainer/exams/$examId/visibility');
      final response = await http.patch(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'visibility': newVisibility}),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Exam visibility updated successfully')),
        );
        _fetchExamsData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('System error, please try again later.'),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error updating exam visibility: $e');
    }
  }

  Widget _buildVisibilityChip(Map<String, dynamic> exam) {
    String? visibility = exam['visibility'];
    bool isPublic = visibility?.toUpperCase() == 'PUBLIC';
    bool canEdit =
        _currentUserId != null && exam['creatorId'] == _currentUserId;

    return InkWell(
      onTap: canEdit
          ? () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text(
                    'Change Visibility',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  content: Text(
                    'Do you want to change visibility to ${isPublic ? "Private" : "Public"}?',
                    style: const TextStyle(fontFamily: 'Outfit'),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Color(0xFF64748B)),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _updateExamVisibility(
                          exam['id'],
                          isPublic ? 'PRIVATE' : 'PUBLIC',
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF20B486),
                      ),
                      child: const Text(
                        'Confirm',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              );
            }
          : null,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isPublic ? const Color(0xFFE0F2FE) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: canEdit
                ? (isPublic ? const Color(0xFFBAE6FD) : const Color(0xFFE2E8F0))
                : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isPublic ? Icons.public : Icons.lock_outline,
              size: 14,
              color: isPublic
                  ? const Color(0xFF0284C7)
                  : const Color(0xFF64748B),
            ),
            const SizedBox(width: 6),
            Text(
              isPublic ? 'Public' : 'Private',
              style: TextStyle(
                color: isPublic
                    ? const Color(0xFF0284C7)
                    : const Color(0xFF64748B),
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
        child: Icon(
          icon,
          size: 18,
          color: onPressed == null
              ? const Color(0xFFCBD5E1)
              : const Color(0xFF64748B),
        ),
      ),
    );
  }

  Widget _buildPaginationNumber(
    String text, {
    bool isActive = false,
    VoidCallback? onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF0F766E) : Colors.white,
          border: Border.all(
            color: isActive ? const Color(0xFF0F766E) : const Color(0xFFE2E8F0),
          ),
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
          ],
          const Expanded(
            child: Text(
              'Exam Management',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
                fontFamily: 'Outfit',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _isCreatingExam = true;
              });
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
              backgroundColor: const Color(0xFF20B486),
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
