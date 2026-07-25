import 'package:flutter/material.dart';

import '../../../data/services/course_manager_api.dart';
import '../../../utils/toast_helper.dart';
import '../../widgets/course_manager_sidebar.dart';
import '../../widgets/shared_header.dart';
import '../trainer/matrix_management_page.dart';
import 'course_manager_dashboard_page.dart';
import 'course_manager_exams_page.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import '../../../data/services/auth_service.dart';
import '../../../utils/config.dart';
import '../../../utils/download_helper.dart';
import '../trainer/create_course_page.dart';
import '../trainer/edit_course_page.dart';
import 'course_manager_question_bank_page.dart';

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
  bool _isLoading = true;
  bool _isMockPreview = false;
  bool _isDownloadingTemplate = false;
  bool _isImportingExcel = false;
  final AuthService _authService = AuthService();
  String get apiBaseUrl => EnvConfig.v1BaseUrl;

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<CourseReviewCourse> get _displayedCourses {
    final keyword = _searchController.text.trim().toLowerCase();
    return _courses.where((course) {
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
      builder: (context) => _CourseReviewDialog(
        course: detail,
        onReject: (String reason) {
          Navigator.pop(context);
          _rejectCourse(detail, reason: reason);
        },
        onPublish: () {
          Navigator.pop(context);
          _publishCourse(detail);
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
      appBar: SharedHeader(
        isDesktop: isDesktop,
        activeTab: '',
        hideNavLinks: true,
        hideCommerceActions: true,
      ),
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

    final search = SizedBox(
      width: compact ? double.infinity : 360,
      child: TextField(
        controller: _searchController,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B)),
          hintText: 'Search by course, trainer, or code',
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
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
      ),
    );

    final filters = Wrap(
      spacing: 8,
      children: [
        _buildStatusFilter('All', 'ALL'),
        _buildStatusFilter('Pending', 'PENDING'),
        _buildStatusFilter('Published', 'PUBLISHED'),
        _buildStatusFilter('Draft', 'DRAFT'),
      ],
    );

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [search, const SizedBox(height: 12), filters],
      );
    }

    return Row(
      children: [
        Expanded(child: filters),
        search,
        const SizedBox(width: 12),
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
    );
  }

  Widget _buildStatusFilter(String label, String status) {
    final selected = _statusFilter == status;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: const Color(0xFFE6F7F1),
      labelStyle: TextStyle(
        color: selected ? const Color(0xFF0F8B68) : const Color(0xFF475569),
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        fontFamily: 'Outfit',
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: selected ? const Color(0xFF20B486) : const Color(0xFFE2E8F0),
        ),
      ),
      onSelected: (_) {
        setState(() {
          _statusFilter = status;
        });
        _loadCourses();
      },
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
      color: Color(0xFF475569),
      fontWeight: FontWeight.bold,
      fontFamily: 'Outfit',
      fontSize: 12,
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
        const SizedBox(width: 88, child: Text('ACTION', style: style)),
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
          width: 88,
          child: TextButton.icon(
            onPressed: () => _showCourseDetail(course),
            icon: const Icon(Icons.search_rounded, size: 15),
            label: const Text('Review'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF20B486),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              textStyle: const TextStyle(
                fontFamily: 'Outfit',
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
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

  Widget _buildSidebar(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSidebarItem(
            Icons.dashboard,
            'Dashboard',
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const CourseManagerDashboardPage(),
                ),
              );
            },
          ),
          _buildSidebarItem(Icons.book_outlined, 'Courses', isActive: true),
          _buildSidebarItem(
            Icons.assignment_outlined,
            'Exam',
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const CourseManagerExamsPage(),
                ),
              );
            },
          ),
          _buildSidebarItem(
            Icons.grid_on,
            'Exam Matrix',
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => MatrixManagementPage(
                    onBack: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const CourseManagerDashboardPage(),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
          _buildSidebarItem(
            Icons.question_answer_outlined,
            'Question Bank',
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const CourseManagerQuestionBankPage(),
                ),
              );
            },
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(
    IconData icon,
    String title, {
    bool isActive = false,
    VoidCallback? onTap,
  }) {
    final activeColor = const Color(0xFF20B486);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
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
                color: isActive ? Colors.white : const Color(0xFF64748B),
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  color: isActive ? Colors.white : const Color(0xFF1F2937),
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

bool _isPendingStatus(String status) {
  final s = status.toUpperCase();
  return s == 'PENDING' || s == 'PENDING_APPROVAL';
}

class _CourseReviewDialog extends StatefulWidget {
  final CourseReviewCourse course;
  final ValueChanged<String> onReject;
  final VoidCallback onPublish;

  const _CourseReviewDialog({
    required this.course,
    required this.onReject,
    required this.onPublish,
  });

  @override
  State<_CourseReviewDialog> createState() => _CourseReviewDialogState();
}

class _CourseReviewDialogState extends State<_CourseReviewDialog> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _reasonController = TextEditingController();
  bool _hasScrolledAll = false;
  bool _showReasonInput = false;

  // Track which lesson IDs have been opened
  final Set<String> _viewedLessonKeys = {};
  late int _totalLessons;

  bool get _hasViewedAll {
    if (!_hasScrolledAll) return false;
    if (_totalLessons == 0) return true;
    return _viewedLessonKeys.length >= _totalLessons;
  }

  void _markLessonViewed(String key) {
    setState(() {
      _viewedLessonKeys.add(key);
    });
  }

  @override
  void initState() {
    super.initState();
    // Count total lessons
    _totalLessons = widget.course.sessions.fold<int>(0, (sum, session) {
      final map = session is Map ? session : const {};
      final lessons = map['lessons'] as List? ?? const [];
      return sum + lessons.length;
    });
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkIfScrolledAll();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_hasScrolledAll) return;
    _checkIfScrolledAll();
  }

  void _checkIfScrolledAll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (maxScroll <= 0 || currentScroll >= maxScroll - 20) {
      setState(() {
        _hasScrolledAll = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860, maxHeight: 780),
        child: Column(
          children: [
            _buildHeader(context),
            if (_isPendingStatus(widget.course.status))
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                color: _hasViewedAll
                    ? const Color(0xFFECFDF5)
                    : const Color(0xFFFFFBEB),
                child: Row(
                  children: [
                    Icon(
                      _hasViewedAll
                          ? Icons.check_circle_outline
                          : Icons.info_outline,
                      color: _hasViewedAll
                          ? const Color(0xFF059669)
                          : const Color(0xFFB45309),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _hasViewedAll
                          ? const Text(
                              'All content reviewed. You may now approve or reject.',
                              style: TextStyle(
                                color: Color(0xFF065F46),
                                fontFamily: 'Outfit',
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          : Text(
                              _hasScrolledAll
                                  ? 'Open each lesson below to review its content (${_viewedLessonKeys.length}/$_totalLessons viewed).'
                                  : 'Scroll down to review all information, then open each lesson.',
                              style: const TextStyle(
                                color: Color(0xFF92400E),
                                fontFamily: 'Outfit',
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.course.thumbnailUrl.isNotEmpty) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          widget.course.thumbnailUrl,
                          height: 220,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const SizedBox(),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _InfoTile(label: 'Trainer', value: widget.course.creatorName),
                        _InfoTile(label: 'Code', value: widget.course.code),
                        _InfoTile(
                          label: 'Category',
                          value: widget.course.categoryName,
                        ),
                        _InfoTile(label: 'Level', value: widget.course.difficultyName),
                        _InfoTile(label: 'Version', value: widget.course.version),
                        _InfoTile(
                          label: 'Price',
                          value: _formatPrice(widget.course.price),
                        ),
                        _InfoTile(
                          label: 'Content',
                          value:
                              '${widget.course.sectionsCount} sections / ${widget.course.lessonsCount} lessons',
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _SectionBlock(
                      title: 'Description',
                      content: widget.course.description.isEmpty
                          ? 'No description provided.'
                          : widget.course.description,
                    ),
                    const SizedBox(height: 16),
                    _SectionBlock(
                      title: 'Objectives',
                      content: widget.course.objectives.isEmpty
                          ? 'No objectives provided.'
                          : widget.course.objectives,
                    ),
                    if (widget.course.sessions.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _SyllabusPreview(
                        sessions: widget.course.sessions,
                        viewedLessonKeys: _viewedLessonKeys,
                        onLessonViewed: _markLessonViewed,
                      ),
                    ],
                    const SizedBox(height: 40), // extra space to ensure scrolling
                  ],
                ),
              ),
            ),
            if (_showReasonInput)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFFFEF2F2),
                  border: Border(top: BorderSide(color: Color(0xFFFECACA))),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Rejection Reason',
                      style: TextStyle(
                        color: Color(0xFF991B1B),
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Outfit',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _reasonController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Please provide a reason for rejecting this course...',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFFCA5A5)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFFCA5A5)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _showReasonInput = false;
                              _reasonController.clear();
                            });
                          },
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            if (_reasonController.text.trim().isEmpty) {
                              ToastHelper.showError(context, 'Please enter a rejection reason.');
                              return;
                            }
                            widget.onReject(_reasonController.text.trim());
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEF4444),
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Confirm Rejection'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: (_isPendingStatus(widget.course.status) && _hasViewedAll)
                        ? () {
                            setState(() {
                              _showReasonInput = !_showReasonInput;
                            });
                          }
                        : null,
                    icon: const Icon(Icons.undo_outlined),
                    label: const Text('Return to Draft'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                      side: const BorderSide(color: Color(0xFFEF4444)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: (_isPendingStatus(widget.course.status) && _hasViewedAll)
                        ? widget.onPublish
                        : null,
                    icon: const Icon(Icons.check),
                    label: const Text('Publish'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF20B486),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.course.title,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    fontFamily: 'Outfit',
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _StatusPill(status: widget.course.status),
                    const SizedBox(width: 8),
                    const Text(
                      'DRAFT → PENDING → PUBLISHED',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12,
                        fontFamily: 'Outfit',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Close',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;

  const _InfoTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.w700,
              fontFamily: 'Outfit',
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionBlock extends StatelessWidget {
  final String title;
  final String content;

  const _SectionBlock({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
            fontFamily: 'Outfit',
          ),
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: const TextStyle(
            color: Color(0xFF475569),
            height: 1.5,
            fontFamily: 'Outfit',
          ),
        ),
      ],
    );
  }
}

class _SyllabusPreview extends StatelessWidget {
  final List<dynamic> sessions;
  final Set<String> viewedLessonKeys;
  final void Function(String key) onLessonViewed;

  const _SyllabusPreview({
    required this.sessions,
    required this.viewedLessonKeys,
    required this.onLessonViewed,
  });

  IconData _lessonIcon(String? type) {
    switch ((type ?? '').toLowerCase()) {
      case 'video':
        return Icons.play_circle_outline_rounded;
      case 'quiz':
        return Icons.quiz_outlined;
      case 'pdf':
        return Icons.picture_as_pdf_outlined;
      default:
        return Icons.article_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Course Syllabus',
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.bold,
                fontSize: 15,
                fontFamily: 'Outfit',
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFE6F7F1),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${sessions.length} sections',
                style: const TextStyle(
                  color: Color(0xFF0F8B68),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Outfit',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Tap each lesson to review its content.',
          style: TextStyle(
            color: Color(0xFF64748B),
            fontSize: 12,
            fontFamily: 'Outfit',
          ),
        ),
        const SizedBox(height: 12),
        ...sessions.asMap().entries.map((sEntry) {
          final sIdx = sEntry.key;
          final session = sEntry.value;
          final map = session is Map ? session : const {};
          final lessons = map['lessons'] as List? ?? const [];
          final sectionId = map['id']?.toString() ?? 'sec-$sIdx';

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Theme(
              data: Theme.of(context).copyWith(
                dividerColor: Colors.transparent,
              ),
              child: ExpansionTile(
                initiallyExpanded: true,
                tilePadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                childrenPadding: EdgeInsets.zero,
                title: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: const Color(0xFF20B486),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${sIdx + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          fontFamily: 'Outfit',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        map['title']?.toString() ?? 'Untitled section',
                        style: const TextStyle(
                          color: Color(0xFF1E293B),
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          fontFamily: 'Outfit',
                        ),
                      ),
                    ),
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(left: 38, top: 2),
                  child: Text(
                    '${lessons.length} lessons',
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                      fontFamily: 'Outfit',
                    ),
                  ),
                ),
                children: [
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  ...lessons.asMap().entries.map((lEntry) {
                    final lIdx = lEntry.key;
                    final lesson = lEntry.value;
                    final lessonMap =
                        lesson is Map ? lesson : const {};
                    final lessonKey = '${sectionId}_$lIdx';
                    final isViewed = viewedLessonKeys.contains(lessonKey);
                    final itemType = lessonMap['itemType']?.toString();
                    final title =
                        lessonMap['title']?.toString() ??
                        'Untitled lesson';
                    final description =
                        lessonMap['description']?.toString() ?? '';
                    final content =
                        lessonMap['questionText']?.toString() ?? '';

                    return InkWell(
                      onTap: () {
                        onLessonViewed(lessonKey);
                        showDialog(
                          context: context,
                          builder: (ctx) => _LessonDetailDialog(
                            title: title,
                            itemType: itemType ?? 'lesson',
                            description: description,
                            content: content,
                            lessonMap: lessonMap,
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isViewed
                              ? const Color(0xFFF0FDF4)
                              : Colors.white,
                          border: lIdx < lessons.length - 1
                              ? const Border(
                                  bottom: BorderSide(
                                    color: Color(0xFFF1F5F9),
                                  ),
                                )
                              : null,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: isViewed
                                    ? const Color(0xFFD1FAE5)
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                isViewed
                                    ? Icons.check_rounded
                                    : _lessonIcon(itemType),
                                color: isViewed
                                    ? const Color(0xFF059669)
                                    : const Color(0xFF94A3B8),
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: TextStyle(
                                      fontFamily: 'Outfit',
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: isViewed
                                          ? const Color(0xFF065F46)
                                          : const Color(0xFF1E293B),
                                    ),
                                  ),
                                  if (itemType != null)
                                    Text(
                                      itemType.toUpperCase(),
                                      style: const TextStyle(
                                        fontFamily: 'Outfit',
                                        fontSize: 11,
                                        color: Color(0xFF94A3B8),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: isViewed
                                  ? const Color(0xFF059669)
                                  : const Color(0xFFCBD5E1),
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _LessonDetailDialog extends StatelessWidget {
  final String title;
  final String itemType;
  final String description;
  final String content;
  final Map lessonMap;

  const _LessonDetailDialog({
    required this.title,
    required this.itemType,
    required this.description,
    required this.content,
    required this.lessonMap,
  });

  IconData get _icon {
    switch (itemType.toLowerCase()) {
      case 'video':
        return Icons.play_circle_outline_rounded;
      case 'quiz':
        return Icons.quiz_outlined;
      case 'pdf':
        return Icons.picture_as_pdf_outlined;
      default:
        return Icons.article_outlined;
    }
  }

  Color get _iconColor {
    switch (itemType.toLowerCase()) {
      case 'video':
        return const Color(0xFF8B5CF6);
      case 'quiz':
        return const Color(0xFF3B82F6);
      case 'pdf':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF20B486);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _iconColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(_icon, color: _iconColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _iconColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            itemType.toUpperCase(),
                            style: TextStyle(
                              color: _iconColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Outfit',
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF94A3B8)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (description.isNotEmpty) ...[
                      const Text(
                        'Description',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF475569),
                          fontSize: 12,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        description,
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          color: Color(0xFF1E293B),
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (content.isNotEmpty) ...[
                      const Text(
                        'Content',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF475569),
                          fontSize: 12,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          content,
                          style: const TextStyle(
                            fontFamily: 'Outfit',
                            color: Color(0xFF1E293B),
                            height: 1.6,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    // Extra info from lessonMap
                    _buildExtraInfo(),
                    if (description.isEmpty && content.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'No detailed content available for this lesson.',
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              color: Color(0xFF94A3B8),
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF20B486),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Done',
                      style: TextStyle(fontFamily: 'Outfit'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExtraInfo() {
    final chips = <Widget>[];
    final estimatedTime = lessonMap['estimatedTime'];
    final pdfName = lessonMap['pdfName']?.toString() ?? '';
    if (estimatedTime != null) {
      chips.add(_infoChip(Icons.timer_outlined, '$estimatedTime min'));
    }
    if (pdfName.isNotEmpty) {
      chips.add(_infoChip(Icons.attach_file_outlined, pdfName));
    }
    if (chips.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }

  Widget _infoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF64748B)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontSize: 12,
              color: Color(0xFF475569),
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