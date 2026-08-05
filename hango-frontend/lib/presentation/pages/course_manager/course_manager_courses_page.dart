import 'package:flutter/material.dart';

import '../../../data/services/course_manager_api.dart';
import '../../../utils/toast_helper.dart';
import '../../widgets/course_manager_sidebar.dart';
import 'package:hango/presentation/widgets/internal_app_header.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import '../../../data/services/auth_service.dart';
import '../../../utils/config.dart';
import '../../../utils/download_helper.dart';
import '../trainer/create_course_page.dart';
import '../trainer/edit_course_page.dart';
import 'course_review_dashboard_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CourseManagerCoursesPage extends StatefulWidget {
  const CourseManagerCoursesPage({super.key});

  @override
  State<CourseManagerCoursesPage> createState() =>
      _CourseManagerCoursesPageState();
}

class _CourseManagerCoursesPageState extends State<CourseManagerCoursesPage> {
  final _api = CourseManagerApi();
  final _searchController = TextEditingController();

  List<CourseReviewCourse> _courses = [];
  String _statusFilter = 'PENDING';
  String _selectedSortBy = 'NEWEST';
  String _selectedTimePeriod = 'ALL';
  bool _isLoading = true;
  bool _isMockPreview = false;
  bool _isDownloadingTemplate = false;
  bool _isImportingExcel = false;
  bool _canCreateCourses = false;
  final AuthService _authService = AuthService();
  String get apiBaseUrl => EnvConfig.v1BaseUrl;

  @override
  void initState() {
    super.initState();
    _loadPermissions();
    _loadCourses();
  }

  Future<void> _loadPermissions() async {
    final prefs = await SharedPreferences.getInstance();
    final roles = prefs.getStringList('user_roles') ?? [];
    if (mounted) {
      setState(() {
        _canCreateCourses = roles.contains('MANAGE_OWN_COURSES') || roles.contains('ROLE_ADMINISTRATOR');
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<CourseReviewCourse> get _displayedCourses {
    final keyword = _searchController.text.trim().toLowerCase();
    final filtered = _courses.where((course) {
      final matchesSearch =
          keyword.isEmpty ||
          course.title.toLowerCase().contains(keyword) ||
          course.creatorName.toLowerCase().contains(keyword) ||
          course.code.toLowerCase().contains(keyword);
      // Normalize: PENDING_APPROVAL from backend should match "PENDING" filter on frontend
      final courseStatus = course.status.toUpperCase();
      final matchesStatus =
          _statusFilter == 'ALL' ||
          courseStatus == _statusFilter ||
          (_statusFilter == 'PENDING' && courseStatus == 'PENDING_APPROVAL');
      return matchesSearch && matchesStatus;
    }).toList();

    // Apply sort
    if (_selectedSortBy == 'NEWEST') {
      filtered.sort((a, b) => (b.submittedAt ?? DateTime(2000)).compareTo(a.submittedAt ?? DateTime(2000)));
    } else if (_selectedSortBy == 'OLDEST') {
      filtered.sort((a, b) => (a.submittedAt ?? DateTime(2000)).compareTo(b.submittedAt ?? DateTime(2000)));
    } else if (_selectedSortBy == 'ALPHABETICAL') {
      filtered.sort((a, b) => a.title.compareTo(b.title));
    }

    return filtered;
  }

  Future<void> _loadCourses() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final courses = await _api.getReviewCourses(status: _statusFilter);
      if (!mounted) return;
      setState(() {
        _courses = courses;
        _isLoading = false;
        _isMockPreview = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _courses = _mockCourses;
        _isLoading = false;
        _isMockPreview = true;
      });
      ToastHelper.showError(
        context,
        'Using mock review data while the review API is unavailable.',
      );
    }
  }

  Future<void> _publishCourse(CourseReviewCourse course) async {
    final confirmed = await _confirmAction(
      title: 'Publish course?',
      message:
          'This will move "${course.title}" from PENDING to PUBLISHED and make it visible to learners.',
      confirmLabel: 'Publish',
      confirmColor: const Color(0xFF20B486),
    );
    if (!confirmed) return;

    try {
      await _api.publishCourse(course.id);
      if (!mounted) return;
      ToastHelper.showSuccess(context, 'Course published successfully.');
      await _loadCourses();
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, 'Could not publish course: $e');
      }
    }
  }

  Future<void> _rejectCourse(CourseReviewCourse course, {String reason = ''}) async {
    final confirmed = await _confirmAction(
      title: 'Return to draft?',
      message:
          'This will return "${course.title}" to DRAFT so the trainer can revise and submit again.\n\nReason: ${reason.isEmpty ? "None" : reason}',
      confirmLabel: 'Return',
      confirmColor: const Color(0xFFEF4444),
    );
    if (!confirmed) return;

    try {
      await _api.rejectCourse(course.id, reason: reason);
      if (!mounted) return;
      ToastHelper.showSuccess(context, 'Course returned to draft.');
      await _loadCourses();
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, 'Could not return course: $e');
      }
    }
  }

  Future<void> _hideCourse(CourseReviewCourse course) async {
    final confirmed = await _confirmAction(
      title: 'Hide course?',
      message:
          'This will hide "${course.title}" from the public marketplace.\n\nNote: Learners who have already enrolled in and purchased this course will still be able to access and study it from their "My Courses" section.',
      confirmLabel: 'Hide Course',
      confirmColor: const Color(0xFFD97706),
    );
    if (!confirmed) return;

    try {
      await _api.hideCourse(course.id);
      if (!mounted) return;
      ToastHelper.showSuccess(context, 'Course hidden successfully.');
      await _loadCourses();
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, 'Could not hide course: $e');
      }
    }
  }

  Future<void> _unhideCourse(CourseReviewCourse course) async {
    final confirmed = await _confirmAction(
      title: 'Unhide course?',
      message:
          'This will move "${course.title}" back to PUBLISHED and make it visible to all new learners on the marketplace again.',
      confirmLabel: 'Unhide & Publish',
      confirmColor: const Color(0xFF20B486),
    );
    if (!confirmed) return;

    try {
      await _api.unhideCourse(course.id);
      if (!mounted) return;
      ToastHelper.showSuccess(context, 'Course unhidden and published successfully.');
      await _loadCourses();
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, 'Could not unhide course: $e');
      }
    }
  }

  Future<void> _showCourseDetail(CourseReviewCourse course) async {
    CourseReviewCourse detail = course;
    try {
      if (!_isMockPreview) {
        detail = await _api.getReviewCourseDetail(course.id);
      }
    } catch (_) {
      detail = course;
    }

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => CourseReviewDashboardDialog(
        course: detail,
        onReject: (String reason) {
          Navigator.pop(context);
          _rejectCourse(detail, reason: reason);
        },
        onPublish: () {
          Navigator.pop(context);
          _publishCourse(detail);
        },
        onHide: () {
          Navigator.pop(context);
          _hideCourse(detail);
        },
        onUnhide: () {
          Navigator.pop(context);
          _unhideCourse(detail);
        },
      ),
    );
  }

  Future<void> _downloadImportTemplate() async {
    setState(() {
      _isDownloadingTemplate = true;
    });

    try {
      final token = await _authService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await http.get(
        Uri.parse('$apiBaseUrl/trainer/courses/import/template'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        downloadBytes(
          bytes: response.bodyBytes,
          filename: 'Hango_Course_Import_Template.xlsx',
          mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        );
        if (mounted) {
          ToastHelper.showSuccess(context, 'Course import template downloaded');
        }
      } else {
        throw Exception('Failed to download template: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error downloading course import template: $e');
      if (mounted) {
        ToastHelper.showError(context, 'Error downloading template: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloadingTemplate = false;
        });
      }
    }
  }

  Future<void> _importCourseExcel() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['xlsx'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final pickedFile = result.files.single;
      final bytes = pickedFile.bytes;
      if (bytes == null || bytes.isEmpty) {
        throw Exception('Selected file is empty');
      }

      setState(() {
        _isImportingExcel = true;
      });

      final token = await _authService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final request = http.MultipartRequest('POST', Uri.parse('$apiBaseUrl/trainer/courses/import'))
        ..headers['Authorization'] = 'Bearer $token'
        ..files.add(
          http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: pickedFile.name,
          ),
        );

      final streamedResponse = await request.send();
      final responseBody = await streamedResponse.stream.bytesToString();

      if (streamedResponse.statusCode == 200 || streamedResponse.statusCode == 201) {
        final data = jsonDecode(responseBody) as Map<String, dynamic>;

        final importedCourses = data['importedCourses'] ?? 0;
        final importedSections = data['importedSections'] ?? 0;
        final importedLessons = data['importedLessons'] ?? 0;
        final warnings = data['warnings'];

        final dynamic courseIdsRaw = data['courseIds'];
        final List<int> courseIds = (courseIdsRaw is List)
            ? courseIdsRaw.map((e) => e is int ? e : int.tryParse(e.toString()) ?? -1).where((id) => id > 0).toList()
            : [];

        if (mounted) {
          setState(() {
            _statusFilter = 'ALL';
          });
          await _loadCourses();

          final warningText = warnings is List && warnings.isNotEmpty ? ' Warning: ${warnings.first}' : '';

          if (mounted) {
            ToastHelper.showSuccess(context, 'Imported $importedCourses course, $importedSections sections, $importedLessons lessons.$warningText');
          }

          if (courseIds.isNotEmpty) {
            final firstCourseId = courseIds.first;
            if (mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => EditCoursePage(courseId: firstCourseId)),
              );
            }
          }
        }
      } else {
        throw Exception(_extractErrorMessage(responseBody));
      }
    } catch (e) {
      debugPrint('Error importing course Excel: $e');
      if (mounted) {
        ToastHelper.showError(context, 'Error importing Excel: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isImportingExcel = false;
        });
      }
    }
  }

  String _extractErrorMessage(String responseBody) {
    try {
      final data = jsonDecode(responseBody);
      if (data is Map && data['error'] != null) {
        return data['error'].toString();
      }
    } catch (_) {}
    return responseBody.isEmpty ? 'Import failed' : responseBody;
  }

  Future<bool> _confirmAction({
    required String title,
    required String message,
    required String confirmLabel,
    required Color confirmColor,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: Text(
          title,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontFamily: 'Outfit',
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          message,
          style: const TextStyle(
            color: Color(0xFF475569),
            fontFamily: 'Outfit',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 1024;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: InternalAppHeader(isMobile: !(isDesktop), activeTab: '',),
      drawer: !isDesktop ? const Drawer(child: CourseManagerSidebar(currentRoute: 'courses')) : null,
      body: Row(
        children: [
          if (isDesktop)
            const SizedBox(width: 240, child: CourseManagerSidebar(currentRoute: 'courses')),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildContentHeader(context, isDesktop),
                Expanded(
                  child: _buildContent(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF20B486)));
    }
    final courses = _displayedCourses;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildToolbar(constraints.maxWidth),
              if (_isMockPreview) ...[
                const SizedBox(height: 12),
                _buildMockBanner(),
              ],
              const SizedBox(height: 16),
              if (courses.isEmpty)
                _buildEmptyState()
              else
                _buildReviewTable(courses),
            ],
          ),
        );
      },
    );
  }

  Widget _buildToolbar(double width) {
    final compact = width < 760;

    final searchField = TextField(
      controller: _searchController,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: 'Search for courses...',
        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
        prefixIcon: const Icon(Icons.search, color: Color(0xFF94A3B8), size: 20),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
        DropdownMenuItem(value: 'NEWEST', child: Text('Sort by: Newest')),
        DropdownMenuItem(value: 'OLDEST', child: Text('Sort by: Oldest')),
        DropdownMenuItem(value: 'ALPHABETICAL', child: Text('Sort by: Alphabetical')),
      ],
      onChanged: (val) {
        if (val != null) {
          setState(() => _selectedSortBy = val);
        }
      },
    );

    final timePeriodDropdown = _buildDropdown(
      value: _selectedTimePeriod,
      items: const [
        DropdownMenuItem(value: 'ALL', child: Text('Time Period: All')),
        DropdownMenuItem(value: 'THIS_WEEK', child: Text('Time Period: This Week')),
        DropdownMenuItem(value: 'THIS_MONTH', child: Text('Time Period: This Month')),
      ],
      onChanged: (val) {
        if (val != null) {
          setState(() => _selectedTimePeriod = val);
        }
      },
    );

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
          // 1. Tabs row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildStatusFilter('All', 'ALL'),
                const SizedBox(width: 8),
                _buildStatusFilter('Pending', 'PENDING'),
                const SizedBox(width: 8),
                _buildStatusFilter('Published', 'PUBLISHED'),
                const SizedBox(width: 8),
                _buildStatusFilter('Rejected', 'REJECTED'),
                const SizedBox(width: 8),
                _buildStatusFilter('Hidden', 'HIDDEN'),
                const SizedBox(width: 8),
                _buildStatusFilter('Draft', 'DRAFT'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // 2. Filters controls row
          compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton.filledTonal(
                        tooltip: 'Refresh queue',
                        onPressed: _loadCourses,
                        icon: const Icon(Icons.refresh),
                        style: IconButton.styleFrom(
                          foregroundColor: const Color(0xFF20B486),
                          backgroundColor: const Color(0xFFE6F7F1),
                        ),
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(flex: 3, child: searchField),
                    const SizedBox(width: 16),
                    Expanded(flex: 1, child: sortByDropdown),
                    const SizedBox(width: 16),
                    Expanded(flex: 1, child: timePeriodDropdown),
                    const SizedBox(width: 16),
                    IconButton.filledTonal(
                      tooltip: 'Refresh queue',
                      onPressed: _loadCourses,
                      icon: const Icon(Icons.refresh),
                      style: IconButton.styleFrom(
                        foregroundColor: const Color(0xFF20B486),
                        backgroundColor: const Color(0xFFE6F7F1),
                      ),
                    ),
                  ],
                ),
        ],
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
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF64748B)),
          style: const TextStyle(
            color: Color(0xFF334155),
            fontSize: 14,
            fontFamily: 'Outfit',
            fontWeight: FontWeight.w500,
          ),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildStatusFilter(String label, String status) {
    final isActive = _statusFilter == status;
    return InkWell(
      onTap: () {
        setState(() => _statusFilter = status);
        _loadCourses();
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
                color: isActive ? const Color(0xFF0D9488) : const Color(0xFF64748B),
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                fontSize: 14,
                fontFamily: 'Outfit',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMockBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: Color(0xFFB45309), size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Previewing mock course submissions. The table will use live API data when the backend is available.',
              style: TextStyle(
                color: Color(0xFF92400E),
                fontSize: 13,
                fontFamily: 'Outfit',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewTable(List<CourseReviewCourse> courses) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: _buildTableHeaderRow(),
          ),
          // Data rows
          ...courses.asMap().entries.map((entry) {
            final idx = entry.key;
            final course = entry.value;
            return Column(
              children: [
                Container(
                  color: idx.isOdd ? const Color(0xFFFAFAFB) : Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  child: _buildTableDataRow(course),
                ),
                if (idx < courses.length - 1)
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTableHeaderRow() {
    const style = TextStyle(
      fontFamily: 'Outfit',
      fontWeight: FontWeight.w700,
      fontSize: 11,
      color: Color(0xFF64748B),
      letterSpacing: 0.5,
    );

    return Row(
      children: [
        const Expanded(flex: 28, child: Text('COURSE', style: style)),
        const Expanded(flex: 15, child: Text('TRAINER', style: style)),
        const Expanded(flex: 13, child: Text('CATEGORY', style: style)),
        const Expanded(flex: 13, child: Text('CONTENT', style: style)),
        const Expanded(flex: 10, child: Text('PRICE', style: style)),
        const Expanded(flex: 11, child: Text('STATUS', style: style)),
        const SizedBox(width: 170, child: Text('ACTION', style: style)),
      ],
    );
  }

  Widget _buildTableDataRow(CourseReviewCourse course) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(flex: 28, child: _CourseTitleCell(course: course)),
        Expanded(
          flex: 15,
          child: Text(
            course.creatorName,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontFamily: 'Outfit',
              fontSize: 13,
              color: Color(0xFF1E293B),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Expanded(
          flex: 13,
          child: Text(
            course.categoryName,
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontSize: 13,
              color: Color(0xFF1E293B),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Expanded(
          flex: 13,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${course.sectionsCount} sections',
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Color(0xFF1E293B),
                ),
              ),
              Text(
                '${course.lessonsCount} lessons',
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 12,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 10,
          child: Text(
            _formatPrice(course.price),
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontSize: 13,
              color: Color(0xFF1E293B),
            ),
          ),
        ),
        Expanded(flex: 11, child: _StatusPill(status: course.status)),
        SizedBox(
          width: 170,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton.icon(
                onPressed: () => _showCourseDetail(course),
                icon: const Icon(Icons.search_rounded, size: 15),
                label: const Text('Review'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF20B486),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  textStyle: const TextStyle(
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              if (course.status.toUpperCase() == 'PUBLISHED')
                TextButton.icon(
                  onPressed: () => _hideCourse(course),
                  icon: const Icon(Icons.visibility_off_outlined, size: 15),
                  label: const Text('Hide'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFD97706),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                    textStyle: const TextStyle(
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              if (course.status.toUpperCase() == 'HIDDEN')
                TextButton.icon(
                  onPressed: () => _unhideCourse(course),
                  icon: const Icon(Icons.visibility_outlined, size: 15),
                  label: const Text('Unhide'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF20B486),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                    textStyle: const TextStyle(
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Column(
        children: [
          Icon(Icons.fact_check_outlined, color: Color(0xFF94A3B8), size: 40),
          SizedBox(height: 12),
          Text(
            'No courses match this review queue.',
            style: TextStyle(
              color: Color(0xFF475569),
              fontWeight: FontWeight.w700,
              fontFamily: 'Outfit',
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Submitted trainer courses will appear here before learners can see them.',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 13,
              fontFamily: 'Outfit',
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildContentHeader(BuildContext context, bool isDesktop) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
      child: Row(
        children: [
          if (!isDesktop)
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu, color: Color(0xFF4B5563)),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
          const SizedBox(width: 8),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Course Review',
                  style: TextStyle(
                    color: Color(0xFF1E293B),
                    fontWeight: FontWeight.bold,
                    fontSize: 28,
                    fontFamily: 'Outfit',
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Review trainer submissions and publish approved courses to learners.',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 13,
                    fontFamily: 'Outfit',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              IconButton.filledTonal(
                tooltip: 'Refresh queue',
                onPressed: _loadCourses,
                icon: const Icon(Icons.refresh),
                style: IconButton.styleFrom(
                  foregroundColor: const Color(0xFF20B486),
                  backgroundColor: const Color(0xFFE6F7F1),
                ),
              ),
              if (_canCreateCourses) ...[
                OutlinedButton.icon(
                  onPressed: _isDownloadingTemplate ? null : _downloadImportTemplate,
                  icon: _isDownloadingTemplate
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF20B486)),
                        )
                      : const Icon(Icons.download_outlined, color: Color(0xFF20B486), size: 18),
                  label: const Text(
                    'Download Template',
                    style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF20B486),
                    side: const BorderSide(color: Color(0xFF20B486)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _isImportingExcel ? null : _importCourseExcel,
                  icon: _isImportingExcel
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF20B486)),
                        )
                      : const Icon(Icons.upload_file_outlined, color: Color(0xFF20B486), size: 18),
                  label: const Text(
                    'Import Excel',
                    style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF20B486),
                    side: const BorderSide(color: Color(0xFF99F6E4)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const CreateCoursePage()),
                    );
                    _loadCourses();
                  },
                  icon: const Icon(Icons.add, color: Colors.white, size: 18),
                  label: const Text(
                    'Create Course',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF38C9A6),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _CourseTitleCell extends StatelessWidget {
  final CourseReviewCourse course;

  const _CourseTitleCell({required this.course});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFE6F7F1),
              borderRadius: BorderRadius.circular(8),
            ),
            clipBehavior: Clip.antiAlias,
            child: course.thumbnailUrl.isEmpty
                ? const Icon(Icons.school_outlined, color: Color(0xFF20B486))
                : Image.network(
                    course.thumbnailUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.school_outlined,
                      color: Color(0xFF20B486),
                    ),
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Outfit',
                  ),
                ),
                Text(
                  '${course.code} - ${course.version}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                    fontFamily: 'Outfit',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;

  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final normalized = status.toUpperCase();
    final displayText = normalized == 'PENDING_APPROVAL'
        ? 'PENDING'
        : normalized;
    final color = switch (normalized) {
      'PUBLISHED' => const Color(0xFF20B486),
      'PENDING' || 'PENDING_APPROVAL' => const Color(0xFFF59E0B),
      'REJECTED' => const Color(0xFFEF4444),
      'HIDDEN' => const Color(0xFFD97706),
      'DRAFT' => const Color(0xFF64748B),
      _ => const Color(0xFF64748B),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        displayText,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 11,
          fontFamily: 'Outfit',
        ),
      ),
    );
  }
}

String _formatPrice(num price) {
  if (price <= 0) return 'Free';
  return '${price.toStringAsFixed(0)} VND';
}

final List<CourseReviewCourse> _mockCourses = [
  CourseReviewCourse(
    id: 101,
    title: 'THPT Grammar Intensive',
    code: 'ENG-GRM-101',
    creatorName: 'Nguyen Minh Trainer',
    categoryName: 'Grammar',
    difficultyName: 'Intermediate',
    description:
        'A focused grammar course for learners preparing for the national high school English exam.',
    objectives:
        'Master core grammar patterns\nPractice exam-style questions\nBuild confidence before mock tests',
    price: 0,
    version: 'v1.0',
    status: 'PENDING',
    thumbnailUrl: '',
    sectionsCount: 2,
    lessonsCount: 4,
    submittedAt: DateTime.now(),
    sessions: const [
      {
        'title': 'Core Tenses',
        'lessons': [
          {'title': 'Present and Past Tenses', 'itemType': 'text'},
          {'title': 'Perfect Tenses Practice', 'itemType': 'quiz'},
        ],
      },
      {
        'title': 'Clauses',
        'lessons': [
          {'title': 'Relative Clauses', 'itemType': 'video'},
          {'title': 'Adverbial Clauses Review', 'itemType': 'quiz'},
        ],
      },
    ],
  ),
];