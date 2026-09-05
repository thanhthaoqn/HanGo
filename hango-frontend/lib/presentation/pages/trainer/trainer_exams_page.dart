import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hango/presentation/widgets/internal_app_header.dart';
import '../../../utils/permission_utils.dart';
import '../../../utils/config.dart';
import '../../../data/services/auth_service.dart';
import '../course_manager/course_manager_create_exam_page.dart';
import '../course_manager/course_manager_edit_exam_page.dart';
import '../course_manager/exam_review_dashboard_dialog.dart';
import '../course_manager/exam_history_dialog.dart';
import '../../widgets/trainer/trainer_sidebar.dart';
import '../../../utils/toast_helper.dart';
import '../../../domain/model/trainer_ai_exam_models.dart';

class TrainerExamsPage extends StatefulWidget {
  final bool isEmbedded;
  const TrainerExamsPage({super.key, this.isEmbedded = false});

  @override
  State<TrainerExamsPage> createState() => _TrainerExamsPageState();
}

class _TrainerExamsPageState extends State<TrainerExamsPage> {
  final _authService = AuthService();
  String _trainerName = 'Thảo';
  String _trainerInitials = 'T';
  String _trainerAvatarUrl = '';

  bool _isCourseManager = false;
  bool _isCreatingExam = false;
  Map<String, dynamic>? _editingExamData;
  int? _currentUserId;

  bool _isLoading = true;
  List<dynamic> _allLoadedExams = [];
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
  int _rejectedCount = 0;

  // Filter values
  final TextEditingController _searchController = TextEditingController();
  String _selectedSortBy = 'STATUS';
  String _selectedTimePeriod = 'ALL';

  int _getStatusPriority(String status) {
    status = status.toUpperCase();
    if (status == 'DRAFT') return 1;
    if (status == 'SUBMITTED') return 2;
    if (status == 'PUBLISHED' || status == 'APPROVED') return 3;
    if (status == 'HIDDEN') return 4;
    if (status == 'REJECTED') return 5;
    return 6;
  }

  String get apiBaseUrl => EnvConfig.v1BaseUrl;

  @override
  void initState() {
    super.initState();
    _loadTrainerInfo();
    _fetchExamsData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _statusOf(dynamic exam) =>
      exam['status']?.toString().toUpperCase() ?? '';

  Future<void> _fetchExamsData() async {
    setState(() {
      _isLoading = true;
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
        final allData = data is Map
            ? (data['exams'] ?? []) as List<dynamic>
            : (data is List ? data : <dynamic>[]);

        if (mounted) {
          setState(() {
            _allLoadedExams = allData;
            _allCount = allData.length;
            _draftCount = allData.where((e) => _statusOf(e) == 'DRAFT').length;
            _publishedCount = allData.where((e) {
              final s = _statusOf(e);
              return s == 'PUBLISHED' || s == 'APPROVED' || s == 'PUBLIC';
            }).length;
            _hiddenCount = allData.where((e) => _statusOf(e) == 'HIDDEN').length;
            _pendingCount = allData
                .where((e) => _statusOf(e) == 'SUBMITTED')
                .length;
            _rejectedCount = allData
                .where((e) => _statusOf(e) == 'REJECTED')
                .length;
            _isLoading = false;
          });
          _applyFilters();
        }
      } else {
        throw Exception('Failed to load exams data: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error loading exams data: $e');
      if (mounted) {
        setState(() {
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
      var filtered = List<dynamic>.from(_allLoadedExams);

      if (_selectedStatus != 'ALL') {
        filtered = filtered.where((e) {
          final s = _statusOf(e);
          if (_selectedStatus == 'PUBLISHED') {
            return s == 'PUBLISHED' || s == 'APPROVED' || s == 'PUBLIC';
          }
          return s == _selectedStatus;
        }).toList();
      }

      final searchVal = _searchController.text.trim().toLowerCase();
      if (searchVal.isNotEmpty) {
        filtered = filtered
            .where(
              (e) => (e['title']?.toString().toLowerCase() ?? '').contains(
                searchVal,
              ),
            )
            .toList();
      }

      if (_selectedTimePeriod == 'THIS_WEEK') {
        final now = DateTime.now();
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        filtered = filtered.where((e) {
          DateTime d = _parseDate(e['createdAt']);
          return d.isAfter(startOfWeek);
        }).toList();
      } else if (_selectedTimePeriod == 'THIS_MONTH') {
        final now = DateTime.now();
        filtered = filtered.where((e) {
          DateTime d = _parseDate(e['createdAt']);
          return d.year == now.year && d.month == now.month;
        }).toList();
      }

      filtered.sort((a, b) {
        if (_selectedSortBy == 'STATUS') {
          if (_selectedStatus == 'ALL') {
            DateTime d1 = _parseDate(a['updatedAt'] ?? a['createdAt']);
            DateTime d2 = _parseDate(b['updatedAt'] ?? b['createdAt']);
            return d2.compareTo(d1);
          } else {
            final priorityA = _getStatusPriority(_statusOf(a));
            final priorityB = _getStatusPriority(_statusOf(b));
            if (priorityA != priorityB) return priorityA.compareTo(priorityB);

            DateTime d1 = _parseDate(a['updatedAt'] ?? a['createdAt']);
            DateTime d2 = _parseDate(b['updatedAt'] ?? b['createdAt']);
            return d2.compareTo(d1);
          }
        } else if (_selectedSortBy == 'NEWEST') {
          DateTime d1 = _parseDate(a['createdAt']);
          DateTime d2 = _parseDate(b['createdAt']);
          return d2.compareTo(d1);
        } else if (_selectedSortBy == 'OLDEST') {
          DateTime d1 = _parseDate(a['createdAt']);
          DateTime d2 = _parseDate(b['createdAt']);
          return d1.compareTo(d2);
        } else if (_selectedSortBy == 'ALPHABETICAL') {
          String t1 = a['title']?.toString() ?? '';
          String t2 = b['title']?.toString() ?? '';
          return t1.compareTo(t2);
        }
        return 0;
      });

      _examsList = filtered;
      _currentPage = 1;
    });
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
        ToastHelper.showSuccess(
          context,
          'Exam visibility updated successfully',
        );
        _fetchExamsData();
      } else {
        ToastHelper.showError(
          context,
          'Failed to update visibility: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('Error updating exam visibility: $e');
    }
  }

  Future<void> _updateExamStatus(int examId, String newStatus) async {
    try {
      final token = await _authService.getToken();
      if (token == null) return;
      final uri = Uri.parse('$apiBaseUrl/trainer/exams/$examId/status');
      final response = await http.patch(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'status': newStatus}),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        ToastHelper.showSuccess(context, 'Exam status updated successfully');
        _fetchExamsData();
      } else {
        ToastHelper.showError(
          context,
          'Failed to update status: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('Error updating exam status: $e');
    }
  }

  void _loadMockFallback() {
    setState(() {
      _allCount = 1;
      _draftCount = 0;
      _publishedCount = 1;
      _hiddenCount = 0;
      _pendingCount = 0;
      _rejectedCount = 0;
      _allLoadedExams = [
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
      _examsList = List<dynamic>.from(_allLoadedExams);
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
      if (str.length >= 10) return str.substring(0, 10);
      return str;
    }
  }

  Future<void> _loadTrainerInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final fullName = prefs.getString('user_fullname') ?? 'Thảo';
    final avatarUrl = prefs.getString('user_avatar_url') ?? '';

    final roles = prefs.getStringList('user_roles') ?? [];

    String initials = 'T';
    if (fullName.trim().isNotEmpty) {
      final parts = fullName.trim().split(' ');
      if (parts.isNotEmpty) {
        initials = parts.last[0].toUpperCase();
      }
    }
    if (mounted) {
      setState(() {
        _trainerName = fullName;
        _trainerInitials = initials;
        _trainerAvatarUrl = avatarUrl;
        _currentUserId = prefs.getInt('user_id');

        _isCourseManager = PermissionUtils.canManageExamsAsCourseManager(roles);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 1024;

    if (widget.isEmbedded) {
      return _isCreatingExam
          ? CourseManagerCreateExamPage(
              isEmbedded: true,
              isCourseManager: false,
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
          ? CourseManagerEditExamPage(
              examId: _editingExamData!['id'] as int,
              examTitle: _editingExamData!['title'] ?? 'Untitled Exam',
              examExpectedCount:
                  _editingExamData!['expectedQuestionCount'] as int? ?? 10,
              isReadOnly: ![
                'DRAFT',
                'REJECTED',
                'PUBLISHED',
              ].contains(_editingExamData!['status']?.toString().toUpperCase()),
              initialExamData: _editingExamData,
              isCourseManager: false,
              isEmbedded: true,
              initialAiData:
                  _editingExamData!['aiData'] as TrainerAiExamGenerateResponse?,
              onBack: () {
                setState(() {
                  _editingExamData = null;
                  _fetchExamsData();
                });
              },
            )
          : _buildBodyContent();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: !isDesktop
          ? const Drawer(child: TrainerSidebar(activeIndex: 2))
          : null,
      body: Row(
        children: [
          if (isDesktop)
            const SizedBox(width: 250, child: TrainerSidebar(activeIndex: 2)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InternalAppHeader(isMobile: !isDesktop, showLogo: !isDesktop),
                Expanded(
                  child: _isCreatingExam
                      ? CourseManagerCreateExamPage(
                          isEmbedded: true,
                          isCourseManager: false,
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
                      ? CourseManagerEditExamPage(
                          examId: _editingExamData!['id'] as int,
                          examTitle:
                              _editingExamData!['title'] ?? 'Untitled Exam',
                          examExpectedCount:
                              _editingExamData!['expectedQuestionCount']
                                  as int? ??
                              10,
                          isReadOnly: !['DRAFT', 'REJECTED', 'PUBLISHED'].contains(
                            _editingExamData!['status']
                                ?.toString()
                                .toUpperCase(),
                          ),
                          isCourseManager: false,
                          isEmbedded: true,
                          initialAiData: _editingExamData!['aiData']
                              as TrainerAiExamGenerateResponse?,
                          onBack: () {
                            setState(() {
                              _editingExamData = null;
                              _fetchExamsData();
                            });
                          },
                        )
                      : _buildBodyContent(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBodyContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWelcomeSection(),
          const SizedBox(height: 24),
          _buildFilterContainer(),
          const SizedBox(height: 24),
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40.0),
                child: CircularProgressIndicator(color: Color(0xFF20B486)),
              ),
            )
          else
            _buildExamsList(),
        ],
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
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
            backgroundColor: const Color(0xFF38C9A6),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 0,
          ),
        ),
      ],
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
                _buildStatusTab('Submitted', 'SUBMITTED', _pendingCount),
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
              final useRow = constraints.maxWidth > 1000;

              final searchField = TextField(
                controller: _searchController,
                onChanged: (val) => _applyFilters(),
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
                    Expanded(flex: 2, child: searchField),
                    const SizedBox(width: 16),
                    Expanded(flex: 1, child: sortByDropdown),
                    const SizedBox(width: 16),
                    Expanded(flex: 1, child: timePeriodDropdown),
                  ],
                );
              } else {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    searchField,
                    const SizedBox(height: 12),
                    sortByDropdown,
                    const SizedBox(height: 12),
                    timePeriodDropdown,
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
            child: const Column(
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
    final status = exam['status']?.toString().toUpperCase() ?? '';
    final creatorId = exam['creatorId'] as int?;
    final isOwnExam = _currentUserId != null && creatorId == _currentUserId;
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
          color: isHovered ? const Color(0xFF38C9A6).withAlpha(102) : borderColor,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isHovered
                ? const Color(0xFF38C9A6).withAlpha(31)
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
                            color: Color(0xFF38C9A6),
                            size: 32,
                          ),
                        )
                      : const Icon(
                          Icons.assignment,
                          color: Color(0xFF38C9A6),
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
              isOwnExam: isOwnExam,
              creatorId: creatorId,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExamActions({
    required Map<String, dynamic> exam,
    required String status,
    required bool isOwnExam,
    required int? creatorId,
  }) {
    final isDraft = status == 'DRAFT';
    return Row(
      children: [
        _actionChip(
          icon: isDraft ? Icons.edit_outlined : Icons.visibility_outlined,
          label: isDraft ? 'Edit Draft' : 'View',
          color: isDraft ? const Color(0xFF64748B) : const Color(0xFF20B486),
          bg: isDraft ? const Color(0xFFF1F5F9) : const Color(0xFFE6F7F1),
          onTap: () {
            if (isDraft) {
              setState(() => _editingExamData = exam);
            } else {
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
                  isCourseManager: false,
                  creatorId: creatorId,
                  creatorName: exam['creatorName']?.toString(),
                  currentUserId: _currentUserId,
                  onActionSuccess: () {
                    _fetchExamsData();
                  },
                  onEditExam: isOwnExam && ['REJECTED', 'PUBLISHED'].contains(status)
                      ? () {
                          setState(() => _editingExamData = exam);
                        }
                      : null,
                ),
              );
            }
          },
        ),
        const Spacer(),
        if (_isCourseManager || isOwnExam) ...[
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
          if (_isCourseManager) const SizedBox(width: 8),
        ],
        if (_isCourseManager) _examMoreMenu(exam, status),
      ],
    );
  }

  Widget _examMoreMenu(Map<String, dynamic> exam, String status) {
    return PopupMenuButton<String>(
      tooltip: 'More actions',
      onSelected: (value) {
        if (value == 'HIDE') {
          _updateExamStatus(exam['id'], 'HIDDEN');
        } else if (value == 'PUBLISH') {
          _updateExamStatus(exam['id'], 'PUBLISHED');
        }
      },
      itemBuilder: (context) {
        return [
          if (status != 'HIDDEN')
            const PopupMenuItem(
              value: 'HIDE',
              child: Row(
                children: [
                  Icon(Icons.visibility_off, color: Colors.orange, size: 18),
                  SizedBox(width: 8),
                  Text('Hide Exam'),
                ],
              ),
            ),
          if (status == 'HIDDEN' || status == 'SUBMITTED')
            const PopupMenuItem(
              value: 'PUBLISH',
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 18),
                  SizedBox(width: 8),
                  Text('Publish Exam'),
                ],
              ),
            ),
        ];
      },
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFEFF2F5)),
        ),
        child: const Icon(Icons.more_vert, color: Color(0xFF64748B), size: 16),
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
    if (status == 'APPROVED' || status == 'PUBLISHED') {
      bgColor = const Color(0xFFE6FFFA);
      textColor = const Color(0xFF20B486);
    } else if (status == 'SUBMITTED') {
      bgColor = const Color(0xFFFEF3C7);
      textColor = const Color(0xFFD97706);
    } else if (status == 'REJECTED') {
      bgColor = const Color(0xFFFEE2E2);
      textColor = const Color(0xFFEF4444);
    } else if (status == 'HIDDEN') {
      bgColor = const Color(0xFFF1F5F9);
      textColor = const Color(0xFF94A3B8);
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
            status.length > 1
                ? status.substring(0, 1).toUpperCase() +
                      status.substring(1).toLowerCase()
                : status,
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

  Widget _unusedLegacyHeader(bool showMenuButton) {
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
