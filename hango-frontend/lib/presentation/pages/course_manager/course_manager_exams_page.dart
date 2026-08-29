import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
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
import '../../../utils/toast_helper.dart';

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
        // In the Published tab, always surface Entry Exam candidates first.
        if (_selectedStatus == 'PUBLISHED') {
          final bool entryA = a['isEntryExam'] == true;
          final bool entryB = b['isEntryExam'] == true;
          if (entryA != entryB) return entryA ? -1 : 1;
        }
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
                isReadOnly: (examStatus != 'DRAFT' && examStatus != 'REJECTED' && examStatus != 'PUBLISHED' && examStatus != 'HIDDEN'),
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
                        _buildExamsList(),
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

  Widget _buildExamsList() {
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (currentExams.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 64),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFEFF2F5)),
            ),
            child: _isLoading
                ? const CircularProgressIndicator(color: Color(0xFF20B486))
                : const Column(
                    children: [
                      Icon(Icons.assignment_outlined, size: 48, color: Color(0xFF94A3B8)),
                      SizedBox(height: 16),
                      Text(
                        'No exams found matching this criteria',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'Outfit',
                        ),
                      ),
                    ],
                  ),
          )
        else
          for (final exam in currentExams)
            _ExamCardWrapper(
              exam: exam as Map<String, dynamic>,
              buildCard: _buildExamCard,
            ),
        const SizedBox(height: 8),
        _buildPagination(totalPages),
      ],
    );
  }

  // ─── Exam Card ─────────────────────────────────────────────────────────────

  Widget _buildExamCard(Map<String, dynamic> exam, bool isHovered) {
    final status = exam['status']?.toString().toUpperCase() ?? 'DRAFT';
    final isCreator = _currentUserId != null && exam['creatorId'] == _currentUserId;
    final title = (exam['title'] ?? 'Untitled Exam') as String;
    final questionCount = exam['questionCount']?.toString() ?? '0';
    final durationMinutes = exam['durationMinutes'] ?? 0;
    final dateStr = _formatDate(exam['createdAt']);
    final thumbnail = (exam['thumbnailUrl'] ?? '').toString();
    final rejectionReason = (exam['rejectionReason'] ?? '').toString();

    final borderColor = status == 'SUBMITTED'
        ? const Color(0xFFFDE68A)
        : status == 'REJECTED'
        ? const Color(0xFFFECACA)
        : const Color(0xFFEFF2F5);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 16),
      transform: Matrix4.translationValues(0, isHovered ? -4 : 0, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHovered ? const Color(0xFF20B486).withAlpha(102) : borderColor,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isHovered
                ? const Color(0xFF20B486).withAlpha(31)
                : const Color.fromRGBO(0, 0, 0, 0.04),
            blurRadius: isHovered ? 20 : 10,
            offset: Offset(0, isHovered ? 8 : 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final useRow = constraints.maxWidth > 600;

                final imageWidget = Container(
                  width: useRow ? 80 : double.infinity,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2F6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: thumbnail.isNotEmpty
                      ? Image.network(
                          thumbnail,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.assignment,
                            color: Color(0xFF20B486),
                            size: 32,
                          ),
                        )
                      : const Icon(
                          Icons.assignment,
                          color: Color(0xFF20B486),
                          size: 32,
                        ),
                );

                final infoCol = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                            fontFamily: 'Outfit',
                          ),
                        ),
                        _buildStatusChip(status),
                        if (exam['isEntryExam'] == true) _buildEntryExamBadge(),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 16,
                      runSpacing: 6,
                      children: [
                        _statChip(Icons.help_outline, '$questionCount questions'),
                        _statChip(Icons.timer_outlined, '$durationMinutes mins'),
                        _statChip(Icons.calendar_today_outlined, dateStr),
                      ],
                    ),
                    if (status == 'REJECTED' && rejectionReason.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline, color: Color(0xFFDC2626), size: 16),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Rejected Reason:',
                                    style: TextStyle(
                                      color: Color(0xFF991B1B),
                                      fontSize: 13,
                                      fontFamily: 'Outfit',
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  MarkdownBody(
                                    data: rejectionReason,
                                    styleSheet: MarkdownStyleSheet(
                                      p: const TextStyle(
                                        color: Color(0xFF991B1B),
                                        fontSize: 12,
                                        fontFamily: 'Outfit',
                                      ),
                                      listBullet: const TextStyle(
                                        color: Color(0xFF991B1B),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                );

                if (useRow) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      imageWidget,
                      const SizedBox(width: 16),
                      Expanded(child: infoCol),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [imageWidget, const SizedBox(height: 14), infoCol],
                );
              },
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(14),
              ),
              border: Border(
                top: BorderSide(color: borderColor.withAlpha(100)),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: _buildExamActions(
              exam: exam,
              status: status,
              isCreator: isCreator,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExamActions({
    required Map<String, dynamic> exam,
    required String status,
    required bool isCreator,
  }) {
    final canEdit = isCreator && (status == 'DRAFT' || status == 'REJECTED');
    return Row(
      children: [
        if (canEdit)
          _actionChip(
            icon: Icons.edit_outlined,
            label: 'Edit',
            color: const Color(0xFF64748B),
            bg: const Color(0xFFF1F5F9),
            onTap: () => setState(() => _editingExamData = exam),
          )
        else
          _actionChip(
            icon: Icons.visibility_outlined,
            label: 'View',
            color: const Color(0xFF20B486),
            bg: const Color(0xFFE6F7F1),
            onTap: () {
              showDialog(
                context: context,
                builder: (ctx) => ExamReviewDashboardDialog(
                  examId: exam['id'] as int,
                  examTitle: exam['title'] ?? 'Untitled Exam',
                  examExpectedCount: exam['expectedQuestionCount'] as int? ?? 10,
                  examQuestionCount: exam['questionCount'] as int? ?? 0,
                  examDurationMinutes: exam['durationMinutes'] as int? ?? 0,
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
                  onEditExam: isCreator && ['REJECTED', 'PUBLISHED', 'HIDDEN'].contains(status)
                      ? () {
                          setState(() => _editingExamData = exam);
                        }
                      : null,
                ),
              );
            },
          ),
        if (status == 'PUBLISHED' || exam['isEntryExam'] == true) ...[
          const SizedBox(width: 8),
          _buildEntryExamToggle(exam),
        ],
        const Spacer(),
        _iconBtn(
          icon: Icons.history,
          tooltip: 'View history',
          onTap: () {
            showDialog(
              context: context,
              builder: (ctx) => ExamHistoryDialog(
                examId: exam['id'] as int,
                examTitle: exam['title'] ?? 'Untitled Exam',
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildEntryExamBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFC7D2FE)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.flag, size: 11, color: Color(0xFF4F46E5)),
          SizedBox(width: 4),
          Text(
            'Entry Exam',
            style: TextStyle(
              color: Color(0xFF4F46E5),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              fontFamily: 'Outfit',
            ),
          ),
        ],
      ),
    );
  }

  // Lets a Course Manager mark any published exam as a candidate for the
  // learner-facing Entry Exam (placement test). When more than one exam is
  // flagged, the backend picks one at random each time a learner takes it.
  Widget _buildEntryExamToggle(Map<String, dynamic> exam) {
    final bool isEntryExam = exam['isEntryExam'] == true;
    return isEntryExam
        ? _actionChip(
            icon: Icons.flag,
            label: 'Entry Exam',
            color: const Color(0xFF4F46E5),
            bg: const Color(0xFFEEF2FF),
            onTap: () => _confirmEntryExamChange(exam, false),
          )
        : _actionChip(
            icon: Icons.outlined_flag,
            label: 'Set as Entry Exam',
            color: const Color(0xFF475569),
            bg: const Color(0xFFF1F5F9),
            onTap: () => _confirmEntryExamChange(exam, true),
          );
  }

  void _confirmEntryExamChange(Map<String, dynamic> exam, bool newValue) {
    final String title = exam['title'] ?? 'this exam';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          newValue ? 'Set as Entry Exam' : 'Remove from Entry Exam',
          style: const TextStyle(
            fontFamily: 'Outfit',
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          newValue
              ? 'Do you want to set "$title" as an Entry Exam candidate for learners?'
              : 'Do you want to remove "$title" from the Entry Exam candidates?',
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
              _updateEntryExamStatus(exam['id'] as int, newValue);
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

  // ─── Shared UI micro-components ───────────────────────────────────────────

  Widget _statChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 13,
            fontFamily: 'Outfit',
          ),
        ),
      ],
    );
  }

  Widget _actionChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = const Color(0xFF475569),
    Color bg = const Color(0xFFF1F5F9),
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontFamily: 'Outfit',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconBtn({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color color = const Color(0xFF64748B),
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFEFF2F5)),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
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

  Future<void> _updateEntryExamStatus(int examId, bool newValue) async {
    try {
      final token = await _authService.getToken();
      if (token == null) return;
      final uri = Uri.parse('$apiBaseUrl/course-manager/exams/$examId/entry-exam-status');
      final response = await http.patch(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'isEntryExam': newValue}),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        ToastHelper.showSuccess(
          context,
          newValue
              ? 'Exam set as an Entry Exam candidate'
              : 'Exam removed from Entry Exam candidates',
        );
        _fetchExamsData();
      } else {
        String message = 'System error, please try again later.';
        try {
          final body = jsonDecode(response.body);
          if (body is Map && body['error'] != null) message = body['error'].toString();
        } catch (_) {}
        ToastHelper.showError(context, message);
      }
    } catch (e) {
      debugPrint('Error updating entry exam status: $e');
      if (mounted) {
        ToastHelper.showError(context, 'System error, please try again later.');
      }
    }
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

  Widget _buildPagination(int totalPages) {
    if (_examsList.isEmpty) return const SizedBox();

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        InkWell(
          onTap: _currentPage > 1
              ? () {
                  setState(() {
                    _currentPage--;
                  });
                }
              : null,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _currentPage > 1 ? Colors.white : const Color(0xFFF1F5F9),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.chevron_left,
              size: 16,
              color: _currentPage > 1 ? const Color(0xFF475569) : const Color(0xFF94A3B8),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'Page $_currentPage of $totalPages',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF475569),
            fontFamily: 'Outfit',
          ),
        ),
        const SizedBox(width: 12),
        InkWell(
          onTap: _currentPage < totalPages
              ? () {
                  setState(() {
                    _currentPage++;
                  });
                }
              : null,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _currentPage < totalPages ? Colors.white : const Color(0xFFF1F5F9),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.chevron_right,
              size: 16,
              color: _currentPage < totalPages ? const Color(0xFF475569) : const Color(0xFF94A3B8),
            ),
          ),
        ),
      ],
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

class _ExamCardWrapper extends StatefulWidget {
  final Map<String, dynamic> exam;
  final Widget Function(Map<String, dynamic> exam, bool isHovered) buildCard;

  const _ExamCardWrapper({required this.exam, required this.buildCard});

  @override
  State<_ExamCardWrapper> createState() => _ExamCardWrapperState();
}

class _ExamCardWrapperState extends State<_ExamCardWrapper> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: widget.buildCard(widget.exam, _isHovered),
    );
  }
}
